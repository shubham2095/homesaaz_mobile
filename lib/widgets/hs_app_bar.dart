// lib/widgets/hs_app_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// White brand top-bar with the yellow underline (theme-provided).
///
/// * On the dashboard pass `home: true` — the leading icon is the side-menu
///   button.
/// * On every other screen the leading icon is a Back arrow (pops to the
///   previous screen, or jumps to the dashboard if there is nothing to pop),
///   and the side-menu stays reachable as the last action.
///
/// Pair every screen's Scaffold with `drawer: const HsDrawer()`.
class HsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HsAppBar({
    super.key,
    this.title,
    this.showLogo = false,
    this.home = false,
    this.actions,
  });

  final String? title;
  final bool showLogo;
  final bool home;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: home
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                final router = GoRouter.of(context);
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go('/');
                }
              },
            ),
      title: showLogo
          ? Image.asset('assets/images/homesaaz_logo.png',
              height: 38, fit: BoxFit.contain, cacheHeight: 76)
          : Text(title ?? ''),
      actions: [
        ...?actions,
        if (!home)
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
