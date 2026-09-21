// lib/features/home_stay/home_stay_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';

/// Mirrors the web "Home Stay" landing page — a hub for the four
/// hostel sub-modules.
const _items = <({String label, IconData icon, String route})>[
  (label: 'PENDING RENT DETAILS', icon: Icons.currency_rupee, route: '/pending-rent'),
  (label: 'STUDENT DETAILS', icon: Icons.school_outlined, route: '/students'),
  (label: 'BED OCCUPANCY', icon: Icons.bed_outlined, route: '/bed-occupancy'),
  (label: 'STUDENT NEW ADMISSION', icon: Icons.person_add_alt_1_outlined, route: '/new-students'),
];

class HomeStayScreen extends StatelessWidget {
  const HomeStayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Home Stay'),
      body: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.08,
        children: [
          for (final it in _items)
            HsGridTile(
              icon: it.icon,
              label: it.label,
              onTap: () => context.push(it.route),
            ),
        ],
      ),
    );
  }
}
