import 'package:flutter/material.dart';
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
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  // 已有本地用户则直接跳首页
  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final user  = prefs.getString('local_user');
    if (token != null && user != null && mounted) {
      context.go('/home');
    }
  }

  Future<void> _enter() async {
    final name = _nicknameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _loading = true);
    await ApiService.instance.updateMe({'id': 'local_user_1', 'phone': '', 'nickname': name});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', 'local_token');
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

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
                const SizedBox(height: 80),
                // Logo
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 28, offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Center(child: Text('👶', style: TextStyle(fontSize: 48))),
                ),
                const SizedBox(height: 20),
                const Text('宝宝胎教',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 6),
                const Text('用爸爸妈妈的声音陪宝宝成长',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),

                const SizedBox(height: 64),
                // 昵称输入
                TextField(
                  controller: _nicknameCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: '给自己起个昵称吧',
                    hintStyle: const TextStyle(fontSize: 16, color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _enter(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _enter,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('开始使用', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 40),
                const Text('所有数据保存在本地，无需注册',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
