// lib/features/bed_occupancy/bed_occupancy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_list_view.dart';

final _repoProvider = Provider((ref) => _BedOccupancyRepo(ref));

class _BedOccupancyRepo {
  _BedOccupancyRepo(this.ref);
  final Ref ref;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/homestay/bed-occupancy/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

class BedOccupancyScreen extends ConsumerWidget {
  const BedOccupancyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Bed Occupancy'),
      body: PagedListView<Map<String, dynamic>>(
        searchHint: 'Search by location…',
        fetchPage: repo.list,
        itemBuilder: (context, m) {
          final total = asInt(m['TOTALBED']) ?? 0;
          final letout = asInt(m['Letout']) ?? 0;
          final vacant = asInt(m['Vacant']) ?? (total - letout);
          return HsListCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orDash(m['LocationName']),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Hs.ink)),
                const SizedBox(height: 6),
                // Order mirrors web's card-row list (bedOccupancy/list.blade.php
                // renderCards): Location [title], Total Bed, Vacant, Let Out.
                HsRow('Total Bed', '$total', bottomDivider: true),
                HsRow('Vacant', '$vacant',
                    valueColor: vacant > 0 ? Hs.green : Hs.red,
                    bold: true,
                    bottomDivider: true),
                HsRow('Let Out', '$letout'),
              ],
            ),
          );
        },
      ),
    );
  }
}
