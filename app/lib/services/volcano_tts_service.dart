import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// 火山引擎 TTS 声音复刻服务
//
// 使用前在"我的 -> 设置 API Key"中填入：
//   - appId   火山引擎控制台 -> 语音技术 -> 应用管理 -> AppID
//   - token   控制台 -> API Key（Access Token）
//
// 整体流程：
//   1. uploadAudio(filePath)    上传音频 → audio_id
//   2. createVoice(audioIds)    创建声音模型 → voice_id（training）
//   3. pollVoiceStatus(voiceId) 轮询直到 finished
//   4. synthesize(voiceId,text) 合成 → audio_url
// ─────────────────────────────────────────────────────────────
class VolcanoTtsService {
  VolcanoTtsService._();
  static final instance = VolcanoTtsService._();

  static const _baseUrl = 'https://openspeech.bytedance.com/api/v1/voice_clone';

  // SharedPreferences key
  static const _kAppId = 'volcano_app_id';
  static const _kToken = 'volcano_token';

  String? _appId;
  String? _token;

  /// 加载已保存的 API 配置
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _appId = prefs.getString(_kAppId);
    _token = prefs.getString(_kToken);
  }

  /// 保存 API 配置
  Future<void> saveConfig({required String appId, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppId, appId);
    await prefs.setString(_kToken, token);
    _appId = appId;
    _token = token;
  }

  bool get isConfigured => (_appId?.isNotEmpty ?? false) && (_token?.isNotEmpty ?? false);

  // ── 内部 Dio 实例
  Dio get _dio => Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Map<String, String> get _headers => {
    'Authorization': 'Bearer;$_token',
    'Content-Type': 'application/json',
    'Resource-Id': 'volc.megatts.voiceclone',
  };

  // ─────────────────────────────────────────────────────────
  // Step 1: 上传音频文件
  // ─────────────────────────────────────────────────────────
  /// 上传一个 m4a/wav 音频文件，返回 audio_id
  Future<String> uploadAudio(String filePath) async {
    _assertConfigured();
    final file = File(filePath);
    if (!file.existsSync()) throw Exception('音频文件不存在: $filePath');

    final formData = FormData.fromMap({
      'appid': _appId,
      'audio_file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final resp = await _dio.post(
      '$_baseUrl/upload',
      data: formData,
      options: Options(headers: {
        'Authorization': 'Bearer;$_token',
        'Resource-Id': 'volc.megatts.voiceclone',
      }),
    );

    _checkCode(resp.data);
    return resp.data['audio_id'] as String;
  }

  // ─────────────────────────────────────────────────────────
  // Step 2: 创建声音模型（训练）
  // ─────────────────────────────────────────────────────────
  /// audioIds: 已上传的音频 ID 列表（建议 ≥5 条）
  /// speaker: 'male' | 'female'
  /// 返回 speaker_id（voice_id）
  Future<String> createVoice({
    required List<String> audioIds,
    required String speaker,
    String? voiceName,
  }) async {
    _assertConfigured();
    final body = {
      'appid': _appId,
      'speaker_id': '${_appId}_${speaker}_${DateTime.now().millisecondsSinceEpoch}',
      'audios': audioIds.map((id) => {'audio_id': id}).toList(),
      'source': 2, // 2 = 用户上传音频
      'language': 0, // 0 = 中文
      'model_type': 1, // 1 = 标准版
    };

    final resp = await _dio.post(
      '$_baseUrl/train',
      data: jsonEncode(body),
      options: Options(headers: _headers),
    );

    _checkCode(resp.data);
    // 返回 speaker_id，后续用于查状态和合成
    return body['speaker_id'] as String;
  }

  // ─────────────────────────────────────────────────────────
  // Step 3: 查询训练状态
  // ─────────────────────────────────────────────────────────
  /// 返回状态字符串: 'training' | 'active' | 'failed'
  Future<String> getVoiceStatus(String speakerId) async {
    _assertConfigured();
    final body = {'appid': _appId, 'speaker_id': speakerId};
    final resp = await _dio.post(
      '$_baseUrl/status',
      data: jsonEncode(body),
      options: Options(headers: _headers),
    );
    _checkCode(resp.data);
    // status: 0=training, 1=active, 2=failed
    final status = resp.data['status'] as int? ?? 0;
    switch (status) {
      case 1: return 'active';
      case 2: return 'failed';
      default: return 'training';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Step 4: 合成语音
  // ─────────────────────────────────────────────────────────
  /// 用训练好的声音合成文本，返回音频 URL
  Future<String> synthesize({
    required String speakerId,
    required String text,
    double speed = 1.0,
  }) async {
    _assertConfigured();

    // 火山引擎 TTS 合成接口（大模型 TTS）
    final body = {
      'app': {
        'appid': _appId,
        'token': _token,
        'cluster': 'volcano_mega',
      },
      'user': {'uid': 'baobao_user'},
      'audio': {
        'voice_type': speakerId,
        'encoding': 'mp3',
        'speed_ratio': speed,
        'volume_ratio': 1.0,
        'pitch_ratio': 1.0,
      },
      'request': {
        'reqid': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
      },
    };

    final resp = await _dio.post(
      'https://openspeech.bytedance.com/api/v1/tts',
      data: jsonEncode(body),
      options: Options(headers: {
        'Authorization': 'Bearer;$_token',
        'Content-Type': 'application/json',
      }),
    );

    // TTS 接口直接返回 base64 音频数据
    if (resp.data['code'] == 3000) {
      final base64Audio = resp.data['data'] as String;
      // 保存到临时文件
      final audioPath = await _saveBase64Audio(base64Audio, speakerId);
      return audioPath;
    }

    throw Exception('合成失败: ${resp.data['message']}');
  }

  // ─────────────────────────────────────────────────────────
  // 将 base64 音频保存为临时 mp3 文件，返回本地路径
  // ─────────────────────────────────────────────────────────
  Future<String> _saveBase64Audio(String base64Data, String speakerId) async {
    final bytes = base64Decode(base64Data);
    // 使用 path_provider 获取缓存目录
    final tmpDir = await _getTmpDir();
    final path = '$tmpDir/synth_${speakerId}_${DateTime.now().millisecondsSinceEpoch}.mp3';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> _getTmpDir() async {
    // 避免循环依赖，直接用 Platform 判断
    if (Platform.isIOS || Platform.isMacOS) {
      // NSTemporaryDirectory
      return Directory.systemTemp.path;
    }
    return Directory.systemTemp.path;
  }

  void _assertConfigured() {
    if (!isConfigured) {
      throw Exception('请先在"我的 -> 设置 API Key"中填入火山引擎 AppID 和 Token');
    }
  }

  void _checkCode(dynamic data) {
    if (data == null) throw Exception('接口无响应');
    final code = data['BaseResp']?['StatusCode'] ?? data['code'] ?? -1;
    if (code != 0) {
      final msg = data['BaseResp']?['StatusMessage'] ?? data['message'] ?? '未知错误';
      throw Exception('火山引擎 API 错误($code): $msg');
    }
  }
}
