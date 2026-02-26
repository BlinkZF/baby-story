package com.baobao.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class AuthDto {

    @Data
    public static class SendCodeRequest {
        @NotBlank @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
        private String phone;
    }

    @Data
    public static class LoginRequest {
        @NotBlank @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
        private String phone;

        @NotBlank @Size(min = 6, max = 6, message = "验证码为 6 位")
        private String code;
    }

    @Data
    public static class UpdateProfileRequest {
        private String nickname;
        private String dueDate;   // ISO 格式 yyyy-MM-dd
    }

    @Data
    public static class LoginResponse {
        private String token;
        private UserVo user;
    }

    @Data
    public static class UserVo {
        private String id;
        private String phone;
        private String nickname;
        private String dueDate;
        private Boolean isNewUser;
    }
}
