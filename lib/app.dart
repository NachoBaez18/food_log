import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme_preferences.dart';
import 'features/meals/presentation/diary_page.dart';

final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const DiaryPage()),
]);

class FoodLogApp extends ConsumerWidget {
  const FoodLogApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'FoodLog', debugShowCheckedModeBanner: false,
    themeMode: ref.watch(themeModeProvider),
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff2d6a4f)),
    darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff2d6a4f), brightness: Brightness.dark),
    routerConfig: router,
  );
}
