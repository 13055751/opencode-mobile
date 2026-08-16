import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'logs.dart';
import 'server_config.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  const SettingsScreen({super.key, required this.config});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _config;
  late double _fontScale;

  static const _fontOptions = <(String, double)>[
    ('小', 0.85),
    ('标准', 1.0),
    ('大', 1.15),
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _fontScale = widget.config.fontScale;
  }

  Future<void> _openServerConfig() async {
    final result = await Navigator.of(context).push<AppConfig>(
      MaterialPageRoute(builder: (_) => ServerConfigScreen(config: _config)),
    );
    if (result != null && mounted) {
      setState(() => _config = result);
      Navigator.of(context).pop(_config);
    }
  }

  Future<void> _setFontScale(double v) async {
    setState(() => _fontScale = v);
    _config = AppConfig(
      host: _config.host,
      port: _config.port,
      password: _config.password,
      useHttps: _config.useHttps,
      fontScale: v,
    );
    final p = await SharedPreferences.getInstance();
    await _config.save(p);
  }

  String get _serverLabel {
    final p = (0 == (_config.port ?? 0)) ? '' : ':${_config.port}';
    final scheme = _config.useHttps ? 'https' : 'http';
    return '$scheme://${_config.host}$p';
  }

  Future<void> _openLogs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_config),
            child: const Text('完成', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('连接'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('连接服务器'),
            subtitle: Text(_serverLabel, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _openServerConfig,
          ),
          const Divider(height: 1, color: Colors.white10),
          const _SectionHeader('显示'),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('消息字号'),
            subtitle: Text(
              _fontOptions.firstWhere((o) => o.$2 == _fontScale).$1,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () => _showFontDialog(),
          ),
          const Divider(height: 1, color: Colors.white10),
          const _SectionHeader('诊断'),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('客户端日志'),
            subtitle: const Text('查看/复制/导出运行日志',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _openLogs,
          ),
          const Divider(height: 1, color: Colors.white10),
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('0.1.0', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('项目主页'),
            subtitle: const Text('github.com/13055751/opencode-mobile',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('项目主页：github.com/13055751/opencode-mobile')),
            ),
          ),
        ],
      ),
    );
  }

  void _showFontDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('消息字号'),
        children: [
          RadioGroup<double>(
            groupValue: _fontScale,
            onChanged: (v) {
              if (v == null) return;
              Navigator.of(dialogContext).pop();
              _setFontScale(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, value) in _fontOptions)
                  RadioListTile<double>(
                    value: value,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(label),
                    onChanged: (_) {},
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
