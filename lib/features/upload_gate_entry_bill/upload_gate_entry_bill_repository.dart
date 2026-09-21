// lib/features/upload_gate_entry_bill/upload_gate_entry_bill_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

final uploadGateEntryBillRepositoryProvider =
    Provider((ref) => UploadGateEntryBillRepository(ref));

class UploadGateEntryBillRepository {
  UploadGateEntryBillRepository(this.ref);
  final Ref ref;

  Future<Map<String, dynamic>> getOne(int id) async {
    final data = await ref
        .read(apiClientProvider)
        .getData('/uploadgateentrybill/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// Create ([id] == null) or update. [imagePath] required on create,
  /// optional on edit (keeps the existing image if omitted).
  Future<void> save({int? id, String? imagePath}) async {
    await ref.read(apiClientProvider).postForm(
          '/uploadgateentrybill/save',
          fields: {'Id': ?id},
          filePath: imagePath,
          fileField: 'image',
        );
  }

  Future<void> approve(int id, {String notes = ''}) async {
    await ref.read(apiClientProvider).postForm(
      '/uploadgateentrybill/$id/approve',
      fields: {'notes': notes},
    );
  }

  Future<void> reject(int id, {String notes = ''}) async {
    await ref.read(apiClientProvider).postForm(
      '/uploadgateentrybill/$id/reject',
      fields: {'notes': notes},
    );
  }

  Future<void> delete(int id) async {
    await ref.read(apiClientProvider).deleteRaw('/uploadgateentrybill/$id');
  }
}
