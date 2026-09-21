// lib/features/gate_entry/gate_entry_repository.dart
//
// Gate Entry is its own module — nothing here is shared with GRN, even
// though both happen to read from the same 3 warehouse locations.
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';

/// Gate Entry only works for these warehouse locations (the web hardcodes
/// the same list in GateEntryController::list()).
const kGateEntryLocationIds = <int>[8, 26, 29];

class GateEntryLocation {
  const GateEntryLocation(this.name, this.colorHex);
  final String name;
  final String? colorHex;
}

Color? parseGateEntryColor(String? v) {
  final s = (v ?? '').replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}

/// { LocationID : (name, colour) } — limited to the Gate Entry locations.
final gateEntryLocationsProvider =
    FutureProvider<Map<int, GateEntryLocation>>((ref) async {
  final rows = <int, GateEntryLocation>{};
  try {
    final data = await ref.read(apiClientProvider).getData('/locations/all');
    for (final row in (data as List? ?? const [])) {
      if (row is Map) {
        final id = asInt(row['LocationID']);
        if (id != null) {
          rows[id] = GateEntryLocation(
            '${row['LocationName'] ?? row['Locationcode'] ?? 'Location $id'}',
            row['Color']?.toString(),
          );
        }
      }
    }
  } catch (_) {
    // fall through to placeholder names
  }
  return {
    for (final id in kGateEntryLocationIds)
      id: rows[id] ?? GateEntryLocation('Location $id', null),
  };
});

final gateEntryRepositoryProvider = Provider((ref) => GateEntryRepository(ref));

class GateEntryRepository {
  GateEntryRepository(this.ref);
  final Ref ref;

  /// GET /gateEntry/datatable — needs a location; date range is optional.
  Future<PagedResponse<Map<String, dynamic>>> list(
    int page,
    String search, {
    required int? locationId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/gateEntry/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
          logoutOn401: false, // heavy stored-proc endpoint — never self-logout
          extra: {
            'locationID': locationId,
            'dateFrom': dateFrom,
            'dateTo': dateTo,
          },
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}
