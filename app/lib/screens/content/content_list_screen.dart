import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});
  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _categories = [null, ...ContentCategory.values]; // null = 全部
  final Map<String, List<ContentModel>> _cache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _loadTab(_tabCtrl.index);
    });
    _loadTab(0);
  }

  Future<void> _loadTab(int idx) async {
    final cat = _categories[idx];
    final key  = cat?.name ?? 'all';
    if (_cache.containsKey(key)) return;
    setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getContents(category: cat?.name);
      if (mounted) setState(() => _cache[key] = list);
    } catch (_) {
      if (mounted) setState(() => _cache[key] = _mockContents);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('胎教内容'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: _categories.map((c) => Tab(text: c == null ? '全部' : c.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _categories.map((cat) {
          final key  = cat?.name ?? 'all';
          final list = _cache[key] ?? [];
          if (_loading && list.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (list.isEmpty) {
            return const Center(child: Text('暂无内容', style: TextStyle(color: AppColors.textHint)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ContentListItem(content: list[i]),
          );
        }).toList(),
      ),
    );
  }
}

class _ContentListItem extends StatelessWidget {
  final ContentModel content;
  const _ContentListItem({required this.content});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/content/${content.id}'),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        // 封面
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(content.category.emoji,
              style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(content.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(content.category.label,
              style: const TextStyle(fontSize: 12, color: AppColors.primary)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
            const SizedBox(width: 3),
            Text(content.durationLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(width: 12),
            const Icon(Icons.pregnant_woman_rounded, size: 13, color: AppColors.textHint),
            const SizedBox(width: 3),
            Text(content.weekLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ]),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
      ]),
    ),
  );
}

// Mock 数据
const _mockContents = [
  ContentModel(id:'1', title:'小兔子乖乖', category: ContentCategory.story,
      textContent:'小兔子乖乖，把门开开，快点开开，我要进来。不开不开我不开，妈妈没回来，谁来我也不开。',
      durationSeconds: 300, minWeek: 16, maxWeek: 42, isFree: true),
  ContentModel(id:'2', title:'三字经', category: ContentCategory.classic,
      textContent:'人之初，性本善，性相近，习相远。苟不教，性乃迁，教之道，贵以专。',
      durationSeconds: 480, minWeek: 20, maxWeek: 42, isFree: true),
  ContentModel(id:'3', title:'睡前冥想放松', category: ContentCategory.meditation,
      textContent:'闭上眼睛，深呼吸，感受宝宝在你肚子里轻轻地动着，感受这份温柔的连接...',
      durationSeconds: 600, minWeek: 12, maxWeek: 42, isFree: false),
  ContentModel(id:'4', title:'一闪一闪亮晶晶', category: ContentCategory.song,
      textContent:'一闪一闪亮晶晶，满天都是小星星，挂在天上放光明，好像许多小眼睛。',
      durationSeconds: 180, minWeek: 16, maxWeek: 42, isFree: true),
  ContentModel(id:'5', title:'小熊请客', category: ContentCategory.story,
      textContent:'小熊家里来了好多朋友，有小兔、小狐狸和小猫...',
      durationSeconds: 420, minWeek: 20, maxWeek: 42, isFree: false),
  ContentModel(id:'6', title:'感恩的心', category: ContentCategory.song,
      textContent:'感恩的心，感谢有你，伴我一生，让我有勇气做我自己...',
      durationSeconds: 240, minWeek: 16, maxWeek: 42, isFree: true),
];
