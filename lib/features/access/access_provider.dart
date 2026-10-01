// lib/features/access/access_provider.dart
//
// What the logged-in user may open. The Laravel backend already enforces it
// (module paths + `locationID` are checked by CheckModuleAccess and answer
// 403), so this only decides what the app *shows*: dashboard tiles, drawer
// links and location dropdowns.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// A dashboard module, keyed by the backend's slug (config/user_access.php).
class ModuleDef {
  const ModuleDef(this.slug, this.label, this.icon, this.color,
      {this.route, this.image});
  final String slug;
  final String label;
  final IconData icon;

  /// Per-tile accent border colour — every web dashboard tile has its own
  /// pastel outline; mirrored here so the mobile tiles aren't all plain grey.
  final Color color;

  /// null = not built on mobile yet ("Coming soon").
  final String? route;
  final String? image;
}

const kModules = <ModuleDef>[
  ModuleDef('item-stock', 'ITEM STOCK', Icons.widgets_outlined,
      Color(0xFF7FC8A9),
      route: '/item-stock', image: 'assets/images/ITEM STOCK.jpg'),
  ModuleDef('all-stock-details', 'ALL STOCK DETAILS',
      Icons.inventory_2_outlined, Color(0xFF7FB3F5),
      route: '/stock', image: 'assets/images/ALL STOCK DETAILS.jpg'),
  ModuleDef('vendor-invoice', 'UPLOAD GATE ENTRY BILL',
      Icons.receipt_long_outlined, Color(0xFFF2A6B3),
      route: '/upload-gate-entry-bill', image: 'assets/images/UPLOAD BILL.png'),
  ModuleDef('gate-entry', 'GATE ENTRY', Icons.meeting_room_outlined,
      Color(0xFFF0879A),
      route: '/gate-entry', image: 'assets/images/GATE ENTRY.jpg'),
  ModuleDef('grn', 'GRN', Icons.assignment_turned_in_outlined,
      Color(0xFF6FD6D1),
      route: '/grn', image: 'assets/images/GRN.png'),
  ModuleDef('attendance', 'ATTENDANCE', Icons.people_alt_outlined,
      Color(0xFFB39DF5),
      route: '/attendance', image: 'assets/images/ATTENDANCE.jpg'),
  ModuleDef('home-stay', 'HOME STAY', Icons.cottage_outlined,
      Color(0xFFB39DF5),
      route: '/home-stay'),
  ModuleDef('pearl-stay', 'PEARL STAY', Icons.home_outlined,
      Color(0xFF7FC8A9),
      image: 'assets/images/PEARL STAY.JPG'),
  ModuleDef('document-download', 'DOCUMENT DOWNLOAD',
      Icons.file_download_outlined, Color(0xFFF08A8A),
      route: '/documents', image: 'assets/images/DOWNLOAD DOCUMENT.jpg'),
  ModuleDef('daily-collection', 'DAILY COLLECTION',
      Icons.point_of_sale_outlined, Color(0xFF7FB3F5),
      route: '/daily-collection', image: 'assets/images/DAILY COLLECTION.jpg'),
  ModuleDef('floor-wise-sales', 'FLOOR WISE SALES', Icons.upload_outlined,
      Color(0xFFF4A1C4),
      image: 'assets/images/FLOOR WISE SALES.jpg'),
];

ModuleDef? moduleBySlug(String slug) {
  for (final m in kModules) {
    if (m.slug == slug) return m;
  }
  return null;
}

class UserAccess {
  const UserAccess({
    required this.isAdmin,
    required this.modules,
    this.locationIds,
    this.locationCodes,
  });

  final bool isAdmin;
  final Set<String> modules;

  /// null = unrestricted / unknown (admin, or the backend didn't say).
  final Set<int>? locationIds;

  /// Upper-case Locationcodes of [locationIds] (LJP, HSD …); null likewise.
  final Set<String>? locationCodes;

  bool canModule(String slug) => isAdmin || modules.contains(slug);
  bool canLocation(int id) =>
      isAdmin || locationIds == null || locationIds!.contains(id);
  bool canLocationCode(String code) =>
      isAdmin ||
      locationCodes == null ||
      locationCodes!.contains(code.trim().toUpperCase());
}

/// GET /dashboard -> the tiles this user may open (`data[].slug`) plus
/// `is_admin`. Allowed locations come from `access.locations` if the backend
/// sends it, otherwise they are probed (see [_probeAllowedLocations]).
final userAccessProvider = FutureProvider<UserAccess>((ref) async {
  // Re-load whenever a different user logs in.
  ref.watch(authControllerProvider.select((s) => s.user?.id));

  final body = await ref.read(apiClientProvider).getRaw('/dashboard');
  final isAdmin = body['is_admin'] == true;
  final modules = <String>{
    for (final t in (body['data'] as List? ?? const []))
      if (t is Map && t['slug'] != null) '${t['slug']}',
  };

  Set<int>? locations;
  final access = body['access'];
  if (access is Map && access['locations'] is List) {
    locations = {
      for (final v in access['locations'] as List)
        if (asInt(v) != null) asInt(v)!,
    };
  }
  // id -> code, for the screens that only know a location by its code.
  final codeById = <int, String>{};
  try {
    final all = await ref.read(apiClientProvider).getData('/locations/all');
    for (final r in (all as List? ?? const [])) {
      if (r is Map && asInt(r['LocationID']) != null) {
        codeById[asInt(r['LocationID'])!] =
            '${r['Locationcode'] ?? ''}'.trim().toUpperCase();
      }
    }
  } catch (_) {}

  if (!isAdmin && locations == null) {
    locations = await _probeAllowedLocations(ref, codeById.keys.toList());
  }
  return UserAccess(
    isAdmin: isAdmin,
    modules: modules,
    locationIds: locations,
    locationCodes: locations == null
        ? null
        : {
            for (final id in locations)
              if ((codeById[id] ?? '').isNotEmpty) codeById[id]!,
          },
  );
});

/// The API has no "my locations" endpoint, but its access middleware answers
/// 403 to ANY /api request carrying a `locationID` the user hasn't been
/// granted (checked before the route runs, and /locations/all belongs to no
/// module). So each location is tried once on that cheap route: 403 = not
/// allowed. Any other failure leaves the location visible (the server still
/// guards the real data) rather than hiding things on a flaky connection.
Future<Set<int>?> _probeAllowedLocations(Ref ref, List<int> ids) async {
  final api = ref.read(apiClientProvider);
  if (ids.isEmpty) return null;
  try {
    final allowed = <int>{};
    for (var i = 0; i < ids.length; i += 6) {
      await Future.wait(ids.skip(i).take(6).map((id) async {
        try {
          await api.getRaw('/locations/all',
              query: {'locationID': id}, logoutOn401: false);
          allowed.add(id);
        } on ApiException catch (e) {
          if (e.statusCode != 403) allowed.add(id);
        } catch (_) {
          allowed.add(id);
        }
      }));
    }
    return allowed;
  } catch (_) {
    return null; // unknown -> don't hide anything
  }
}
