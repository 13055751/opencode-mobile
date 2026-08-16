import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'logs.dart';
import 'screens/home.dart';

void main() {
  AppLog.instance.installGlobalHandlers();
  runApp(const OpenCodeApp());
}

class OpenCodeApp extends StatelessWidget {
  const OpenCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'OpenCode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0E0F13),
        useMaterial3: true,
        fontFamily: null,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF181A20),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF181A20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.primary, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  AppConfig? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final config = AppConfig.fromPrefs(p);
    if (mounted) setState(() => _config = config);
  }

  void _onConfigChanged(AppConfig config) {
    setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(config.fontScale),
      ),
      child: HomeScreen(config: config, onConfigChanged: _onConfigChanged),
    );
  }
}

OpenCodeApi? _apiSingleton;

OpenCodeApi createApi(AppConfig config) {
  _apiSingleton = OpenCodeApi(baseUrl: config.baseUrl, password: config.password);
  return _apiSingleton!;
}
