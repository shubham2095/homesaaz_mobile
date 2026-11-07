// lib/core/item_image.dart
import 'config.dart';

/// Where an item's photo can be loaded from, best first (try them in order,
/// e.g. with `FallbackNetworkImage`).
///
/// A photo is in one of two places:
///  * the old image server, `http://<host>:85/<file>` — plain files, no login;
///    the backend now hands this URL out directly, and the app fetches it
///    itself (asking our own server to fetch it for us fails on some hosts).
///  * uploaded from the app: `public/items/<code>.<ext>` on the API server.
///    The backend announces it either as that file's own URL (used as is) or
///    as the *web* proxy URL (`/stock/image-proxy/<file>?v=…`, session login
///    only); for the latter the file URL `<host>/items/<file>` is tried first,
///    then the API proxy route (Bearer token), then the old image server.
///
/// [serverUrl] is the response's `ImageUrl` / `Image` (or a bare file name);
/// [code] is only used to guess `<code>.jpg` when the server said nothing.
List<String> itemImageUrls({
  String? code,
  Object? serverUrl,
  String? baseUrl,
}) {
  final api = baseUrl ?? AppConfig.baseUrl;
  final host = Uri.parse(api).host;
  String direct(String file) => 'http://$host:85/${Uri.encodeComponent(file)}';

  final raw = '${serverUrl ?? ''}'.trim();
  if (raw.isNotEmpty) {
    const marker = 'image-proxy/';
    final i = raw.indexOf(marker);
    if (i != -1) {
      final rest = raw.substring(i + marker.length);
      final q = rest.indexOf('?');
      var file = q == -1 ? rest : rest.substring(0, q);
      final query = q == -1 ? '' : rest.substring(q);
      try {
        file = Uri.decodeComponent(file);
      } catch (_) {}
      if (file.isNotEmpty) {
        final name = Uri.encodeComponent(file);
        return [
          // The upload sits in public/items, which the web server hands out as a
          // plain file (no PHP, no login) — the proxy answered such a file with
          // bytes that weren't an image.
          '${Uri.parse(api).origin}/items/$name$query',
          '$api/stock/image-proxy/$name$query',
          direct(file),
        ];
      }
    } else if (raw.startsWith('http')) {
      return [raw];
    } else {
      // A bare file name (ItemDet.ItemImage) or a Windows/relative path.
      final file = raw.split(RegExp(r'[\\/]')).last;
      if (file.isNotEmpty) return [direct(file)];
    }
  }

  final c = code?.trim() ?? '';
  return c.isEmpty ? const [] : [direct('$c.jpg')];
}

/// [url] with a `v=<version>` query parameter (replacing an existing one) so
/// a re-uploaded photo isn't served from the image cache.
String withImageVersion(String url, int version) {
  final u = Uri.parse(url);
  return u.replace(queryParameters: {...u.queryParameters, 'v': '$version'}).toString();
}
