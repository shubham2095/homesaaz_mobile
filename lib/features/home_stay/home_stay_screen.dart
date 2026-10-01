// lib/features/home_stay/home_stay_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';

/// Mirrors the web "Home Stay" landing page — a hub for the four
/// hostel sub-modules. Each tile gets its own pastel border, same as the
/// main dashboard's tiles.
const _items = <({String label, IconData icon, String route, Color color})>[
  (
    label: 'PENDING RENT DETAILS',
    icon: Icons.currency_rupee,
    route: '/pending-rent',
    color: Color(0xFFF2A6B3),
  ),
  (
    label: 'STUDENT DETAILS',
    icon: Icons.school_outlined,
    route: '/students',
    color: Color(0xFF7FB3F5),
  ),
  (
    label: 'BED OCCUPANCY',
    icon: Icons.bed_outlined,
    route: '/bed-occupancy',
    color: Color(0xFF7FC8A9),
  ),
  (
    label: 'STUDENT NEW ADMISSION',
    icon: Icons.person_add_alt_1_outlined,
    route: '/new-students',
    color: Color(0xFFB39DF5),
  ),
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
        // A little shorter than square so the fixed-height cell always has
        // room for HsGridTile's content (avoids a bottom overflow on
        // narrower phones).
        childAspectRatio: 0.98,
        children: [
          for (final it in _items)
            HsGridTile(
              icon: it.icon,
              label: it.label,
              borderColor: it.color,
              onTap: () => context.push(it.route),
            ),
        ],
      ),
    );
  }
}
