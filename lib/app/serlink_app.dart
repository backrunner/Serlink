import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_dependencies.dart';
import 'app_router.dart';
import 'app_theme.dart';

class SerlinkApp extends ConsumerWidget {
  const SerlinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(autoSyncControllerProvider);

    return MaterialApp.router(
      title: 'Serlink',
      debugShowCheckedModeBanner: false,
      theme: SerlinkTheme.light(),
      darkTheme: SerlinkTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
