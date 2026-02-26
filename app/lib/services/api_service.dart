import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'volcano_tts_service.dart';

// ─────────────────────────────────────────────────────────────
// 纯本地实现，无需后端。所有数据存储在 SharedPreferences。
// ─────────────────────────────────────────────────────────────
class ApiService {
  ApiService._();
  static final instance = ApiService._();

  // ── 认证（本地模拟）────────────────────────────────────────
  Future<void> sendCode(String phone) async {
    // 本地模式：不发短信，直接返回
  }

  Future<Map<String, dynamic>> login(String phone, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_user');
    if (raw != null) {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      return {'token': 'local_token', 'user': user};
    }
    // 新用户
    final newUser = {
      'id': 'local_user_1',
      'phone': phone,
      'nickname': '',
      'isNewUser': true,
    };
    return {'token': 'local_token', 'user': newUser};
  }

  Future<void> logout() async {
    // 本地模式：不清除用户数据，只清 token
  }

  Future<UserModel> getMe() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_user');
    if (raw != null) {
      return UserModel.fromJson(jsonDecode(raw));
    }
    return const UserModel(id: 'local_user_1', phone: '', nickname: '宝妈');
  }

  Future<UserModel> updateMe(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_user');
    final existing = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{'id': 'local_user_1', 'phone': ''};
    existing.addAll(body);
    await prefs.setString('local_user', jsonEncode(existing));
    return UserModel.fromJson(existing);
  }

  // ── 声音模型（本地存储）─────────────────────────────────────
  Future<List<VoiceModel>> getVoiceModels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_voice_models');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => VoiceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 保存录制好的声音
  /// speakerId: 火山引擎返回的声音 ID（训练中），为空时直接标记本地就绪
  Future<VoiceModel> saveLocalVoice({
    required String role,
    required String audioPath,
    String? speakerId,           // 火山引擎 speaker_id（可空）
    String status = 'ready',     // 'ready' | 'training'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_voice_models');
    final list = raw != null ? (jsonDecode(raw) as List) : [];

    // 同角色已有则升版本
    int version = 1;
    list.removeWhere((e) {
      if ((e as Map<String, dynamic>)['role'] == role) {
        version = (e['version'] as int? ?? 0) + 1;
        return true;
      }
      return false;
    });

    final newModel = {
      'id': speakerId ?? 'local_${role}_v$version',
      'userId': 'local_user_1',
      'role': role,
      'version': version,
      'status': status,
      'similarityScore': 0.90,
      'audioPath': audioPath,
      'speakerId': speakerId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    list.add(newModel);
    await prefs.setString('local_voice_models', jsonEncode(list));
    return VoiceModel.fromJson(newModel);
  }

  /// 更新声音模型状态（训练完成后调用）
  Future<void> updateVoiceStatus(String voiceId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_voice_models');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    for (final item in list) {
      if (item['id'] == voiceId) {
        item['status'] = status;
        break;
      }
    }
    await prefs.setString('local_voice_models', jsonEncode(list));
  }

  // 以下接口保留签名兼容性
  Future<Map<String, dynamic>> startTraining(String role) async =>
      {'taskId': 'local_task_001', 'status': 'done'};

  Future<Map<String, dynamic>> getTrainingStatus(String taskId) async =>
      {'status': 'done'};

  Future<void> confirmVoiceModel(String modelId) async {}

  // ── 内容（内置数据）────────────────────────────────────────
  Future<List<ContentModel>> getContents({String? category, int page = 0}) async {
    final all = _allContents;
    if (category == null) return all;
    return all.where((c) => c.category.name == category).toList();
  }

  Future<ContentModel> getContent(String id) async {
    return _allContents.firstWhere(
      (c) => c.id == id,
      orElse: () => _allContents.first,
    );
  }

  // ── 合成（优先火山引擎，未配置则降级 TTS）──────────────────
  /// 返回 {'audioPath': 本地文件路径} 或抛异常（降级 TTS）
  Future<Map<String, dynamic>> synthesize(
      String contentId, String voiceModelId, {double speed = 1.0}) async {
    final svc = VolcanoTtsService.instance;
    await svc.loadConfig();

    if (!svc.isConfigured) {
      throw Exception('local_mode: use TTS');
    }

    // 取声音模型对应的 speakerId
    final voices = await getVoiceModels();
    final model = voices.where((v) => v.id == voiceModelId).firstOrNull;
    final speakerId = model?.speakerId;
    if (speakerId == null) {
      throw Exception('local_mode: use TTS');
    }

    // 取内容文本
    final content = await getContent(contentId);

    // 调用火山引擎合成
    final audioPath = await svc.synthesize(
      speakerId: speakerId,
      text: content.textContent,
      speed: speed,
    );
    return {'audioPath': audioPath, 'taskId': 'volcano_done'};
  }

  Future<Map<String, dynamic>> getSynthesizeStatus(String taskId) async =>
      {'status': 'done', 'audioUrl': ''};
}

// ─────────────────────────────────────────────────────────────
// 内置内容数据 - 《爸爸的声音 最好的胎教》精选故事
// ─────────────────────────────────────────────────────────────
const _allContents = [
  // ========== 睡前故事（父爱主题）==========
  ContentModel(
    id: '1', title: '小兔子乖乖', category: ContentCategory.story,
    textContent:
        '小兔子乖乖，把门开开，快点开开，我要进来。\n\n'
        '不开不开我不开，妈妈没回来，谁来我也不开。\n\n'
        '叮咚叮咚，妈妈回来了，宝宝开门啦！\n\n'
        '小兔子跑出来，扑进妈妈的怀抱，妈妈轻轻地抱着它，'
        '说：宝宝真乖，知道不给陌生人开门。',
    durationSeconds: 300, minWeek: 16, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '2', title: '小熊请客', category: ContentCategory.story,
    textContent:
        '秋天到了，小熊家里结满了果子。\n\n'
        '小熊决定请好朋友们来做客。\n\n'
        '小兔带来了胡萝卜蛋糕，小狐狸带来了野果酱，'
        '小松鼠带来了松果饼干。\n\n'
        '大家围坐在一起，分享着各自带来的食物，'
        '笑声传遍了整个森林。\n\n'
        '小熊说：有朋友在身边，每天都是好日子。',
    durationSeconds: 420, minWeek: 20, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '3', title: '海边的小贝壳', category: ContentCategory.story,
    textContent:
        '在遥远的海边，住着一只小贝壳。\n\n'
        '每天，海浪轻轻地拍打着它，哗哗哗，就像妈妈的手抚摸着宝宝。\n\n'
        '小贝壳把海的声音收藏起来，等待着一个小宝宝来找它。\n\n'
        '当你把贝壳贴近耳边，就能听到大海在唱歌：\n\n'
        '宝宝宝宝，快快长大，妈妈爱你，永远永远。',
    durationSeconds: 330, minWeek: 14, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '4', title: '云朵里的宝宝', category: ContentCategory.story,
    textContent:
        '在白白的云朵里，有一个小小的宝宝。\n\n'
        '他每天望着地球，看见了一对爱笑的爸爸妈妈。\n\n'
        '他决定从云朵里飞下来，做他们的宝宝。\n\n'
        '从那一天起，妈妈的肚子里开始有了小小的心跳。\n\n'
        '宝宝来了，带着满满的爱，带着所有人的期待。',
    durationSeconds: 360, minWeek: 6, maxWeek: 42, isFree: true,
  ),

  // ========== 《爸爸的声音 最好的胎教》精选故事 ==========

  // 勇敢与信任
  ContentModel(
    id: '5', title: '忠狗救主', category: ContentCategory.story,
    textContent:
        '农夫的家里养了一条狗。这条狗聪明伶俐，经常陪着农夫的小儿子玩耍，'
        '小儿子非常喜欢它，并且把这条狗当作朋友，连晚上睡觉也不愿与它分开，'
        '经常和小狗说知心话。\n\n'
        '有一天，农夫和妻子都去田里劳作了，孩子们也外出郊游了，只留下小狗看家。'
        '狗闲来无事，懒洋洋地趴在桌子下睡觉。\n\n'
        '这时，不知从哪里钻出来一条毒蛇，吐着红红的舌头，不时发出"咝一咝一"的声音。'
        '狗对蛇发出警告，试图赶走它，但毒蛇在逃跑前将毒液喷射到了牛奶罐子里。'
        '这是一条带有剧毒的蛇，如果农夫喝了有毒液的牛奶，就会立即失去生命。\n\n'
        '傍晚，农夫和妻子从农田劳作归来，小狗箭一般冲到农夫的脚下，狂躁地叫着。'
        '小儿子放下牛奶罐子，搂着狗安慰了一会儿，狗暂时安静了下来。\n\n'
        '这时，农夫倒了一杯牛奶递到小儿子的手里。就在这时，狗一下子跳起来，'
        '扑倒了小儿子，小儿子没抓稳牛奶杯子，杯子碎了，牛奶洒了一地。\n\n'
        '小狗呜呜地叫着，眼睛里好像在说：千万别喝，牛奶有毒！'
        '农夫仔细一看，发现牛奶里有毒液，他明白了小狗的一片忠诚。'
        '从那以后，农夫一家更加爱这只勇敢的狗了。',
    durationSeconds: 480, minWeek: 16, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '6', title: '会唱歌的小贝壳', category: ContentCategory.story,
    textContent:
        '这天是沙滩奶奶的生日，大海托海浪们把一些贝壳送给她。\n\n'
        '沙滩奶奶看到那么多精美的贝壳高兴极了，这些贝壳里几乎都有一粒或者两粒珍贵的珍珠，'
        '有白的，有黑的，美丽极了。\n\n'
        '但只有一枚贝壳例外，她里面没有珍珠。\n\n'
        '"小贝壳，你的珍珠呢？"沙滩奶奶问她。\n\n'
        '"对啊，你的珍珠不会被海怪偷走了吧？"另一枚贝壳问。\n\n'
        '"没有，我本身不结珍珠。"小贝壳答。\n\n'
        '"不结珍珠？不会吧！真奇怪！"其他贝壳都议论纷纷。\n\n'
        '"那你会什么呢？"沙滩奶奶温柔地笑着问她。\n\n'
        '"我会唱歌。"小贝壳笑着说。\n\n'
        '"那你唱一首歌给我们听听。"沙滩奶奶说。\n\n'
        '于是，小贝壳就唱起歌来。她一开口世界就马上安静下来，'
        '这歌声多美啊，宛如天籁之音，令人感到欢乐而又美好。\n\n'
        '"多美的歌声啊，小贝壳你真棒！"沙滩奶奶夸奖道，其他贝壳也羡慕极了。\n\n'
        '第二天早上，人们在沙滩上发现了这些贝壳都非常高兴，'
        '他们赶紧把贝壳里的珍珠都拿走了，沙滩上只留下一枚枚悲伤的贝壳。\n\n'
        '会唱歌的小贝壳为了安慰同胞们，就唱起了歌，'
        '她的歌声是那么美妙，连沙滩上的风都停下来倾听。',
    durationSeconds: 420, minWeek: 12, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '7', title: '暖羊羊的爱心', category: ContentCategory.story,
    textContent:
        '暖羊羊是一只心地善良、乐于助人的羊。\n\n'
        '有一次，暖羊羊去超市买东西，路上看见狗熊伯伯正拉着一车水果上坡，'
        '谁知拉到一半拉不动了，车子斜在半坡上，车上的水果撒了一地。\n\n'
        '暖羊羊见了赶紧上前帮忙。她先帮狗熊伯伯把车推到坡上，'
        '然后再帮狗熊伯伯把水果一个一个捡起来，待捡完水果，'
        '暖羊羊已经累得满头大汗。\n\n'
        '狗熊伯伯见了激动得热泪盈眶，连声说道："暖羊羊，太谢谢你了，你真是一个好孩子。"\n\n'
        '还有一次，暖羊羊背着竹筐去山上采果子，就在她满载而归回羊村的路上时，'
        '不时传来一阵阵痛苦的呻吟声。\n\n'
        '于是她寻着声音方向找去，原来是一只受伤的小松鼠躺在草丛里，腿上鲜血直流。\n\n'
        '暖羊羊见了急切地问："小松鼠，你怎么受伤了？"\n\n'
        '小松鼠有气无力地说："因为今天和妈妈一起出来找食物，不小心走散了，'
        '刚才被一只野猫袭击了。"说完伤心的泪水夺眶而出。\n\n'
        '"别着急，别着急，"暖羊羊一边安慰小松鼠，一边从包包里拿出纱布，'
        '先帮小松鼠包扎好伤口，然后把她背回了羊村。\n\n'
        '经过暖羊羊无微不至的照顾，小松鼠很快恢复了健康。'
        '最后，暖羊羊还帮小松鼠找到了妈妈，看到松鼠一家团圆开心的样子，'
        '暖羊羊也开心地笑了。\n\n'
        '暖羊羊真是一只乐于助人、有爱心的羊。',
    durationSeconds: 540, minWeek: 14, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '8', title: '想飞的小母鸡', category: ContentCategory.story,
    textContent:
        '一只小母鸡，每天都梦想着能飞上天空。\n\n'
        '她努力的拍着翅膀，可怎么也不能成功。\n\n'
        '一次，两次，三次，一次又一次，她从没放弃过，可就是没成功。\n\n'
        '没成功也没关系，她努力的尝试着，一直没放弃。\n\n'
        '一天，她顺着主人搭好的梯子爬上了高高的屋顶，'
        '她站在青砖瓦片上，正要往下跳，地上一只小黄狗汪汪大叫起来：'
        '"汪汪！汪汪！小母鸡，你可不要想不开呀！"\n\n'
        '小母鸡听了，微笑着说："不是啦！我不是要跳楼，我只是想飞而已！"\n\n'
        '小黄狗更加疑惑了："飞？据我所知，你们的翅膀早就没有这个功能啦！"\n\n'
        '小母鸡并没有不高兴，她继续说："我想飞，我相信自己能飞，'
        '只要通过不懈的努力，就一定能成功！"\n\n'
        '小黄狗望着高高耸立的楼，直摇头。\n\n'
        '突然，小母鸡纵身一跃，同时拼命拍击着翅膀，是的，她准备起飞了。\n\n'
        '可是呀可是，她还没飞高几厘米呢，就咻的往下一坠，径直掉下地面，摔伤了。\n\n'
        '小母鸡躺在地上，疼得直叫唤。\n\n'
        '小黄狗赶紧跑过去，心疼地说："你看，我说飞不起来吧！"\n\n'
        '小母鸡却笑了："没关系，我至少尝试过了。'
        '下次我一定会飞起来的，相信自己，只要努力，就一定能成功！"\n\n'
        '小黄狗看着勇敢的小母鸡，心里充满了敬佩。',
    durationSeconds: 360, minWeek: 16, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '9', title: '小熊猫的礼貌', category: ContentCategory.story,
    textContent:
        '小熊猫想要找朋友一起玩，可是爸爸说不能打扰正在忙其他事情的动物们，'
        '小熊猫可以和谁玩游戏呢？\n\n'
        '小熊猫想让奶奶和他一起玩，可是爸爸说：'
        '"奶奶正在休息，好孩子不要打扰奶奶。"\n\n'
        '小熊猫想和妈妈一起做游戏，爸爸告诉他：'
        '"妈妈在工作，好孩子不应该打扰妈妈。"\n\n'
        '爸爸开车带小熊猫去公园玩，小熊猫想和爸爸说话，可一想：'
        '爸爸在开车，好孩子不能打扰爸爸。\n\n'
        '到了公园，小熊猫看见山羊公公在长椅上读报，心想：'
        '山羊公公在读报，好孩子不要打扰公公。\n\n'
        '来到亭子边，小熊猫看见公鸡哥哥在练唱歌，小熊猫想：'
        '哥哥在唱歌，好孩子不该打扰哥哥。\n\n'
        '走到大树旁，小熊猫见啄木鸟妹妹在捉虫，心想：'
        '妹妹在做事，好孩子不能打扰妹妹。\n\n'
        '路过小河边，小熊猫看见小猫弟弟在钓鱼，小熊猫想：'
        '弟弟在钓鱼，好孩子不能打扰他。\n\n'
        '跟在旁边的爸爸对小熊猫说：'
        '"你不打扰别人，是个有礼貌的好孩子。"\n\n'
        '来到游乐场，看到小鸭妹妹、小猴弟弟、小狗哥哥都在玩，'
        '小熊猫高兴地和爸爸加入其中。\n\n'
        '小熊猫明白了，要学会等待，学会尊重别人，'
        '这才是有礼貌的好孩子。',
    durationSeconds: 480, minWeek: 12, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '10', title: '小狐狸的生日礼物', category: ContentCategory.story,
    textContent:
        '小狐狸过生日，妈妈送给他一块新地毯。\n\n'
        '小狐狸很开心，请了他的好朋友小猪、小刺猬、小鸡、小狗、'
        '小羊、小猴、小鸭和小松鼠来家里做客。\n\n'
        '朋友们都带了礼物来。小猪带来了一大篮苹果，'
        '小刺猬带来了一袋坚果，小鸡带来了自己下的鸡蛋，'
        '小狗带来了骨头饼干，小羊带来了青草蛋糕，'
        '小猴带来了香蕉，小鸭带来了鱼干，小松鼠带来了松果。\n\n'
        '大家围坐在新地毯上，分享着美味的食物，'
        '唱着生日歌，祝福小狐狸生日快乐。\n\n'
        '小狐狸感动地说："谢谢大家，谢谢你们的礼物，'
        '更谢谢你们来参加我的生日派对。有你们在，'
        '我真是太幸福了！"\n\n'
        '妈妈站在一旁，看着开心的孩子们，心里暖暖的。'
        '她知道，友谊是世界上最珍贵的礼物。\n\n'
        '小狐狸许下了一个愿望："希望我们永远是好朋友，'
        '永远在一起。"\n\n'
        '蜡烛吹灭了，小狐狸的生日充满了欢声笑语。',
    durationSeconds: 420, minWeek: 14, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '11', title: '勇敢的小章鱼', category: ContentCategory.story,
    textContent:
        '小章鱼总是十分的自卑，它常常觉得自己的身躯非常丑陋。\n\n'
        '有一条小章鱼，它时常因为自己丑陋的身躯而感到自卑和伤心。'
        '因此，它总是把自己的身体掩藏在海底礁石的缝隙里，'
        '不肯跟随妈妈一起去远游。\n\n'
        '妈妈温柔地说："孩子，你不丑，你的身体有很多神奇的功能呢。'
        '你的八条触手可以帮朋友做很多事情。"\n\n'
        '小章鱼不相信妈妈的话，它觉得自己就是丑，就是没用。\n\n'
        '有一天，海底发生了一场风暴，许多小鱼被卷进了珊瑚石的缝隙里。'
        '小章鱼躲在缝隙里，看到了被困的小鱼们。\n\n'
        '"救命！救命！"小鱼们大声呼救。\n\n'
        '小章鱼犹豫了一下，但它还是伸出触手，'
        '一条一条地把小鱼们从缝隙里拉了出来。\n\n'
        '"谢谢你，小章鱼！你真勇敢！"小鱼们感激地说。\n\n'
        '小章鱼第一次感受到被需要的感觉，它的心里暖暖的。\n\n'
        '"原来我也能帮助别人，原来我并不丑。"小章鱼开心地笑了。\n\n'
        '从那以后，小章鱼不再自卑了，它和妈妈一起，'
        '用它的八条触手帮助了很多海底的动物朋友们。',
    durationSeconds: 480, minWeek: 16, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '12', title: '照镜子的小狗', category: ContentCategory.story,
    textContent:
        '从前有两户人家养了两只小狗，一只叫白白，一只叫黑黑，'
        '它们俩都长得非常英俊。\n\n'
        '一天，白白和黑黑趁主人不在，偷偷跑出去了。'
        '走啊走，看到了两面大镜子，两只狗分别在两面镜子前照啊照……\n\n'
        '黑黑越照越英俊，他心里得意地想：'
        '我真是狗族中最英俊的狗，我的头发是棕色的，'
        '眼睛里闪着锐利的光芒，鼻子是乌黑色的，比猛、帅气、英俊。\n\n'
        '白白越照越难看：长长的耳朵，三角形的鼻子，没有神采的眼睛，'
        '差不多像一只病猫。白白无法相信自己长得这么难看，'
        '它想以后我怎么见人啊！\n\n'
        '突然，一面镜子向黑黑倾斜过去，眼看就要向黑黑压去。\n\n'
        '说时迟，那时快，白白一个鲤鱼打挺，扑了过去，迅速推开黑黑，'
        '两个人同时摔倒在地上，"啪"的一声倒了下去，'
        '玻璃碎片差点飞到了它们俩的身上。\n\n'
        '黑黑爬起来感动地说："白白，你不愧是一只好狗啊！"\n\n'
        '善良的心灵才是最重要的，我们不能以貌取人，'
        '不能被外表所迷惑。',
    durationSeconds: 420, minWeek: 18, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '13', title: '独自在家的小象', category: ContentCategory.story,
    textContent:
        '小象的爸爸妈妈出门，只留下小象一个人在家，'
        '这时候老狼打起了小象的主意，它悄悄地走到小象家的门口敲门。\n\n'
        '"铛铛铛——铛铛铛——！"\n\n'
        '小象说："谁啊？"\n\n'
        '老狼在外面捏住自己的鼻子说："我是你爸爸妈妈的朋友啊！"\n\n'
        '小象想起了妈妈说的话：不能随便给陌生人开门。\n\n'
        '于是小象说："请你等一下，我给爸爸妈妈打个电话。"\n\n'
        '老狼一听，知道小象要打电话，赶紧溜走了。\n\n'
        '小象透过窗户看见老狼走了，松了一口气。\n\n'
        '它明白了，爸爸妈妈说的是对的，不能随便给陌生人开门，'
        '要学会保护自己。\n\n'
        '过了一会儿，爸爸妈妈回来了，小象把刚才的事情告诉了他们。\n\n'
        '爸爸妈妈表扬了小象："你做得对，遇到陌生人不要轻易开门，'
        '要学会保护自己，做个聪明的孩子。"\n\n'
        '小象开心地笑了，它知道，自己又长大了一点。',
    durationSeconds: 420, minWeek: 16, maxWeek: 42, isFree: true,
  ),

  ContentModel(
    id: '14', title: '小松鼠找妈妈', category: ContentCategory.story,
    textContent:
        '秋天到了，森林里的树叶都变黄了，纷纷落下来。\n\n'
        '小松鼠跟着妈妈去收集松果，准备过冬。\n\n'
        '小松鼠看到一只美丽的蝴蝶，就追了过去。\n\n'
        '蝴蝶飞啊飞，小松鼠追啊追，不知不觉就追到了森林深处。\n\n'
        '"咦，妈妈呢？"小松鼠四下张望，找不到妈妈了。\n\n'
        '"妈妈！妈妈！"小松鼠大声地叫着，可是没有回应。\n\n'
        '小松鼠害怕了，它蹲在树下，呜呜地哭了起来。\n\n'
        '这时，小鸟飞过来了："小松鼠，你怎么啦？"\n\n'
        '"我找不到妈妈了。"小松鼠哭着说。\n\n'
        '"别哭别哭，我来帮你找妈妈。"小鸟说。\n\n'
        '小鸟飞上天空，四处寻找，很快，它就找到了松鼠妈妈。\n\n'
        '松鼠妈妈正在焦急地寻找小松鼠，看到小鸟来了，'
        '激动地说："谢谢你，小鸟！"\n\n'
        '小鸟带着松鼠妈妈找到了小松鼠。\n\n'
        '小松鼠看到妈妈，扑进妈妈的怀抱，再也不想离开了。\n\n'
        '松鼠妈妈抱紧小松鼠："以后不要随便乱跑了，'
        '要跟着妈妈，好不好？"\n\n'
        '"好的，妈妈，我以后一定乖乖的。"小松鼠认真地说。',
    durationSeconds: 480, minWeek: 12, maxWeek: 42, isFree: true,
  ),

  // ========== 国学启蒙 ==========
  ContentModel(
    id: '15', title: '三字经', category: ContentCategory.classic,
    textContent:
        '人之初，性本善，性相近，习相远。\n\n'
        '苟不教，性乃迁，教之道，贵以专。\n\n'
        '昔孟母，择邻处，子不学，断机杼。\n\n'
        '窦燕山，有义方，教五子，名俱扬。\n\n'
        '养不教，父之过，教不严，师之惰。',
    durationSeconds: 480, minWeek: 20, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '16', title: '弟子规', category: ContentCategory.classic,
    textContent:
        '弟子规，圣人训，首孝悌，次谨信。\n\n'
        '泛爱众，而亲仁，有余力，则学文。\n\n'
        '父母呼，应勿缓，父母命，行勿懒。\n\n'
        '父母教，须敬听，父母责，须顺承。\n\n'
        '冬则温，夏则凊，晨则省，昏则定。',
    durationSeconds: 360, minWeek: 22, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '17', title: '百家姓', category: ContentCategory.classic,
    textContent:
        '赵钱孙李，周吴郑王。\n\n'
        '冯陈楮卫，蒋沈韩杨。\n\n'
        '朱秦尤许，何吕施张。\n\n'
        '孔曹严华，金魏陶姜。\n\n'
        '戚谢邹喻，柏水窦章。',
    durationSeconds: 280, minWeek: 24, maxWeek: 42, isFree: true,
  ),

  // ========== 冥想放松 ==========
  ContentModel(
    id: '18', title: '睡前冥想放松', category: ContentCategory.meditation,
    textContent:
        '闭上眼睛，深深地吸一口气，慢慢地呼出来。\n\n'
        '感受宝宝在你肚子里轻轻地动着，感受这份温柔的连接。\n\n'
        '想象你们在一片柔软的云朵上，四周都是温暖的阳光。\n\n'
        '宝宝，妈妈爱你，你是妈妈心里最珍贵的礼物。\n\n'
        '慢慢地放松，慢慢地入睡，好梦，宝贝。',
    durationSeconds: 600, minWeek: 12, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '19', title: '呼吸冥想', category: ContentCategory.meditation,
    textContent:
        '找一个舒适的姿势坐下来，轻轻地闭上眼睛。\n\n'
        '用鼻子慢慢吸气，数一、二、三、四。\n\n'
        '然后慢慢呼气，数一、二、三、四、五、六。\n\n'
        '感受每一次呼吸，感受身体慢慢放松。\n\n'
        '宝宝也在和你一起呼吸，感受这份宁静与美好。\n\n'
        '我们一起慢慢地、深深地呼吸……',
    durationSeconds: 540, minWeek: 8, maxWeek: 42, isFree: true,
  ),

  // ========== 儿歌童谣 ==========
  ContentModel(
    id: '20', title: '一闪一闪亮晶晶', category: ContentCategory.song,
    textContent:
        '一闪一闪亮晶晶，满天都是小星星。\n\n'
        '挂在天上放光明，好像许多小眼睛。\n\n'
        '天空有颗小星星，一直闪呀闪呀闪。\n\n'
        '小宝宝快快睡，星星守护你入梦。',
    durationSeconds: 180, minWeek: 16, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '21', title: '感恩的心', category: ContentCategory.song,
    textContent:
        '感恩的心，感谢有你，伴我一生，让我有勇气做我自己。\n\n'
        '感恩的心，感谢命运，花开花落，我一样会珍惜。\n\n'
        '宝宝，谢谢你来到我们身边，\n\n'
        '你是爸爸妈妈最美丽的礼物，\n\n'
        '我们会用一生守护你。',
    durationSeconds: 240, minWeek: 16, maxWeek: 42, isFree: true,
  ),
  ContentModel(
    id: '22', title: '小星星变奏曲', category: ContentCategory.song,
    textContent:
        '小星星，亮晶晶，照着我的小摇篮。\n\n'
        '宝宝宝宝快睡觉，明天太阳会出来。\n\n'
        '月亮姐姐守着你，星星哥哥陪着你。\n\n'
        '闭上眼睛做好梦，梦里有蝴蝶和花朵。\n\n'
        '爸爸妈妈在身边，宝宝睡得甜又香。',
    durationSeconds: 200, minWeek: 12, maxWeek: 42, isFree: true,
  ),
];
