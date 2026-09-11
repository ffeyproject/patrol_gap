import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/api_config.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/session_service.dart';
import 'services/offline_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  await initializeDateFormatting('id_ID', null);
  runApp(const PatroliSecurityApp());
}

class PatroliSecurityApp extends StatelessWidget {
  const PatroliSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patroli Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = await SessionService.instance.getUser();

    if (user != null) {
      OfflineService.instance.syncAll();
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user != null ? HomeShell(user: user) : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 96, borderRadius: 24),
            SizedBox(height: 20),
            Text(
              'Patroli Security',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Real-Time Monitoring System',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
