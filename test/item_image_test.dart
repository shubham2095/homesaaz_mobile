import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/core/item_image.dart';

const _api = 'http://web.homesaaz.in:84/api';

List<String> _urls(Object? server, {String? code = 'KA8760'}) =>
    itemImageUrls(code: code, serverUrl: server, baseUrl: _api);

void main() {
  group('itemImageUrls', () {
    test('old image server URL from the backend is used directly (no proxy)', () {
      expect(_urls('http://web.homesaaz.in:85/KA8760.jpg'),
          ['http://web.homesaaz.in:85/KA8760.jpg']);
    });

    test('photo uploaded from the app: web proxy URL -> plain file URL first, '
        'then API proxy, then :85', () {
      expect(
        _urls('http://web.homesaaz.in:84/stock/image-proxy/KA8760.jpg?v=1794040430'),
        [
          'http://web.homesaaz.in:84/items/KA8760.jpg?v=1794040430',
          'http://web.homesaaz.in:84/api/stock/image-proxy/KA8760.jpg?v=1794040430',
          'http://web.homesaaz.in:85/KA8760.jpg',
        ],
      );
    });

    test('backend already sends the plain file URL -> used as is', () {
      expect(_urls('http://web.homesaaz.in:84/items/KA8760.jpg?v=1794040430'),
          ['http://web.homesaaz.in:84/items/KA8760.jpg?v=1794040430']);
    });

    test('older server: proxy URL without ?v', () {
      expect(_urls('http://web.homesaaz.in:84/stock/image-proxy/AB2062.JPG'), [
        'http://web.homesaaz.in:84/items/AB2062.JPG',
        'http://web.homesaaz.in:84/api/stock/image-proxy/AB2062.JPG',
        'http://web.homesaaz.in:85/AB2062.JPG',
      ]);
    });

    test('file names with spaces survive the proxy rewrite', () {
      expect(_urls('http://h:84/stock/image-proxy/KASA%20BELLA.jpg'), [
        'http://web.homesaaz.in:84/items/KASA%20BELLA.jpg',
        'http://web.homesaaz.in:84/api/stock/image-proxy/KASA%20BELLA.jpg',
        'http://web.homesaaz.in:85/KASA%20BELLA.jpg',
      ]);
    });

    test('bare file name / Windows path from ItemDet.ItemImage -> :85', () {
      expect(_urls('H2561.jpg'), ['http://web.homesaaz.in:85/H2561.jpg']);
      expect(_urls(r'E:\Images\H2561.jpg'),
          ['http://web.homesaaz.in:85/H2561.jpg']);
      expect(_urls('images/H2561.jpg'),
          ['http://web.homesaaz.in:85/H2561.jpg']);
    });

    test('server said nothing: guess <code>.jpg on the image server', () {
      expect(_urls(null), ['http://web.homesaaz.in:85/KA8760.jpg']);
      expect(_urls('   '), ['http://web.homesaaz.in:85/KA8760.jpg']);
    });

    test('nothing to go on -> no URLs', () {
      expect(_urls(null, code: null), isEmpty);
      expect(_urls('', code: '  '), isEmpty);
    });

    test('the image-server URLs never go through our own API host', () {
      for (final u in _urls('H2561.jpg') + _urls(null)) {
        expect(u.startsWith(_api), isFalse);
      }
    });
  });

  group('withImageVersion', () {
    test('adds v, or replaces an existing one', () {
      expect(withImageVersion('http://h:85/A.jpg', 5), 'http://h:85/A.jpg?v=5');
      expect(withImageVersion('http://h:84/api/stock/image-proxy/A.png?v=1', 9),
          'http://h:84/api/stock/image-proxy/A.png?v=9');
    });
  });
}
