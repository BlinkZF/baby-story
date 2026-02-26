import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final String contentId;
  final String? voiceModelId;
  const PlayerScreen({super.key, required this.contentId, this.voiceModelId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = AudioPlayer();

  ContentModel? _content;
  _SynthState  _synthState = _SynthState.loading;
  bool _isPlaying  = false;
  bool _screenDim  = false;   // 胎教模式
  double _speed    = 1.0;
  int?  _sleepMin;            // 定时关闭（分钟）
  Timer? _sleepTimer;
  Duration _position = Duration.zero;
  Duration _total    = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((p) { if (mounted) setState(() => _position = p); });
    _player.durationStream.listen((d) { if (d != null && mounted) setState(() => _total = d); });
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    _initContent();
  }

  Future<void> _initContent() async {
    try {
      final content = await ApiService.instance.getContent(widget.contentId);
      if (mounted) setState(() => _content = content);
      await _synthesize();
    } catch (_) {
      if (mounted) {
        setState(() {
          _content   = _mockContent(widget.contentId);
          _synthState = _SynthState.ready;
        });
        // 演示：加载一段示例音频（公共域）
        try {
          await _player.setUrl(
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
        } catch (_) {}
      }
    }
  }

  Future<void> _synthesize() async {
    setState(() => _synthState = _SynthState.loading);
    try {
      final res = await ApiService.instance.synthesize(
        widget.contentId,
        widget.voiceModelId ?? 'system',
      );
      // 轮询合成状态
      await _pollSynthesize(res['taskId']);
    } catch (_) {
      if (mounted) setState(() => _synthState = _SynthState.ready);
    }
  }

  Future<void> _pollSynthesize(String taskId) async {
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final data = await ApiService.instance.getSynthesizeStatus(taskId);
        if (data['status'] == 'done') {
          await _player.setUrl(data['audioUrl']);
          if (mounted) setState(() => _synthState = _SynthState.ready);
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _synthState = _SynthState.failed);
  }

  void _togglePlay() {
    if (_isPlaying) _player.pause(); else _player.play();
  }

  void _seek(Duration pos) => _player.seek(pos);

  void _changeSpeed(double s) {
    setState(() => _speed = s);
    _player.setSpeed(s);
  }

  void _setSleepTimer(int? min) {
    _sleepTimer?.cancel();
    setState(() => _sleepMin = min);
    if (min != null) {
      _sleepTimer = Timer(Duration(minutes: min), () {
        _player.pause();
        if (mounted) setState(() => _sleepMin = null);
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 胎教模式：全屏变暗
    if (_screenDim) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return Scaffold(
      backgroundColor: _screenDim ? const Color(0xFF1A1A2E) : AppColors.bg,
      body: SafeArea(
        child: _screenDim ? _buildDimMode() : _buildNormalMode(),
      ),
    );
  }

  // ── 胎教模式（暗屏大字）
  Widget _buildDimMode() => GestureDetector(
    onTap: () => setState(() => _screenDim = false),
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _content?.textContent ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.white70, height: 1.9),
          ),
        ),
        const SizedBox(height: 60),
        _buildPlayButton(large: true),
        const SizedBox(height: 24),
        const Text('轻触屏幕退出胎教模式',
            style: TextStyle(fontSize: 12, color: Colors.white30)),
      ]),
    ),
  );

  // ── 普通模式
  Widget _buildNormalMode() => Column(children: [
    // 顶部栏
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: () => context.pop(),
        ),
        const Spacer(),
        const Text('正在播放', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        IconButton(
          icon: Icon(_screenDim ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
              color: AppColors.primary),
          tooltip: '胎教模式',
          onPressed: () => setState(() => _screenDim = true),
        ),
      ]),
    ),

    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 16),
          // 封面
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 30, offset: const Offset(0, 12),
              )],
            ),
            child: Center(child: Text(
              _content?.category.emoji ?? '🎵',
              style: const TextStyle(fontSize: 80),
            )),
          ),
          const SizedBox(height: 28),
          Text(_content?.title ?? '加载中...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.voiceModelId != null ? '专属声音版本' : '系统声音版本',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 32),

          // 合成状态
          if (_synthState == _SynthState.loading) ...[
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('正在生成专属音频，约 10~30 秒...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 32),
          ],

          if (_synthState == _SynthState.failed) ...[
            const Text('🙁', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            const Text('生成失败，请重试',
                style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: _synthesize, child: const Text('重新生成')),
            const SizedBox(height: 24),
          ],

          // 进度条
          if (_synthState == _SynthState.ready) ...[
            Slider(
              value: _position.inSeconds.toDouble().clamp(0, _total.inSeconds.toDouble()),
              max: _total.inSeconds.toDouble().clamp(1, double.infinity),
              activeColor: AppColors.primary,
              inactiveColor: AppColors.divider,
              onChanged: (v) => _seek(Duration(seconds: v.toInt())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Text(_formatDur(_position), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                const Spacer(),
                Text(_formatDur(_total), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // 主控制按钮
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded, size: 36),
              color: AppColors.textSecondary,
              onPressed: () => _seek(_position - const Duration(seconds: 10)),
            ),
            const SizedBox(width: 16),
            _buildPlayButton(),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded, size: 36),
              color: AppColors.textSecondary,
              onPressed: () => _seek(_position + const Duration(seconds: 10)),
            ),
          ]),
          const SizedBox(height: 24),

          // 速度 & 定时
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // 速度选择
            _ControlChip(
              label: '${_speed}x',
              onTap: () => _showSpeedSheet(),
            ),
            const SizedBox(width: 12),
            // 定时关闭
            _ControlChip(
              label: _sleepMin == null ? '定时关闭' : '$_sleepMin 分钟后停',
              active: _sleepMin != null,
              onTap: () => _showSleepSheet(),
            ),
          ]),
          const SizedBox(height: 40),

          // 内容文字（跟读区）
          if (_content != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            const Text('内容文字',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Text(_content!.textContent,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.9)),
            const SizedBox(height: 32),
          ],
        ]),
      ),
    ),
  ]);

  Widget _buildPlayButton({bool large = false}) {
    final size = large ? 80.0 : 64.0;
    return GestureDetector(
      onTap: _synthState == _SynthState.ready ? _togglePlay : null,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 6),
          )],
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white, size: large ? 44 : 36,
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        const Text('播放速度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final s in [0.8, 1.0, 1.2])
          ListTile(
            title: Text('$s倍速${s == 1.0 ? '（正常）' : ''}'),
            trailing: _speed == s ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { _changeSpeed(s); Navigator.pop(context); },
          ),
        const SizedBox(height: 8),
      ]),
    );
  }

  void _showSleepSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        const Text('定时关闭', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final m in [15, 30, 60])
          ListTile(
            title: Text('$m 分钟后停止'),
            trailing: _sleepMin == m ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { _setSleepTimer(m); Navigator.pop(context); },
          ),
        ListTile(
          title: const Text('取消定时'),
          onTap: () { _setSleepTimer(null); Navigator.pop(context); },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

enum _SynthState { loading, ready, failed }

class _ControlChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ControlChip({required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary : AppColors.divider),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: active ? AppColors.primary : AppColors.textSecondary,
      )),
    ),
  );
}

ContentModel _mockContent(String id) => const ContentModel(
  id: '1', title: '小兔子乖乖', category: ContentCategory.story,
  textContent: '小兔子乖乖，把门开开，快点开开，我要进来。\n\n不开不开我不开，妈妈没回来，谁来我也不开。\n\n叮咚叮咚，妈妈回来了，宝宝开门啦！',
  durationSeconds: 300, minWeek: 16, maxWeek: 42, isFree: true,
);
