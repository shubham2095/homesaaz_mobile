// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/bed_occupancy/bed_occupancy_screen.dart';
import '../features/daily_collection/daily_collection_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/documents/document_detail_screen.dart';
import '../features/documents/document_list_screen.dart';
import '../features/gate_entry/gate_entry_details_screen.dart';
import '../features/gate_entry/gate_entry_screen.dart';
import '../features/grn/grn_items_screen.dart';
import '../features/grn/grn_list_screen.dart';
import '../features/home_stay/home_stay_screen.dart';
import '../features/item_stock/item_stock_screen.dart';
import '../features/locations/location_list_screen.dart';
import '../features/new_students/new_student_list_screen.dart';
import '../features/pending_rent/pending_rent_screen.dart';
import '../features/stock/stock_detail_screen.dart';
import '../features/stock/stock_list_screen.dart';
import '../features/students/student_list_screen.dart';
import '../features/upload_gate_entry_bill/upload_gate_entry_bill_detail_screen.dart';
import '../features/upload_gate_entry_bill/upload_gate_entry_bill_list_screen.dart';
import '../features/users/user_list_screen.dart';

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (loc == '/splash') {
        return status == AuthStatus.authenticated ? '/' : '/login';
      }
      final loggedIn = status == AuthStatus.authenticated;
      if (!loggedIn) return loc == '/login' ? null : '/login';
      if (loggedIn && loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),

      GoRoute(path: '/stock', builder: (_, __) => const StockListScreen()),
      GoRoute(
        path: '/stock/:id',
        builder: (_, s) =>
            StockDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),

      GoRoute(path: '/item-stock', builder: (_, __) => const ItemStockScreen()),

      GoRoute(
        path: '/upload-gate-entry-bill',
        builder: (_, __) => const UploadGateEntryBillListScreen(),
      ),
      GoRoute(
        path: '/upload-gate-entry-bill/:id',
        builder: (_, s) => UploadGateEntryBillDetailScreen(
          id: int.parse(s.pathParameters['id']!),
        ),
      ),

      GoRoute(path: '/home-stay', builder: (_, __) => const HomeStayScreen()),
      GoRoute(path: '/pending-rent', builder: (_, __) => const PendingRentScreen()),
      GoRoute(path: '/students', builder: (_, __) => const StudentListScreen()),
      GoRoute(path: '/bed-occupancy', builder: (_, __) => const BedOccupancyScreen()),
      GoRoute(path: '/new-students', builder: (_, __) => const NewStudentListScreen()),

      GoRoute(path: '/gate-entry', builder: (_, __) => const GateEntryScreen()),
      GoRoute(
        path: '/gate-entry/:id',
        builder: (_, s) => GateEntryDetailsScreen(
          grnId: int.parse(s.pathParameters['id']!),
          locationId: int.tryParse(s.uri.queryParameters['loc'] ?? '') ?? 0,
          dateFrom: s.uri.queryParameters['from'],
          dateTo: s.uri.queryParameters['to'],
          header: s.extra is Map<String, dynamic>
              ? s.extra as Map<String, dynamic>
              : null,
        ),
      ),

      GoRoute(path: '/grn', builder: (_, __) => const GrnListScreen()),
      GoRoute(
        path: '/grn/:id',
        builder: (_, s) => GrnItemsScreen(
          grnId: int.parse(s.pathParameters['id']!),
          locationId: int.tryParse(s.uri.queryParameters['loc'] ?? '') ?? 0,
          header: s.extra is Map<String, dynamic>
              ? s.extra as Map<String, dynamic>
              : null,
        ),
      ),

      GoRoute(path: '/documents', builder: (_, __) => const DocumentListScreen()),
      GoRoute(
        path: '/documents/:id',
        builder: (_, s) =>
            DocumentDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),

      GoRoute(
        path: '/daily-collection',
        builder: (_, __) => const DailyCollectionScreen(),
      ),

      GoRoute(path: '/locations', builder: (_, __) => const LocationListScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UserListScreen()),
    ],
    errorBuilder: (_, s) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No screen for ${s.uri}')),
    ),
  );
});
