-- 宝宝胎教数据库初始化 SQL
CREATE DATABASE IF NOT EXISTS baobao DEFAULT CHARSET utf8mb4;
USE baobao;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id          VARCHAR(36)  PRIMARY KEY COMMENT '用户ID',
    phone       VARCHAR(20)  UNIQUE NOT NULL COMMENT '手机号',
    nickname    VARCHAR(50)  COMMENT '昵称',
    due_date    DATE         COMMENT '预产期',
    avatar_url  VARCHAR(500) COMMENT '头像URL',
    created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 声音模型表
CREATE TABLE IF NOT EXISTS voice_models (
    id               VARCHAR(36)  PRIMARY KEY,
    user_id          VARCHAR(36)  NOT NULL,
    role             VARCHAR(10)  NOT NULL COMMENT 'dad | mom',
    version          INT          DEFAULT 1,
    status           VARCHAR(20)  NOT NULL COMMENT 'training | ready | failed',
    model_path       VARCHAR(500) COMMENT 'OSS路径',
    similarity_score DOUBLE       COMMENT '相似度评分',
    sample_duration  INT          COMMENT '样本时长(秒)',
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='声音模型表';

-- 胎教内容表
CREATE TABLE IF NOT EXISTS contents (
    id               VARCHAR(36)   PRIMARY KEY,
    title            VARCHAR(200)  NOT NULL,
    category         VARCHAR(50)   NOT NULL COMMENT 'story|song|meditation|classic',
    text_content     MEDIUMTEXT,
    duration_seconds INT,
    min_week         INT           COMMENT '适合最小孕周',
    max_week         INT           COMMENT '适合最大孕周',
    is_free          TINYINT(1)    DEFAULT 0,
    cover_url        VARCHAR(500),
    created_at       DATETIME      DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_week (min_week, max_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='胎教内容表';

-- 合成音频缓存表
CREATE TABLE IF NOT EXISTS synthesized_audios (
    id               VARCHAR(36) PRIMARY KEY,
    content_id       VARCHAR(36) NOT NULL,
    voice_model_id   VARCHAR(36) NOT NULL,
    speed            DOUBLE      DEFAULT 1.0,
    audio_url        VARCHAR(500),
    duration_seconds INT,
    created_at       DATETIME    DEFAULT CURRENT_TIMESTAMP,
    expire_at        DATETIME,
    INDEX idx_content_voice (content_id, voice_model_id, speed)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='合成音频缓存表';

-- 示例内容数据
INSERT IGNORE INTO contents (id, title, category, text_content, duration_seconds, min_week, max_week, is_free) VALUES
('1', '小兔子乖乖', 'story', '小兔子乖乖，把门开开，快点开开，我要进来。不开不开我不开，妈妈没回来，谁来我也不开。', 300, 16, 42, 1),
('2', '三字经', 'classic', '人之初，性本善，性相近，习相远。苟不教，性乃迁，教之道，贵以专。', 480, 20, 42, 1),
('3', '睡前冥想放松', 'meditation', '闭上眼睛，深呼吸，感受宝宝在你肚子里轻轻地动着...', 600, 12, 42, 0),
('4', '一闪一闪亮晶晶', 'song', '一闪一闪亮晶晶，满天都是小星星，挂在天上放光明，好像许多小眼睛。', 180, 16, 42, 1);
