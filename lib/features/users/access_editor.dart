// lib/features/users/access_editor.dart
//
// The "Module Access / <Module> - Field Access / <Module> - Locations" part of
// the User form (mirrors the web modal): which dashboard modules a user can
// open, which fields inside a module they can see, and — per module — which
// locations' data they get there. Options come from GET /users/access-options.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../widgets/states.dart';
import '../access/access_provider.dart';
import 'user_repository.dart';

/// The web modal's own blue (`--primary-blue`), used for every ticked state
/// here so the checks, borders and counts all agree.
const _accent = Color(0xFF0052CC);
const _accentSoft = Color(0xFFEAF1FF);

final _accessOptionsProvider = FutureProvider.autoDispose<AccessOptions>(
    (ref) => ref.read(userRepositoryProvider).accessOptions());

class AccessEditor extends ConsumerStatefulWidget {
  const AccessEditor({super.key, required this.selection, this.onChanged});

  /// Edited in place; [onChanged] fires after every change.
  final AccessSelection selection;
  final VoidCallback? onChanged;

  @override
  ConsumerState<AccessEditor> createState() => _AccessEditorState();
}

class _AccessEditorState extends ConsumerState<AccessEditor> {
  AccessSelection get _sel => widget.selection;

  /// Per-module location cards that are currently open, and the ones whose
  /// initial open/closed state has already been decided.
  final _openLocationCards = <String>{};
  final _seenLocationCards = <String>{};

  void _change(VoidCallback f) {
    setState(f);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final opts = ref.watch(_accessOptionsProvider);
    return opts.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: SizedBox(height: 60, child: LoadingView()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_accessOptionsProvider),
        ),
      ),
      data: (o) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _modulesCard(o),
          for (final m in o.modules)
            if (m.fields.isNotEmpty && _sel.modules.contains(m.slug)) ...[
              const SizedBox(height: 14),
              _fieldsCard(m),
            ],
          // One location panel per ticked module.
          for (final m in o.modules)
            if (_sel.modules.contains(m.slug)) ...[
              const SizedBox(height: 14),
              _moduleLocationsCard(m, o.locations),
            ],
          const SizedBox(height: 12),
          _summary(),
        ],
      ),
    );
  }

  /// "Selected: N module(s), M location(s)." — as on the web.
  Widget _summary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selected: ${_sel.modules.length} module(s), $_locationGrants '
              'location(s).',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _accent),
            ),
          ),
        ],
      ),
    );
  }

  // ---- shared bits ---------------------------------------------------------

  /// A section card: title (with the module icon, if any), a one-line
  /// description, then a "x / y selected" count beside "Select All", then the
  /// [child]. Keeping "Select All" off the title row stops a long title
  /// ("ALL STOCK DETAILS - Locations") from fighting it for space.
  ///
  /// With [onToggle] the header becomes a tap target with a chevron, and while
  /// [expanded] is false the [summary] stands in for the [child] — the long
  /// per-module location lists would otherwise make the sheet endless.
  Widget _card({
    String? iconSlug,
    required String title,
    required String subtitle,
    required int selected,
    required int total,
    required ValueChanged<bool> onSelectAll,
    required Widget child,
    bool expanded = true,
    VoidCallback? onToggle,
    Widget? summary,
  }) {
    final all = total > 0 && selected == total;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (iconSlug != null) ...[
          _moduleIcon(iconSlug, size: 26),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: Hs.ink)),
        ),
        if (onToggle != null) ...[
          const SizedBox(width: 8),
          Icon(expanded ? Icons.expand_less : Icons.expand_more,
              size: 24, color: Hs.muted),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onToggle != null)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: header,
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(top: 2), child: header),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, height: 1.35, color: Hs.muted)),
          const SizedBox(height: 12),
          // A Wrap, not a Row: with a big system font the count and the
          // "Select All" toggle drop onto two lines instead of overflowing.
          // Full width so `spaceBetween` pushes them to opposite edges.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: all ? _accent : _accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$selected / $total selected',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: all ? Colors.white : _accent)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: total == 0 ? null : () => onSelectAll(!all),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: all,
                          activeColor: _accent,
                          onChanged:
                              total == 0 ? null : (v) => onSelectAll(v ?? false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Select All',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            child,
          ] else if (summary != null) ...[
            const SizedBox(height: 10),
            summary,
          ],
        ],
      ),
    );
  }

  /// [tiles] laid out [columns] per row with the SAME height across a row
  /// (a plain Wrap leaves a one-line tile next to a three-line one ragged).
  Widget _grid(List<Widget> tiles, {int columns = 2, double gap = 8}) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: gap),
              Expanded(
                child: i + c < tiles.length ? tiles[i + c] : const SizedBox(),
              ),
            ],
          ],
        ),
      ));
      if (i + columns < tiles.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }

  /// The round tick at a tile's right edge: filled blue when ticked, an empty
  /// ring when not.
  Widget _tick(bool selected, {double size = 20}) {
    return AnimatedContainer(
      duration: Hs.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _accent : Colors.transparent,
        border: Border.all(
            color: selected ? _accent : const Color(0xFFC3CAD3), width: 1.5),
      ),
      child: selected
          ? Icon(Icons.check, size: size - 6, color: Colors.white)
          : null,
    );
  }

  /// A tappable option: label on the left, round tick on the right.
  Widget _tile({
    required bool selected,
    required VoidCallback onTap,
    required Widget label,
  }) {
    return Material(
      color: selected ? _accentSoft : Hs.surface,
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Hs.radiusSm),
            border: Border.all(
                color: selected ? _accent : Hs.border,
                width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 8),
              _tick(selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileLabel(String text, bool selected, {int maxLines = 3}) => Text(text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.25,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Hs.ink : Hs.inkSoft,
      ));

  // ---- modules -------------------------------------------------------------

  Widget _modulesCard(AccessOptions o) {
    return _card(
      title: 'Module Access',
      subtitle: 'Select the dashboard modules this user can open.',
      selected: o.modules.where((m) => _sel.modules.contains(m.slug)).length,
      total: o.modules.length,
      onSelectAll: (v) => _change(() {
        _sel.modules
          ..clear()
          ..addAll(v ? o.modules.map((m) => m.slug) : const <String>[]);
      }),
      child: o.modules.isEmpty
          ? const Text('No modules configured.',
              style: TextStyle(color: Hs.muted))
          : _grid([for (final m in o.modules) _moduleTile(m)],
              columns: 3, gap: 8),
    );
  }

  /// Icon over name, so even "UPLOAD GATE ENTRY BILL" or "DOCUMENT DOWNLOAD"
  /// get the full tile width instead of the sliver a side-by-side icon,
  /// label and tick left (which cut names mid-word).
  Widget _moduleTile(AccessModule m) {
    final selected = _sel.modules.contains(m.slug);
    return Material(
      color: selected ? _accentSoft : Hs.surface,
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        onTap: () => _change(() {
          if (!_sel.modules.add(m.slug)) _sel.modules.remove(m.slug);
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Hs.radiusSm),
            border: Border.all(
                color: selected ? _accent : Hs.border,
                width: selected ? 1.4 : 1),
          ),
          // Clip.none: the tick sits in the tile's top-right corner, partly
          // over the padding — a clipping Stack cut it off.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _moduleIcon(m.slug, size: 44),
                    const SizedBox(height: 8),
                    Text(m.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: selected ? Hs.ink : Hs.inkSoft,
                        )),
                  ],
                ),
              ),
              Positioned(top: -8, right: -2, child: _tick(selected, size: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moduleIcon(String slug, {double size = 30}) {
    final def = moduleBySlug(slug);
    if (def?.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .2),
        // contain, not cover: the logos aren't square and were being cropped.
        child: Image.asset(def!.image!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            cacheWidth: (size * 3).round(),
            errorBuilder: (_, __, ___) =>
                Icon(def.icon, size: size * .7, color: Hs.muted)),
      );
    }
    return SizedBox(
        width: size,
        height: size,
        child: Icon(def?.icon ?? Icons.apps, size: size * .7, color: Hs.muted));
  }

  // ---- fields inside a module ---------------------------------------------

  Widget _fieldsCard(AccessModule m) {
    final picked = _sel.fields.putIfAbsent(m.slug, () => <String>{});
    return _card(
      iconSlug: m.slug,
      title: '${m.label} - Field Access',
      subtitle: 'Unticked fields (and their Save buttons) will be hidden '
          'for this user.',
      selected: m.fields.where((f) => picked.contains(f.key)).length,
      total: m.fields.length,
      onSelectAll: (v) => _change(() {
        picked
          ..clear()
          ..addAll(v ? m.fields.map((f) => f.key) : const <String>[]);
      }),
      child: _grid([
        for (final f in m.fields)
          _tile(
            selected: picked.contains(f.key),
            onTap: () => _change(() {
              if (!picked.add(f.key)) picked.remove(f.key);
            }),
            label: _tileLabel(f.label, picked.contains(f.key)),
          ),
      ]),
    );
  }

  // ---- locations (per module) ----------------------------------------------

  /// Ticked locations summed over the ticked modules — the web's summary
  /// counts every ticked location checkbox the same way.
  int get _locationGrants => [
        for (final m in _sel.modules)
          (_sel.moduleLocations[m] ?? const <int>{}).length,
      ].fold(0, (a, b) => a + b);

  Widget _moduleLocationsCard(AccessModule m, List<AccessLocation> locations) {
    final picked = _sel.moduleLocations.putIfAbsent(m.slug, () => <int>{});
    // The first time a card shows, open it only if nothing is ticked yet (it
    // needs attention); a user who already has locations starts collapsed.
    if (_seenLocationCards.add(m.slug) && picked.isEmpty) {
      _openLocationCards.add(m.slug);
    }
    final names = [
      for (final l in locations)
        if (picked.contains(l.id)) l.name,
    ];
    return _card(
      iconSlug: m.slug,
      title: '${m.label} - Locations',
      subtitle: 'User will see ${m.label} data only for these locations.',
      selected: names.length,
      total: locations.length,
      onSelectAll: (v) => _change(() {
        picked
          ..clear()
          ..addAll(v ? locations.map((l) => l.id) : const <int>[]);
      }),
      expanded: _openLocationCards.contains(m.slug),
      onToggle: () => setState(() {
        if (!_openLocationCards.add(m.slug)) _openLocationCards.remove(m.slug);
      }),
      summary: names.isEmpty
          ? const Text('No location selected — tap to choose.',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A6D00)))
          : Text(
              names.length <= 2
                  ? names.join(', ')
                  : '${names.take(2).join(', ')} +${names.length - 2} more',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, height: 1.3, color: Hs.inkSoft)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (picked.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Hs.amber.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(Hs.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6D00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No location selected — this user will see no '
                      '${m.label} data.',
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: Color(0xFF6B5400)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (locations.isEmpty)
            const Text('No locations found.',
                style: TextStyle(color: Hs.muted))
          else
            _grid([
              for (final l in locations)
                _tile(
                  selected: picked.contains(l.id),
                  onTap: () => _change(() {
                    if (!picked.add(l.id)) picked.remove(l.id);
                  }),
                  // Name then code; 4 lines so a long name such as
                  // "AVENUE WARE HOUSE (BHIWANDI GODOWN)" isn't cut off.
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tileLabel(l.name, picked.contains(l.id), maxLines: 4),
                      if (l.code.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(l.code,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Hs.faint)),
                        ),
                    ],
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}
