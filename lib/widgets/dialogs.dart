import 'package:flutter/material.dart';

import '../theme.dart';

/// Asks for the password again. Returns null if the user cancels.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continue',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PasswordDialog(title: title, message: message, confirmLabel: confirmLabel),
  );
}

class _PasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  const _PasswordDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            obscureText: _hide,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: fieldDecoration(
              'Password',
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// A yes/no question. Returns true only if the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.bad, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Asks for a line of text (new folder name, new file name...). Null if cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = 'OK',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextDialog(title: title, label: label, initial: initial, confirmLabel: confirmLabel),
  );
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initial;
  final String confirmLabel;
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: fieldDecoration(widget.label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
