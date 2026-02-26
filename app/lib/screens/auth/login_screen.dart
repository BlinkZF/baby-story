import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  bool _loading    = false;
  bool _codeSent   = false;
  int  _countdown  = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── 发送验证码
  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) { _toast('请输入正确的手机号'); return; }
    try {
      setState(() => _loading = true);
      await ApiService.instance.sendCode(phone);
      setState(() { _codeSent = true; _countdown = 60; });
      _tick();
    } catch (_) {
      // 演示模式：忽略网络错误直接进入验证码输入
      setState(() { _codeSent = true; _countdown = 60; });
      _tick();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _countdown <= 0) return;
      setState(() => _countdown--);
      _tick();
    });
  }

  // ── 登录
  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code  = _codeCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) { _toast('请填写手机号和验证码'); return; }
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.login(phone, code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      if (!mounted) return;
      final isNew = data['user']?['isNewUser'] == true;
      context.go(isNew ? '/profile-setup' : '/home');
    } catch (_) {
      // 演示模式：直接跳首页
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEDE6), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 64),
                // Logo
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 24, offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Center(child: Text('👶', style: TextStyle(fontSize: 44))),
                ),
                const SizedBox(height: 16),
                const Text('宝宝胎教',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(height: 6),
                const Text('用爸爸妈妈的声音陪宝宝成长',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),

                const SizedBox(height: 52),
                // 手机号
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '请输入手机号',
                    counterText: '',
                    prefixIcon: Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 6, 0),
                      child: Text('+86', style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
                const SizedBox(height: 12),
                // 验证码行
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '验证码', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 108, height: 52,
                    child: OutlinedButton(
                      onPressed: (_loading || _countdown > 0) ? null : _sendCode,
                      child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),
                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('登录'),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '未注册的手机号将自动创建账号\n登录即代表同意《用户协议》和《隐私政策》',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint, height: 1.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
