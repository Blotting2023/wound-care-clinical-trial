import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/api_config.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/offline_provider.dart';

/// 启动参数：演示模式快速登录角色（如 PI/CRC/Admin/SubI/Sponsor/IRB）。
const _quickLoginRole = String.fromEnvironment('DEMO_QUICK_LOGIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 在 runApp 前完成自动登录，AuthProvider 才能在初始路由判断身份
  final auth = AuthProvider();
  await auth.maybeAutoLogin(_quickLoginRole);
  runApp(WoundAssessmentApp(auth: auth));
}

/// 全局路由观察者：供页面在"从下级页面返回"时刷新数据（如签名后刷新角标）。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class WoundAssessmentApp extends StatelessWidget {
  const WoundAssessmentApp({super.key, this.auth});

  /// 由 main() 注入；缺省时仍可独立启动（登录页手输）。
  final AuthProvider? auth;

  @override
  Widget build(BuildContext context) {
    final demoAutoLogin =
        ApiConfig.demoMode && _quickLoginRole.isNotEmpty && auth?.isAuthenticated == true;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth ?? AuthProvider()),
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
        initialRoute: demoAutoLogin ? '/home' : '/',
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
