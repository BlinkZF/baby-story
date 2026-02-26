import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ContentDetailScreen extends StatefulWidget {
  final String contentId;
  const ContentDetailScreen({super.key, required this.contentId});
  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  ContentModel? _content;
  List<VoiceModel> _voices = [];
  String? _selectedVoiceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 先并发请求内容和声音列表
    ContentModel? content;
    List<VoiceModel> voices = [];

    try {
      content = await ApiService.instance.getContent(widget.contentId);
    } catch (_) {
      content = _mockContent(widget.contentId);
    }

    try {
      final all = await ApiService.instance.getVoiceModels();
      voices = all.where((v) => v.status == VoiceStatus.ready).toList();
    } catch (_) {
      // API 不通时用 mock 声音数据，方便演示专属声音流程
      voices = _mockVoices;
    }

    if (mounted) setState(() {
      _content = content;
      _voices  = voices;
      _selectedVoiceId = voices.isNotEmpty ? voices.first.id : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final c = _content!;
    return Scaffold(
      body: CustomScrollView(slivers: [
        // 顶部封面
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Center(child: Text(c.category.emoji,
                  style: const TextStyle(fontSize: 80))),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 标题 & 标签
            Text(c.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              _Tag(c.category.label, AppColors.primary),
              _Tag(c.durationLabel, AppColors.textSecondary),
              _Tag(c.weekLabel, AppColors.textSecondary),
              if (c.isFree) _Tag('免费', AppColors.success),
            ]),
            const SizedBox(height: 24),

            // 内容预览
            const Text('内容预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(c.textContent,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary,
                      height: 1.8)),
            ),
            const SizedBox(height: 28),

            // 选择声音
            const Text('选择声音', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            // 默认声音始终显示在最上方
            _VoiceOption(
              systemVoice: true,
              selected: _selectedVoiceId == null,
              onTap: () => setState(() => _selectedVoiceId = null),
            ),
            // 专属声音列表
            for (final v in _voices)
              _VoiceOption(
                voice: v,
                selected: _selectedVoiceId == v.id,
                onTap: () => setState(() => _selectedVoiceId = v.id),
              ),
            // 没有专属声音时，显示录音引导提示
            if (_voices.isEmpty) ...[
              const SizedBox(height: 8),
              _RecordVoiceHint(onTap: () => context.push('/voice/guide?role=mom')),
            ],
            const SizedBox(height: 80),
          ]),
        )),
      ]),

      // 底部合成按钮
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_selectedVoiceId != null ? '生成专属版本并播放' : '使用默认声音播放'),
              onPressed: () => context.push(
                '/player/${c.id}${_selectedVoiceId != null ? '?voiceModelId=$_selectedVoiceId' : ''}'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
  );
}

class _VoiceOption extends StatelessWidget {
  final VoiceModel? voice;
  final bool systemVoice;
  final bool selected;
  final VoidCallback onTap;

  const _VoiceOption({
    this.voice, this.systemVoice = false,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Text(systemVoice ? '🔊' : (voice?.roleEmoji ?? ''),
            style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(systemVoice ? '系统声音' : '${voice?.roleLabel}的声音',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(systemVoice ? '标准普通话朗读' : 'v${voice?.version} · 相似度 ${((voice?.similarityScore ?? 0.9) * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
      ]),
    ),
  );
}

class _RecordVoiceHint extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordVoiceHint({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Text('🎙', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('录制专属声音', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          Text('用爸爸/妈妈的声音朗读，更有温度', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
      ]),
    ),
  );
}

ContentModel _mockContent(String id) {
  const map = {
    '1': ContentModel(id:'1', title:'小兔子乖乖', category: ContentCategory.story,
        textContent:'小兔子乖乖，把门开开，快点开开，我要进来。\n\n不开不开我不开，妈妈没回来，谁来我也不开。\n\n叮咚叮咚，妈妈回来了，宝宝开门啦，小兔子欢快地跑出来，扑进妈妈怀抱。',
        durationSeconds: 300, minWeek: 16, maxWeek: 42, isFree: true),
  };
  return map[id] ?? map['1']!;
}

// 演示用 mock 声音模型（API 不通时展示）
final _mockVoices = [
  VoiceModel(
    id: 'mock_mom_v1',
    userId: 'demo',
    role: 'mom',
    version: 1,
    status: VoiceStatus.ready,
    similarityScore: 0.92,
    createdAt: DateTime(2025, 1, 1),
  ),
  VoiceModel(
    id: 'mock_dad_v1',
    userId: 'demo',
    role: 'dad',
    version: 1,
    status: VoiceStatus.ready,
    similarityScore: 0.88,
    createdAt: DateTime(2025, 1, 1),
  ),
];
