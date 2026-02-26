import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';

// 引导朗读文本（40 句，覆盖常见音节）
const _sentences = [
  '春天来了，小花朵悄悄地开放了。',
  '宝贝，爸爸妈妈每天都很想你。',
  '小鸟在树上唱歌，声音真好听。',
  '我们要健康快乐地成长。',
  '蓝天白云，微风吹来好凉爽。',
  '小朋友们手拉手，一起去郊游。',
  '月亮出来了，星星也跟着笑了。',
  '妈妈做的饭菜香喷喷，真好吃。',
  '河里的小鱼游来游去，多快活。',
  '爸爸下班回家，宝宝跑去拥抱他。',
  '早上起来，我们刷牙洗脸。',
  '小猫咪蹦蹦跳跳，喵喵喵地叫。',
  '彩虹有红橙黄绿青蓝紫七种颜色。',
  '下雨了，青蛙呱呱叫着欢迎雨水。',
  '奶奶讲的故事，我最爱听了。',
  '一闪一闪亮晶晶，满天都是小星星。',
  '小种子发芽了，努力向上生长。',
  '我们爱护小动物，不伤害它们。',
  '风轻轻地吹，树叶沙沙地响。',
  '太阳公公每天早早地起床。',
  '小河流水哗哗响，鱼儿水中游。',
  '今天天气真好，适合出去玩耍。',
  '爸爸妈妈爱宝宝，宝宝也爱爸爸妈妈。',
  '我们要做诚实善良的好孩子。',
  '小蝴蝶飞来飞去，真漂亮啊。',
  '一年有春夏秋冬四个季节。',
  '晚上睡觉前要说晚安，做个好梦。',
  '小手拍拍，小脚踩踩，快乐做运动。',
  '葡萄是紫色的，苹果是红色的。',
  '勇敢的孩子不怕困难，努力向前。',
  '大山高高，白云绕着山腰飘。',
  '小朋友爱读书，知识像宝藏。',
  '雪花飘落下来，世界变成白色了。',
  '海浪一波波，沙滩上有贝壳。',
  '小兔子乖乖，把门开开，快点开开。',
  '竹子节节高，我们要向竹子学习。',
  '天上的云朵变成了一只小羊。',
  '秋天到了，树叶变成了金黄色。',
  '睡觉前喝杯牛奶，身体棒棒的。',
  '宝宝加油，你是最棒的小天使。',
];

class VoiceRecordScreen extends StatefulWidget {
  final String role;
  const VoiceRecordScreen({super.key, required this.role});

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen>
    with TickerProviderStateMixin {
  final _recorder = AudioRecorder();

  int  _current   = 0;        // 当前朗读句子索引
  bool _recording = false;
  bool _loading   = false;
  String? _currentPath;

  // 已录制的文件路径
  final List<String?> _recorded = List.filled(_sentences.length, null);

  // 波形动画
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    await Permission.microphone.request();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecord();
    } else {
      await _startRecord();
    }
  }

  Future<void> _startRecord() async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${widget.role}_${_current}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _recording = true; _currentPath = path; });
  }

  Future<void> _stopRecord() async {
    await _recorder.stop();
    setState(() {
      _recording = false;
      _recorded[_current] = _currentPath;
    });
  }

  void _next() {
    if (_current < _sentences.length - 1) {
      setState(() => _current++);
    }
  }

  void _prev() {
    if (_current > 0) setState(() => _current--);
  }

  int get _doneCount => _recorded.where((p) => p != null).length;
  double get _progress => _doneCount / _sentences.length;

  Future<void> _submit() async {
    if (_doneCount < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少完成 20 句录音'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _loading = true);
    // TODO: 上传音频文件到服务器，然后调用 start-training 接口
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) context.go('/voice/result?taskId=demo_task_001');
  }

  @override
  void dispose() {
    _recorder.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _recorded[_current] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('录制${widget.role == 'dad' ? '爸爸' : '妈妈'}的声音'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(),
        ),
        actions: [
          if (_doneCount >= 20)
            TextButton(
              onPressed: _loading ? null : _submit,
              child: const Text('提交', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(children: [
        // 进度条
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppColors.divider,
          color: AppColors.primary,
          minHeight: 3,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Text('已完成 $_doneCount / ${_sentences.length} 句',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Text('${(_progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ]),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // 句子编号
              Text('第 ${_current + 1} 句',
                  style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 16),
              // 朗读文本
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _recording ? AppColors.primary : AppColors.divider,
                    width: _recording ? 2 : 1,
                  ),
                ),
                child: Text(
                  _sentences[_current],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, height: 1.7,
                      color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),

              // 波形指示器
              SizedBox(
                height: 48,
                child: _recording
                    ? AnimatedBuilder(
                        animation: _waveCtrl,
                        builder: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(12, (i) {
                            final offset = (i % 3) * 0.3;
                            final h = 8 + 28 * (((_waveCtrl.value + offset) % 1.0));
                            return Container(
                              width: 5, height: h,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      )
                    : isDone
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                            SizedBox(width: 6),
                            Text('已录制', style: TextStyle(color: AppColors.success, fontSize: 14)),
                          ])
                        : const Text('点击麦克风开始录音',
                            style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ),
              const SizedBox(height: 32),

              // 录音按钮
              GestureDetector(
                onTap: _toggleRecord,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: _recording ? AppColors.error : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: (_recording ? AppColors.error : AppColors.primary).withOpacity(0.35),
                      blurRadius: 20, offset: const Offset(0, 6),
                    )],
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(_recording ? '点击停止' : (isDone ? '重新录制' : '开始录音'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ),

        // 底部上下翻页
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _current > 0 ? _prev : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                label: const Text('上一句'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _current < _sentences.length - 1 ? _next : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                label: const Text('下一句'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _showExitDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出录制？'),
        content: const Text('已录制的内容将丢失，确定退出吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续录制')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('退出', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true && mounted) context.pop();
  }
}
