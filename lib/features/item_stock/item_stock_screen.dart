// lib/features/item_stock/item_stock_screen.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/states.dart';

/// Web `bg-info` (Bootstrap) — not in [Hs] because it's used only for this
/// screen's "Branch-wise Stock Distribution" card header.
const _infoCyan = Color(0xFF0DCAF0);

Color? _parseHex(Object? v) {
  final s = '${v ?? ''}'.replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}

class ItemStockScreen extends ConsumerStatefulWidget {
  const ItemStockScreen({super.key});
  @override
  ConsumerState<ItemStockScreen> createState() => _ItemStockScreenState();
}

class _ItemStockScreenState extends ConsumerState<ItemStockScreen> {
  final _ctrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = false;
  bool _downloading = false;
  bool _uploading = false;
  bool _savingMrp = false;
  bool _savingDiscount = false;
  String? _error;
  String? _code;
  String? _token;
  String? _mrpOriginal;
  String? _discountOriginal;
  int _imgBust = 0;
  XFile? _pending; // picked but not yet uploaded
  Map<String, dynamic>? _result;
  Map<String, Color> _locationColors = {};

  /// Field access granted on the User form — `permissions.fields` of the
  /// search response (supplier_name, markup, mrp, image_upload …). null =
  /// backend didn't say, so nothing is hidden.
  Map<String, bool>? _fieldAccess;

  /// Fields that aren't one of the configurable ones are always visible.
  bool _can(String key) => _fieldAccess == null || (_fieldAccess![key] ?? false);

  @override
  void initState() {
    super.initState();
    ref.read(authStoreProvider).readToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
    _loadLocationColors();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _mrpCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  /// Per-location swatch colours for the "Branch-wise Stock Distribution"
  /// table header — same source the web page's own table uses.
  Future<void> _loadLocationColors() async {
    try {
      final data =
          await ref.read(apiClientProvider).getData('/itemstock/location-mapping');
      final map = <String, Color>{};
      for (final e in (data as List? ?? const [])) {
        if (e is! Map) continue;
        final code = '${e['locationCode'] ?? ''}'.trim();
        final c = _parseHex(e['color']);
        if (code.isNotEmpty && c != null) map[code] = c;
      }
      if (mounted) setState(() => _locationColors = map);
    } catch (_) {
      // Non-critical — the table still works with plain (uncoloured) cells.
    }
  }

  /// Turn whatever the API sends back into a URL the app can actually load.
  ///
  /// POST /itemstock/search doesn't reliably populate an `ImageUrl` (or even
  /// a usable `Image`) field — the web app's own JS has the same gap, since
  /// it also gates the preview on `stock.ImageUrl`. But the upload flow
  /// (`uploadImage()`) always saves a searched item's photo under
  /// `public/items/<itemCode>/`, and `imageProxy($filename)` resolves purely
  /// from that folder using the `<itemCode>` stem of whatever filename it's
  /// given — so building the URL directly from the searched item code is
  /// reliable regardless of what (if anything) the response fields contain.
  /// Base image URL (no cache-buster).
  String? get _baseImageUrl {
    final code = _code?.trim();
    if (code != null && code.isNotEmpty) {
      return '${AppConfig.baseUrl}/stock/image-proxy/$code.jpg';
    }
    final raw = '${_result?['ImageUrl'] ?? _result?['Image'] ?? ''}'.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) {
      final i = raw.indexOf('image-proxy/');
      if (i != -1) {
        final file = raw.substring(i + 'image-proxy/'.length).split('?').first;
        return '${AppConfig.baseUrl}/stock/image-proxy/$file';
      }
      return raw.split('?').first;
    }
    final file = raw.split('/').last;
    return '${AppConfig.baseUrl}/stock/image-proxy/$file';
  }

  String? get _imageUrl {
    final url = _baseImageUrl;
    if (url == null) return null;
    return _imgBust == 0
        ? url
        : '$url${url.contains('?') ? '&' : '?'}v=$_imgBust';
  }

  /// Wipe every cached copy of this item's image (base + any busted URLs).
  Future<void> _evictImage() async {
    final base = _baseImageUrl;
    if (base == null) return;
    try {
      await CachedNetworkImage.evictFromCache(base);
      if (_imgBust != 0) {
        await CachedNetworkImage.evictFromCache(
          '$base${base.contains('?') ? '&' : '?'}v=$_imgBust',
        );
      }
    } catch (_) {}
  }

  Map<String, String> get _authHeader =>
      (_token == null || _token!.isEmpty) ? {} : {'Authorization': 'Bearer $_token'};

  Future<void> _search({bool refresh = false}) async {
    // On pull-to-refresh use the last searched code, not the (maybe cleared) box.
    final code = refresh ? (_code ?? _ctrl.text.trim()) : _ctrl.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (refresh) await _evictImage();
    setState(() {
      if (!refresh) {
        _loading = true;
        _result = null;
        _pending = null;
      }
      _error = null;
      _imgBust = refresh ? DateTime.now().millisecondsSinceEpoch : 0;
    });
    try {
      final body = await ref
          .read(apiClientProvider)
          .postRaw('/itemstock/search', body: {'itemCode': code});
      if (!mounted) return;
      final data = (body['data'] as Map).cast<String, dynamic>();
      final mrp = data.containsKey('MRP')
          ? (asNum(data['MRP'])?.toStringAsFixed(2) ?? '')
          : null;
      final discount = data.containsKey('Discount')
          ? (asNum(data['Discount'])?.toStringAsFixed(2) ?? '')
          : null;
      final perms = (body['permissions'] as Map?)?['fields'];
      setState(() {
        _fieldAccess = perms is Map
            ? {for (final e in perms.entries) '${e.key}': e.value == true}
            : null;
        _result = data;
        _code = code;
        _mrpCtrl.text = mrp ?? '';
        _mrpOriginal = mrp;
        _discountCtrl.text = discount ?? '';
        _discountOriginal = discount;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _ctrl.clear();
    _mrpCtrl.clear();
    _discountCtrl.clear();
    setState(() {
      _result = null;
      _error = null;
      _code = null;
      _pending = null;
      _mrpOriginal = null;
      _discountOriginal = null;
    });
  }

  Future<void> _downloadPdf() async {
    final code = _code;
    if (code == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(apiClientProvider).getBytes(
        '/itemstock/download-pdf',
        query: {'itemCode': code},
      );
      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().split('T').first;
      final safe = code.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/ItemStockReport_${safe}_$date.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done && mounted) {
        _snack('Could not open PDF: ${res.message}');
      }
    } catch (e) {
      if (mounted) _snack('PDF download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_uploading) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked != null && mounted) setState(() => _pending = picked);
    } catch (e) {
      if (mounted) _snack('Could not open ${source.name}: $e');
    }
  }

  Future<void> _saveImage() async {
    final code = _code;
    final file = _pending;
    if (code == null || file == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      await ref.read(apiClientProvider).uploadFile(
        '/itemstock/upload-image',
        fileField: 'image',
        filePath: file.path,
        fields: {'itemCode': code},
      );
      if (!mounted) return;
      // Drop every cached copy so the new image loads fresh.
      await _evictImage();
      imageCache.clear();
      imageCache.clearLiveImages();
      setState(() {
        _pending = null;
        _imgBust = DateTime.now().millisecondsSinceEpoch;
      });
      _snack('Image saved');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveMrp() async {
    final code = _code;
    if (code == null || _savingMrp) return;
    final value = _mrpCtrl.text.trim();
    if (value == (_mrpOriginal ?? '')) {
      _snack('No changes to save');
      return;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) {
      _snack('Enter a valid MRP');
      return;
    }
    setState(() => _savingMrp = true);
    try {
      final body = await ref
          .read(apiClientProvider)
          .postRaw('/itemstock/update-mrp', body: {'itemCode': code, 'mrp': parsed});
      if (body['success'] == true) {
        _mrpOriginal = value;
        _snack('MRP updated successfully');
      } else {
        _snack('${body['message'] ?? 'Error updating MRP'}');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Error updating MRP: $e');
    } finally {
      if (mounted) setState(() => _savingMrp = false);
    }
  }

  Future<void> _saveDiscount() async {
    final code = _code;
    if (code == null || _savingDiscount) return;
    final value = _discountCtrl.text.trim();
    if (value == (_discountOriginal ?? '')) {
      _snack('No changes to save');
      return;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) {
      _snack('Enter a valid discount');
      return;
    }
    setState(() => _savingDiscount = true);
    try {
      final body = await ref.read(apiClientProvider).postRaw(
        '/itemstock/update-discount',
        body: {'itemCode': code, 'discount': parsed},
      );
      if (body['success'] == true) {
        _discountOriginal = value;
        _snack('Discount updated successfully');
      } else {
        _snack('${body['message'] ?? 'Error updating Discount'}');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Error updating Discount: $e');
    } finally {
      if (mounted) setState(() => _savingDiscount = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Item Stock Report'),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: Builder(builder: (_) {
              if (_loading) return const LoadingView();
              if (_error != null) {
                return ErrorView(message: _error!, onRetry: _search);
              }
              if (_result == null) {
                return const EmptyView(
                    message: 'Enter an item code to look it up.');
              }
              return RefreshIndicator(
                color: Hs.blue,
                onRefresh: () => _search(refresh: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _imageSection(),
                    const SizedBox(height: 14),
                    _detailsCard(),
                    const SizedBox(height: 14),
                    _pricingCard(),
                    const SizedBox(height: 14),
                    _branchCard(),
                    const SizedBox(height: 14),
                    _saveButtonsRow(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              labelText: 'Search by Item Code',
              prefixIcon: Icon(Icons.qr_code_2),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Hs.red),
                    onPressed: _downloading ? null : _downloadPdf,
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required String header, required Color headerColor, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              header,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    ),
  );

  Widget _detailsCard() {
    final r = _result!;
    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          HsRow('Item Code', null,
              valueWidget: _badge(orDash(r['ItemCode']), Hs.blue),
              bottomDivider: true),
          HsRow('Company Name', orDash(r['CompanyName']), bottomDivider: true),
          HsRow('Item Name', orDash(r['ItemName']), bottomDivider: true),
          HsRow('Design Name', orDash(r['DesignName']), bottomDivider: true),
          HsRow(
            'Available Qty',
            null,
            valueWidget:
                _badge((asNum(r['StkQty']) ?? 0).toStringAsFixed(2), Hs.green),
            bottomDivider: true,
          ),
          HsRow('Color', orDash(r['Color']), bottomDivider: true),
          HsRow('Size', orDash(r['Size']), bottomDivider: true),
          HsRow('Unit', orDash(r['Unit']), bottomDivider: true),
          HsRow('Section Name', orDash(r['SectionName']), bottomDivider: true),
          HsRow('Quality Name', orDash(r['QualityName']), bottomDivider: true),
          if (_can('supplier_name'))
            HsRow('Supplier Name', orDash(r['SupplierName']),
                bottomDivider: true),
          if (_can('supplier_mobile'))
            HsRow('Supplier Mobile', orDash(r['SupplierMobileNo']),
                bottomDivider: true),
          if (_can('contact_person'))
            HsRow('Contact Person', orDash(r['ContactPerson']),
                bottomDivider: true),
          HsRow('HSN Code', orDash(r['HSNCODE']), bottomDivider: true),
          if (_can('markup')) HsRow('MU', orDash(r['MU']), bottomDivider: true),
          HsRow('Collection Name', orDash(r['COLLECTIONNAME'])),
        ],
      ),
    );
  }

  Widget _pricingCard() {
    final r = _result!;
    final acost = asNum(r['ACost']) ?? 0;
    final gst = asNum(r['GST']);
    // Matches web's own client-side formula exactly (not the API's DPEX
    // field): Cost + GST% of Cost.
    final dpExclusive = acost + acost * ((gst ?? 0) / 100);
    return _card(
      header: 'Pricing & Discount Details',
      headerColor: Hs.green,
      child: Column(
        children: [
          if (r.containsKey('MRP') && _can('mrp'))
            HsRow(
              'MRP',
              null,
              bottomDivider: true,
              valueWidget: TextField(
                controller: _mrpCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₹ ', isDense: true),
              ),
            ),
          HsRow('Cost Price', '₹ ${acost.toStringAsFixed(2)}', bottomDivider: true),
          if (_can('markup'))
            HsRow(
              'Markup (%)',
              r['Markup'] != null
                  ? '${(asNum(r['Markup']) ?? 0).toStringAsFixed(2)}%'
                  : '-',
              bottomDivider: true,
            ),
          if (_can('markdown'))
            HsRow('Markdown (%)', orDash(r['MD']), bottomDivider: true),
          if (r.containsKey('Discount') && _can('discount'))
            HsRow(
              'Discount (%)',
              null,
              bottomDivider: true,
              valueWidget: TextField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
          if (_can('dp_exclusive'))
            HsRow('DP Exclusive', '₹ ${dpExclusive.toStringAsFixed(2)}',
                bottomDivider: true),
          HsRow('GST (%)', gst != null ? gst.toStringAsFixed(2) : '-'),
        ],
      ),
    );
  }

  Widget _branchCard() {
    final raw = _result?['branchWiseStock'];
    final entries =
        raw is Map ? raw.entries.toList() : const <MapEntry<dynamic, dynamic>>[];
    return _card(
      header: 'Branch-wise Stock Distribution',
      headerColor: _infoCyan,
      child: entries.isEmpty
          ? const Text('No stock distribution fields found',
              style: TextStyle(color: Hs.muted))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Web shows warehouse quantity (HSStock.WHQTY) as its own
                  // plain (uncoloured) leading column, ahead of the
                  // per-location colour-coded ones.
                  _branchCell('WHQTY', asNum(_result?['WHQTY']) ?? 0),
                  for (var i = 0; i < entries.length; i++) ...[
                    const SizedBox(width: 6),
                    _branchCell('${entries[i].key}', asNum(entries[i].value) ?? 0),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _branchCell(String code, num qty) {
    final bg = _locationColors[code];
    final on = bg == null
        ? Hs.ink
        : (bg.computeLuminance() < 0.5 ? Colors.white : Colors.black);
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: bg ?? Hs.hairline,
              border: Border.all(color: Hs.border),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: on),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Hs.border),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration:
                    BoxDecoration(color: Hs.muted, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  qty.toStringAsFixed(2),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButtonsRow() {
    final hasMrp = (_result?.containsKey('MRP') ?? false) && _can('mrp');
    final hasDiscount =
        (_result?.containsKey('Discount') ?? false) && _can('discount');
    if (!hasMrp && !hasDiscount) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasMrp)
          Expanded(
            child: FilledButton.icon(
              onPressed: _savingMrp ? null : _saveMrp,
              icon: _savingMrp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_savingMrp ? 'Saving…' : 'Save MRP'),
            ),
          ),
        if (hasMrp && hasDiscount) const SizedBox(width: 12),
        if (hasDiscount)
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Hs.green),
              onPressed: _savingDiscount ? null : _saveDiscount,
              icon: _savingDiscount
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_savingDiscount ? 'Saving…' : 'Save Discount'),
            ),
          ),
      ],
    );
  }

  Widget _imageSection() {
    final url = _imageUrl;
    final hasPending = _pending != null;

    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              hasPending ? 'Item Image  ·  new (unsaved)' : 'Item Image',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: hasPending ? Hs.amber : Hs.ink,
              ),
            ),
          ),
          Container(
            height: 220,
            width: double.infinity,
            color: Hs.hairline,
            alignment: Alignment.center,
            child: hasPending
                ? Image.file(File(_pending!.path), fit: BoxFit.contain)
                : url == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 40, color: Hs.faint),
                          SizedBox(height: 6),
                          Text('No image',
                              style: TextStyle(color: Hs.muted)),
                        ],
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        httpHeaders: _authHeader,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(
                            width: 26,
                            height: 26,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) => const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 38, color: Hs.faint),
                            SizedBox(height: 4),
                            Text('Image unavailable',
                                style: TextStyle(color: Hs.muted)),
                          ],
                        ),
                      ),
          ),
          // Camera / gallery / save only for users with "Image Upload".
          if (_can('image_upload'))
            Padding(
              padding: const EdgeInsets.all(12),
              child: hasPending ? _pendingActions() : _pickActions(),
            ),
        ],
      ),
    );
  }

  Widget _pickActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Take Photo from Camera'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('OR', style: TextStyle(color: Hs.muted)),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Choose from Gallery'),
          ),
        ),
      ],
    );
  }

  Widget _pendingActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _uploading ? null : () => setState(() => _pending = null),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Hs.green),
            onPressed: _uploading ? null : _saveImage,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 20),
            label: Text(_uploading ? 'Saving…' : 'Save Image'),
          ),
        ),
      ],
    );
  }
}
