import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class VoiceResultScreen extends StatefulWidget {
  final String taskId;
  const VoiceResultScreen({super.key, required this.taskId});

  @override
  State<VoiceResultScreen> createState() => _VoiceResultScreenState();
}

class _VoiceResultScreenState extends State<VoiceResultScreen> {
  _TrainState _state = _TrainState.training;
  int _elapsedSeconds = 0;
  Timer? _pollTimer;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final data = await ApiService.instance.getTrainingStatus(widget.taskId);
        final status = data['status'] as String?;
        if (!mounted) return;
        if (status == 'ready') {
          setState(() => _state = _TrainState.done);
          _pollTimer?.cancel();
          _elapsedTimer?.cancel();
        } else if (status == 'failed') {
          setState(() => _state = _TrainState.failed);
          _pollTimer?.cancel();
          _elapsedTimer?.cancel();
        }
      } catch (_) {
        // 演示模式：15 秒后模拟完成
        if (_elapsedSeconds >= 15 && mounted) {
          setState(() => _state = _TrainState.done);
          _pollTimer?.cancel();
          _elapsedTimer?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('声音训练'),
        automaticallyImplyLeading: _state != _TrainState.training,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _state == _TrainState.training
              ? _buildTraining()
              : _state == _TrainState.done
                  ? _buildDone()
                  : _buildFailed(),
        ),
      ),
    );
  }

  Widget _buildTraining() => Column(mainAxisSize: MainAxisSize.min, children: [
    const SizedBox(
      width: 80, height: 80,
      child: CircularProgressIndicator(strokeWidth: 5, color: AppColors.primary),
    ),
    const SizedBox(height: 28),
    const Text('AI 正在学习你的声音', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('这大约需要 5~10 分钟，请稍候',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    const SizedBox(height: 24),
    Text('已用时 ${_formatTime(_elapsedSeconds)}',
        style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
    const SizedBox(height: 32),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: const [
        _StepItem(icon: '✅', text: '音频上传完成'),
        _StepItem(icon: '✅', text: '音频预处理（降噪）完成'),
        _StepItem(icon: '🔄', text: 'AI 声音模型训练中...'),
        _StepItem(icon: '⏳', text: '声音相似度评估', pending: true),
      ]),
    ),
  ]);

  Widget _buildDone() => Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🎉', style: TextStyle(fontSize: 72)),
    const SizedBox(height: 20),
    const Text('声音训练完成！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('AI 已学会你的声音，快去给宝宝讲故事吧',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
    const SizedBox(height: 36),
    SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: () => context.go('/content'),
        child: const Text('去选一个故事'),
      ),
    ),
    const SizedBox(height: 12),
    TextButton(
      onPressed: () => context.go('/home'),
      child: const Text('返回首页', style: TextStyle(color: AppColors.textSecondary)),
    ),
  ]);

  Widget _buildFailed() => Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('😔', style: TextStyle(fontSize: 64)),
    const SizedBox(height: 20),
    const Text('训练失败', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('可能是录音质量不够好，请重新录制',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    const SizedBox(height: 32),
    SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: () => context.go('/voice/guide?role=mom'),
        child: const Text('重新录制'),
      ),
    ),
  ]);

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

enum _TrainState { training, done, failed }

class _StepItem extends StatelessWidget {
  final String icon, text;
  final bool pending;
  const _StepItem({required this.icon, required this.text, this.pending = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(
          fontSize: 14,
          color: pending ? AppColors.textHint : AppColors.textPrimary)),
    ]),
  );
}
