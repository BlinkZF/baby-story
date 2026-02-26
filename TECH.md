# 宝宝胎教 App —— 技术方案

**版本**：v1.0  
**日期**：2026-02-25

---

## 一、整体架构

```
┌─────────────────────────────────────────────────────┐
│                  客户端（App）                        │
│       iOS (Swift/SwiftUI)  Android (Kotlin)          │
│       或跨平台：Flutter                               │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS / WebSocket
┌───────────────────▼─────────────────────────────────┐
│         Spring Cloud Gateway（API 网关）              │
│         JWT 鉴权 / 限流 / 路由 / 熔断                 │
└──┬──────────────┬──────────────┬──────────────────── ┘
   │              │              │
┌──▼──────┐ ┌────▼──────┐ ┌─────▼─────────────────┐
│ 用户服务  │ │ 内容服务  │ │  合成调度服务            │
│(Java)   │ │ (Java)   │ │  (Java)               │
└──┬──────┘ └────┬──────┘ └─────┬─────────────────┘
   │              │              │ gRPC（内网）
   │              │         ┌────▼──────────────────┐
   │              │         │  AI 声音服务（Python）  │
   │              │         │  CosyVoice TTS/Clone   │
   │              │         └───────────────────────┘
   │              │
┌──▼──────────────▼─────────────────────────────────┐
│                   基础设施层                         │
│  MySQL 8  │  Redis  │  阿里云OSS  │  RocketMQ      │
│  Nacos（注册/配置）   │  SLB       │  FCM/APNs      │
└───────────────────────────────────────────────────┘
```

---

## 二、技术栈选型

### 2.1 客户端

| 选项 | 推荐方案 | 原因 |
|---|---|---|
| 跨平台框架 | **Flutter** | 一套代码覆盖 iOS/Android，音频处理生态完善 |
| 音频录制 | `flutter_sound` / `record` | 支持 WAV/PCM 格式，满足声音训练要求 |
| 音频播放 | `just_audio` | 支持流式播放、后台播放、速度调节 |
| 状态管理 | Riverpod / Bloc | 适合复杂异步场景 |
| 本地存储 | Hive + SQLite | 音频元数据 + 离线内容缓存 |

### 2.2 后端服务

> 业务服务采用 **Java** 技术栈；AI 推理（声音克隆/TTS）因依赖 Python 生态，独立为 Python 微服务，通过内部 HTTP/gRPC 调用。

| 服务 | 技术 | 说明 |
|---|---|---|
| API 网关 | **Spring Cloud Gateway** | 统一鉴权、限流、路由、熔断 |
| 业务服务框架 | **Spring Boot 3.x** | 用户服务、内容服务、合成调度服务 |
| 服务注册/发现 | **Nacos** | 服务注册、配置中心 |
| 服务间通信 | **OpenFeign + gRPC** | 同步调用；与 AI 服务通信用 gRPC |
| 实时通知 | **WebSocket（Spring WebSocket）** + FCM/APNs | 训练完成推送 |
| 消息队列 | **RocketMQ** | 异步处理声音训练任务、解耦业务 |
| 数据库 | **MySQL 8.x**（主从）| 主数据库；MyBatis-Plus ORM |
| 缓存 | **Redis（Redisson）** | Session、热点内容、合成任务状态 |
| 文件存储 | **阿里云 OSS** | 声音样本、合成音频存储 |
| CDN | 阿里云 CDN | 音频内容加速分发 |
| 认证 | **手机号 + 短信验证码（SMS OTP）+ JWT** | 无状态鉴权；未注册手机号自动创建账号；Token 存 Redis，支持主动失效 |
| AI 服务（独立） | **Python FastAPI** | 声音克隆训练 + TTS 推理（仅内网） |

### 2.3 AI 核心技术

| 能力 | 方案 | 说明 |
|---|---|---|
| **声音克隆（Voice Clone）** | CosyVoice 2（阿里）/ XTTS-v2 | 少样本声音克隆，5分钟音频即可训练 |
| **文本转语音（TTS）** | 使用克隆模型直接推理 | 调用训练好的声音模型合成 |
| **音频质量评估** | WebRTC VAD + DNSMOS | 实时检测噪声、静音段、清晰度 |
| **语音增强** | RNNoise / DeepFilterNet | 降噪预处理，提升样本质量 |
| **向量相似度** | 声纹特征提取（ECAPA-TDNN） | 验证合成声音与原始声音的相似度 |

---

## 三、核心模块设计

### 3.1 声音采集流程

```
App 端                          服务端
 │                                │
 ├─ 1. 实时录音（PCM 16kHz/16bit）│
 ├─ 2. VAD 静音检测（本地）        │
 ├─ 3. 实时噪声评估（DNSMOS本地）  │
 ├─ 4. 逐句上传（分片）──────────►│
 │                               ├─ 5. 音频预处理（降噪、归一化）
 │                               ├─ 6. 质量打分，不合格返回
 │◄────────────── 质量反馈 ────────┤
 ├─ 7. 全部通过，提交训练请求 ────►│
 │                               ├─ 8. 发送 RocketMQ 消息（训练任务）
 │                               ├─ 9. AI Python Worker 消费，GPU 训练
 │                               │    （CosyVoice Fine-tune）
 │◄────── 10. 推送通知（完成）─────┤
 ├─ 11. 拉取试听样本              │
 └─ 12. 确认保存                  │
```

#### 录制规格要求

| 参数 | 规格 |
|---|---|
| 采样率 | 24000 Hz |
| 位深 | 16-bit PCM |
| 声道 | 单声道（Mono） |
| 最短样本时长 | 3 分钟（推荐 5 分钟） |
| 环境噪声要求 | SNR ≥ 20dB |

---

### 3.2 AI 声音模型训练

#### 方案对比

| 方案 | 优点 | 缺点 | 推荐 |
|---|---|---|---|
| **CosyVoice 2（开源）** | 中文效果极佳，少样本支持，可私有化部署 | 需要 GPU 资源 | ✅ 首选 |
| XTTS-v2 | 多语言，开源 | 中文效果略逊 | 备选 |
| 微软 Azure Custom Neural Voice | 效果好，SaaS | 贵，数据出境 | 商业版备选 |
| 阿里云语音合成（定制音色） | 稳定、中文好 | SaaS，成本高 | 商业版备选 |

#### CosyVoice 2 训练流程

```python
# 伪代码示意
from cosyvoice import CosyVoiceFineTuner

tuner = CosyVoiceFineTuner(
    base_model="CosyVoice2-0.5B",
    speaker_name=f"user_{user_id}_{role}",  # role: dad/mom
)

# 1. 加载用户录音样本（降噪后）
tuner.load_audio_samples(audio_paths, transcript_paths)

# 2. 微调训练（LoRA 方式，约 5~15 分钟，A100 GPU）
tuner.fine_tune(
    steps=500,
    learning_rate=1e-4,
    lora_rank=16,
)

# 3. 导出声音模型
model_path = tuner.export(output_dir=f"models/{user_id}/")

# 4. 评估相似度
similarity = tuner.evaluate_similarity()  # 目标 ≥ 0.85
```

---

### 3.3 语音合成（TTS）流程

```
用户请求合成                   TTS 服务
 │                               │
 ├─ 1. 选择内容 + 声音 ─────────►│
 │                               ├─ 2. 查询缓存（Redis）
 │                               │   命中 → 直接返回 OSS URL
 │                               ├─ 3. 未命中：加载用户声音模型
 │                               ├─ 4. 文本预处理（分句、标点处理）
 │                               ├─ 5. CosyVoice 推理合成
 │                               ├─ 6. 背景音乐混音（可选）
 │                               ├─ 7. 上传 OSS，写入缓存
 │◄──────── 8. 返回音频 URL ──────┤
 ├─ 9. 流式播放 / 下载缓存        │
```

#### 合成性能优化

- **流式合成**：句子级别流式输出，首包延迟 ≤ 3s
- **预生成**：用户打开内容详情时，后台提前触发合成
- **缓存策略**：相同（content_id + voice_id + speed）的合成结果 OSS 缓存 30 天
- **GPU 集群**：A10G GPU × 4，支持并发合成

---

### 3.4 数据库设计（核心表）

> 数据库使用 **MySQL 8.x**，ORM 层使用 **MyBatis-Plus**。

```sql
-- 用户表
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY COMMENT '用户ID (UUID)',
    phone VARCHAR(20) UNIQUE NOT NULL COMMENT '手机号',
    nickname VARCHAR(50) COMMENT '昵称',
    due_date DATE COMMENT '预产期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 家庭表
CREATE TABLE families (
    id VARCHAR(36) PRIMARY KEY,
    baby_name VARCHAR(50) COMMENT '宝宝昵称',
    created_by VARCHAR(36) NOT NULL COMMENT '创建者用户ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created_by (created_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 家庭成员
CREATE TABLE family_members (
    family_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    role VARCHAR(10) NOT NULL COMMENT 'dad | mom | other',
    PRIMARY KEY (family_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 声音模型表
CREATE TABLE voice_models (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    role VARCHAR(10) NOT NULL COMMENT 'dad | mom',
    version INT DEFAULT 1,
    status VARCHAR(20) NOT NULL COMMENT 'training | ready | failed',
    model_path VARCHAR(500) COMMENT 'OSS 路径',
    similarity_score DOUBLE COMMENT '相似度评分',
    sample_duration INT COMMENT '样本时长（秒）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 内容表
CREATE TABLE contents (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL COMMENT 'story | song | meditation',
    text_content MEDIUMTEXT,
    duration_seconds INT,
    min_week INT COMMENT '适合最小孕周',
    max_week INT COMMENT '适合最大孕周',
    is_free TINYINT(1) DEFAULT 0,
    cover_url VARCHAR(500),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_week (min_week, max_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 合成音频缓存表
CREATE TABLE synthesized_audios (
    id VARCHAR(36) PRIMARY KEY,
    content_id VARCHAR(36) NOT NULL,
    voice_model_id VARCHAR(36) NOT NULL,
    speed DOUBLE DEFAULT 1.0,
    audio_url VARCHAR(500) COMMENT 'OSS URL',
    duration_seconds INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expire_at DATETIME,
    INDEX idx_content_voice (content_id, voice_model_id, speed)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 打卡记录
CREATE TABLE checkins (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    content_id VARCHAR(36) NOT NULL,
    voice_model_id VARCHAR(36),
    played_duration INT COMMENT '实际播放时长（秒）',
    checked_in_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_date (user_id, checked_in_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

### 3.5 API 设计（核心接口）

#### 用户登录

```
POST /api/v1/auth/send-code           # 发送短信验证码（60s 限频）
POST /api/v1/auth/login               # 验证码校验 + 登录（未注册自动注册）
POST /api/v1/auth/logout              # 登出（服务端 Token 失效）
GET  /api/v1/auth/me                  # 获取当前登录用户信息
PUT  /api/v1/auth/me                  # 更新用户信息（昵称、预产期）
```

**登录流程**：
```
POST /api/v1/auth/send-code
Body: { "phone": "13800138000" }

POST /api/v1/auth/login
Body: { "phone": "13800138000", "code": "123456" }
Response: { "token": "eyJ...", "user": { "id": "...", "nickname": "...", "isNewUser": true } }
```

- `isNewUser: true` 时，App 引导用户填写昵称/预产期
- JWT 有效期 30 天，Redis 存储 Token 白名单支持主动踢出

#### 声音采集

```
POST /api/v1/voice/upload-chunk       # 上传录音分片
POST /api/v1/voice/start-training     # 提交训练
GET  /api/v1/voice/training-status    # 查询训练状态
GET  /api/v1/voice/preview            # 获取试听音频
POST /api/v1/voice/confirm            # 确认声音模型
GET  /api/v1/voice/models             # 获取用户声音模型列表
```

#### 内容与合成

```
GET  /api/v1/contents                 # 内容列表（支持分页/筛选）
GET  /api/v1/contents/{id}            # 内容详情
POST /api/v1/synthesize               # 请求合成
GET  /api/v1/synthesize/{task_id}     # 查询合成状态
```

#### 孕期 & 家庭

```
GET  /api/v1/today-recommend          # 今日推荐
GET  /api/v1/checkins/stats           # 打卡统计
POST /api/v1/family/invite            # 邀请家庭成员
GET  /api/v1/family/voice-album       # 声音相册
```

---

## 四、安全与隐私

### 4.1 声音数据保护

| 措施 | 实现方式 |
|---|---|
| 传输加密 | TLS 1.3，禁用弱密码套件 |
| 存储加密 | OSS 服务端加密（SSE-KMS） |
| 访问控制 | OSS 私有桶 + 临时签名 URL（有效期 1h） |
| 数据隔离 | 声音模型按 user_id 隔离，不跨用户共享 |
| 用户授权 | 明确告知声音数据用途，获取书面同意 |
| 数据删除 | 用户注销后 30 天内彻底删除所有声音数据 |

### 4.2 合规要求

- 《个人信息保护法》（PIPL）合规
- 生物特征信息（声纹）单独授权
- 隐私政策中明确声明声音数据不用于第三方商业用途
- 未成年人（胎儿）数据保护条款

---

## 五、基础设施与部署

### 5.1 云架构（阿里云）

```
┌─────────────────────────────────────────────┐
│  阿里云                                      │
│                                             │
│  ┌──────────┐    ┌──────────────────────┐  │
│  │  ECS     │    │  GPU 服务器（AI推理）  │  │
│  │  业务服务 │    │  A10G × 4            │  │
│  │  × 3节点  │    │  训练 + 推理          │  │
│  └──────────┘    └──────────────────────┘  │
│                                             │
│  RDS MySQL 8  │  Redis  │  OSS  │  RocketMQ      │
│  Nacos（注册/配置）   │  SLB       │  APNs/FCM    │
└─────────────────────────────────────────────┘
```

### 5.2 Java 微服务工程结构

```
baobao-backend/
├── baobao-gateway/          # Spring Cloud Gateway 网关
├── baobao-user/             # 用户服务（注册/登录/家庭）
├── baobao-content/          # 内容服务（故事/儿歌库）
├── baobao-voice/            # 声音服务（上传/训练调度/模型管理）
├── baobao-synthesize/       # 合成调度服务（任务分发/缓存）
├── baobao-notify/           # 通知服务（WebSocket/FCM/APNs）
├── baobao-common/           # 公共模块（DTO/工具类/异常）
└── baobao-ai-service/       # AI 服务（Python FastAPI，独立部署）
```

**核心依赖（pom.xml 关键依赖）**：

```xml
<!-- Spring Boot 3 + Spring Cloud -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
</parent>

<dependencies>
    <!-- Web -->
    <dependency>spring-boot-starter-web</dependency>
    <!-- Gateway -->
    <dependency>spring-cloud-starter-gateway</dependency>
    <!-- 服务注册/配置 -->
    <dependency>spring-cloud-starter-alibaba-nacos-discovery</dependency>
    <dependency>spring-cloud-starter-alibaba-nacos-config</dependency>
    <!-- 服务调用 -->
    <dependency>spring-cloud-starter-openfeign</dependency>
    <!-- 消息队列 -->
    <dependency>rocketmq-spring-boot-starter</dependency>
    <!-- ORM -->
    <dependency>mybatis-plus-boot-starter</dependency>
    <dependency>mysql-connector-j</dependency>
    <!-- 缓存 -->
    <dependency>redisson-spring-boot-starter</dependency>
    <!-- 鉴权 -->
    <dependency>sa-token-spring-boot3-starter</dependency>
    <!-- OSS -->
    <dependency>aliyun-sdk-oss</dependency>
    <!-- gRPC（与 AI 服务通信） -->
    <dependency>grpc-spring-boot-starter</dependency>
</dependencies>
```

### 5.3 容器化部署

```yaml
# docker-compose（开发环境示意）
services:
  gateway:
    image: baobao-gateway:latest
    ports: ["8080:8080"]
    env_file: .env

  user-service:
    image: baobao-user:latest
    ports: ["8081:8081"]

  content-service:
    image: baobao-content:latest
    ports: ["8082:8082"]

  voice-service:
    image: baobao-voice:latest
    ports: ["8083:8083"]

  synthesize-service:
    image: baobao-synthesize:latest
    ports: ["8084:8084"]

  ai-service:
    image: baobao-ai-service:latest   # Python FastAPI
    ports: ["8090:8090"]
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  nacos:
    image: nacos/nacos-server:v2.3.0
    ports: ["8848:8848"]
    environment:
      MODE: standalone

  rocketmq:
    image: apache/rocketmq:5.1.0
    ports: ["9876:9876", "10911:10911"]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  mysql:
    image: mysql:8.0
    ports: ["3306:3306"]
    environment:
      MYSQL_ROOT_PASSWORD: baobao123
      MYSQL_DATABASE: baobao
```

### 5.3 成本估算（月度）

| 资源 | 规格 | 估算费用 |
|---|---|---|
| ECS 业务服务器 | 4C8G × 3 | ¥900 |
| GPU 服务器（推理） | A10G × 1（按量） | ¥3,000 |
| GPU 服务器（训练） | A100 × 1（按量）| ¥2,000 |
| RDS PostgreSQL | 4C8G 主从 | ¥800 |
| Redis | 2G 主从 | ¥200 |
| OSS 存储 | 1TB | ¥150 |
| CDN 流量 | 5TB | ¥500 |
| **合计** | | **≈ ¥7,550/月** |

---

## 六、开发阶段划分

### Phase 1：MVP（M1~M3，约 12 周）

| 模块 | 前端 | 后端 | AI |
|---|---|---|---|
| 用户注册/登录 | 2w | 1w | - |
| 声音采集（录制+上传） | 2w | 1w | - |
| CosyVoice 训练流程 | - | 1w | 3w |
| 内容库（基础） | 1w | 1w | - |
| TTS 合成 + 播放器 | 2w | 1w | 1w |
| 孕期日历（基础） | 1w | 0.5w | - |

### Phase 2：Beta（M4~M5）

- 家庭空间 + 邀请机制
- 付费订阅系统（IAP）
- 声音相册
- 推送通知完善

### Phase 3：正式版（M6）

- 性能优化（合成速度、模型质量）
- 数据埋点 & 分析
- App Store / 应用宝审核上线

---

## 七、风险与应对

| 风险 | 概率 | 影响 | 应对措施 |
|---|---|---|---|
| 声音克隆效果不达预期 | 中 | 高 | 提前做用户测试，准备系统 TTS 兜底方案 |
| GPU 资源成本超预期 | 中 | 中 | 合成结果强缓存，降低重复推理 |
| App Store 合规审查（声纹数据） | 中 | 高 | 提前准备隐私声明，PIPL 合规材料 |
| 用户录音质量差导致模型差 | 高 | 高 | 严格质量检测 + 重录引导 + 专业优化增值服务 |
| 内容版权问题 | 低 | 高 | 只使用原创或已授权内容，建立内容审核流程 |
