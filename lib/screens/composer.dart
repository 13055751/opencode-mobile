import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/file_picker.dart';

class ChatActionsSheet extends StatelessWidget {
  final OpenCodeApi api;
  final Session session;
  final VoidCallback? onDeleted;
  const ChatActionsSheet({super.key, required this.api, required this.session, this.onDeleted});

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
                  widget.onDeleted?.call();
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
  final OpenCodeApi api;
  final bool busy;
  final void Function(String text, List<Map<String, dynamic>> parts) onSend;
  final VoidCallback onAbort;
  final VoidCallback? onPickModeModel;
  const Composer({
    super.key,
    required this.api,
    required this.busy,
    required this.onSend,
    required this.onAbort,
    this.onPickModeModel,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _attachments = [];
  List<dynamic> _commands = [];
  List<dynamic> _agents = [];
  bool _commandsLoaded = false;
  String _match = ''; // current prefix match: for / or @

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCommands() async {
    if (_commandsLoaded) return;
    try {
      final c = await widget.api.listCommands();
      _commands = c.whereType<Map<String, dynamic>>().toList();
    } catch (_) {}
    _commandsLoaded = true;
  }

  Future<void> _loadAgents() async {
    if (_agents.isNotEmpty) return;
    try {
      final a = await widget.api.listAgents();
      _agents = a.whereType<Map<String, dynamic>>().toList();
    } catch (_) {}
  }

  void _onChanged(String text) {
    _loadCommands();
    _loadAgents();
    String m = '';
    if (text.startsWith('/')) {
      m = text.substring(1);
    } else {
      final at = text.lastIndexOf('@');
      if (at != -1 && !text.substring(0, at).contains('\n')) m = text.substring(at + 1);
    }
    if (m != _match) setState(() => _match = m);
  }

  List<Map<String, dynamic>> _suggestions() {
    final text = _controller.text;
    final term = _match.toLowerCase();
    if (text.startsWith('/')) {
      return _commands.where((c) => (c['name'] as String? ?? '').toLowerCase().contains(term)).toList();
    }
    return _agents.where((a) => (a['name'] as String? ?? '').toLowerCase().contains(term)).toList();
  }

  void _applySuggestion(Map<String, dynamic> item) {
    final text = _controller.text;
    if (text.startsWith('/')) {
      _controller.text = '/${item['name']} ';
    } else {
      final at = text.lastIndexOf('@');
      final prefix = at > 0 ? text.substring(0, at + 1) : '@';
      _controller.text = '$prefix${item['name']} ';
    }
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() => _match = '');
  }

  Future<void> _pickAttachment() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ServerFilePickerPage(
          api: widget.api,
          initialDirectory: '/',
          pickDirectories: false,
        ),
      ),
    );
    if (path == null) return;
    setState(() {
      _attachments.add({
        'path': path,
        'name': path.split('/').last,
      });
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    if (widget.busy) return;
    final parts = <Map<String, dynamic>>[
      for (final att in _attachments)
        {
          'type': 'file',
          'filename': att['name'],
          'url': att['path'],
        },
      if (text.isNotEmpty) {'type': 'text', 'text': text},
    ];
    widget.onSend(text, parts);
    _controller.clear();
    setState(() {
      _attachments.clear();
      _match = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _match.isEmpty ? <Map<String, dynamic>>[] : _suggestions();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1E26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (_, i) {
                final s = suggestions[i];
                final name = s['name'] as String? ?? '';
                final desc =
                    (s['description'] as String?) ?? (s['template'] as String?) ?? '';
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    _controller.text.startsWith('/') ? Icons.terminal : Icons.person_outline,
                    size: 18,
                    color: const Color(0xFF6C5CE7),
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  subtitle: desc.isEmpty
                      ? null
                      : Text(desc.replaceAll('\n', ' '),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  onTap: () => _applySuggestion(s),
                );
              },
            ),
          ),
        if (suggestions.isNotEmpty) const SizedBox(height: 6),
        if (_attachments.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _attachments.length; i++)
                  Chip(
                    label: Text(
                      _attachments[i]['name'] as String? ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: Icon(Icons.close, size: 16, color: Colors.white54),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => setState(() => _attachments.removeAt(i)),
                  ),
              ],
            ),
          ),
        Container(
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
                IconButton(
                  onPressed: widget.busy ? null : _pickAttachment,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2D3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.attach_file, size: 20),
                  tooltip: '添加文件',
                ),
                const SizedBox(width: 4),
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
                        hintText: '输入消息…（/指令 @模式）',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.newline,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (widget.onPickModeModel != null)
                  IconButton(
                    onPressed: widget.busy ? null : widget.onPickModeModel,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2D3A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: '模式与模型',
                  ),
                const SizedBox(width: 4),
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
        ),
      ],
    );
  }
}