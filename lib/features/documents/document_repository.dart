// lib/features/documents/document_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';

/// A row from GET /documentdownload/data (raw DocumentPrint columns).
class DocRow {
  DocRow(this.raw);
  final Map<String, dynamic> raw;

  int get id => asInt(raw['DocID'] ?? raw['id']) ?? 0;
  String get docNo => (raw['DocNo'] ?? raw['docNo'] ?? '').toString().trim();
  String get docType => (raw['DocType'] ?? raw['docType'] ?? '').toString().trim();
  String get vendor => (raw['VendorName'] ?? raw['vendorName'] ?? '').toString();
  String get itemCode => (raw['ItemCode'] ?? raw['itemCode'] ?? '').toString();
  String get date => (raw['DocDate'] ?? raw['docDate'] ?? '').toString();
  String get location => (raw['LOCATION'] ?? raw['location'] ?? '').toString();
  num? get amount => asNum(raw['Amount']);

  factory DocRow.fromJson(Map<String, dynamic> j) => DocRow(j);
}

final documentRepositoryProvider = Provider((ref) => DocumentRepository(ref));

class DocumentRepository {
  DocumentRepository(this.ref);
  final Ref ref;

  Future<PagedResponse<DocRow>> list(
    int page,
    String search, {
    String? docType,
  }) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/documentdownload/data',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
          extra: {'docType': docType},
        );
    return PagedResponse.parse(body, DocRow.fromJson,
        page: page, perPage: AppConfig.pageSize);
  }

  /// [{ DocTypeID, DocTypeName }]
  Future<List<Map<String, dynamic>>> types() async {
    final data =
        await ref.read(apiClientProvider).getData('/documentdownload/doc-types');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> show(int id) async {
    final data = await ref
        .read(apiClientProvider)
        .getData('/documentdownload/detail/$id');
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<int>> downloadBytes(int id) {
    return ref
        .read(apiClientProvider)
        .getBytes('/documentdownload/download/$id');
  }
}

final documentTypesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(documentRepositoryProvider).types(),
);
