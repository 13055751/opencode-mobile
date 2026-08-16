import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logs.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ScrollController _scroll = ScrollController();
  String? _logPath;
  String? _logError;

  int get _count => AppLog.instance.entries.length;

  @override
  void initState() {
    super.initState();
    AppLog.instance.addListener(_onLog);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    AppLog.instance.removeListener(_onLog);
    _scroll.dispose();
    super.dispose();
  }

  void _onLog() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position.maxScrollExtent;
    if (pos > 0) _scroll.jumpTo(pos);
  }

  Future<void> _copyAll() async {
    final text = AppLog.instance.export();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('日志为空')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  Future<void> _export() async {
    final text = AppLog.instance.export();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('日志为空')));
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/opencode_log_$ts.txt');
      await file.writeAsString(text);
      if (!mounted) return;
      setState(() {
        _logPath = file.path;
        _logError = null;
      });
      Share.shareXFiles([XFile(file.path)], text: 'opencode 客户端日志');
    } catch (e) {
      AppLog.instance.error('logs', 'export failed: $e');
      if (!mounted) return;
      setState(() => _logError = '导出失败: $e');
    }
  }

  Future<void> _clear() async {
    AppLog.instance.clear();
    setState(() => _logPath = null);
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'E':
        return const Color(0xFFFF6B6B);
      case 'W':
        return const Color(0xFFFFC557);
      case 'H':
      case 'S':
        return const Color(0xFF74C0FC);
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = AppLog.instance.entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          TextButton.icon(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制'),
          ),
          TextButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('导出'),
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_logPath != null || _logError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _logError ?? '已导出: $_logPath',
                      style: TextStyle(
                        fontSize: 12,
                        color: _logError != null
                            ? const Color(0xFFFF6B6B)
                            : Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('暂无日志',
                        style: TextStyle(color: Colors.white38)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SelectableText(
                          e.toLine(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: _levelColor(e.level),
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}