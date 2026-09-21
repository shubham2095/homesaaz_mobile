// lib/widgets/paged_list_view.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../core/api_client.dart';
import '../core/paged_response.dart';
import 'hs_widgets.dart';
import 'states.dart';

typedef PageFetcher<T> = Future<PagedResponse<T>> Function(int page, String search);

/// Infinite-scroll list with pull-to-refresh + optional debounced search.
///
/// When parent-controlled filters change, give this widget a new [key]
/// (e.g. `ValueKey(filterSignature)`) so it reloads from page 1.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetchPage,
    this.itemBuilder,
    this.indexedItemBuilder,
    this.searchable = true,
    this.searchHint = 'Search…',
    this.onPageLoaded,
    this.emptyMessage = 'No records found.',
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 28),
    this.separator = const SizedBox(height: 10),
    this.header,
  }) : assert(
         itemBuilder != null || indexedItemBuilder != null,
         'Provide itemBuilder or indexedItemBuilder',
       );

  final PageFetcher<T> fetchPage;
  final Widget Function(BuildContext, T)? itemBuilder;

  /// Alternative to [itemBuilder] for callers that need the item's
  /// page-relative position (e.g. a table's "S.No" column) — `index` counts
  /// across the whole loaded list, not just the current page.
  final Widget Function(BuildContext, T, int index)? indexedItemBuilder;
  final bool searchable;
  final String searchHint;
  final void Function(PageMeta meta, Map<String, dynamic> extra)? onPageLoaded;
  final String emptyMessage;
  final EdgeInsets padding;
  final Widget separator;

  /// Optional content (e.g. a filter panel + table header) rendered as the
  /// first item of the SAME scrollable list — it scrolls away with the
  /// rest of the content instead of staying pinned above it, and still
  /// participates in the one scroll controller driving pagination.
  final Widget? header;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<T> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loadingFirst = true;
      _error = null;
    });
    try {
      final res = await widget.fetchPage(1, _search);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.meta.page;
        _hasMore = res.meta.hasMore;
        _loadingFirst = false;
      });
      widget.onPageLoaded?.call(res.meta, res.extra);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFirst = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFirst = false;
        _error = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loadingFirst) return;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.fetchPage(_page + 1, _search);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.meta.page;
        _hasMore = res.meta.hasMore;
        _loadingMore = false;
      });
      widget.onPageLoaded?.call(res.meta, res.extra);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false; // stop hammering a failing endpoint
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search = value.trim();
      _loadFirst();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20, color: Hs.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 42, minHeight: 42),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        splashRadius: 18,
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final header = widget.header;
    if (_loadingFirst) {
      if (header == null) return const LoadingView();
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [header, const SizedBox(height: 240, child: LoadingView())],
      );
    }
    if (_error != null) {
      if (header == null) {
        return ErrorView(message: _error!, onRetry: _loadFirst);
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          header,
          SizedBox(
            height: 300,
            child: ErrorView(message: _error!, onRetry: _loadFirst),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ?header,
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: EmptyView(message: widget.emptyMessage),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      color: Hs.blue,
      child: ListView.separated(
        controller: _scroll,
        padding: widget.padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount:
            (header != null ? 1 : 0) + _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, i) {
          if (header != null && i == 0) return const SizedBox.shrink();
          return widget.separator;
        },
        itemBuilder: (context, i) {
          var idx = i;
          if (header != null) {
            if (idx == 0) return header;
            idx -= 1;
          }
          if (idx >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }
          return HsAppear(
            index: idx,
            child: widget.indexedItemBuilder != null
                ? widget.indexedItemBuilder!(context, _items[idx], idx)
                : widget.itemBuilder!(context, _items[idx]),
          );
        },
      ),
    );
  }
}
