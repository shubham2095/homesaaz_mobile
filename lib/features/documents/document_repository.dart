// lib/features/documents/document_repository.dart
//
// Document Download "v2" API: documents are read LIVE from the selected
// location's own sales database (no DocumentPrint table any more), so every
// call carries locationID + docType, and a document is identified by its
// `key` (DocKey) instead of a numeric id.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

class DocLocation {
  const DocLocation(this.id, this.name, this.colorHex);
  final int id;
  final String name;
  final String? colorHex;
}

/// GET /documentdownload/locations -> locations that have a sales database
/// set (and this user may see).
final documentLocationsProvider =
    FutureProvider<List<DocLocation>>((ref) async {
  final access = await ref.watch(userAccessProvider.future);
  final data =
      await ref.read(apiClientProvider).getData('/documentdownload/locations');
  final list = <DocLocation>[];
  for (final row in (data as List? ?? const [])) {
    if (row is! Map) continue;
    final id = asInt(row['id']);
    if (id == null || !access.canLocation(id)) continue;
    list.add(DocLocation(
      id,
      '${row['name'] ?? 'Location $id'}',
      row['color']?.toString(),
    ));
  }
  return list;
});

class DocTypeOption {
  const DocTypeOption(this.key, this.label);
  final String key;
  final String label;
}

/// GET /documentdownload/doc-types -> `{ key: label }` (JSON object).
final documentTypesProvider =
    FutureProvider<List<DocTypeOption>>((ref) async {
  final data =
      await ref.read(apiClientProvider).getData('/documentdownload/doc-types');
  if (data is! Map) return const [];
  return [
    for (final e in data.entries) DocTypeOption('${e.key}', '${e.value}'),
  ];
});

final documentRepositoryProvider = Provider((ref) => DocumentRepository(ref));

class DocumentRepository {
  DocumentRepository(this.ref);
  final Ref ref;

  /// GET /documentdownload/data — one page. The columns come from the doc
  /// type's own query (always starting DocKey, DocDate, PartyName, Amount),
  /// so they're returned in `extra['columns']` for the table header.
  Future<PagedResponse<Map<String, dynamic>>> list(
    int page,
    String search, {
    required int locationId,
    required String docType,
    required String fromDate,
    required String toDate,
  }) async {
    const size = AppConfig.pageSize;
    final body = await ref.read(apiClientProvider).getRaw(
      '/documentdownload/data',
      query: {
        'locationID': locationId,
        'docType': docType,
        'fromDate': fromDate,
        'toDate': toDate,
        'search': search.isEmpty ? null : search,
        'start': (page - 1) * size,
        'length': size,
      },
      // Runs live SQL on the location's own database.
      receiveTimeout: const Duration(seconds: 90),
    );
    final rows = (body['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final total = asInt(body['recordsFiltered']) ?? rows.length;
    return PagedResponse<Map<String, dynamic>>(
      items: rows,
      meta: PageMeta(
        page: page,
        perPage: size,
        total: total,
        lastPage: total > 0 ? ((total + size - 1) ~/ size) : page,
      ),
      extra: {
        'columns': rows.isEmpty ? const <String>[] : rows.first.keys.toList(),
      },
    );
  }

  /// GET /documentdownload/detail — one row per line item (header columns
  /// repeat on every row).
  Future<List<Map<String, dynamic>>> detail({
    required int locationId,
    required String docType,
    required String key,
  }) async {
    final data = await ref.read(apiClientProvider).getData(
      '/documentdownload/detail',
      query: {'locationID': locationId, 'docType': docType, 'key': key},
    );
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// GET /documentdownload/pdf — the letterhead PDF's raw bytes.
  Future<List<int>> pdfBytes({
    required int locationId,
    required String docType,
    required String key,
  }) {
    return ref.read(apiClientProvider).getBytes(
      '/documentdownload/pdf',
      query: {'locationID': locationId, 'docType': docType, 'key': key},
    );
  }
}
