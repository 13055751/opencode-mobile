import 'package:flutter/material.dart';

import '../models.dart';

class QuestionDialog extends StatefulWidget {
  final List<QuestionInfo> questions;
  final Future<void> Function(List<String> answers) onSubmit;
  const QuestionDialog({super.key, required this.questions, required this.onSubmit});

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  final List<String> _custom = [];
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Color(0xFF6C5CE7), size: 22),
          SizedBox(width: 10),
          Text('需要你确认', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final q in widget.questions) _buildQuestion(q),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onSubmit(const ['']);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('取消', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  await widget.onSubmit(_collectAnswers());
                  if (context.mounted) Navigator.of(context).pop();
                },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
          child: const Text('提交'),
        ),
      ],
    );
  }

  List<String> _collectAnswers() {
    final out = <String>[];
    for (var i = 0; i < widget.questions.length; i++) {
      if (_custom.length <= i) _custom.add('');
      out.add(_custom[i]);
    }
    return out;
  }

  Widget _buildQuestion(QuestionInfo q) {
    final i = widget.questions.indexOf(q);
    while (_custom.length <= i) {
      _custom.add('');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (q.header != null && q.header!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(q.header!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _custom[i],
            onChanged: (v) => setState(() => _custom[i] = v ?? ''),
            child: Column(
              children: [
                ...q.options.map(
                  (o) => RadioListTile<String>(
                    value: o.label,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF6C5CE7),
                    title: Text(o.label, style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          if (q.custom)
            TextField(
              onChanged: (v) => setState(() => _custom[i] = v),
              decoration: const InputDecoration(
                hintText: '输入自定义回答…',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14),
            ),
        ],
      ),
    );
  }
}
