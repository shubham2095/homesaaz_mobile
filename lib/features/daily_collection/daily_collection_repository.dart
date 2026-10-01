// lib/features/daily_collection/daily_collection_repository.dart
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';

class DailyCollectionResult {
  const DailyCollectionResult({
    required this.rows,
    required this.totals,
    required this.updatedAt,
    required this.locationColors,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;
  final String updatedAt;

  /// Locationcode (upper-case) -> `#RRGGBB`, from the Locations table — the
  /// same colour Gate Entry/GRN show for each branch.
  final Map<String, String> locationColors;
}

final dailyCollectionRepositoryProvider =
    Provider((ref) => DailyCollectionRepository(ref));

class DailyCollectionRepository {
  DailyCollectionRepository(this.ref);
  final Ref ref;

  /// GET /daily-collection?search= -> location-wise rows + grand totals,
  /// joined with GET /locations/all for each row's branch colour.
  Future<DailyCollectionResult> load({String search = ''}) async {
    final api = ref.read(apiClientProvider);
    final results = await Future.wait([
      api.getRaw('/daily-collection', query: {
        'search': search.isEmpty ? null : search,
      }),
      api.getData('/locations/all').catchError((_) => const []),
    ]);
    final body = results[0] as Map<String, dynamic>;
    final locations = results[1];

    final colors = <String, String>{};
    for (final l in (locations as List? ?? const [])) {
      if (l is! Map) continue;
      final code = '${l['Locationcode'] ?? ''}'.trim().toUpperCase();
      final color = '${l['Color'] ?? ''}'.trim();
      if (code.isNotEmpty && color.isNotEmpty) colors[code] = color;
    }

    return DailyCollectionResult(
      rows: (body['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      totals: (body['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      updatedAt: '${body['updatedAt'] ?? ''}',
      locationColors: colors,
    );
  }
}

/// Looks up a row's branch colour by its `Location` code, tolerant of a
/// trailing qualifier (`LJP-GF` -> `LJP`), same rule the backend's own
/// `canLocationCode()` uses.
Color? dailyCollectionRowColor(
    Map<String, String> colors, Object? locationCode) {
  final code = '${locationCode ?? ''}'.trim().toUpperCase();
  if (code.isEmpty) return null;
  final hex = colors[code] ?? colors[code.split('-').first];
  return hex == null ? null : parseHexColor(hex);
}
