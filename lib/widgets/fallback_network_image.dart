// lib/widgets/fallback_network_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows the first of [urls] that actually loads, trying the next one when a
/// URL fails — and [fallback] when none do.
///
/// For files whose URL can legitimately come out differently depending on
/// how the server is configured (an absolute `asset()` URL built from its
/// APP_URL, or the same path on this app's own API host), where picking just
/// one would leave the picture blank whenever that guess is wrong.
class FallbackNetworkImage extends StatefulWidget {
  const FallbackNetworkImage({
    super.key,
    required this.urls,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.headersFor,
    this.placeholder,
  });

  final List<String> urls;
  final Widget fallback;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// HTTP headers for one URL — e.g. the Bearer token for this app's own API
  /// but not for a plain image server on another port.
  final Map<String, String> Function(String url)? headersFor;

  /// Shown while the current URL loads.
  final Widget? placeholder;

  @override
  State<FallbackNetworkImage> createState() => _FallbackNetworkImageState();
}

class _FallbackNetworkImageState extends State<FallbackNetworkImage> {
  int _index = 0;

  @override
  void didUpdateWidget(FallbackNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.urls.join('|') != widget.urls.join('|')) _index = 0;
  }

  void _next(int failed) {
    // The error builder can run more than once per failure — only advance
    // from the URL that actually failed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _index == failed) setState(() => _index = failed + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.fallback;
    final current = _index;
    return CachedNetworkImage(
      key: ValueKey(widget.urls[current]),
      imageUrl: widget.urls[current],
      httpHeaders: widget.headersFor?.call(widget.urls[current]),
      placeholder: widget.placeholder == null ? null : (_, __) => widget.placeholder!,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      errorWidget: (_, __, ___) {
        _next(current);
        return const SizedBox.shrink();
      },
    );
  }
}
