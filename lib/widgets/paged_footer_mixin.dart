// lib/widgets/paged_footer_mixin.dart
import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../core/paged_response.dart';

/// Shared "Showing 1 to N of Total" footer bookkeeping — mobile loads via
/// infinite scroll instead of Previous/Next pages, so every list screen
/// that shows this bar needs the same running-total tracking. Wire a
/// `PagedListView`'s `onPageLoaded` to [trackPage], call [resetFooter]
/// wherever the query/filters change (inside the caller's own `setState`),
/// and render [footerBar] once `footerTotal > 0`.
mixin PagedFooterMixin<T extends StatefulWidget> on State<T> {
  int footerTotal = 0;
  int footerLoaded = 0;

  /// Mutates the counters directly (no `setState`) — call from inside a
  /// `setState` block that's already rebuilding for other reasons (e.g.
  /// applying a new filter), matching how every call site already resets
  /// its other query-state fields.
  void resetFooter() {
    footerTotal = 0;
    footerLoaded = 0;
  }

  /// Pass directly as a `PagedListView.onPageLoaded` callback.
  void trackPage(PageMeta meta, Map<String, dynamic> extra) {
    final loaded = meta.page * meta.perPage > meta.total
        ? meta.total
        : meta.page * meta.perPage;
    if (meta.total != footerTotal || loaded != footerLoaded) {
      setState(() {
        footerTotal = meta.total;
        footerLoaded = loaded;
      });
    }
  }

  /// Web's `.pagination-section` "Showing 1 to N of Total".
  Widget footerBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Hs.surface,
        border: Border(top: BorderSide(color: Hs.border)),
      ),
      child: Text(
        'Showing 1 to $footerLoaded of $footerTotal',
        style: const TextStyle(fontSize: 12.5, color: Hs.muted),
      ),
    );
  }
}
