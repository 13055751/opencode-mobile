import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

/// Full-screen server directory browser. Lets the user pick an existing
/// directory or create a new one via a one-shot PTY mkdir.
class DirectoryPickerPage extends StatefulWidget {
  final OpenCodeApi api;
  final String initialDirectory;
  const DirectoryPickerPage({super.key, required this.api, required this.initialDirectory});

  @override
  State<DirectoryPickerPage> createState() => _DirectoryPickerPageState();
}

class _DirectoryPickerPageState extends State<DirectoryPickerPage> {
  late String _current;
  List<FileEntry> _entries = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = widget.initialDirectory.isEmpty ? '/' : widget.initialDirectory;
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
        _entries = list.where((e) => e.isDir).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  String get _parent {
    final c = _current;
    if (c == '/' || c.isEmpty) return c;
    final i = c.lastIndexOf('/');
    return i <= 0 ? '/' : c.substring(0, i);
  }

  Future<void> _enter(String abs) async {
    _current = abs;
    await _load();
  }

  Future<void> _pick() async {
    Navigator.of(context).pop(_current);
  }

  Future<void> _createNew() async {
    final parent = _parent == _current && _current != '/' ? _current : _current;
    final name = (await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('新建项目'),
            content: TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '项目名',
                hintText: '例如 my-project',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_nameCtrl.text.trim()),
                child: const Text('创建'),
              ),
            ],
          ),
        )) ??
        '';
    if (name.isEmpty) return;
    final target = parent.endsWith('/')
        ? '$parent$name'
        : '$parent/$name';
    setState(() => _busy = true);
    try {
      await widget.api.createDirectory(target);
      if (!mounted) return;
      setState(() => _busy = false);
      _current = target;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择工作目录'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _createNew,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('新建项目'),
          ),
          FilledButton(
            onPressed: _busy ? null : _pick,
            child: const Text('使用此目录'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 18, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _current,
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white38, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    return ListView(
      children: [
        if (_current != '/')
          ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.white38),
            title: const Text('..'),
            onTap: () async {
              _current = _parent;
              await _load();
            },
          ),
        if (_entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              '此目录下没有子目录',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38),
            ),
          ),
        for (final e in _entries)
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: Colors.white54),
            title: Text(e.name),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
            onTap: () => _enter(e.absolute),
          ),
      ],
    );
  }
}
