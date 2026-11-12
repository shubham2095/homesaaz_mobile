import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/features/documents/document_format.dart';

void main() {
  group('docRowKey', () {
    test('the cash memo row from the live list: RowKey, not the repeating Doc No',
        () {
      final row = {
        'DocKey': 13980, // CMNo — 7 different cash memos carry this number
        'RowKey': 1816526, // CaMoID — unique
        'DocDate': '2026-11-11',
      };
      expect(docRowKey(row), '1816526');
      expect('${row['DocKey']}', '13980');
    });

    test('tolerates other spellings of the column', () {
      expect(docRowKey({'rowKey': '77'}), '77');
      expect(docRowKey({'Row_Key': '78'}), '78');
      expect(docRowKey({'ROWKEY': 79}), '79');
      expect(docRowKey({'Row Key': ' 80 '}), '80');
    });

    test('no RowKey (or an empty one) -> empty, so the Doc No is used', () {
      expect(docRowKey({'DocKey': '91614', 'DocDate': 'x'}), '');
      expect(docRowKey({'DocKey': '1', 'RowKey': null}), '');
      expect(docRowKey({'DocKey': '1', 'RowKey': ''}), '');
      expect(docRowKey(const {}), '');
    });

    test('other columns that merely contain "key" are not mistaken for it', () {
      expect(docRowKey({'DocKey': '5', 'PrimaryKey': '9', 'RowKeys': '3'}), '');
    });
  });
}
