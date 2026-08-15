import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/config.dart';

void main() {
  test('AppConfig builds baseUrl from parts', () {
    final c = AppConfig(host: '192.168.1.10', port: 4096, password: '', useHttps: false);
    expect(c.baseUrl, 'http://192.168.1.10:4096');
    final s = AppConfig(host: 'oc.example.com', port: 443, password: 'secret', useHttps: true);
    expect(s.baseUrl, 'https://oc.example.com:443');
  });

  test('AppConfig defaults', () {
    final c = AppConfig();
    expect(c.host, '127.0.0.1');
    expect(c.port, 4096);
    expect(c.useHttps, false);
  });
}
