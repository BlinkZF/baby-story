import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _loading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 120)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 300)),
      helpText: '选择预产期',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_nicknameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写昵称'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateMe({
        'nickname': _nicknameCtrl.text.trim(),
        if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String(),
      });
    } catch (_) {}
    if (mounted) context.go('/home');
  }

  @override
  void dispose() { _nicknameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('完善信息'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('欢迎加入宝宝胎教 👶',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('完善信息后，我们为你推荐专属胎教内容',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 36),

          const Text('昵称', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _nicknameCtrl, decoration: const InputDecoration(hintText: '给自己起个昵称')),
          const SizedBox(height: 24),

          const Text('预产期（选填）', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textHint),
                const SizedBox(width: 10),
                Text(
                  _dueDate == null
                      ? '选择预产期'
                      : '${_dueDate!.year}年${_dueDate!.month}月${_dueDate!.day}日',
                  style: TextStyle(
                    fontSize: 15,
                    color: _dueDate == null ? AppColors.textHint : AppColors.textPrimary,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          const Text('填写后可获得孕周专属内容推荐',
              style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 52),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('开始使用'),
            ),
          ),
        ]),
      ),
    );
  }
}
