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

  // Full (filtered + sorted) result of the last page-1 load — pages 2+ are
  // sliced from it locally, exactly like the web list does.
  String? _cacheKey;
  List<Map<String, dynamic>> _cacheRows = const [];

  /// Months loaded when no From date is chosen (the web walks back to 2015
  /// progressively; a phone can't afford that).
  static const _defaultMonthsBack = 6;

  /// Mirrors the web list: the API is asked for ONE month at a time
  /// (`month=YYYY-MM`), rows are trimmed to the chosen date range and sorted
  /// newest first, then searched / paged on the device.
  Future<PagedResponse<Map<String, dynamic>>> list(
      int page,
      String search, {
        required int? locationId,
        String? dateFrom,
        String? dateTo,
      }) async {
    final key = '$locationId|$dateFrom|$dateTo';
    if (page <= 1 || _cacheKey != key) {
      _cacheRows = await _loadAll(locationId, dateFrom, dateTo);
      _cacheKey = key;
    }

    final q = search.trim().toLowerCase();
    final rows = q.isEmpty
        ? _cacheRows
        : _cacheRows
            .where((r) => r.values
                .any((v) => v != null && '$v'.toLowerCase().contains(q)))
            .toList();

    const size = AppConfig.pageSize;
    final start = (page - 1) * size;
    final slice = start >= rows.length
        ? <Map<String, dynamic>>[]
        : rows.sublist(start, (start + size).clamp(0, rows.length));
    return PagedResponse<Map<String, dynamic>>(
      items: slice,
      meta: PageMeta(
        page: page,
        perPage: size,
        total: rows.length,
        lastPage: rows.isEmpty ? 1 : (rows.length + size - 1) ~/ size,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAll(
      int? locationId, String? dateFrom, String? dateTo) async {
    final now = DateTime.now();
    final to = dateTo == null ? now : DateTime.parse(dateTo);
    final from = dateFrom == null
        ? DateTime(to.year, to.month - (_defaultMonthsBack - 1), 1)
        : DateTime.parse(dateFrom);

    // Newest month first.
    final months = <String>[];
    var m = DateTime(to.year, to.month);
    final first = DateTime(from.year, from.month);
    while (!m.isBefore(first)) {
      months.add('${m.year}-${m.month.toString().padLeft(2, '0')}');
      m = DateTime(m.year, m.month - 1);
    }

    final api = ref.read(apiClientProvider);
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < months.length; i += 3) {
      final chunk = months.skip(i).take(3);
      final bodies = await Future.wait(chunk.map((ym) => api.getRaw(
            '/gateEntry/datatable',
            query: {'locationID': locationId, 'month': ym},
            logoutOn401: false, // heavy stored-proc endpoint — never self-logout
          )));
      for (final body in bodies) {
        for (final r in (body['data'] as List? ?? const [])) {
          if (r is Map) rows.add(r.cast<String, dynamic>());
        }
      }
    }
    if (rows.isEmpty) return rows;

    // Same date-column detection / range trim / newest-first sort as the web.
    final dateCol = rows.first.keys.firstWhere(
        (k) => k.toLowerCase().contains('date'),
        orElse: () => '');
    if (dateCol.isEmpty) return rows;

    String d(Map<String, dynamic> r) => '${r[dateCol] ?? ''}';
    final kept = rows.where((r) {
      final v = d(r);
      final day = v.length >= 10 ? v.substring(0, 10) : v;
      if (day.isEmpty) return true;
      if (dateFrom != null && day.compareTo(dateFrom) < 0) return false;
      if (dateTo != null && day.compareTo(dateTo) > 0) return false;
      return true;
    }).toList();

    // List.sort isn't stable — keep server order for equal dates, as the
    // browser's stable sort does.
    final idx = {for (var i = 0; i < kept.length; i++) kept[i]: i};
    kept.sort((a, b) {
      final c = d(b).compareTo(d(a));
      return c != 0 ? c : idx[a]!.compareTo(idx[b]!);
    });
    return kept;
  }

  /// GET /gateEntry/details/{id} -> the GRN's line items (same shape GRN
  /// itself uses — `GRN::getGRNItemData()` backs both) plus the entry row
  /// and running totals.
  Future<Map<String, dynamic>> details(
    int grnId, {
    required int locationId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final body = await ref.read(apiClientProvider).getRaw(
      '/gateEntry/details/$grnId',
      query: {
        'locationID': locationId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
      logoutOn401: false,
    );
    return body;
  }

  /// GET /gateEntry/details/{id}/pdf -> raw PDF bytes.
  Future<List<int>> downloadPdf(
    int grnId, {
    required int locationId,
    String? dateFrom,
    String? dateTo,
  }) {
    return ref.read(apiClientProvider).getBytes(
      '/gateEntry/details/$grnId/pdf',
      query: {
        'locationID': locationId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
  }
}

/// Normalises a key for loose matching against the stored procedure's raw
/// (and location-dependent) column names — e.g. the GRN id column comes
/// back as `GrnID` for most locations but `gmID` for location 8.
String _normKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Finds a value in a dynamic-column row by normalised key match — tries
/// each candidate in order and returns the first present (non-null) hit.
Object? findByNormalizedKey(Map<String, dynamic> row, List<String> candidates) {
  final normalized = {for (final e in row.entries) _normKey(e.key): e.value};
  for (final c in candidates) {
    final v = normalized[_normKey(c)];
    if (v != null) return v;
  }
  return null;
}