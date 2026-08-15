import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

class ChatActionsSheet extends StatelessWidget {
  final OpenCodeApi api;
  final Session session;
  const ChatActionsSheet({super.key, required this.api, required this.session});

  @override
  Widget build(BuildContext context) {
    final ts = session.createdAtMillis;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.white54),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        ts > 0 ? '会话时间: ${_fmtTime(ts)}' : session.id,
                        style: const TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFE17055)),
            title: const Text('删除会话', style: TextStyle(color: Color(0xFFE17055))),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('删除会话？'),
                  content: const Text('此操作会同时删除服务器上的会话记录。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE17055)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await api.deleteSession(session.id);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                  }
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmtTime(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}月${t.day}日';
  }
}

class Composer extends StatefulWidget {
  final bool busy;
  final void Function(String text) onSend;
  final VoidCallback onAbort;
  const Composer({super.key, required this.busy, required this.onSend, required this.onAbort});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.busy) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Color(0xFF14161C),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1E26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '输入消息…',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.busy)
              IconButton.filled(
                onPressed: widget.onAbort,
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE17055)),
                icon: const Icon(Icons.stop),
                tooltip: '中止',
              )
            else
              IconButton.filled(
                onPressed: _submit,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.arrow_upward),
                tooltip: '发送',
              ),
          ],
        ),
      ),
    );
  }
}
