import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../widgets/directory_picker.dart';
import 'chat.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  final ValueChanged<AppConfig> onConfigChanged;
  const HomeScreen({super.key, required this.config, required this.onConfigChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late OpenCodeApi _api;
  late List<Session> _sessions = [];
  bool _loading = true;
  String? _error;
  bool _connected = false;
  String? _projectDir;

  @override
  void initState() {
    super.initState();
    _api = OpenCodeApi(baseUrl: widget.config.baseUrl, password: widget.config.password);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await _api.checkHealth();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _connected = false;
        _error = '无法连接服务器 ${widget.config.baseUrl}\n请确认 opencode web 已在局域网启动，或修改服务器设置';
      });
      return;
    }
    try {
      final list = await _api.listSessions(limit: 100, directory: _projectDir);
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _connected = true;
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

  Future<void> _selectProject() async {
    final result = await showModalBottomSheet<_ProjectAction?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (widget.config.projects.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text('已选项目', style: TextStyle(fontSize: 12, color: Colors.white38)),
              ),
              for (final p in widget.config.projects)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.folder_outlined,
                    size: 20,
                    color: p == _projectDir ? const Color(0xFF6C5CE7) : Colors.white38,
                  ),
                  title: Text(
                    p,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: p == _projectDir ? const Color(0xFF6C5CE7) : null,
                      fontWeight: p == _projectDir ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: p == _projectDir
                      ? const Icon(Icons.check, size: 18, color: Color(0xFF6C5CE7))
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.white24),
                          tooltip: '移除',
                          onPressed: () => Navigator.of(ctx).pop(_ProjectAction.remove(p)),
                        ),
                  onTap: () => Navigator.of(ctx).pop(_ProjectAction.choose(p)),
                ),
            ],
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('浏览服务器目录'),
              subtitle: Text(_projectDir ?? '还没选择项目，显示全部会话'),
              onTap: () => Navigator.of(ctx).pop(_ProjectAction.browse),
            ),
            if (_projectDir != null)
              ListTile(
                leading: const Icon(Icons.clear_all_outlined),
                title: const Text('显示全部会话'),
                onTap: () => Navigator.of(ctx).pop(_ProjectAction.all),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case _ProjectAction.browse:
        final picked = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => DirectoryPickerPage(
              api: _api,
              initialDirectory: _projectDir ?? '/',
            ),
          ),
        );
        if (picked == null || !mounted) return;
        await _addProject(picked);
        break;
      case _ProjectAction.all:
        setState(() => _projectDir = null);
        await _refresh();
        break;
      case _ProjectAction choose(:final dir):
        setState(() => _projectDir = dir);
        await _refresh();
        break;
      case _ProjectAction remove(:final dir):
        setState(() {
          final list = [...widget.config.projects]..remove(dir);
          _saveProjects(list);
          if (_projectDir == dir) _projectDir = null;
        });
        await _refresh();
        break;
    }
  }

  Future<void> _addProject(String dir) async {
    final list = [...widget.config.projects];
    if (!list.contains(dir)) list.insert(0, dir);
    _saveProjects(list);
    setState(() => _projectDir = dir);
    await _refresh();
  }

  void _saveProjects(List<String> list) {
    widget.onConfigChanged(AppConfig(
      host: widget.config.host,
      port: widget.config.port,
      password: widget.config.password,
      useHttps: widget.config.useHttps,
      fontScale: widget.config.fontScale,
      projects: list,
    ));
  }

  Future<void> _openConfig() async {
    final result = await Navigator.of(context).push<AppConfig>(
      MaterialPageRoute(builder: (_) => SettingsScreen(config: widget.config)),
    );
    if (result != null && mounted) {
      widget.onConfigChanged(result);
      setState(() {
        _api = OpenCodeApi(baseUrl: result.baseUrl, password: result.password);
      });
      _refresh();
    }
  }

  Future<void> _newSession() async {
    final result = await showDialog<_NewSessionInput>(
      context: context,
      builder: (ctx) => _NewSessionDialog(api: _api, initialDirectory: _projectDir),
    );
    if (result == null || !mounted) return;
    try {
      final s = await _api.createSession(title: result.title, directory: result.directory);
      if (!mounted) return;
      if (_projectDir != null) {
        setState(() => _sessions.insert(0, s));
      }
      await _openChat(s);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  Future<void> _openChat(Session s) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChatScreen(api: _api, session: s)),
    );
    if (changed == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenCode'),
        actions: [
          IconButton(
            onPressed: _selectProject,
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: '选择项目',
          ),
          IconButton(
            onPressed: _openConfig,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '服务器设置',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSession,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('新会话'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            if (_projectDir != null) _projectBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _projectBar() {
    return Material(
      color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
      child: InkWell(
        onTap: _selectProject,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _projectDir!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(
            _connected ? Icons.error_outline : Icons.cloud_off_outlined,
            size: 56,
            color: _connected ? Colors.orange : Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openConfig,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('服务器设置'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (_sessions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.forum_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            '还没有会话',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, i) {
        final s = _sessions[i];
        return ListTile(
          onTap: () => _openChat(s),
          leading: CircleAvatar(
            backgroundColor: Color.lerp(
              const Color(0xFF6C5CE7),
              const Color(0xFF00B894),
              (i % 3) / 2,
            ),
            child: Text(
              (s.displayTitle.characters.firstOrNull ?? '?').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(
            s.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _timeLabel(s),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          trailing: s.archived == true
              ? const Icon(Icons.archive_outlined, color: Colors.white24, size: 18)
              : null,
        );
      },
    );
  }

  String _timeLabel(Session s) {
    final created = s.createdAtMillis;
    if (created > 0) {
      return _fmt(DateTime.fromMillisecondsSinceEpoch(created).toLocal());
    }
    final parts = <String>[
      if (s.agent != null) s.agent!,
    ];
    return parts.join(' · ');
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    String two(int n) => n.toString().padLeft(2, '0');
    if (day == today) return '${two(local.hour)}:${two(local.minute)}';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    return '${local.month}/${local.day}';
  }
}

class _NewSessionInput {
  final String? title;
  final String? directory;
  _NewSessionInput({this.title, this.directory});
}

enum _ProjectAction {
  browse,
  all,
  choose(String dir),
  remove(String dir);
}

class _NewSessionDialog extends StatefulWidget {
  final OpenCodeApi api;
  final String? initialDirectory;
  const _NewSessionDialog({required this.api, this.initialDirectory});

  @override
  State<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<_NewSessionDialog> {
  final _titleCtrl = TextEditingController();
  late final _dirCtrl = TextEditingController(text: widget.initialDirectory ?? '');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DirectoryPickerPage(
          api: widget.api,
          initialDirectory: _dirCtrl.text.trim().isEmpty ? '/' : _dirCtrl.text.trim(),
        ),
      ),
    );
    if (picked != null && mounted) {
      _dirCtrl.text = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新会话'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '会话标题（可选）',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dirCtrl,
            decoration: InputDecoration(
              labelText: '工作目录（可选）',
              hintText: '服务器上的绝对路径',
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: '浏览服务器目录',
                onPressed: _browse,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final dir = _dirCtrl.text.trim();
            Navigator.of(context).pop(
              _NewSessionInput(
                title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
                directory: dir.isEmpty ? null : dir,
              ),
            );
          },
          child: const Text('创建'),
        ),
      ],
    );
  }
}
