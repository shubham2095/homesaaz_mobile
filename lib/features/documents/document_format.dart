// lib/features/documents/document_format.dart
//
// Display helpers for Document Download. Both the list and detail columns
// come straight from each document type's SQL query (they differ per type
// and can gain columns without an app release), so — like the web page —
// labels and number/date formatting are derived from the column name.
import 'package:intl/intl.dart';

import '../../core/format.dart';

final _amount2 = NumberFormat('#,##0.00', 'en_IN');

/// Friendly labels for known keys; anything else is auto-spaced
/// ("CamelCase" -> "Camel Case"). Same table as web's `ddFriendlyLabels`.
const _friendly = <String, String>{
  'DocKey': 'Doc No',
  'DocDate': 'Date',
  'PartyName': 'Party / Salesman',
  'Amount': 'Amount',
  'RefDocNo': 'Ref Doc No',
  'EWAYBILL': 'E-Way Bill',
  'IRN': 'IRN',
  'CAmount': 'Amount',
};

String prettifyDocLabel(String key) {
  final known = _friendly[key];
  if (known != null) return known;
  return key
      .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}')
      .trim();
}

/// Web's `ddIsAmountColumn`: names containing amt / amount / disc.
bool isDocAmountColumn(String key) =>
    key != 'DocKey' &&
    RegExp(r'amt|amount|disc', caseSensitive: false).hasMatch(key);

bool isDocDateColumn(String key) =>
    RegExp(r'date', caseSensitive: false).hasMatch(key);

/// Cell text for [raw] under column [key] — dates as `dd MMM yyyy`, amounts
/// with 2 decimals / Indian grouping, empty as `-`.
String formatDocCell(String key, Object? raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty) return '-';
  if (isDocDateColumn(key)) return prettyDate(s);
  if (isDocAmountColumn(key)) {
    final n = asNum(s);
    if (n != null) return _amount2.format(n);
  }
  return s;
}

/// Column width for the list/detail tables, by what the column holds.
double docColumnWidth(String key) {
  if (key == 'DocDate' || isDocDateColumn(key)) return 105;
  if (key == 'PartyName') return 190;
  if (isDocAmountColumn(key)) return 105;
  return 125;
}
