// lib/features/stock/stock_list_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/states.dart';
import 'stock_repository.dart';

/// Fixed columns — mirrors web `stock/list.blade.php`'s `<thead>` (minus the
/// bulk-select checkbox). Image is the pinned leading cell. The per-location
/// quantity columns + trailing Action column are dynamic (depend on which
/// warehouse locations the backend returns) — see `_columns` getter below.
const _fixedColumns = <HsTableColumn>[
  HsTableColumn('Item Code', width: 100),
  HsTableColumn('Item Name', width: 150),
  HsTableColumn('Product', width: 110),
  HsTableColumn('Design', width: 110),
  HsTableColumn('Color', width: 90),
  HsTableColumn('Size', width: 70),
  HsTableColumn('Quantity', width: 80, alignEnd: true),
  HsTableColumn('WHQTY', width: 80, alignEnd: true),
  HsTableColumn('Unit', width: 70),
  HsTableColumn('MRP', width: 90, alignEnd: true),
  HsTableColumn('Rate', width: 90, alignEnd: true),
  HsTableColumn('Cost', width: 90, alignEnd: true),
  HsTableColumn('HSN Code', width: 90),
  HsTableColumn('GST', width: 60),
  HsTableColumn('Section', width: 110),
  HsTableColumn('Company', width: 120),
  HsTableColumn('Quality', width: 100),
  HsTableColumn('Serial No', width: 110),
  HsTableColumn('Supplier', width: 140),
  HsTableColumn('Supplier Mobile', width: 120),
  HsTableColumn('Contact Person', width: 130),
];

bool _sameCodes(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Color? _parseHex(Object? v) {
  final s = '${v ?? ''}'.replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}

/// Independent dropdowns, populated from GET /stock/all-options.
/// (Location -> Section -> Company are handled separately as a cascade.)
const _fields = <({String param, String label, String key})>[
  (param: 'supplier', label: 'Supplier', key: 'suppliers'),
  (param: 'serial_no', label: 'Serial No', key: 'serial_nos'),
  (param: 'color', label: 'Colour', key: 'colors'),
  (param: 'size', label: 'Size', key: 'sizes'),
  (param: 'quantity', label: 'Quantity', key: 'quantities'),
  (param: 'unit', label: 'Unit', key: 'units'),
  (param: 'quality', label: 'Quality', key: 'qualities'),
  (param: 'product', label: 'Product', key: 'products'),
];

/// Distinguishes "explicitly picked -- All --" from "dismissed the sheet
/// without choosing" — both would otherwise pop `null`.
const Object _clearedSentinel = Object();

/// One row in a `_PickerSheet` — `value` is what gets applied as the
/// filter, `label` is what's shown (they differ for Location, where the
/// filter value is the bare code but the row also shows the full name).
class _PickerOption {
  const _PickerOption(this.value, {String? label, this.color})
    : label = label ?? value;
  final String value;
  final String label;
  final Color? color;
}

class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});
  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen>
    with PagedFooterMixin<StockListScreen> {
  final _searchCtrl = TextEditingController();
  final _sel = <String, String?>{}; // independent dropdown values
  final _hScroll = LinkedScrollControllerGroup();

  // Location -> Section -> Company cascade
  String? _location;
  String? _section;
  String? _company;
  List<Map<String, dynamic>> _locations = [];
  List<String> _sections = [];
  List<String> _companies = [];
  bool _loadingLoc = true;
  bool _loadingSec = false;
  bool _loadingCom = false;

  bool _expanded = true;
  Map<String, String> _applied = {};
  Map<String, dynamic>? _stats;
  List<String> _locationCodes = [];
  String? _token;

  Map<String, String> get _authHeader =>
      (_token == null || _token!.isEmpty) ? {} : {'Authorization': 'Bearer $_token'};

  List<HsTableColumn> get _columns => [
    ..._fixedColumns,
    for (final c in _locationCodes) HsTableColumn(c, width: 64, alignEnd: true),
    const HsTableColumn('Action', width: 64),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
    ref.read(authStoreProvider).readToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  StockRepository get _repo => ref.read(stockRepositoryProvider);

  Future<void> _loadLocations() async {
    setState(() => _loadingLoc = true);
    try {
      final l = await _repo.locations();
      if (mounted) setState(() => _locations = l);
    } finally {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  Future<void> _onLocation(String? v) async {
    setState(() {
      _location = v;
      _section = null;
      _company = null;
      _sections = [];
      _companies = [];
    });
    if (v == null) return;
    setState(() => _loadingSec = true);
    try {
      final s = await _repo.sectionsByLocation(v);
      if (mounted) setState(() => _sections = s);
    } finally {
      if (mounted) setState(() => _loadingSec = false);
    }
  }

  Future<void> _onSection(String? v) async {
    setState(() {
      _section = v;
      _company = null;
      _companies = [];
    });
    if (v == null) return;
    setState(() => _loadingCom = true);
    try {
      final c = await _repo.companiesBySection(v, location: _location);
      if (mounted) setState(() => _companies = c);
    } finally {
      if (mounted) setState(() => _loadingCom = false);
    }
  }

  void _apply() {
    final f = <String, String>{
      'location': ?_location,
      'section': ?_section,
      'company': ?_company,
    };
    for (final fld in _fields) {
      final v = _sel[fld.param];
      if (v != null && v.isNotEmpty) f[fld.param] = v;
    }
    final s = _searchCtrl.text.trim();
    if (s.isNotEmpty) f['search'] = s;
    setState(() {
      _applied = f;
      _stats = null;
      _expanded = false;
      resetFooter();
    });
    FocusScope.of(context).unfocus();
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() {
      _location = null;
      _section = null;
      _company = null;
      _sections = [];
      _companies = [];
      _sel.clear();
      _applied = {};
      _stats = null;
      _expanded = true;
      resetFooter();
    });
  }

  bool get _canQuery => _applied.isNotEmpty;
  String get _signature =>
      _applied.entries.map((e) => '${e.key}=${e.value}').join('&');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'All Stock Details'),
      body: Column(
        children: [
          if (_expanded)
            Expanded(child: _panel())
          else ...[
            _panel(),
            Expanded(
              child: !_canQuery
                  ? const EmptyView(
                      message:
                          'Please select at least one filter (Location, Section, Company, or others) and Search.',
                    )
                  : Column(
                      children: [
                        HsTableHeader(
                          columns: _columns,
                          group: _hScroll,
                          leadingWidth: 56,
                        ),
                        Expanded(
                          child: PagedListView<StockItem>(
                            key: ValueKey(_signature),
                            searchable: false,
                            padding: EdgeInsets.zero,
                            separator: const SizedBox.shrink(),
                            emptyMessage: 'No stock matches this filter.',
                            fetchPage: (page, _) => _repo.list(
                              page,
                              _applied['search'] ?? '',
                              filters: Map.of(_applied)..remove('search'),
                            ),
                            onPageLoaded: (meta, extra) {
                              final s = extra['stats'];
                              final codesRaw = extra['locationCodes'];
                              final codes = codesRaw is List
                                  ? codesRaw.map((e) => '$e').toList()
                                  : null;
                              final statsMap =
                                  s is Map ? s.cast<String, dynamic>() : null;
                              final loaded = meta.page * meta.perPage > meta.total
                                  ? meta.total
                                  : meta.page * meta.perPage;
                              if (statsMap != null ||
                                  (codes != null &&
                                      !_sameCodes(codes, _locationCodes)) ||
                                  meta.total != footerTotal ||
                                  loaded != footerLoaded) {
                                setState(() {
                                  if (statsMap != null) _stats = statsMap;
                                  if (codes != null) _locationCodes = codes;
                                  footerTotal = meta.total;
                                  footerLoaded = loaded;
                                });
                              }
                            },
                            indexedItemBuilder: (context, it, index) => HsTableRow(
                              columns: _columns,
                              group: _hScroll,
                              leadingWidth: 56,
                              backgroundColor: index.isEven
                                  ? Colors.white
                                  : _stripeColor,
                              onTap: () => context.push('/stock/${it.id}'),
                              leading: Padding(
                                padding: const EdgeInsets.all(8),
                                child: it.image == null
                                    ? const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 22,
                                        color: Hs.faint,
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedNetworkImage(
                                          imageUrl: it.image!,
                                          httpHeaders: _authHeader,
                                          width: 40,
                                          height: 40,
                                          // Caps the decoded bitmap to
                                          // thumbnail size instead of
                                          // decoding the full-resolution
                                          // photo for a 40x40 display —
                                          // matters a lot on a long
                                          // scrolling list of these.
                                          memCacheWidth: 120,
                                          memCacheHeight: 120,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                                size: 20,
                                              ),
                                        ),
                                      ),
                              ),
                              cells: [
                                Text(orDash(it.code)),
                                Text(
                                  orDash(it.name),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Hs.ink,
                                  ),
                                ),
                                Text(orDash(it.product)),
                                Text(orDash(it.design)),
                                Text(orDash(it.color)),
                                Text(orDash(it.size)),
                                Text('${it.qty}'),
                                Text(it.whQty.toStringAsFixed(2)),
                                Text(orDash(it.unit)),
                                Text(money(it.mrp)),
                                Text(money(it.rate)),
                                Text(money(it.cost)),
                                Text(orDash(it.hsnCode)),
                                Text(orDash(it.gst)),
                                Text(orDash(it.section)),
                                Text(orDash(it.company)),
                                Text(orDash(it.quality)),
                                Text(orDash(it.serialNo)),
                                Text(orDash(it.supplier)),
                                Text(orDash(it.supplierMobile)),
                                Text(orDash(it.contactPerson)),
                                for (final c in _locationCodes)
                                  Text(it.locationQty(c).toStringAsFixed(2)),
                                IconButton(
                                  tooltip: 'View',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                    color: Hs.blue,
                                  ),
                                  onPressed: () =>
                                      context.push('/stock/${it.id}'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_stats != null) ...[
                          _StatsBar(stats: _stats!),
                          _TotalBar(stats: _stats!),
                        ],
                        if (footerTotal > 0) footerBar(),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- filter panel ----------------------------------------------------

  Widget _panel() {
    final opts = ref.watch(stockAllOptionsProvider);
    final activeCount = _applied.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 18, color: Hs.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Hs.ink,
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    HsPill('$activeCount', color: Hs.blue),
                  ],
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Hs.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    _locationField(),
                    const SizedBox(height: 10),
                    // Section/Company stay open and pickable even before a
                    // parent is chosen — fall back to the full unfiltered
                    // list (GET /stock/all-options) until Location/Section
                    // narrows it. Picking a parent still narrows the child
                    // (the "connected" cascade), it just never leaves the
                    // child blank/unusable while unset.
                    _cascadeField(
                      label: 'Section',
                      value: _section,
                      items: _sections.isNotEmpty
                          ? _sections
                          : (opts.value?['sections'] ?? const []),
                      loading: _loadingSec,
                      onChanged: _onSection,
                    ),
                    const SizedBox(height: 10),
                    _cascadeField(
                      label: 'Company',
                      value: _company,
                      items: _companies.isNotEmpty
                          ? _companies
                          : (opts.value?['companies'] ?? const []),
                      loading: _loadingCom,
                      onChanged: (v) => setState(() => _company = v),
                    ),
                    const SizedBox(height: 10),
                    for (final f in _fields) ...[
                      opts.when(
                        loading: () => _skeletonField(f.label),
                        error: (_, __) =>
                            _lazyField(f.param, f.label, const []),
                        data: (m) =>
                            _lazyField(f.param, f.label, m[f.key] ?? const []),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _apply(),
                      decoration: const InputDecoration(
                        labelText: 'Item Code / Item Name',
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _apply,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Search'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clear,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Clear'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _skeletonField(String label) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    child: const Text('Loading…', style: TextStyle(color: Hs.faint)),
  );

  /// Tap target only — the picker's item list (which can run into the
  /// thousands for fields like Product) is built lazily inside the bottom
  /// sheet, only once the admin actually opens this field.
  Widget _lazyField(String param, String label, List<String> items) {
    final selected = items.contains(_sel[param]) ? _sel[param] : null;
    return _pickerTapField(
      label: label,
      selectedLabel: selected,
      onTap: () => _openPicker(
        label: label,
        options: [for (final s in items) _PickerOption(s)],
        selected: _sel[param],
        onChanged: (v) => setState(() => _sel[param] = v),
      ),
    );
  }

  /// Opens the shared search-and-select bottom sheet for any filter field
  /// (web `Select2` parity — every filter gets a search box + list, not
  /// just the "extra" fields).
  Future<void> _openPicker({
    required String label,
    required List<_PickerOption> options,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PickerSheet(label: label, options: options, selected: selected),
    );
    if (result == null) return; // dismissed without choosing
    onChanged(result == _clearedSentinel ? null : result as String);
  }

  Widget _cascadeField({
    required String label,
    required String? value,
    required List<String> items,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = items.contains(value) ? value : null;
    return _pickerTapField(
      label: label,
      selectedLabel: selected,
      loading: loading,
      onTap: () => _openPicker(
        label: label,
        options: [for (final s in items) _PickerOption(s)],
        selected: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Shared trigger widget for every filter field — tapping opens the
  /// search-and-select bottom sheet (`_PickerSheet`), matching web's
  /// `Select2` control exactly: closed box + search box & list on open.
  Widget _pickerTapField({
    required String label,
    required String? selectedLabel,
    required VoidCallback onTap,
    bool loading = false,
    Color? swatch,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      onTap: loading ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            if (swatch != null) ...[
              _swatch(swatch),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                selectedLabel ?? '-- All ${label}s --',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selectedLabel == null ? Hs.faint : Hs.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed zebra-stripe colour for every other Stock row, independent of
  /// any filter — alternates with plain white.
  static const _stripeColor = Color.fromRGBO(151, 217, 209, 1.0);

  List<_PickerOption> get _locationOptions => [
    for (final l in _locations)
      _PickerOption(
        '${l['Locationcode']}',
        label: '${l['LocationName']} (${l['Locationcode']})',
        color: _parseHex(l['Color']),
      ),
  ];

  Widget _locationField() {
    if (_loadingLoc) return _skeletonField('Location');
    final selected = _locationOptions.where((o) => o.value == _location);
    return _pickerTapField(
      label: 'Location',
      selectedLabel: selected.isEmpty ? null : selected.first.label,
      swatch: selected.isEmpty ? null : selected.first.color,
      onTap: () => _openPicker(
        label: 'Location',
        options: _locationOptions,
        selected: _location,
        onChanged: _onLocation,
      ),
    );
  }

  Widget _swatch(Color? c) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: c ?? Hs.hairline,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: Hs.border),
    ),
  );

}

/// Search + lazily-built list (`ListView.builder`) so opening a field with
/// thousands of distinct values (e.g. Product) only ever inflates the rows
/// actually on screen, instead of building every DropdownMenuItem up front.
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.label,
    required this.options,
    required this.selected,
  });

  final String label;
  final List<_PickerOption> options;
  final String? selected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<_PickerOption> _filtered = widget.options;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    final q = v.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.options
          : widget.options
                .where((o) => o.label.toLowerCase().contains(q))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Hs.ink,
                ),
              ),
            ),
            // Always shown — web's Select2 always opens with a search box
            // above the option list, regardless of how many options there
            // are.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search & Select...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              // The "-- All X --" clear option must always be reachable,
              // even when there are zero (or zero matching) specific
              // values — a search-runtime check caught this hiding behind
              // a blanket "No matches." otherwise.
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _filtered.isEmpty ? 2 : _filtered.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _row(
                      label: '-- All ${widget.label}s --',
                      faint: true,
                      selected: widget.selected == null,
                      onTap: () => Navigator.pop(context, _clearedSentinel),
                    );
                  }
                  if (_filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No matches.',
                          style: TextStyle(color: Hs.muted),
                        ),
                      ),
                    );
                  }
                  final o = _filtered[i - 1];
                  return _row(
                    label: o.label,
                    color: o.color,
                    selected: o.value == widget.selected,
                    onTap: () => Navigator.pop(context, o.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool faint = false,
    Color? color,
  }) {
    final on = color == null
        ? null
        : (color.computeLuminance() < 0.5 ? Colors.white : Colors.black);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected || color != null
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: faint
                      ? Hs.faint
                      : (on ?? (selected ? Hs.blue : Hs.inkSoft)),
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: on ?? Hs.blue),
          ],
        ),
      ),
    );
  }
}

/// Web `stock/list.blade.php`'s card-footer stat cards — Total Quantity
/// (text-primary), Total Stock Value (text-success), Allocation Stock
/// (text-info). Sits below the table now, matching the web layout.
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: HsStatRow([
        HsStat(
          'Total Quantity',
          (asNum(stats['total_quantity']) ?? 0).toStringAsFixed(2),
          color: _statBlue,
        ),
        HsStat('Total Stock Value', money(stats['total_value']), color: Hs.green),
        HsStat(
          'Allocation Stock',
          (asNum(stats['allocation_stock']) ?? 0).toStringAsFixed(2),
          color: _statInfo,
        ),
      ]),
    );
  }
}

/// Web's plain "Total: Quantity: … | WHQTY: … | MRP: … | Rate: … | Cost: …"
/// line directly below the stat cards (`card-footer bg-light`).
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    String n(String key) => (asNum(stats[key]) ?? 0).toStringAsFixed(2);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12.5, color: Hs.inkSoft),
          children: [
            const TextSpan(
              text: 'Total: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: Hs.ink),
            ),
            TextSpan(text: 'Quantity: ${n('total_quantity')} | '),
            TextSpan(text: 'WHQTY: ${n('total_whqty')} | '),
            TextSpan(text: 'MRP: ₹${n('total_mrp')} | '),
            TextSpan(text: 'Rate: ₹${n('total_rate')} | '),
            TextSpan(text: 'Cost: ₹${n('total_cost')}'),
          ],
        ),
      ),
    );
  }
}

const _statBlue = Color(0xFF0D6EFD);
const _statInfo = Color(0xFF0DCAF0);
