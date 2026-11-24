import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/meals/presentation/diary_page.dart';

final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const DiaryPage()),
]);

class FoodLogApp extends StatelessWidget {
  const FoodLogApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'FoodLog', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff426b50)),
    darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff426b50), brightness: Brightness.dark),
    routerConfig: router,
  );
}
