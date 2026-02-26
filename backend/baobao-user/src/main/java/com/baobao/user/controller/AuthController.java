package com.baobao.user.controller;

import com.baobao.user.config.JwtUtil;
import com.baobao.user.dto.AuthDto;
import com.baobao.user.entity.User;
import com.baobao.user.mapper.UserMapper;
import com.baobao.user.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final JwtUtil jwtUtil;
    private final UserMapper userMapper;

    /** 发送短信验证码 */
    @PostMapping("/send-code")
    public ResponseEntity<?> sendCode(@Valid @RequestBody AuthDto.SendCodeRequest req) {
        authService.sendCode(req.getPhone());
        return ResponseEntity.ok(Map.of("message", "验证码已发送"));
    }

    /** 登录（未注册自动创建账号） */
    @PostMapping("/login")
    public ResponseEntity<AuthDto.LoginResponse> login(@Valid @RequestBody AuthDto.LoginRequest req) {
        return ResponseEntity.ok(authService.login(req.getPhone(), req.getCode()));
    }

    /** 登出 */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpServletRequest request) {
        String userId = extractUserId(request);
        if (userId != null) authService.logout(userId);
        return ResponseEntity.ok(Map.of("message", "已退出"));
    }

    /** 获取当前用户信息 */
    @GetMapping("/me")
    public ResponseEntity<?> me(HttpServletRequest request) {
        String userId = extractUserId(request);
        if (userId == null) return ResponseEntity.status(401).build();
        User user = userMapper.selectById(userId);
        if (user == null) return ResponseEntity.status(404).build();
        return ResponseEntity.ok(Map.of(
                "id", user.getId(),
                "phone", user.getPhone(),
                "nickname", user.getNickname() != null ? user.getNickname() : "",
                "dueDate", user.getDueDate() != null ? user.getDueDate().toString() : ""
        ));
    }

    /** 更新用户信息 */
    @PutMapping("/me")
    public ResponseEntity<?> updateMe(HttpServletRequest request,
                                       @RequestBody AuthDto.UpdateProfileRequest req) {
        String userId = extractUserId(request);
        if (userId == null) return ResponseEntity.status(401).build();
        User user = authService.updateProfile(userId, req);
        return ResponseEntity.ok(Map.of(
                "id", user.getId(),
                "nickname", user.getNickname() != null ? user.getNickname() : "",
                "dueDate", user.getDueDate() != null ? user.getDueDate().toString() : ""
        ));
    }

    private String extractUserId(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try { return jwtUtil.parseUserId(header.substring(7)); } catch (Exception ignored) {}
        }
        return null;
    }
}
