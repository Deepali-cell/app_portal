import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class TcbPortalApp extends ConsumerWidget {
  const TcbPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TCB Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Light-mode only: force the light theme regardless of system setting.
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
