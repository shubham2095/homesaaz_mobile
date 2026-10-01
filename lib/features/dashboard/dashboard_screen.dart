// lib/features/dashboard/dashboard_screen.dart
//
// Mirrors web `resources/views/dashboard.blade.php` + `.hs-wrap` / `.hs-grid`
// / `.hs-tile` (homesaaz.css). The web grid is 3 columns on desktop and
// collapses to a single centred column under its own 520px breakpoint —
// every phone viewport falls under that breakpoint, so this reproduces the
// single-column mobile layout the web app itself renders at phone widths.
//
// Only the modules the user was granted on the User form are shown (admins
// see all); the module list itself lives in access_provider.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/states.dart';
import '../access/access_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userAccessProvider);

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(showLogo: true, home: true),
      body: access.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(userAccessProvider),
        ),
        data: (a) {
          final tiles = kModules.where((m) => a.canModule(m.slug)).toList();
          if (tiles.isEmpty) {
            return const EmptyView(
                message: 'No modules assigned to your account yet.\n'
                    'Please contact the administrator.');
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userAccessProvider);
                  await ref.read(userAccessProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 40),
                  itemCount: tiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 22),
                  itemBuilder: (context, i) {
                    final t = tiles[i];
                    return HsAppear(
                      index: i,
                      child: HsGridTile(
                        icon: t.icon,
                        label: t.label,
                        imageAsset: t.image,
                        borderColor: t.color,
                        onTap: () {
                          if (t.route == null) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('Coming soon')),
                              );
                          } else {
                            context.push(t.route!);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
