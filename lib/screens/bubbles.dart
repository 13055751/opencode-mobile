import 'package:flutter/material.dart';

import '../models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') return _UserBubble(message: message);
    return _AssistantBubble(message: message);
  }
}

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message.visibleText;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 6, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text.isEmpty ? '(空)' : text,
          style: const TextStyle(color: Colors.white, height: 1.4, fontSize: 15),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.error != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B1B1B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE17055), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${message.error!['name'] ?? 'Error'}: ${message.error!['message'] ?? message.error}',
                style: const TextStyle(color: Color(0xFFE17055), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    final hasContent = message.parts.any(
      (p) => p.kind == PartKind.text && (p.text ?? '').isNotEmpty && p.raw['synthetic'] != true,
    );

    if (message.agent != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF6C5CE7)),
            const SizedBox(width: 5),
            Text(
              message.agent!,
              style: const TextStyle(color: Color(0xFF6C5CE7), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ));
    }

    if (!hasContent) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C5CE7)),
            ),
            const SizedBox(width: 8),
            const Text('思考中…', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ));
    }

    for (final part in message.parts) {
      children.add(PartWidget(part: part));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4, right: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class PartWidget extends StatelessWidget {
  final Part part;
  const PartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    switch (part.kind) {
      case PartKind.text:
        final text = part.text ?? '';
        if (text.isEmpty && part.raw['synthetic'] == true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: SelectableText(
            text.isEmpty ? '' : text,
            style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 15),
          ),
        );
      case PartKind.reasoning:
        final text = part.text ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined, size: 13, color: Colors.white24),
                  const SizedBox(width: 5),
                  Text('思考过程', style: TextStyle(color: Colors.white24, fontSize: 11)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF13151B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        );
      case PartKind.tool:
        return _ToolPart(part: part);
      case PartKind.file:
        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF13151B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.raw['url'] as String? ?? part.raw['source'] as String? ?? '文件',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      case PartKind.agent:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: Color(0xFF6C5CE7)),
              const SizedBox(width: 6),
              Text(
                part.raw['name'] as String? ?? 'Agent',
                style: const TextStyle(color: Color(0xFF6C5CE7), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      case PartKind.compaction:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1E26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compress, size: 13, color: Colors.white38),
              SizedBox(width: 6),
              Text('上下文已压缩', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ToolPart extends StatelessWidget {
  final Part part;
  const _ToolPart({required this.part});

  @override
  Widget build(BuildContext context) {
    final state = part.toolState;
    final status = state?.status ?? part.stateText ?? 'running';
    final title = state?.title ?? part.toolName ?? 'tool';
    final running = status == 'running' || status == 'pending';

    Color color;
    IconData icon;
    if (status == 'completed') {
      color = const Color(0xFF00B894);
      icon = Icons.check_circle_outline;
    } else if (status == 'error') {
      color = const Color(0xFFE17055);
      icon = Icons.error_outline;
    } else if (running) {
      color = Colors.orange;
      icon = Icons.sync;
    } else {
      color = Colors.white38;
      icon = Icons.more_horiz;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF13151B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (running)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(status, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
          if (state?.input != null && (state!.input!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _preview(state.input!),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          if (state?.output != null && state!.output!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _previewOutput(state.output!),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _preview(Map<String, dynamic> input) {
    final buf = StringBuffer();
    input.forEach((k, v) {
      buf.write('$k: $v  ');
    });
    return buf.toString();
  }

  String _previewOutput(String out) {
    final compact = out.trim();
    if (compact.length > 300) return '${compact.substring(0, 300)}…';
    return compact;
  }
}
