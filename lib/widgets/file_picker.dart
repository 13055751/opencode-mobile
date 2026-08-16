import 'package:flutter/material.dart';

import '../api.dart';
import '../logs.dart';
import '../models.dart';

/// Browses the server's filesystem and returns an absolute file path (or
/// directory path when [pickDirectories] is true).
class ServerFilePickerPage extends StatefulWidget {
  final OpenCodeApi api;
  final String initialDirectory;
  final bool pickDirectories;
  const ServerFilePickerPage({
    super.key,
    required this.api,
    required this.initialDirectory,
    this.pickDirectories = false,
  });

  @override
  State<ServerFilePickerPage> createState() => _ServerFilePickerPageState();
}

class _ServerFilePickerPageState extends State<ServerFilePickerPage> {
  late String _current = widget.initialDirectory;
  List<FileEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.listFiles(_current);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      AppLog.instance.error('picker', 'list files $dir failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _parentOf(String path) {
    final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final idx = trimmed.lastIndexOf('/');
    if (idx <= 0) return '/';
    return trimmed.substring(0, idx);
  }

  void _enter(String dir) {
    setState(() => _current = dir);
    _load();
  }

  void _pick(String path) => Navigator.of(context).pop(path);

  @override
  Widget build(BuildContext context) {
    final entries = [..._entries]
      ..sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择文件'),
        actions: [
          if (widget.pickDirectories)
            TextButton(
              onPressed: () => _pick(_current),
              child: const Text('使用此文件夹'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF14161C),
            child: Text(
              _current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('重试'),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          if (_current != '/')
                            ListTile(
                              leading: const Icon(Icons.subdirectory_arrow_left, color: Colors.white38),
                              title: const Text('..', style: TextStyle(color: Colors.white70)),
                              onTap: () => _enter(_parentOf(_current)),
                            ),
                          for (final e in entries)
                            ListTile(
                              leading: Icon(
                                e.isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                                color: e.isDir ? const Color(0xFF6C5CE7) : Colors.white38,
                              ),
                              title: Text(
                                e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: e.isDir && widget.pickDirectories
                                  ? const Icon(Icons.chevron_right, size: 18, color: Colors.white24)
                                  : null,
                              onTap: () {
                                if (e.isDir) {
                                  _enter(e.absolute);
                                } else if (widget.pickDirectories) {
                                  // folders only
                                } else {
                                  _pick(e.absolute);
                                }
                              },
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}