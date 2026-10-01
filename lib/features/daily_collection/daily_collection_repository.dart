// lib/features/daily_collection/daily_collection_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class DailyCollectionResult {
  const DailyCollectionResult({
    required this.rows,
    required this.totals,
    required this.updatedAt,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;
  final String updatedAt;
}

final dailyCollectionRepositoryProvider =
    Provider((ref) => DailyCollectionRepository(ref));

class DailyCollectionRepository {
  DailyCollectionRepository(this.ref);
  final Ref ref;

  /// GET /daily-collection?search= -> location-wise rows + grand totals.
  /// Each row already carries its own `LocationColor` / `LocationName`
  /// (server-resolved from the Locations table), so no extra join is
  /// needed here — unlike Gate Entry/GRN, which still build that mapping
  /// client-side from `/locations/all`.
  Future<DailyCollectionResult> load({String search = ''}) async {
    final body = await ref.read(apiClientProvider).getRaw(
      '/daily-collection',
      query: {'search': search.isEmpty ? null : search},
    );
    return DailyCollectionResult(
      rows: (body['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      totals: (body['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      updatedAt: '${body['updatedAt'] ?? ''}',
    );
  }
}
