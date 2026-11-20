// lib/features/home_stay/home_stay_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import 'stay.dart';

typedef _Tile = ({String label, IconData icon, String route, Color color});

/// The landing hub of ALFOHOMES (formerly "Home Stay") and of Pearl Stay — the
/// four hostel sub-modules. Each tile gets its own pastel border, same as the
/// main dashboard's tiles. The tile names follow each one's web hub page.
List<_Tile> _tilesFor(Stay stay) {
  final pearl = stay == Stay.pearl;
  return [
    (
      label: pearl ? 'PENDING RENT' : 'PENDING RENT DETAILS',
      icon: Icons.currency_rupee,
      route: stay.pendingRentRoute,
      color: const Color(0xFFF2A6B3),
    ),
    (
      label: 'STUDENT DETAILS',
      icon: Icons.school_outlined,
      route: stay.studentsRoute,
      color: const Color(0xFF7FB3F5),
    ),
    (
      label: pearl ? 'BED STATUS' : 'BED OCCUPANCY',
      icon: Icons.bed_outlined,
      route: stay.bedOccupancyRoute,
      color: const Color(0xFF7FC8A9),
    ),
    (
      label: pearl ? 'NEW STUDENT' : 'STUDENT NEW ADMISSION',
      icon: Icons.person_add_alt_1_outlined,
      route: stay.newStudentsRoute,
      color: const Color(0xFFB39DF5),
    ),
  ];
}

class StayHubScreen extends StatelessWidget {
  const StayHubScreen({super.key, this.stay = Stay.home});

  final Stay stay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(title: stay.title),
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
          for (final it in _tilesFor(stay))
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
