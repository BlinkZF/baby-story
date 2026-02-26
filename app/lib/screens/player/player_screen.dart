import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  // 专属声音播放器
  final _player = AudioPlayer();
  // 系统 TTS（默认声音）
  final _tts = FlutterTts();

  ContentModel? _content;
  _SynthState _synthState = _SynthState.loading;
  bool _isPlaying = false;
  bool _screenDim = false; // 胎教模式
  double _speed = 1.0;
  int? _sleepMin;
  Timer? _sleepTimer;

  // TTS 进度（字符位置）
  int _ttsWordStart = 0;
  int _ttsWordEnd = 0;

  // 专属声音进度
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  bool get _isTtsMode => widget.voiceModelId == null;

  @override
  void initState() {
    super.initState();

    // 专属声音播放器监听
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _total = d);
    });
    _player.playerStateStream.listen((s) {
      if (mounted && !_isTtsMode) setState(() => _isPlaying = s.playing);
    });

    _initContent();
  }

  Future<void> _initContent() async {
    try {
      final content = await ApiService.instance.getContent(widget.contentId);
      if (mounted) setState(() => _content = content);
    } catch (_) {
      if (mounted) setState(() => _content = _mockContent(widget.contentId));
    }

    if (_isTtsMode) {
      await _initTts();
    } else {
      await _synthesize();
    }
  }

  // ── TTS 初始化
  Future<void> _initTts() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5); // 0.0~1.0，0.5 接近正常语速
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _tts.setPauseHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _tts.setContinueHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });
    // 高亮朗读进度（部分平台支持）
    _tts.setProgressHandler((text, start, end, word) {
      if (mounted) setState(() {
        _ttsWordStart = start;
        _ttsWordEnd = end;
      });
    });

    if (mounted) setState(() => _synthState = _SynthState.ready);
  }

  // ── TTS 播放/暂停
  Future<void> _ttsTogglePlay() async {
    final text = _content?.textContent ?? '';
    if (text.isEmpty) return;
    if (_isPlaying) {
      await _tts.pause();
    } else {
      // 重新朗读（部分平台不支持 resume，统一用 speak）
      await _tts.speak(text);
    }
  }

  // ── 专属声音合成
  Future<void> _synthesize() async {
    setState(() => _synthState = _SynthState.loading);
    try {
      final res = await ApiService.instance.synthesize(
        widget.contentId,
        widget.voiceModelId!,
      );
      await _pollSynthesize(res['taskId']);
    } catch (_) {
      // 合成失败降级为 TTS
      if (mounted) {
        setState(() => _isTtsFallback = true);
        await _initTts();
      }
    }
  }

  bool _isTtsFallback = false;

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
    if (_isTtsMode || _isTtsFallback) {
      _ttsTogglePlay();
    } else {
      if (_isPlaying) _player.pause(); else _player.play();
    }
  }

  void _seek(Duration pos) {
    if (!_isTtsMode) _player.seek(pos);
  }

  void _changeSpeed(double s) {
    setState(() => _speed = s);
    if (_isTtsMode || _isTtsFallback) {
      // TTS 速度：0.5 = 1x，映射关系
      _tts.setSpeechRate(0.5 * s);
    } else {
      _player.setSpeed(s);
    }
  }

  void _setSleepTimer(int? min) {
    _sleepTimer?.cancel();
    setState(() => _sleepMin = min);
    if (min != null) {
      _sleepTimer = Timer(Duration(minutes: min), () async {
        if (_isTtsMode || _isTtsFallback) {
          await _tts.stop();
        } else {
          _player.pause();
        }
        if (mounted) setState(() => _sleepMin = null);
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _tts.stop();
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

  // ── 胎教模式（暗屏大字 + 高亮朗读进度）
  Widget _buildDimMode() => GestureDetector(
    onTap: () => setState(() => _screenDim = false),
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _isTtsMode
              ? _HighlightText(
                  text: _content?.textContent ?? '',
                  start: _ttsWordStart,
                  end: _ttsWordEnd,
                  style: const TextStyle(fontSize: 22, color: Colors.white70, height: 1.9),
                  highlightColor: AppColors.primary,
                )
              : Text(
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
          Text(
            _isTtsFallback
                ? '系统普通话朗读（专属声音生成失败）'
                : (widget.voiceModelId != null ? '专属声音版本' : '系统普通话朗读'),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),

          // 合成状态
          if (_synthState == _SynthState.loading) ...[
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              widget.voiceModelId != null
                  ? '正在生成专属音频，约 10~30 秒...'
                  : '正在初始化朗读引擎...',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
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

          // 进度条（专属声音模式才显示，TTS 不支持 seek）
          if (_synthState == _SynthState.ready && !_isTtsMode && !_isTtsFallback) ...[
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

          if (_synthState == _SynthState.ready && (_isTtsMode || _isTtsFallback))
            const SizedBox(height: 24),

          // 主控制按钮
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (!_isTtsMode && !_isTtsFallback)
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, size: 36),
                color: AppColors.textSecondary,
                onPressed: () => _seek(_position - const Duration(seconds: 10)),
              ),
            if (!_isTtsMode && !_isTtsFallback) const SizedBox(width: 16),
            _buildPlayButton(),
            if (!_isTtsMode && !_isTtsFallback) const SizedBox(width: 16),
            if (!_isTtsMode && !_isTtsFallback)
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, size: 36),
                color: AppColors.textSecondary,
                onPressed: () => _seek(_position + const Duration(seconds: 10)),
              ),
          ]),
          const SizedBox(height: 24),

          // 速度 & 定时
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ControlChip(
              label: '${_speed}x',
              onTap: () => _showSpeedSheet(),
            ),
            const SizedBox(width: 12),
            _ControlChip(
              label: _sleepMin == null ? '定时关闭' : '$_sleepMin 分钟后停',
              active: _sleepMin != null,
              onTap: () => _showSleepSheet(),
            ),
          ]),
          const SizedBox(height: 40),

          // 内容文字（TTS 模式高亮当前朗读词）
          if (_content != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            const Text('内容文字',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            _isTtsMode || _isTtsFallback
                ? _HighlightText(
                    text: _content!.textContent,
                    start: _ttsWordStart,
                    end: _ttsWordEnd,
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.9),
                    highlightColor: AppColors.primary,
                  )
                : Text(_content!.textContent,
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
          color: _synthState == _SynthState.ready ? AppColors.primary : AppColors.divider,
          shape: BoxShape.circle,
          boxShadow: _synthState == _SynthState.ready
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))]
              : [],
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

// ── 朗读高亮文字组件
class _HighlightText extends StatelessWidget {
  final String text;
  final int start;
  final int end;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightText({
    required this.text,
    required this.start,
    required this.end,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (start >= end || start < 0 || end > text.length) {
      return Text(text, style: style, textAlign: TextAlign.left);
    }
    return RichText(
      text: TextSpan(children: [
        TextSpan(text: text.substring(0, start), style: style),
        TextSpan(
          text: text.substring(start, end),
          style: style.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.w700,
            backgroundColor: highlightColor.withOpacity(0.15),
          ),
        ),
        TextSpan(text: text.substring(end), style: style),
      ]),
    );
  }
}

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
