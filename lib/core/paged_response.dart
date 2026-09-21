// lib/core/paged_response.dart
//
// The Laravel API speaks two dialects:
//   * DataTables  -> { data, recordsTotal, recordsFiltered, draw }
//   * hand-rolled -> { data, total, current_page, last_page, per_page }  (Stock)
// [PageMeta.fromBody] understands both.

class PageMeta {
  const PageMeta({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMore => page < lastPage;

  /// Derive the meta from whatever pagination keys the endpoint returned,
  /// falling back to the page/size we asked for.
  factory PageMeta.fromBody(
    Map<String, dynamic> body, {
    required int requestedPage,
    required int perPage,
  }) {
    // SQL Server returns counts as strings — never cast, always parse.
    int? asInt(Object? v) =>
        v is num ? v.toInt() : num.tryParse('${v ?? ''}'.trim())?.toInt();

    final total = asInt(body['recordsFiltered']) ??
        asInt(body['total']) ??
        asInt(body['recordsTotal']) ??
        0;
    final page = asInt(body['current_page']) ?? requestedPage;
    final size = asInt(body['per_page']) ?? (perPage <= 0 ? 1 : perPage);
    final lastPage = asInt(body['last_page']) ??
        (total > 0 ? ((total + size - 1) ~/ size) : page);

    return PageMeta(
      page: page,
      perPage: size,
      total: total,
      lastPage: lastPage < page ? page : lastPage,
    );
  }
}

/// A typed page of results plus its meta and any extra top-level keys
/// (`stats`, `locationCodes`, `summary`, …).
class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.meta,
    this.extra = const {},
  });

  final List<T> items;
  final PageMeta meta;
  final Map<String, dynamic> extra;

  static const _metaKeys = {
    'data', 'success', 'message', 'draw',
    'recordsTotal', 'recordsFiltered', 'total', 'filtered',
    'current_page', 'last_page', 'per_page',
  };

  /// Parse a list body. [dataKey] lets callers pull the rows from a key
  /// other than `data` (GRN `show` returns them under `items`).
  static PagedResponse<T> parse<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson, {
    required int page,
    required int perPage,
    String dataKey = 'data',
  }) {
    final rawList = (body[dataKey] as List?) ?? const [];
    final items = rawList
        .whereType<Map>()
        .map((e) => fromJson(e.cast<String, dynamic>()))
        .toList();

    final extra = <String, dynamic>{
      for (final e in body.entries)
        if (!_metaKeys.contains(e.key) && e.key != dataKey) e.key: e.value,
    };

    return PagedResponse<T>(
      items: items,
      meta: PageMeta.fromBody(body, requestedPage: page, perPage: perPage),
      extra: extra,
    );
  }
}
