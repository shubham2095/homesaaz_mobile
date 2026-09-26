// lib/features/locations/location_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../access/access_provider.dart';

class LocationRow {
  LocationRow(this.raw);
  final Map<String, dynamic> raw;

  int get id => asInt(raw['LocationID']) ?? 0;
  String get code => (raw['Locationcode'] ?? '').toString();
  String get name => (raw['LocationName'] ?? '').toString();
  String get address => (raw['LocationAddress'] ?? '').toString();
  String get gst =>
      (raw['GSTDisplay'] ?? raw['GST'] ?? '').toString().trim();
  String get colorHex => (raw['Color'] ?? '').toString();

  factory LocationRow.fromJson(Map<String, dynamic> j) => LocationRow(j);
}

final locationRepositoryProvider = Provider((ref) => LocationRepository(ref));

class LocationRepository {
  LocationRepository(this.ref);
  final Ref ref;

  Future<PagedResponse<LocationRow>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/locations/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    final res = PagedResponse.parse(body, LocationRow.fromJson,
        page: page, perPage: AppConfig.pageSize);
    // Only the locations this user was granted.
    final access = await ref.read(userAccessProvider.future);
    if (access.isAdmin || access.locationIds == null) return res;
    return PagedResponse<LocationRow>(
      items: res.items.where((l) => access.canLocation(l.id)).toList(),
      meta: res.meta,
      extra: res.extra,
    );
  }

  Future<Map<String, dynamic>> getOne(int id) async {
    final data = await ref.read(apiClientProvider).getData('/locations/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// Create ([id] == null) or update.
  Future<void> save({
    int? id,
    required String name,
    String? code, // required by API on create, ignored on edit
    String? address,
    String? gst,
    String? colorHex, // '#RRGGBB' or null
  }) async {
    final valid = RegExp(r'^#[0-9A-Fa-f]{6}$');
    final fields = <String, dynamic>{
      'LocationName': name,
      'LocationAddress': address ?? '',
      'GST': gst ?? '',
    };
    if (id != null) {
      fields['LocationID'] = id;
    } else {
      fields['Locationcode'] = code ?? '';
    }
    if (colorHex != null && valid.hasMatch(colorHex)) {
      fields['Color'] = colorHex;
    }
    await ref.read(apiClientProvider).postForm('/locations/save', fields: fields);
  }

  Future<void> delete(int id) async {
    await ref.read(apiClientProvider).deleteRaw('/locations/$id');
  }
}
