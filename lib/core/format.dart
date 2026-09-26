// lib/core/format.dart
import 'package:intl/intl.dart';

import 'config.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _date = DateFormat('dd MMM yyyy');

String money(Object? v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  if (n == null) return '-';
  return _money.format(n);
}

String prettyDate(Object? v) {
  if (v == null || '$v'.trim().isEmpty) return '-';
  final d = DateTime.tryParse('$v');
  return d == null ? '$v' : _date.format(d);
}

/// Web's own `safe()` helper falls back to a plain hyphen for null/empty
/// values — matched here (not an em dash) for exact parity.
String orDash(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty ? '-' : s;
}

/// The SQL Server (`sqlsrv`) driver serialises numeric / money / decimal
/// columns as JSON **strings**, so `x as num` blows up. Always go through
/// these instead of casting.
num? asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}'.trim());

int? asInt(Object? v) => asNum(v)?.toInt();

double? asDouble(Object? v) => asNum(v)?.toDouble();

/// A user's profile photo as a URL the app can load, or null (-> initials).
///
/// The API returns either a bare path (`uploads/users/x.jpg`) or a full
/// `asset()` URL whose host/port depends on the server's APP_URL, so only
/// the path is kept and joined to the app's own API origin. The web's
/// default avatar is an SVG, which Flutter can't decode — treated as none.
String? profileImageUrl(Object? v) {
  var s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http')) {
    final u = Uri.tryParse(s);
    if (u == null) return null;
    s = u.path;
  }
  s = s.replaceFirst(RegExp(r'^/+'), '');
  if (s.isEmpty || s.toLowerCase().endsWith('.svg')) return null;
  final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin/$s';
}
