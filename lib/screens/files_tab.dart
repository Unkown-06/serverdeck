import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../services/uploader.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/dialogs.dart';
import '../widgets/glass_card.dart';

/// The Files tab: browse the server's folders, upload from the phone,
/// download to the phone, rename, delete and make folders.
class FilesTab extends StatefulWidget {
  final Api api;
  const FilesTab({super.key, required this.api});

  @override
  State<FilesTab> createState() => FilesTabState();
}

class _UploadJob {
  final String name;
  final int total;
  final int index;
  final int count;
  final CancelToken cancel = CancelToken();
  int sent = 0;
  _UploadJob(this.name, this.total, this.index, this.count);
}

class FilesTabState extends State<FilesTab> {
  String? _path;
  String? _parent;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  bool _showHidden = true;
  _UploadJob? _job;
  DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  /// Called by the home screen when the phone's back button is pressed.
  /// Returns true if we went up one folder.
  bool goUp() {
    if (_parent == null) return false;
    _load(_parent);
    return true;
  }

  String _full(String name) => _path == '/' ? '/$name' : '$_path/$name';

  Future<void> _load(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = '/files/list?path=${Uri.encodeQueryComponent(path ?? '')}&hidden=${_showHidden ? 1 : 0}';
      final r = Map<String, dynamic>.from((await api.get(q)) as Map);
      if (!mounted) return;
      setState(() {
        _path = r['path'] as String;
        _parent = r['parent'] as String?;
        _entries = (r['entries'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------ actions
  Future<void> _newFolder() async {
    final name = await askText(context, title: 'New folder', label: 'Folder name', confirmLabel: 'Create');
    if (name == null || _path == null) return;
    try {
      await api.post('/files/mkdir', {'path': _path, 'name': name});
      _load(_path);
    } catch (e) {
      _snack(errorText(e));
    }
  }

  Future<void> _rename(Map<String, dynamic> entry) async {
    final name = await askText(
      context,
      title: 'Rename',
      label: 'New name',
      initial: entry['name'] as String,
      confirmLabel: 'Rename',
    );
    if (name == null || name == entry['name']) return;
    try {
      await api.post('/files/rename', {'path': _full(entry['name'] as String), 'new_name': name});
      _load(_path);
    } catch (e) {
      _snack(errorText(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final isDir = entry['is_dir'] == true;
    final name = entry['name'] as String;
    final ok = await confirmDialog(
      context,
      title: 'Delete $name?',
      message: isDir
          ? 'The folder and everything inside it will be deleted. This cannot be undone.'
          : 'The file will be deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    try {
      await api.post('/files/delete', {'path': _full(name), 'recursive': isDir});
      _load(_path);
    } catch (e) {
      _snack(errorText(e));
    }
  }

  /// The phone's browser downloads the file (progress shows in its notification).
  Future<void> _download(Map<String, dynamic> entry) async {
    try {
      final r = Map<String, dynamic>.from(
        (await api.post('/files/link', {'path': _full(entry['name'] as String)})) as Map,
      );
      final ok = await launchUrl(api.url(r['url'] as String), mode: LaunchMode.externalApplication);
      _snack(ok ? 'Download started in your browser' : 'Could not open the browser');
    } catch (e) {
      _snack(errorText(e));
    }
  }

  Future<void> _pickAndUpload() async {
    if (_path == null) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    final files = result.files;
    for (var i = 0; i < files.length; i++) {
      final keepGoing = await _uploadOne(files[i], i + 1, files.length);
      if (!keepGoing) break;
    }
    _load(_path);
  }

  void _progressTick() {
    final now = DateTime.now();
    if (now.difference(_lastUi).inMilliseconds > 150 && mounted) {
      _lastUi = now;
      setState(() {});
    }
  }

  /// Returns false if the user cancelled or it failed (stop the rest).
  Future<bool> _uploadOne(PlatformFile f, int index, int count) async {
    final path = f.path;
    if (path == null) {
      _snack('Could not read ${f.name}');
      return true;
    }
    var overwrite = false;
    if (_entries.any((e) => e['name'] == f.name)) {
      final ok = await confirmDialog(
        context,
        title: 'Replace ${f.name}?',
        message: 'A file with this name already exists in this folder.',
        confirmLabel: 'Replace',
      );
      if (!ok) return true;
      overwrite = true;
    }
    final job = _UploadJob(f.name, f.size, index, count);
    setState(() => _job = job);
    try {
      await uploadFile(
        api: api,
        folder: _path!,
        name: f.name,
        localPath: path,
        size: f.size,
        overwrite: overwrite,
        cancel: job.cancel,
        onProgress: (sent) {
          job.sent = sent;
          _progressTick();
        },
      );
      _snack('Uploaded ${f.name}');
      return true;
    } on UploadCancelled {
      _snack('Upload cancelled');
      return false;
    } catch (e) {
      _snack(errorText(e));
      return false;
    } finally {
      if (mounted) setState(() => _job = null);
    }
  }

  void _showActions(Map<String, dynamic> entry) {
    final isDir = entry['is_dir'] == true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_iconFor(entry), color: _colorFor(entry)),
              title: Text(entry['name'] as String, overflow: TextOverflow.ellipsis),
              subtitle: Text(isDir ? 'Folder' : fmtBytes(entry['size'] as num?)),
            ),
            const Divider(height: 1),
            if (!isDir)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download to phone'),
                onTap: () {
                  Navigator.pop(ctx);
                  _download(entry);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.bad),
              title: const Text('Delete', style: TextStyle(color: AppColors.bad)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ look
  IconData _iconFor(Map<String, dynamic> e) {
    if (e['is_dir'] == true) return Icons.folder_rounded;
    final name = (e['name'] as String).toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return Icons.image_rounded;
    if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) return Icons.movie_rounded;
    if (['mp3', 'flac', 'wav', 'ogg', 'm4a'].contains(ext)) return Icons.audiotrack_rounded;
    if (['zip', 'tar', 'gz', 'xz', '7z', 'rar', 'bz2'].contains(ext)) return Icons.archive_rounded;
    if (['txt', 'md', 'log', 'conf', 'cfg', 'ini', 'json', 'yml', 'yaml', 'sh', 'py'].contains(ext)) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _colorFor(Map<String, dynamic> e) {
    if (e['is_dir'] == true) return AppColors.warn;
    return AppColors.accent2;
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: job == null && _path != null ? _pickAndUpload : null,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _parent == null ? null : () => _load(_parent),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: 'Up one folder',
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _path ?? '...',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _path == null ? null : _newFolder,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    tooltip: 'New folder',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) {
                      if (v == 'home') _load(null);
                      if (v == 'root') _load('/');
                      if (v == 'refresh') _load(_path);
                      if (v == 'hidden') {
                        setState(() => _showHidden = !_showHidden);
                        _load(_path);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'home', child: Text('Go to home folder')),
                      const PopupMenuItem(value: 'root', child: Text('Go to / (top)')),
                      const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                      PopupMenuItem(
                        value: 'hidden',
                        child: Text(_showHidden ? 'Hide hidden files' : 'Show hidden files'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (job != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Uploading ${job.name}${job.count > 1 ? '  (${job.index}/${job.count})' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => job.cancel.cancelled = true,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: job.total == 0 ? null : (job.sent / job.total).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtBytes(job.sent)} of ${fmtBytes(job.total)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.bad),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _load(_path), child: const Text('Try again')),
              if (_parent != null)
                TextButton(onPressed: () => _load(_parent), child: const Text('Go up')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('This folder is empty', style: TextStyle(color: AppColors.muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(_path),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final e = _entries[i];
          final isDir = e['is_dir'] == true;
          final subtitle = [
            isDir ? 'Folder' : fmtBytes(e['size'] as num?),
            if (e['modified'] != null) fmtDate(e['modified'] as num),
          ].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colorFor(e).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(e), color: _colorFor(e), size: 22),
                ),
                title: Text(e['name'] as String, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => _showActions(e),
                ),
                onTap: () => isDir ? _load(_full(e['name'] as String)) : _showActions(e),
                onLongPress: () => _showActions(e),
              ),
            ),
          );
        },
      ),
    );
  }
}
