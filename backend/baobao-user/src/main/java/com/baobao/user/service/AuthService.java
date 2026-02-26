package com.baobao.user.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baobao.user.config.JwtUtil;
import com.baobao.user.dto.AuthDto;
import com.baobao.user.entity.User;
import com.baobao.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redis;

    @Value("${sms.mock:true}")
    private boolean smsMock;

    private static final String SMS_KEY_PREFIX   = "sms:code:";
    private static final String TOKEN_KEY_PREFIX = "token:";
    private static final int SMS_EXPIRE_SECONDS  = 300; // 5 分钟

    // ── 发送验证码 ────────────────────────────────
    public void sendCode(String phone) {
        // 60 秒内不能重复发送
        String cooldownKey = SMS_KEY_PREFIX + "cd:" + phone;
        if (Boolean.TRUE.equals(redis.hasKey(cooldownKey))) {
            throw new RuntimeException("发送过于频繁，请稍后再试");
        }

        String code = smsMock ? "123456" : generateCode();
        redis.opsForValue().set(SMS_KEY_PREFIX + phone, code, SMS_EXPIRE_SECONDS, TimeUnit.SECONDS);
        redis.opsForValue().set(cooldownKey, "1", 60, TimeUnit.SECONDS);

        if (smsMock) {
            log.info("[SMS Mock] phone={} code={}", phone, code);
        } else {
            // TODO: 对接阿里云 / 腾讯云短信服务
        }
    }

    // ── 登录（验证码校验 + 自动注册）────────────────
    public AuthDto.LoginResponse login(String phone, String code) {
        // 1. 验证码校验
        String cached = redis.opsForValue().get(SMS_KEY_PREFIX + phone);
        if (cached == null || !cached.equals(code)) {
            throw new RuntimeException("验证码错误或已过期");
        }
        redis.delete(SMS_KEY_PREFIX + phone);

        // 2. 查找或创建用户
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
        boolean isNewUser = (user == null);
        if (isNewUser) {
            user = new User();
            user.setPhone(phone);
            user.setNickname("宝妈_" + phone.substring(7));
            userMapper.insert(user);
        }

        // 3. 生成 JWT，存入 Redis 白名单
        String token = jwtUtil.generate(user.getId());
        redis.opsForValue().set(TOKEN_KEY_PREFIX + user.getId(), token, 30, TimeUnit.DAYS);

        // 4. 组装响应
        AuthDto.UserVo vo = new AuthDto.UserVo();
        vo.setId(user.getId());
        vo.setPhone(phone);
        vo.setNickname(user.getNickname());
        vo.setDueDate(user.getDueDate() != null ? user.getDueDate().toString() : null);
        vo.setIsNewUser(isNewUser);

        AuthDto.LoginResponse resp = new AuthDto.LoginResponse();
        resp.setToken(token);
        resp.setUser(vo);
        return resp;
    }

    // ── 登出 ────────────────────────────────────
    public void logout(String userId) {
        redis.delete(TOKEN_KEY_PREFIX + userId);
    }

    // ── 更新用户信息 ─────────────────────────────
    public User updateProfile(String userId, AuthDto.UpdateProfileRequest req) {
        User user = userMapper.selectById(userId);
        if (user == null) throw new RuntimeException("用户不存在");
        if (req.getNickname() != null) user.setNickname(req.getNickname());
        if (req.getDueDate() != null) {
            user.setDueDate(LocalDate.parse(req.getDueDate(), DateTimeFormatter.ISO_DATE));
        }
        userMapper.updateById(user);
        return user;
    }

    private String generateCode() {
        return String.format("%06d", (int) (Math.random() * 1000000));
    }
}
