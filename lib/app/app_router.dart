import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/workspace/presentation/workspace_screen.dart';
import 'app_navigator.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: ref.watch(appNavigatorKeyProvider),
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WorkspaceScreen()),
    ],
  );
});
