// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class HomeSaazApp extends ConsumerWidget {
  const HomeSaazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'HomeSaaz',
      debugShowCheckedModeBanner: false,
      // The web app is light-only — pin the app to light so the palette
      // stays consistent regardless of the phone's system theme.
      theme: buildTheme(Brightness.light),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
