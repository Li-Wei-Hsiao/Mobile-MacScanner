// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

import '../features/mac_scanner/presentation/file_list_page.dart';
import '../features/mac_scanner/presentation/history_page.dart';
import '../features/mac_scanner/presentation/settings_page.dart';

class AppRouter {
  final List<CameraDescription> cameras;
  late final GoRouter router;

  AppRouter({required this.cameras}) {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => FileListPage(cameras: cameras),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );
  }
}
