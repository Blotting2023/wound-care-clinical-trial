import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/offline_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WoundAssessmentApp());
}

/// 全局路由观察者：供页面在"从下级页面返回"时刷新数据（如签名后刷新角标）。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class WoundAssessmentApp extends StatelessWidget {
  const WoundAssessmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Note: Patient/Assessment providers share ApiClient.instance, so the
        // auth token is picked up automatically; no proxy wiring needed.
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => AssessmentProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: MaterialApp(
        title: 'Wound Assessment',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorObservers: [routeObserver],
        initialRoute: '/',
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
