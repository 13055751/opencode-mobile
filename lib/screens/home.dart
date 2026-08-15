import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
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
      final list = await _api.listSessions(limit: 100);
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
    try {
      final s = await _api.createSession();
      if (!mounted) return;
      _sessions.insert(0, s);
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
        child: _buildBody(),
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
