import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/photo_viewer_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authProvider);

  return GoRouter(
    initialLocation: isLoggedIn ? '/' : '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/view',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          final photos = extras['photos'] as List<RecordModel>;
          final index = extras['index'] as int;
          
          return PhotoViewerScreen(
            photos: photos,
            initialIndex: index,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final loggingIn = state.uri.toString() == '/login';
      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/';
      return null;
    },
  );
});
