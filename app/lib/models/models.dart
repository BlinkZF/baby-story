// ────────────────────────────────────────────
// 用户
// ────────────────────────────────────────────
class UserModel {
  final String id;
  final String phone;
  final String nickname;
  final DateTime? dueDate;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.phone,
    required this.nickname,
    this.dueDate,
    this.avatarUrl,
  });

  /// 当前孕周（无预产期返回 0）
  int get currentWeek {
    if (dueDate == null) return 0;
    final diff = DateTime.now()
        .difference(dueDate!.subtract(const Duration(days: 280)))
        .inDays;
    return diff.clamp(1, 42);
  }

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        phone: j['phone'],
        nickname: j['nickname'] ?? '',
        dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
        avatarUrl: j['avatarUrl'],
      );

  UserModel copyWith({String? nickname, DateTime? dueDate}) => UserModel(
        id: id, phone: phone,
        nickname: nickname ?? this.nickname,
        dueDate: dueDate ?? this.dueDate,
        avatarUrl: avatarUrl,
      );
}

// ────────────────────────────────────────────
// 声音模型
// ────────────────────────────────────────────
class VoiceModel {
  final String id;
  final String userId;
  final String role;           // 'dad' | 'mom'
  final int version;
  final VoiceStatus status;
  final double? similarityScore;
  final int? sampleDuration;
  final DateTime createdAt;
  /// 火山引擎 speaker_id（有值说明已上传训练）
  final String? speakerId;

  const VoiceModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.version,
    required this.status,
    this.similarityScore,
    this.sampleDuration,
    required this.createdAt,
    this.speakerId,
  });

  String get roleLabel => role == 'dad' ? '爸爸' : '妈妈';
  String get roleEmoji => role == 'dad' ? '👨' : '👩';
  /// 是否已接入火山引擎声音克隆
  bool get hasVolcanoVoice => speakerId != null && status == VoiceStatus.ready;

  factory VoiceModel.fromJson(Map<String, dynamic> j) => VoiceModel(
        id: j['id'],
        userId: j['userId'],
        role: j['role'],
        version: j['version'] ?? 1,
        status: VoiceStatus.values.byName(j['status']),
        similarityScore: (j['similarityScore'] as num?)?.toDouble(),
        sampleDuration: j['sampleDuration'],
        createdAt: DateTime.parse(j['createdAt']),
        speakerId: j['speakerId'],
      );
}

enum VoiceStatus { training, ready, failed }

// ────────────────────────────────────────────
// 胎教内容
// ────────────────────────────────────────────
class ContentModel {
  final String id;
  final String title;
  final ContentCategory category;
  final String textContent;
  final int durationSeconds;
  final int minWeek;
  final int maxWeek;
  final bool isFree;
  final String? coverUrl;

  const ContentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.textContent,
    required this.durationSeconds,
    required this.minWeek,
    required this.maxWeek,
    required this.isFree,
    this.coverUrl,
  });

  String get durationLabel => '${durationSeconds ~/ 60} 分钟';
  String get weekLabel => '孕 $minWeek~$maxWeek 周';

  factory ContentModel.fromJson(Map<String, dynamic> j) => ContentModel(
        id: j['id'],
        title: j['title'],
        category: ContentCategory.values.byName(j['category']),
        textContent: j['textContent'] ?? '',
        durationSeconds: j['durationSeconds'] ?? 0,
        minWeek: j['minWeek'] ?? 0,
        maxWeek: j['maxWeek'] ?? 42,
        isFree: j['isFree'] ?? false,
        coverUrl: j['coverUrl'],
      );
}

enum ContentCategory {
  story, song, meditation, classic;

  String get label {
    switch (this) {
      case story:      return '睡前故事';
      case song:       return '儿歌童谣';
      case meditation: return '冥想放松';
      case classic:    return '国学启蒙';
    }
  }

  String get emoji {
    switch (this) {
      case story:      return '📖';
      case song:       return '🎵';
      case meditation: return '🌙';
      case classic:    return '🏮';
    }
  }
}
