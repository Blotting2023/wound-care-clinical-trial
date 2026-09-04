import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _serverUrl = ApiConfig.baseUrl;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<AuthProvider>().login(
        _userCtrl.text.trim(),
        _passCtrl.text,
        _serverUrl,
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部品牌区
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.actionBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.medical_services,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                Text('创面评估系统',
                    textAlign: TextAlign.center, style: AppTheme.display),
                const SizedBox(height: 8),
                Text('临床工作台 · 演示版',
                    textAlign: TextAlign.center, style: AppTheme.caption),
                const SizedBox(height: 40),
                // 登录表单卡
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _userCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '手机号 / 工号',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请输入账号' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '请输入密码' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: loading ? null : _login,
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Text('登录'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // demo 模式提示
                if (ApiConfig.demoMode)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.actionBlue, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '演示模式：手机号和密码随便填即可登录',
                            style: AppTheme.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _showServerDialog,
                    child: Text('服务器：$_serverUrl'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerDialog() {
    final ctrl = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'http://host:8080/api'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _serverUrl = ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
