import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class VoiceGuideScreen extends StatelessWidget {
  final String role;
  const VoiceGuideScreen({super.key, required this.role});

  String get _label => role == 'dad' ? '爸爸' : '妈妈';
  String get _emoji => role == 'dad' ? '👨‍🍼' : '👩‍🍼';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDE6), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // 顶部返回
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 12),
                  // 主插图
                  Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withOpacity(0.18),
                        blurRadius: 28, offset: const Offset(0, 10),
                      )],
                    ),
                    child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 60))),
                  ),
                  const SizedBox(height: 28),
                  Text('录制${_label}的专属声音',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('只需 5 分钟，AI 就能学会用\n${_label}的声音给宝宝讲故事',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 32),

                  // 注意事项
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('录音前请注意',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      for (final t in _tips) _TipRow(icon: t[0], text: t[1]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // 时间预估
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Text('⏱', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('预计耗时 5~8 分钟',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        const SizedBox(height: 2),
                        const Text('朗读约 40 句引导文本，支持逐句重录',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go('/voice/record?role=$role'),
                  child: Text('开始录制${_label}的声音'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static const _tips = [
    ['🤫', '选择安静环境，关闭电视、空调等噪声源'],
    ['📱', '手机距嘴约 15cm，保持正常语速'],
    ['☕', '喝点水润嗓，保持放松自然的状态'],
    ['🔄', '每句话可以重录，不满意可以重来'],
  ];
}

class _TipRow extends StatelessWidget {
  final String icon, text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5))),
    ]),
  );
}
