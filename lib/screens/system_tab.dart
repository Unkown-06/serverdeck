import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../services/session_store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/dialogs.dart';
import '../widgets/glass_card.dart';
import 'update_page.dart';

/// The System tab: server info, updates, restart / shut down, terminal,
/// notifications and your account.
class SystemTab extends StatefulWidget {
  final Api api;
  final SessionStore store;
  final Map<String, dynamic>? info;
  final void Function(String? message) onLogout;
  final VoidCallback onOpenTerminal;

  const SystemTab({
    super.key,
    required this.api,
    required this.store,
    required this.info,
    required this.onLogout,
    required this.onOpenTerminal,
  });

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  Map<String, dynamic>? _pending;
  bool _checking = false;
  bool _ntfyEnabled = false;
  String _ntfyUrl = '';

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    if (api.role == 'administrator') _loadAlertSettings();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadAlertSettings() async {
    try {
      final r = Map<String, dynamic>.from((await api.get('/alerts/settings')) as Map);
      if (!mounted) return;
      setState(() {
        _ntfyEnabled = r['ntfy_enabled'] == true;
        _ntfyUrl = (r['ntfy_url'] as String?) ?? '';
      });
    } catch (_) {}
  }

  // ------------------------------------------------------------ updates
  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      final r = await api.get('/system/updates');
      if (mounted) setState(() => _pending = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _runUpdate() async {
    final ok = await confirmDialog(
      context,
      title: 'Update the server?',
      message:
          'This installs all available Ubuntu updates. It can take several minutes and some programs may restart.',
      confirmLabel: 'Continue',
    );
    if (!ok || !mounted) return;
    final pw = await askPassword(
      context,
      title: 'Confirm with your password',
      message: 'Enter your password to start the update.',
      confirmLabel: 'Start update',
    );
    if (pw == null || !mounted) return;
    try {
      await api.post('/system/update', {'password': pw});
    } on ApiException catch (e) {
      // 409 = an update is already running: just show its progress.
      if (e.statusCode != 409) {
        _snack(e.message);
        return;
      }
    } catch (e) {
      _snack(errorText(e));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UpdatePage(api: api)));
  }

  // ------------------------------------------------------------ power
  Future<void> _power(String action) async {
    final restart = action == 'reboot';
    final ok = await confirmDialog(
      context,
      title: restart ? 'Restart the server?' : 'Shut down the server?',
      message: restart
          ? 'The server will restart. Your apps and files will be unavailable for a minute or two.'
          : 'The server will turn off. You will have to switch it on again by hand.',
      confirmLabel: restart ? 'Restart' : 'Shut down',
      danger: true,
    );
    if (!ok || !mounted) return;
    final pw = await askPassword(
      context,
      title: 'Confirm with your password',
      message: 'Enter your password to ${restart ? 'restart' : 'shut down'} the server.',
      confirmLabel: restart ? 'Restart' : 'Shut down',
    );
    if (pw == null || !mounted) return;
    try {
      await api.post('/power/$action', {'password': pw});
    } catch (e) {
      _snack(errorText(e));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(restart ? 'Restarting...' : 'Shutting down...'),
        content: Text(restart
            ? 'The server is restarting. The app will reconnect on its own when it is back.'
            : 'The server is shutting down. The app cannot reach it until you switch it on again.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  // ------------------------------------------------------------ account
  Future<void> _changePassword() async {
    final old = await askPassword(
      context,
      title: 'Change password',
      message: 'Enter your current password.',
    );
    if (old == null || !mounted) return;
    final fresh = await askPassword(
      context,
      title: 'New password',
      message: 'Choose a new password (at least 8 characters).',
      confirmLabel: 'Change',
    );
    if (fresh == null || !mounted) return;
    try {
      await api.post('/me/password', {'old_password': old, 'new_password': fresh});
      _snack('Password changed');
    } catch (e) {
      _snack(errorText(e));
    }
  }

  Future<void> _editHomeHost() async {
    final value = await askText(
      context,
      title: 'Home address',
      label: 'e.g. 192.168.1.20',
      initial: api.openHost,
      confirmLabel: 'Save',
    );
    if (value == null) return;
    api.openHost = value;
    await widget.store.setHomeHost(value);
    if (mounted) setState(() {});
  }

  Future<void> _testAlert() async {
    try {
      await api.post('/alerts/test');
      _snack('Test alert sent. Check the bell.');
    } catch (e) {
      _snack(errorText(e));
    }
  }

  // ------------------------------------------------------------ look
  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap,
      {Color? color, bool busy = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: busy ? null : onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: (color ?? AppColors.accent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon, color: color ?? AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final pending = _pending;
    String updateSubtitle = 'See if Ubuntu updates are waiting';
    if (pending != null) {
      final n = pending['pending'];
      updateSubtitle = n == null
          ? 'Could not check'
          : (n == 0 ? 'Everything is up to date' : '$n updates are available');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        if (info != null) ...[
          const SectionTitle('This server'),
          GlassCard(
            child: Column(
              children: [
                KeyValueRow('Name', (info['hostname'] as String?) ?? ''),
                KeyValueRow('System', (info['os'] as String?) ?? ''),
                KeyValueRow('Kernel', (info['kernel'] as String?) ?? ''),
                KeyValueRow('Uptime', fmtUptime((info['uptime_seconds'] as num?) ?? 0)),
                if (info['reboot_required'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        StatusPill('Restart needed', AppColors.warn, icon: Icons.restart_alt_rounded),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (api.can('terminal')) ...[
          const SectionTitle('Terminal'),
          _tile(Icons.terminal_rounded, 'Open terminal', 'A command line on your server',
              widget.onOpenTerminal),
        ],
        if (api.can('system_update')) ...[
          const SectionTitle('Updates'),
          _tile(Icons.search_rounded, 'Check for updates', updateSubtitle, _checkUpdates,
              busy: _checking),
          _tile(Icons.system_update_alt_rounded, 'Update server', 'Install all Ubuntu updates',
              _runUpdate),
        ],
        if (api.can('power')) ...[
          const SectionTitle('Power'),
          _tile(Icons.restart_alt_rounded, 'Restart server', 'Reboots the whole computer',
              () => _power('reboot'),
              color: AppColors.warn),
          _tile(Icons.power_settings_new_rounded, 'Shut down server', 'Turns the computer off',
              () => _power('shutdown'),
              color: AppColors.bad),
        ],
        const SectionTitle('Notifications'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ServerDeck watches CPU, memory, disk, temperature and your Docker apps. '
                'Problems appear under the bell at the top of the app.',
              ),
              if (api.role == 'administrator') ...[
                const SizedBox(height: 12),
                if (_ntfyEnabled) ...[
                  const StatusPill('Phone notifications are on', AppColors.good,
                      icon: Icons.notifications_active_rounded),
                  const SizedBox(height: 8),
                  const Text(
                    'In the ntfy app on your phone, subscribe to this topic:',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _ntfyUrl,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _ntfyUrl));
                          _snack('Copied');
                        },
                      ),
                    ],
                  ),
                ] else
                  const Text(
                    'To also get notifications on your phone while the app is closed, set '
                    'NTFY_TOPIC in config.py on the server and install the free ntfy app '
                    '(see the README).',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _testAlert,
                icon: const Icon(Icons.notifications_rounded, size: 18),
                label: const Text('Send a test alert'),
              ),
            ],
          ),
        ),
        const SectionTitle('Account'),
        GlassCard(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.cardHigh,
                child: Icon(Icons.person_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(api.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(cap(api.role), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _tile(
          Icons.home_rounded,
          'Home address for Open buttons',
          api.openHost.isEmpty ? 'Same as the server address' : api.openHost,
          _editHomeHost,
        ),
        _tile(Icons.lock_rounded, 'Change password', '', _changePassword),
        _tile(Icons.logout_rounded, 'Log out', 'Also forgets the saved login on this phone',
            () => widget.onLogout(null),
            color: AppColors.bad),
      ],
    );
  }
}
