import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _kHost = 'oc_host';
  static const _kPort = 'oc_port';
  static const _kPassword = 'oc_password';
  static const _kUseHttps = 'oc_https';
  static const _kFontScale = 'oc_font_scale';

  String host;
  int? port;
  String password;
  bool useHttps;
  double fontScale;

  AppConfig({
    this.host = '127.0.0.1',
    this.port = 4096,
    this.password = '',
    this.useHttps = false,
    this.fontScale = 1.0,
  });

  String get baseUrl {
    final scheme = useHttps ? 'https' : 'http';
    final p = (port == null || port == 0) ? '' : ':$port';
    return '$scheme://$host$p';
  }

  factory AppConfig.fromPrefs(SharedPreferences p) => AppConfig(
        host: p.getString(_kHost) ?? '127.0.0.1',
        port: p.getInt(_kPort),
        password: p.getString(_kPassword) ?? '',
        useHttps: p.getBool(_kUseHttps) ?? false,
        fontScale: p.getDouble(_kFontScale) ?? 1.0,
      );

  Future<void> save(SharedPreferences p) async {
    await p.setString(_kHost, host);
    await p.setInt(_kPort, port ?? 0);
    await p.setString(_kPassword, password);
    await p.setBool(_kUseHttps, useHttps);
    await p.setDouble(_kFontScale, fontScale);
  }
}
