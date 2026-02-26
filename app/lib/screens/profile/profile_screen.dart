import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  List<VoiceModel> _voices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user   = await ApiService.instance.getMe();
      final voices = await ApiService.instance.getVoiceModels();
      if (mounted) setState(() { _user = user; _voices = voices; });
    } catch (_) {
      if (mounted) setState(() {
        _user = const UserModel(id: '1', phone: '138****8888', nickname: '准妈妈小花');
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('退出', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      try { await ApiService.instance.logout(); } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(children: [
        // 用户信息卡
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primarySoft],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('👩', style: TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_user?.nickname ?? '加载中...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(_user?.phone ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
              if ((_user?.currentWeek ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Text('孕 ${_user!.currentWeek} 周',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ])),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white70),
              onPressed: () async {
                await context.push('/profile-setup');
                _load();
              },
            ),
          ]),
        ),

        // 专属声音管理
        _SectionCard(title: '专属声音', children: [
          if (_voices.isEmpty)
            _MenuItem(
              icon: '🎙', label: '录制声音',
              subtitle: '还没有专属声音，立即录制',
              onTap: () => context.push('/voice/guide?role=mom'),
            )
          else ...[
            for (final v in _voices)
              _MenuItem(
                icon: v.roleEmoji, label: '${v.roleLabel}的声音 v${v.version}',
                subtitle: v.status == VoiceStatus.ready
                    ? '已就绪 · 相似度 ${((v.similarityScore ?? 0.9) * 100).toInt()}%'
                    : '训练中...',
                trailing: v.status == VoiceStatus.ready
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                    : const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                onTap: () {},
              ),
            _MenuItem(
              icon: '➕', label: '添加声音',
              onTap: () => context.push('/voice/guide?role=dad'),
            ),
          ],
        ]),

        // 设置
        _SectionCard(title: '设置', children: [
          _MenuItem(icon: '🔔', label: '通知设置', onTap: () {}),
          _MenuItem(icon: '🔒', label: '隐私政策', onTap: () {}),
          _MenuItem(icon: '📋', label: '用户协议', onTap: () {}),
          _MenuItem(icon: '❓', label: '帮助与反馈', onTap: () {}),
          _MenuItem(icon: '📱', label: '关于宝宝胎教', onTap: () {}),
        ]),

        // 退出登录
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _logout,
            child: const Text('退出登录'),
          ),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(title, style: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    ),
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    ),
    const SizedBox(height: 16),
  ]);
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _MenuItem({
    required this.icon, required this.label, required this.onTap,
    this.subtitle, this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ])),
        trailing ?? const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: AppColors.textHint),
      ]),
    ),
  );
}
