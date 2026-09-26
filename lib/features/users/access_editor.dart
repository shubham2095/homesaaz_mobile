// lib/features/users/access_editor.dart
//
// The "Module Access / <Module> - Field Access / Location Access" part of the
// User form (mirrors the web modal): which dashboard modules a user can open,
// which fields inside a module they can see, and which locations' data they
// get. Options come from GET /users/access-options.
import  'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../widgets/states.dart';
import '../access/access_provider.dart';
import 'user_repository.dart';

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
  final _search = TextEditingController();
  String _q = '';

  AccessSelection get _sel => widget.selection;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
              const SizedBox(height: 12),
              _fieldsCard(m),
            ],
          const SizedBox(height: 12),
          _locationsCard(o),
          const SizedBox(height: 10),
          Text(
            'Selected: ${_sel.modules.length} module(s), '
            '${_sel.locations.length} location(s).',
            style: const TextStyle(fontSize: 12, color: Hs.muted),
          ),
        ],
      ),
    );
  }

  // ---- shared bits ---------------------------------------------------------

  Widget _card({
    required String title,
    required String subtitle,
    required bool allSelected,
    required ValueChanged<bool> onSelectAll,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Hs.ink)),
              ),
              InkWell(
                onTap: () => onSelectAll(!allSelected),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: allSelected,
                        onChanged: (v) => onSelectAll(v ?? false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Select All',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Hs.muted)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _tile({
    required bool selected,
    required VoidCallback onTap,
    required Widget label,
    Widget? leading,
  }) {
    return Material(
      color: selected ? const Color(0xFFEAF1FF) : Hs.surface,
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Hs.radiusSm),
            border: Border.all(
                color: selected ? const Color(0xFF0052CC) : Hs.border),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(child: label),
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(value: selected, onChanged: (_) => onTap()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- modules -------------------------------------------------------------

  Widget _modulesCard(AccessOptions o) {
    final all = o.modules.isNotEmpty &&
        o.modules.every((m) => _sel.modules.contains(m.slug));
    return _card(
      title: 'Module Access',
      subtitle: 'Select the dashboard modules this user can open.',
      allSelected: all,
      onSelectAll: (v) => _change(() {
        _sel.modules
          ..clear()
          ..addAll(v ? o.modules.map((m) => m.slug) : const <String>[]);
      }),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in o.modules)
              SizedBox(
                width: w,
                child: _tile(
                  selected: _sel.modules.contains(m.slug),
                  onTap: () => _change(() {
                    if (!_sel.modules.add(m.slug)) _sel.modules.remove(m.slug);
                  }),
                  leading: _moduleIcon(m.slug),
                  label: Text(m.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _moduleIcon(String slug) {
    final def = moduleBySlug(slug);
    if (def?.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(def!.image!,
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(def.icon, size: 22, color: Hs.muted)),
      );
    }
    return SizedBox(
        width: 30,
        height: 30,
        child: Icon(def?.icon ?? Icons.apps, size: 22, color: Hs.muted));
  }

  // ---- fields inside a module ---------------------------------------------

  Widget _fieldsCard(AccessModule m) {
    final picked = _sel.fields.putIfAbsent(m.slug, () => <String>{});
    final all = m.fields.every((f) => picked.contains(f.key));
    return _card(
      title: '${m.label} - Field Access',
      subtitle: 'Unticked fields (and their Save buttons) will be hidden '
          'for this user.',
      allSelected: all,
      onSelectAll: (v) => _change(() {
        picked
          ..clear()
          ..addAll(v ? m.fields.map((f) => f.key) : const <String>[]);
      }),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final f in m.fields)
              SizedBox(
                width: w,
                child: _tile(
                  selected: picked.contains(f.key),
                  onTap: () => _change(() {
                    if (!picked.add(f.key)) picked.remove(f.key);
                  }),
                  label: Text(f.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ---- locations -----------------------------------------------------------

  Widget _locationsCard(AccessOptions o) {
    final q = _q.toLowerCase();
    final shown = o.locations
        .where((l) =>
            q.isEmpty ||
            l.name.toLowerCase().contains(q) ||
            l.code.toLowerCase().contains(q))
        .toList();
    final all = o.locations.isNotEmpty &&
        o.locations.every((l) => _sel.locations.contains(l.id));
    return _card(
      title: 'Location Access',
      subtitle: 'User will see data only for these locations (branch-wise).',
      allSelected: all,
      onSelectAll: (v) => _change(() {
        _sel.locations
          ..clear()
          ..addAll(v ? o.locations.map((l) => l.id) : const <int>[]);
      }),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(hintText: 'Search location…'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: shown.isEmpty
                ? const Center(
                    child: Text('No locations found.',
                        style: TextStyle(color: Hs.muted)))
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final l = shown[i];
                      return _tile(
                        selected: _sel.locations.contains(l.id),
                        onTap: () => _change(() {
                          if (!_sel.locations.add(l.id)) {
                            _sel.locations.remove(l.id);
                          }
                        }),
                        label: Row(
                          children: [
                            Expanded(
                              child: Text(l.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5)),
                            ),
                            const SizedBox(width: 6),
                            Text(l.code,
                                style: const TextStyle(
                                    fontSize: 11, color: Hs.faint)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
