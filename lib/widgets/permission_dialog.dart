import 'package:flutter/material.dart';

import '../models.dart';

class PermissionDialog extends StatefulWidget {
  final PermissionRequest req;
  final Future<void> Function(String reply, bool remember) onReply;
  const PermissionDialog({super.key, required this.req, required this.onReply});

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  bool _remember = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF6C5CE7), size: 22),
          SizedBox(width: 10),
          Text('权限请求', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13151B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.display,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                if (req.action != null && req.action!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(req.action!, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFF6C5CE7),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: _remember,
                activeColor: const Color(0xFF6C5CE7),
                onChanged: (v) => setState(() => _remember = v ?? false),
              ),
              const Text('总是允许（记住此选择）', style: TextStyle(fontSize: 13, color: Colors.white54)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onReply('reject', _remember);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('拒绝', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton.tonal(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onReply('once', _remember);
                  if (context.mounted) Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
          ),
          child: const Text('允许一次'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onReply('always', _remember);
                  if (context.mounted) Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00B894),
            foregroundColor: Colors.white,
          ),
          child: const Text('始终允许'),
        ),
      ],
    );
  }
}
