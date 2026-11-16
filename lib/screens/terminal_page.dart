import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';

/// A real command line on the server.
/// Only administrators can open it, and it asks for the password again.
class TerminalPage extends StatefulWidget {
  final Api api;
  const TerminalPage({super.key, required this.api});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final Terminal _terminal = Terminal(maxLines: 5000);
  final TerminalController _controller = TerminalController();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected = false;
  bool _ctrl = false; // the Ctrl button is armed for the next key
  String? _status; // message shown over the terminal
  double _fontSize = 13;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = _onInput;
    _terminal.onResize = (w, h, pw, ph) => _send({'type': 'resize', 'cols': w, 'rows': h});
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close(1000);
    } catch (_) {}
    _channel = null;
    _connected = false;
  }

  Future<void> _start() async {
    final pw = await askPassword(
      context,
      title: 'Open terminal',
      message: 'Enter your password to open a terminal on the server.',
      confirmLabel: 'Open',
    );
    if (!mounted) return;
    if (pw == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _status = 'Connecting...');
    try {
      final channel = WebSocketChannel.connect(widget.api.wsUri('/terminal'));
      await channel.ready;
      _channel = channel;
      channel.sink.add(jsonEncode({
        'token': widget.api.token,
        'password': pw,
        'rows': _terminal.viewHeight,
        'cols': _terminal.viewWidth,
      }));
      _sub = channel.stream.listen(
        (data) {
          if (!_connected && mounted) {
            setState(() {
              _connected = true;
              _status = null;
            });
          }
          _terminal.write(data.toString());
        },
        onDone: () => _closed(channel),
        onError: (Object e) => _closed(channel, error: e),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not connect. ${errorText(e)}');
    }
  }

  void _closed(WebSocketChannel channel, {Object? error}) {
    if (!mounted || channel != _channel) return;
    final reason = channel.closeReason;
    final text = error != null
        ? 'Connection lost.'
        : (reason != null && reason.isNotEmpty ? reason : 'Disconnected.');
    _terminal.write('\r\n[$text]\r\n');
    setState(() {
      _connected = false;
      _status = text;
    });
  }

  Future<void> _reconnect() async {
    _disconnect();
    setState(() => _status = null);
    await _start();
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  /// Keys typed on the phone keyboard arrive here.
  void _onInput(String data) {
    var out = data;
    if (_ctrl) {
      if (data.length == 1) {
        final c = data.toLowerCase().codeUnitAt(0);
        if (c >= 97 && c <= 122) out = String.fromCharCode(c - 96); // Ctrl+A..Z
      }
      setState(() => _ctrl = false);
    }
    _send({'type': 'input', 'data': out});
  }

  void _key(String sequence) => _send({'type': 'input', 'data': sequence});

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text != null && text.isNotEmpty) _key(text);
  }

  Widget _keyButton(String label, VoidCallback onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Material(
        color: active ? AppColors.accent : AppColors.cardHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? AppColors.onAccent : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keysBar() {
    return Container(
      color: AppColors.card,
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _keyButton('Esc', () => _key('\x1b')),
          _keyButton('Tab', () => _key('\t')),
          _keyButton('Ctrl', () => setState(() => _ctrl = !_ctrl), active: _ctrl),
          _keyButton('^C', () => _key('\x03')),
          _keyButton('^D', () => _key('\x04')),
          _keyButton('↑', () => _key('\x1b[A')),
          _keyButton('↓', () => _key('\x1b[B')),
          _keyButton('←', () => _key('\x1b[D')),
          _keyButton('→', () => _key('\x1b[C')),
          _keyButton('Home', () => _key('\x1b[H')),
          _keyButton('End', () => _key('\x1b[F')),
          _keyButton('PgUp', () => _key('\x1b[5~')),
          _keyButton('PgDn', () => _key('\x1b[6~')),
          _keyButton('|', () => _key('|')),
          _keyButton('/', () => _key('/')),
          _keyButton('~', () => _key('~')),
          _keyButton('-', () => _key('-')),
          _keyButton('Paste', _paste),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Icon(Icons.circle, size: 10, color: _connected ? AppColors.good : AppColors.warn),
            const SizedBox(width: 10),
            const Text('Terminal'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(8, 24).toDouble()),
          ),
          IconButton(
            tooltip: 'Bigger text',
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(8, 24).toDouble()),
          ),
          IconButton(
            tooltip: 'Reconnect',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reconnect,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  TerminalView(
                    _terminal,
                    controller: _controller,
                    autofocus: true,
                    padding: const EdgeInsets.all(6),
                    textStyle: TerminalStyle(fontSize: _fontSize),
                  ),
                  if (_status != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: Material(
                        color: AppColors.cardHigh,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(child: Text(_status!)),
                              if (!_connected)
                                TextButton(onPressed: _reconnect, child: const Text('Reconnect')),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _keysBar(),
          ],
        ),
      ),
    );
  }
}
