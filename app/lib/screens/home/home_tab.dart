import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  UserModel? _user;
  List<VoiceModel> _voices = [];
  List<ContentModel> _recommends = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user   = await ApiService.instance.getMe();
      final voices = await ApiService.instance.getVoiceModels();
      final contents = await ApiService.instance.getContents();
      if (mounted) setState(() { _user = user; _voices = voices; _recommends = contents.take(4).toList(); });
    } catch (_) {
      // 演示模式：使用本地 mock 数据
      if (mounted) setState(() {
        _user = const UserModel(id: '1', phone: '138****8888', nickname: '准妈妈小花');
        _recommends = _mockContents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(slivers: [
          // ── 顶部 Banner
          SliverToBoxAdapter(child: _buildBanner()),
          // ── 声音克隆入口
          SliverToBoxAdapter(child: _buildVoiceSection()),
          // ── 今日推荐
          SliverToBoxAdapter(child: _buildSectionTitle('今日推荐')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ContentCard(content: _recommends[i]),
                childCount: _recommends.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBanner() {
    final week = _user?.currentWeek ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('你好，${_user?.nickname ?? '宝妈'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (week > 0) ...[
              const SizedBox(height: 4),
              Text('宝宝已经 $week 周啦 🎉',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ])),
          const Text('👶', style: TextStyle(fontSize: 42)),
        ]),
        const SizedBox(height: 16),
        // 横幅卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primarySoft],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('用你的声音\n陪宝宝成长',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: Colors.white, height: 1.4)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.go('/voice/guide?role=mom'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('录制我的声音',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ),
            ])),
            const Text('🎙', style: TextStyle(fontSize: 56)),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildVoiceSection() {
    final hasVoice = _voices.any((v) => v.status == VoiceStatus.ready);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('专属声音', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (!hasVoice)
          _VoiceEntryCard(
            emoji: '🎙',
            title: '录制专属声音',
            subtitle: '用爸爸/妈妈的声音给宝宝讲故事',
            onTap: () => context.go('/voice/guide?role=mom'),
          )
        else
          Row(children: [
            for (final v in _voices.where((v) => v.status == VoiceStatus.ready))
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _VoiceChip(voice: v),
              )),
            Expanded(child: _VoiceEntryCard(
              emoji: '➕', title: '添加声音', subtitle: '',
              onTap: () => context.go('/voice/guide?role=dad'),
            )),
          ]),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(title, style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  );
}

// ── 小组件 ────────────────────────────────────────

class _VoiceEntryCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback onTap;
  const _VoiceEntryCard({required this.emoji, required this.title,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ]),
    ),
  );
}

class _VoiceChip extends StatelessWidget {
  final VoiceModel voice;
  const _VoiceChip({required this.voice});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(voice.roleEmoji, style: const TextStyle(fontSize: 28)),
      const SizedBox(height: 6),
      Text('${voice.roleLabel}的声音',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      const Text('已就绪 ✓',
          style: TextStyle(fontSize: 11, color: AppColors.success)),
    ]),
  );
}

class _ContentCard extends StatelessWidget {
  final ContentModel content;
  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/content/${content.id}'),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 封面
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Center(
            child: Text(content.category.emoji,
                style: const TextStyle(fontSize: 48)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(content.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Text(content.category.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              const Spacer(),
              Text(content.durationLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

// ── Mock 数据（演示用）────────────────────────────
const _mockContents = [
  ContentModel(id:'1', title:'小兔子乖乖', category: ContentCategory.story,
      textContent:'小兔子乖乖，把门开开...', durationSeconds: 300,
      minWeek: 16, maxWeek: 42, isFree: true),
  ContentModel(id:'2', title:'三字经', category: ContentCategory.classic,
      textContent:'人之初，性本善...', durationSeconds: 480,
      minWeek: 20, maxWeek: 42, isFree: true),
  ContentModel(id:'3', title:'睡前冥想', category: ContentCategory.meditation,
      textContent:'闭上眼睛，深呼吸...', durationSeconds: 600,
      minWeek: 12, maxWeek: 42, isFree: false),
  ContentModel(id:'4', title:'小星星', category: ContentCategory.song,
      textContent:'一闪一闪亮晶晶...', durationSeconds: 180,
      minWeek: 16, maxWeek: 42, isFree: true),
];
