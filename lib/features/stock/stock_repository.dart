// lib/features/stock/stock_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

class StockItem {
  StockItem(this.raw);
  final Map<String, dynamic> raw;

  int get id => asInt(raw['ItemDetID']) ?? 0;
  String get code => (raw['ItemCode'] ?? '').toString();
  String get name => (raw['ItemName'] ?? raw['ProductName'] ?? '').toString();
  String get company => (raw['CompanyName'] ?? '').toString();
  String get section => (raw['SectionName'] ?? '').toString();
  String get color => (raw['Color'] ?? '').toString();
  String get supplier => (raw['SupplierName'] ?? '').toString();
  num get qty => asNum(raw['StkQty']) ?? 0;
  num get whQty => asNum(raw['WHQTY']) ?? 0;
  num get rate => asNum(raw['Rate']) ?? 0;

  // Additional columns the /stock/datatable response already includes —
  // exposed for the full web-parity table view (stock_list_screen.dart).
  String get product => (raw['ProductName'] ?? '').toString();
  String get design => (raw['DesignName'] ?? '').toString();
  String get size => (raw['Size'] ?? '').toString();
  String get unit => (raw['Unit'] ?? '').toString();
  num get mrp => asNum(raw['MRP']) ?? 0;
  num get cost => asNum(raw['ACost']) ?? 0;
  String get hsnCode => (raw['HSNCODE'] ?? '').toString();
  String get gst => (raw['GST'] ?? '').toString();
  String get quality => (raw['QualityName'] ?? '').toString();
  String get serialNo => (raw['SerialNo'] ?? '').toString();
  String get supplierMobile => (raw['SupplierMobileNo'] ?? '').toString();
  String get contactPerson => (raw['ContactPerson'] ?? '').toString();

  /// Per-location stock quantity — the `/stock/datatable` response adds one
  /// dynamic column per warehouse location, keyed by its location code
  /// (e.g. `LJP`, `AVWH`), directly alongside the fixed fields above.
  num locationQty(String code) => asNum(raw[code]) ?? 0;

  /// Whether the backend found a photo for this item — signalled via
  /// `ImageName`/`ImageUrl` (or the raw `ItemImage`/`IImage` fallback) on
  /// `/stock/datatable`.
  bool get hasImage {
    final n = '${raw['ImageName'] ?? raw['ImageUrl'] ?? raw['ItemImage'] ?? raw['IImage'] ?? ''}'
        .trim();
    return n.isNotEmpty;
  }

  /// Built from the item code rather than trusted verbatim from the API —
  /// same fix as the Item Stock Report screen: the API's own `ImageUrl`
  /// points at the *web* session-authenticated proxy route
  /// (`url('/stock/image-proxy/...')` has no `/api` prefix), not this
  /// app's Bearer-token `/api/stock/image-proxy/...` route, so it 401s
  /// when this app tries to load it directly.
  String? get image =>
      hasImage && code.isNotEmpty ? '${AppConfig.baseUrl}/stock/image-proxy/$code.jpg' : null;

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(j);
}

final stockRepositoryProvider = Provider((ref) => StockRepository(ref));

class StockRepository {
  StockRepository(this.ref);
  final Ref ref;

  /// GET /stock/datatable — needs at least one filter OR a search term,
  /// otherwise the API answers 422.
  Future<PagedResponse<StockItem>> list(
    int page,
    String search, {
    Map<String, dynamic> filters = const {},
  }) async {
    final body = await ref
        .read(apiClientProvider)
        .listRaw(
          '/stock/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
          dataTableSearch: false, // Stock reads a scalar `search`
          extra: filters,
        );
    return PagedResponse.parse(
      body,
      StockItem.fromJson,
      page: page,
      perPage: AppConfig.pageSize,
    );
  }

  Future<Map<String, dynamic>> show(int id) async {
    final data = await ref.read(apiClientProvider).getData('/stock/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// [{ Locationcode, LocationName }]
  Future<List<Map<String, dynamic>>> locations() async {
    final data = await ref.read(apiClientProvider).getData('/locations/all');
    final access = await ref.read(userAccessProvider.future);
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        // Only the locations this user was granted on the User form.
        .where((e) => access.canLocation(asInt(e['LocationID']) ?? -1))
        .toList();
  }

  Future<List<String>> sectionsByLocation(String location) async {
    final data = await ref
        .read(apiClientProvider)
        .getData('/stock/sections-by-location', query: {'location': location});
    return ((data as List?) ?? const []).map((e) => '$e').toList();
  }

  Future<List<String>> companiesBySection(
    String section, {
    String? location,
  }) async {
    final data = await ref
        .read(apiClientProvider)
        .getData(
          '/stock/companies-by-section',
          query: {'section': section, 'location': location},
        );
    return ((data as List?) ?? const []).map((e) => '$e').toList();
  }

  /// GET /stock/all-options -> every distinct filter value in one call.
  /// { sections, companies, products, designs, colors, sizes, units,
  ///   quantities, suppliers, serial_nos, qualities }
  Future<Map<String, List<String>>> allOptions() async {
    final data = await ref
        .read(apiClientProvider)
        .getData('/stock/all-options');
    final m = (data as Map).cast<String, dynamic>();
    // De-duplicated: a numeric column (e.g. StkQty) can yield distinct DB
    // values that collapse to the same string once stringified (10 vs
    // 10.0), and a DropdownButtonFormField crashes if two items share a
    // value.
    List<String> pick(String k) => ((m[k] as List?) ?? const [])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return {
      for (final k in const [
        'sections',
        'companies',
        'products',
        'designs',
        'colors',
        'sizes',
        'units',
        'quantities',
        'suppliers',
        'serial_nos',
        'qualities',
      ])
        k: pick(k),
    };
  }
}

final stockAllOptionsProvider = FutureProvider<Map<String, List<String>>>(
  (ref) => ref.watch(stockRepositoryProvider).allOptions(),
);

final stockLocationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(stockRepositoryProvider).locations(),
);
