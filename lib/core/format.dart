// lib/core/format.dart
import 'package:flutter/material.dart' show Color;
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

/// Normalises an uploaded file reference — a bare path
/// (`uploads/users/x.jpg`) or a full `asset()` URL — to a URL this app can
/// load. Always rejoins against the app's own API origin rather than
/// trusting a host/port the server embedded (e.g. a misconfigured
/// `APP_URL`), so a wrong server setting can't break every image.
String? resolveAssetUrl(Object? v) {
  var s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http')) {
    final u = Uri.tryParse(s);
    if (u == null) return null;
    s = u.path;
  }
  s = s.replaceFirst(RegExp(r'^/+'), '');
  if (s.isEmpty) return null;
  final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin/$s';
}

/// A user's profile photo as a URL the app can load, or null (-> initials).
///
/// `GET /users/{id}` now also returns a ready-made `profileImageUrl` field
/// (prefer that where it's available — e.g. `user_form.dart`'s edit load);
/// this stays for the places that only get the bare `profileImage` column
/// (`/auth/me`, the users datatable). The web's default avatar is an SVG,
/// which Flutter can't decode — treated as none either way.
String? profileImageUrl(Object? v) {
  final s = resolveAssetUrl(v);
  if (s == null || s.toLowerCase().endsWith('.svg')) return null;
  return s;
}

/// Parses a `#RRGGBB` (or bare `RRGGBB`) Location colour. Same rule Gate
/// Entry / GRN use for their location chips.
Color? parseHexColor(String? v) {
  final s = (v ?? '').replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}
