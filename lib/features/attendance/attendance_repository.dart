// lib/features/attendance/attendance_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

class AttendanceLocation {
  const AttendanceLocation(this.id, this.name, this.colorHex);
  final int id;
  final String name;
  final String? colorHex;
}

/// GET /attendance/locations -> locations this user may see. The backend
/// already filters these by the user's access; [userAccessProvider] is
/// re-applied defensively, same as Gate Entry/GRN's own location lists.
final attendanceLocationsProvider =
    FutureProvider<List<AttendanceLocation>>((ref) async {
  final access = await ref.watch(userAccessProvider.future);
  final data =
      await ref.read(apiClientProvider).getData('/attendance/locations');
  final list = <AttendanceLocation>[];
  for (final row in (data as List? ?? const [])) {
    if (row is! Map) continue;
    final id = asInt(row['id'] ?? row['LocationID']);
    if (id == null || !access.canLocation(id)) continue;
    list.add(AttendanceLocation(
      id,
      '${row['name'] ?? row['LocationName'] ?? 'Location $id'}',
      (row['color'] ?? row['Color'])?.toString(),
    ));
  }
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

/// The 4 summary cards — ignores the `today` filter server-side, so these
/// numbers stay the same no matter which status chip is selected.
class AttendanceSummary {
  const AttendanceSummary({
    this.total = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.late = 0,
  });

  final int total;
  final int presentToday;
  final int absentToday;
  final int late;

  factory AttendanceSummary.fromJson(Map? j) {
    int n(Object? v) => asInt(v) ?? 0;
    return AttendanceSummary(
      total: n(j?['total']),
      presentToday: n(j?['presentToday']),
      absentToday: n(j?['absentToday']),
      late: n(j?['late']),
    );
  }
}

final attendanceRepositoryProvider =
    Provider((ref) => AttendanceRepository(ref));

class AttendanceRepository {
  AttendanceRepository(this.ref);
  final Ref ref;

  /// GET /attendance — true server-side pagination (unlike Gate Entry's
  /// month-by-month load), so every page is its own request.
  Future<PagedResponse<Map<String, dynamic>>> list(
    int page,
    String search, {
    int? locationId,
    String today = 'present',
  }) async {
    final body = await ref.read(apiClientProvider).getRaw(
      '/attendance',
      query: {
        'locationID': locationId,
        'search': search.isEmpty ? null : search,
        'today': today,
        'page': page,
        'perPage': AppConfig.pageSize,
      },
      // "All Locations" + "All" scans every employee row twice (summary +
      // page) — give it more room than the default 60s.
      receiveTimeout: const Duration(seconds: 90),
    );
    final rows = (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    // The endpoint speaks its own dialect (page/perPage/totalPages), not
    // DataTables or the Stock-style keys PageMeta.fromBody understands.
    final size = asInt(body['perPage']) ?? AppConfig.pageSize;
    final total = asInt(body['recordsFiltered']) ?? rows.length;
    final lastPage = asInt(body['totalPages']) ??
        (total > 0 ? ((total + size - 1) ~/ size) : page);

    return PagedResponse<Map<String, dynamic>>(
      items: rows,
      meta: PageMeta(
        page: asInt(body['page']) ?? page,
        perPage: size,
        total: total,
        lastPage: lastPage < page ? page : lastPage,
      ),
      extra: {
        'summary': AttendanceSummary.fromJson(
            (body['summary'] as Map?)?.cast<String, dynamic>()),
      },
    );
  }
}
