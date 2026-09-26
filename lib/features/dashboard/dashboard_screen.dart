// lib/features/dashboard/dashboard_screen.dart
//
// Mirrors web `resources/views/dashboard.blade.php` + `.hs-wrap` / `.hs-grid`
// / `.hs-tile` (homesaaz.css). The web grid is 3 columns on desktop and
// collapses to a single centred column under its own 520px breakpoint —
// every phone viewport falls under that breakpoint, so this reproduces the
// single-column mobile layout the web app itself renders at phone widths.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../auth/auth_controller.dart';

/// Tile grid — mirrors the web app's module list. Modules not yet built on
/// mobile (`route` is null) show a "Coming soon" message instead of navigating.
/// [image] is a photo/logo asset that replaces the plain icon glyph when set.
const _tiles = <({
  String label,
  IconData icon,
  String? route,
  bool adminOnly,
  String? image,
})>[
  (
    label: 'ITEM STOCK',
    icon: Icons.widgets_outlined,
    route: '/item-stock',
    adminOnly: false,
    image: 'assets/images/ITEM STOCK.jpg',
  ),
  (
    label: 'ALL STOCK DETAILS',
    icon: Icons.inventory_2_outlined,
    route: '/stock',
    adminOnly: false,
    image: 'assets/images/ALL STOCK DETAILS.jpg',
  ),
  (
    label: 'UPLOAD GATE ENTRY BILL',
    icon: Icons.receipt_long_outlined,
    route: '/upload-gate-entry-bill',
    adminOnly: false,
    image: 'assets/images/UPLOAD BILL.png',
  ),
  (
    label: 'GATE ENTRY',
    icon: Icons.meeting_room_outlined,
    route: '/gate-entry',
    adminOnly: false,
    image: 'assets/images/GATE ENTRY.jpg',
  ),
  (
    label: 'GRN',
    icon: Icons.assignment_turned_in_outlined,
    route: '/grn',
    adminOnly: false,
    image: 'assets/images/GRN.png',
  ),
  (
    label: 'ATTENDANCE',
    icon: Icons.people_alt_outlined,
    route: null,
    adminOnly: false,
    image: 'assets/images/ATTENDANCE.jpg',
  ),
  (
    label: 'HOME STAY',
    icon: Icons.cottage_outlined,
    route: '/home-stay',
    adminOnly: false,
    image: null,
  ),
  (
    label: 'PEARL STAY',
    icon: Icons.home_outlined,
    route: null,
    adminOnly: false,
    image: 'assets/images/PEARL STAY.JPG',
  ),
  (
    label: 'DOCUMENT DOWNLOAD',
    icon: Icons.file_download_outlined,
    route: '/documents',
    adminOnly: false,
    image: 'assets/images/DOWNLOAD DOCUMENT.jpg',
  ),
  (
    label: 'DAILY COLLECTION',
    icon: Icons.point_of_sale_outlined,
    route: '/daily-collection',
    adminOnly: false,
    image: 'assets/images/DAILY COLLECTION.jpg',
  ),
  (
    label: 'FLOOR WISE SALES',
    icon: Icons.upload_outlined,
    route: null,
    adminOnly: false,
    image: 'assets/images/FLOOR WISE SALES.jpg',
  ),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authControllerProvider).user?.isAdmin ?? false;
    final tiles = _tiles.where((t) => !t.adminOnly || isAdmin).toList();

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(showLogo: true, home: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ListView.separated(
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
  }
}
