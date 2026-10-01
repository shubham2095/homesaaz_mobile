// lib/features/floor_wise_sales/floor_wise_sales_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

class FloorWiseSalesLocation {
  const FloorWiseSalesLocation(this.id, this.name, this.colorHex);
  final int id;
  final String name;
  final String? colorHex;
}

/// GET /floor-wise-sales/locations -> only locations with a sales database
/// configured (the ones this report can actually run against), joined with
/// GET /locations/all for each one's colour (the dedicated endpoint strips
/// that field server-side).
final floorWiseSalesLocationsProvider =
    FutureProvider<List<FloorWiseSalesLocation>>((ref) async {
  final access = await ref.watch(userAccessProvider.future);
  final api = ref.read(apiClientProvider);
  final results = await Future.wait([
    api.getData('/floor-wise-sales/locations'),
    api.getData('/locations/all').catchError((_) => const []),
  ]);

  final colorById = <int, String>{};
  for (final row in (results[1] as List? ?? const [])) {
    if (row is! Map) continue;
    final id = asInt(row['LocationID']);
    final color = '${row['Color'] ?? ''}'.trim();
    if (id != null && color.isNotEmpty) colorById[id] = color;
  }

  final list = <FloorWiseSalesLocation>[];
  for (final row in (results[0] as List? ?? const [])) {
    if (row is! Map) continue;
    final id = asInt(row['id']);
    if (id == null || !access.canLocation(id)) continue;
    list.add(FloorWiseSalesLocation(
        id, '${row['name'] ?? 'Location $id'}', colorById[id]));
  }
  return list;
});

/// One floor's row — same 6 money columns the SQL query returns by name.
class FloorRow {
  const FloorRow(this.floorName, this.values);
  final String floorName;

  /// GrossAmt, GrossAmt1 (40%+ disc), DisAmount, AddDiscAmt, TaxAmt, NetAmt.
  final Map<String, num> values;

  factory FloorRow.fromJson(Map<String, dynamic> j) {
    num n(String k) => asNum(j[k]) ?? 0;
    final name = '${j['FloorName'] ?? ''}'.trim();
    return FloorRow(name.isEmpty ? '-' : name, {
      'GrossAmt': n('GrossAmt'),
      'GrossAmt1': n('GrossAmt1'),
      'DisAmount': n('DisAmount'),
      'AddDiscAmt': n('AddDiscAmt'),
      'TaxAmt': n('TaxAmt'),
      'NetAmt': n('NetAmt'),
    });
  }
}

class FloorWiseSalesResult {
  const FloorWiseSalesResult({required this.rows, required this.totals});
  final List<FloorRow> rows;

  /// Same keys as each [FloorRow.values].
  final Map<String, num> totals;
}

final floorWiseSalesRepositoryProvider =
    Provider((ref) => FloorWiseSalesRepository(ref));

class FloorWiseSalesRepository {
  FloorWiseSalesRepository(this.ref);
  final Ref ref;

  /// GET /floor-wise-sales?locationID=&dateFrom=&dateTo= — runs a UNION
  /// query on the location's own sales database, so give it more room than
  /// the default JSON timeout.
  Future<FloorWiseSalesResult> load({
    required int locationId,
    required String dateFrom,
    required String dateTo,
  }) async {
    final body = await ref.read(apiClientProvider).getRaw(
      '/floor-wise-sales',
      query: {
        'locationID': locationId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
      receiveTimeout: const Duration(seconds: 90),
    );
    final rows = (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => FloorRow.fromJson(e.cast<String, dynamic>()))
        .toList();
    final totalsJson = (body['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    num n(String k) => asNum(totalsJson[k]) ?? 0;
    return FloorWiseSalesResult(rows: rows, totals: {
      'GrossAmt': n('GrossAmt'),
      'GrossAmt1': n('GrossAmt1'),
      'DisAmount': n('DisAmount'),
      'AddDiscAmt': n('AddDiscAmt'),
      'TaxAmt': n('TaxAmt'),
      'NetAmt': n('NetAmt'),
    });
  }
}
