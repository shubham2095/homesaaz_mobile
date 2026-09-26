// lib/widgets/hs_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/tokens.dart';
import '../core/format.dart';
import '../features/access/access_provider.dart';
import '../features/auth/auth_controller.dart';
import 'hs_widgets.dart';

/// Side menu — the mobile equivalent of the web top navbar.
class HsDrawer extends ConsumerWidget {
  const HsDrawer({super.key});

  // [slug] = backend module the link belongs to (null = always visible).
  static const _items = <({String label, IconData icon, String route, bool adminOnly, String? slug})>[
    (label: 'Dashboard', icon: Icons.grid_view_outlined, route: '/', adminOnly: false, slug: null),
    (label: 'All Stock Details', icon: Icons.inventory_2_outlined, route: '/stock', adminOnly: false, slug: 'all-stock-details'),
    (label: 'Item Stock', icon: Icons.widgets_outlined, route: '/item-stock', adminOnly: false, slug: 'item-stock'),
    (label: 'Upload Gate Entry Bill', icon: Icons.receipt_long_outlined, route: '/upload-gate-entry-bill', adminOnly: false, slug: 'vendor-invoice'),
    (label: 'Home Stay', icon: Icons.cottage_outlined, route: '/home-stay', adminOnly: false, slug: 'home-stay'),
    (label: 'Gate Entry', icon: Icons.meeting_room_outlined, route: '/gate-entry', adminOnly: false, slug: 'gate-entry'),
    (label: 'GRN', icon: Icons.assignment_turned_in_outlined, route: '/grn', adminOnly: false, slug: 'grn'),
    (label: 'Document Download', icon: Icons.file_download_outlined, route: '/documents', adminOnly: false, slug: 'document-download'),
    (label: 'Daily Collection', icon: Icons.point_of_sale_outlined, route: '/daily-collection', adminOnly: false, slug: 'daily-collection'),
    (label: 'Locations', icon: Icons.location_on_outlined, route: '/locations', adminOnly: false, slug: null),
    (label: 'User', icon: Icons.people_outline, route: '/users', adminOnly: true, slug: null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    // While the access list loads (or if it fails) module links stay hidden.
    final access = ref.watch(userAccessProvider).valueOrNull;
    final current = GoRouterState.of(context).matchedLocation;
    final photo = profileImageUrl(user?.profileImage);
    final name = (user?.fullName.isNotEmpty ?? false) ? user!.fullName : 'User';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
        .join();

    return Drawer(
      backgroundColor: Hs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ---- header --------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Hs.yellowBorder, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/homesaaz_logo.png',
                      height: 34, fit: BoxFit.contain),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Hs.teal,
                        backgroundImage: photo == null
                            ? null
                            : NetworkImage(photo, headers: null),
                        onBackgroundImageError: photo == null ? null : (_, __) {},
                        child: photo != null
                            ? null
                            : Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Hs.ink)),
                            if ((user?.email ?? '').isNotEmpty)
                              Text(user!.email,
                                  style: const TextStyle(
                                      fontSize: 12, color: Hs.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ---- links --------------------------------------------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final (i, it) in _items.indexed)
                    if ((!it.adminOnly || isAdmin) &&
                        (it.slug == null || (access?.canModule(it.slug!) ?? false)))
                      HsAppear(
                        index: i,
                        child: _NavTile(
                          icon: it.icon,
                          label: it.label,
                          selected: current == it.route,
                          onTap: () {
                            Navigator.pop(context);
                            if (current != it.route) context.go(it.route);
                          },
                        ),
                      ),
                ],
              ),
            ),
            // ---- logoff -------------------------------------------------
            const Divider(height: 1),
            _NavTile(
              icon: Icons.logout,
              label: 'Logoff',
              color: Hs.brandRed,
              onTap: () {
                Navigator.pop(context);
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (selected ? Hs.blue : Hs.inkSoft);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 1, 8, 1),
      child: Material(
        color: selected ? Hs.blue.withValues(alpha: .09) : Colors.transparent,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Hs.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 19, color: c),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: c,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Hs.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
