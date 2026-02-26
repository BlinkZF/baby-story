import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/home/main_shell.dart';
import '../screens/home/home_tab.dart';
import '../screens/voice/voice_guide_screen.dart';
import '../screens/voice/voice_record_screen.dart';
import '../screens/voice/voice_result_screen.dart';
import '../screens/content/content_list_screen.dart';
import '../screens/content/content_detail_screen.dart';
import '../screens/player/player_screen.dart';
import '../screens/profile/profile_screen.dart';

final _rootKey  = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login',
        builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/profile-setup',
        builder: (_, __) => const ProfileSetupScreen()),

    // ── Shell（底部导航）
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',
            builder: (_, __) => const HomeTab()),
        GoRoute(path: '/content',
            builder: (_, __) => const ContentListScreen()),
        GoRoute(path: '/profile',
            builder: (_, __) => const ProfileScreen()),
      ],
    ),

    // ── 声音采集（全屏流程）
    GoRoute(path: '/voice/guide',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VoiceGuideScreen(role: s.uri.queryParameters['role'] ?? 'mom')),
    GoRoute(path: '/voice/record',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VoiceRecordScreen(role: s.uri.queryParameters['role'] ?? 'mom')),
    GoRoute(path: '/voice/result',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VoiceResultScreen(taskId: s.uri.queryParameters['taskId'] ?? '')),

    // ── 内容详情 & 播放器（全屏）
    GoRoute(path: '/content/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ContentDetailScreen(contentId: s.pathParameters['id']!)),
    GoRoute(path: '/player/:contentId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => PlayerScreen(
          contentId: s.pathParameters['contentId']!,
          voiceModelId: s.uri.queryParameters['voiceModelId'],
        )),
  ],
);
