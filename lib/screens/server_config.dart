import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../config.dart';

class ServerConfigScreen extends StatefulWidget {
  final AppConfig config;
  const ServerConfigScreen({super.key, required this.config});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _password;
  late bool _https;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.config.host);
    _port = TextEditingController(text: (widget.config.port ?? 0) == 0 ? '' : widget.config.port.toString());
    _password = TextEditingController(text: widget.config.password);
    _https = widget.config.useHttps;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  AppConfig _build() => AppConfig(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()),
        password: _password.text,
        useHttps: _https,
      );

  Future<void> _save() async {
    final config = _build();
    final p = await SharedPreferences.getInstance();
    await config.save(p);
    if (!mounted) return;
    Navigator.of(context).pop(config);
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final config = _build();
    final api = OpenCodeApi(baseUrl: config.baseUrl, password: config.password);
    final ok = await api.checkHealth();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '连接成功 ✓' : '连接失败，请检查地址 / 密码 / 是否已启用 OPENCODE_SERVER_PASSWORD'),
        backgroundColor: ok ? const Color(0xFF00B894) : const Color(0xFFD63031),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器设置'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '连接 opencode web',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
            const Text(
              '在电脑上运行 opencode web --hostname 0.0.0.0 --port 4096，\n手机与本机连同一 WiFi 后填写本机局域网 IP。\n端口留空表示使用默认端口（HTTPS 443 / HTTP 80）。',
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: '服务器地址 (IP 或域名)',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _port,
                  decoration: const InputDecoration(
                    labelText: '端口 (可选)',
                    hintText: '留空则用默认端口',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码 (可选)',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用 HTTPS', style: TextStyle(fontSize: 15)),
            subtitle: const Text('服务器用 TLS 时开启', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _https,
            onChanged: (v) => setState(() => _https = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
