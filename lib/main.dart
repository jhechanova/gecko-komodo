import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/url_setup_screen.dart';
import 'services/app_icon_service.dart';
import 'services/database_service.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FcmService.instance.initialize();
    await FcmService.instance.getAndSyncToken();
  } catch (e, st) {
    debugPrint('FCM init failed (add google-services.json?): $e\n$st');
  }

  runApp(const NotifApp());
}

class NotifApp extends StatelessWidget {
  const NotifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notif App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<Widget> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _resolveStartScreen();
  }

  Future<Widget> _resolveStartScreen() async {
    final db = DatabaseService.instance;
    final baseUrl = await db.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      return const UrlSetupScreen();
    }
    await AppIconService.instance.applyForUrl(baseUrl);
    final user = await db.getUser();
    if (user == null) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: const Text('Unable to start the app.'),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
