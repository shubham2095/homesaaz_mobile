
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

/// GRN only works for these warehouse locations (the web hardcodes the
/// same list in GateEntryController::list(), which GRN::datatable reuses).
const kGrnLocationIds = <int>[8, 26, 29];

class GrnLocation {
  const GrnLocation(this.name, this.colorHex);
  final String name;
  final String? colorHex;
}

Color? parseGrnColor(String? v) {
  final s = (v ?? '').replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}

/// { LocationID : (name, colour) } — limited to the GRN locations.
final grnLocationsProvider = FutureProvider<Map<int, GrnLocation>>((ref) async {
  final rows = <int, GrnLocation>{};
  try {
    final data = await ref.read(apiClientProvider).getData('/locations/all');
    for (final row in (data as List? ?? const [])) {
      if (row is Map) {
        final id = asInt(row['LocationID']);
        if (id != null) {
          rows[id] = GrnLocation(
            '${row['LocationName'] ?? row['Locationcode'] ?? 'Location $id'}',
            row['Color']?.toString(),
          );
        }
      }
    }
  } catch (_) {
    // fall through to placeholder names
  }
  // Only the locations this user was granted on the User form.
  final access = await ref.watch(userAccessProvider.future);
  return {
    for (final id in kGrnLocationIds)
      if (access.canLocation(id))
        id: rows[id] ?? GrnLocation('Location $id', null),
  };
});

final grnRepositoryProvider = Provider((ref) => GrnRepository(ref));

class GrnRepository {
  GrnRepository(this.ref);
  final Ref ref;

  /// GET /grn/datatable — needs a location; date range is optional.
  Future<PagedResponse<Map<String, dynamic>>> list(
    int page,
    String search, {
    required int? locationId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/grn/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
          logoutOn401: false,
          extra: {
            'locationID': locationId,
            'dateFrom': dateFrom,
            'dateTo': dateTo,
          },
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }

  /// GET /grn/{id}?locationID={loc} -> { grnId, locationID, items: [...] }
  Future<List<Map<String, dynamic>>> items(int grnId, int locationId) async {
    final body = await ref.read(apiClientProvider).getRaw(
      '/grn/$grnId',
      query: {'locationID': locationId},
      logoutOn401: false,
    );
    return ((body['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// GET /grn/{id}/pdf?locationID=&date= -> raw PDF bytes.
  /// [date] must fall within the GRN's month (any `YYYY-MM-DD` in it).
  Future<List<int>> downloadPdf(int grnId,
      {required int locationId, required String date}) {
    return ref.read(apiClientProvider).getBytes(
      '/grn/$grnId/pdf',
      query: {'locationID': locationId, 'date': date},
    );
  }
}
