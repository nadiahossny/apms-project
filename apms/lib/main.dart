import 'package:apms/home_dashboard_screen.dart';
import 'package:apms/inventory_screen.dart';
import 'package:apms/rx_scanner_screen.dart';
import 'package:apms/screens/operational_reports.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/tokens.dart';
import 'widgets/app_shell.dart';
import 'services/api_service.dart';
import 'services/token_store.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/robot_panel_screen.dart';
import 'screens/ai_center_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedHost = await TokenStore.loadGatewayHost();
  if (savedHost != null && savedHost.isNotEmpty) {
    ApiService.setGatewayHost(savedHost);
    print('[INIT] Gateway host loaded from storage: $savedHost');
  } else {
    print(
      '[INIT] No saved gateway host; using default: ${ApiService.gatewayHost}',
    );
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  runApp(const PharmaSysApp());
}

class PharmaSysApp extends StatefulWidget {
  const PharmaSysApp({super.key});
  @override
  State<PharmaSysApp> createState() => _PharmaSysAppState();
}

class _PharmaSysAppState extends State<PharmaSysApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaSys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AC.page,
        colorScheme: const ColorScheme.light(
          primary: AC.blue500,
          secondary: AC.amberFg,
          surface: AC.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF3F6FA),
          border: OutlineInputBorder(
            borderRadius: AR.r10,
            borderSide: BorderSide(color: AC.border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AR.r10,
            borderSide: BorderSide(color: AC.border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AR.r10,
            borderSide: BorderSide(color: AC.blue500, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          hintStyle: TextStyle(fontSize: 13, color: AC.ink300),
        ),
      ),
      initialRoute: '/',
     routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/scanner': (_) => const RxScannerScreen(),
        '/dashboard': (_) => const AppShell(index: 0, child: HomeDashboardScreen()),
        '/inventory': (_) => const AppShell(index: 1, child: InventoryScreen()),
        '/invoices': (_) => const AppShell(index: 2, child: InvoicesScreen()),
        '/prescriptions': (_) => const AppShell(index: 3, child: PrescriptionsScreen()),
        '/robot': (_) => const AppShell(index: 4, child: RobotPanelScreen()),
        
        // 🌟 Index 5: The Operational Reports
        '/reports': (_) => const AppShell(index: 5, child: OperationalReportsScreen()),
        
        // 🌟 Index 6: The AI Command Center
        '/ai_center': (_) => const AppShell(index: 6, child: AIScreen()),
        
        // 🌟 Index 7: Settings pushed down one spot
        '/settings': (_) => const AppShell(index: 7, child: SettingsScreen()),
      },
    );
  }
}
