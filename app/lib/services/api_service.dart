import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

// localhost 用于 Web/macOS 调试，手机调试时改为 Mac 局域网 IP
const _baseUrl = 'http://172.16.10.13:8081/api/v1';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  late final Dio _dio = Dio(BaseOptions(baseUrl: _baseUrl))
    ..interceptors.add(_AuthInterceptor());

  // ── 认证 ──────────────────────────────────────
  Future<void> sendCode(String phone) =>
      _dio.post('/auth/send-code', data: {'phone': phone});

  Future<Map<String, dynamic>> login(String phone, String code) async {
    final res = await _dio.post('/auth/login', data: {'phone': phone, 'code': code});
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() => _dio.post('/auth/logout');

  Future<UserModel> getMe() async {
    final res = await _dio.get('/auth/me');
    return UserModel.fromJson(res.data);
  }

  Future<UserModel> updateMe(Map<String, dynamic> body) async {
    final res = await _dio.put('/auth/me', data: body);
    return UserModel.fromJson(res.data);
  }

  // ── 声音模型 ──────────────────────────────────
  Future<List<VoiceModel>> getVoiceModels() async {
    final res = await _dio.get('/voice/models');
    return (res.data as List).map((e) => VoiceModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> startTraining(String role) async {
    final res = await _dio.post('/voice/start-training', data: {'role': role});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTrainingStatus(String taskId) async {
    final res = await _dio.get('/voice/training-status', queryParameters: {'taskId': taskId});
    return res.data as Map<String, dynamic>;
  }

  Future<void> confirmVoiceModel(String modelId) =>
      _dio.post('/voice/confirm', data: {'modelId': modelId});

  // ── 内容 ──────────────────────────────────────
  Future<List<ContentModel>> getContents({String? category, int page = 0}) async {
    final res = await _dio.get('/contents', queryParameters: {
      if (category != null) 'category': category,
      'page': page,
      'size': 20,
    });
    return (res.data['list'] as List).map((e) => ContentModel.fromJson(e)).toList();
  }

  Future<ContentModel> getContent(String id) async {
    final res = await _dio.get('/contents/$id');
    return ContentModel.fromJson(res.data);
  }

  // ── 合成 ──────────────────────────────────────
  Future<Map<String, dynamic>> synthesize(String contentId, String voiceModelId, {double speed = 1.0}) async {
    final res = await _dio.post('/synthesize', data: {
      'contentId': contentId,
      'voiceModelId': voiceModelId,
      'speed': speed,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSynthesizeStatus(String taskId) async {
    final res = await _dio.get('/synthesize/$taskId');
    return res.data as Map<String, dynamic>;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
