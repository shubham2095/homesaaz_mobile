// lib/features/home_stay/stay.dart

/// ALFOHOMES (formerly Home Stay) and Pearl Stay are the same four hostel
/// screens — Pending Rent, Student Details, Bed Occupancy, New Student — over
/// two databases. The backend exposes them as `/homestay/...` and
/// `/pearlstay/...` with identical response shapes, so one set of screens
/// serves both; a [Stay] says which.
enum Stay {
  home(
    title: 'ALFOHOMES',
    apiBase: '/homestay',
    hubRoute: '/home-stay',
    pendingRentRoute: '/pending-rent',
    studentsRoute: '/students',
    bedOccupancyRoute: '/bed-occupancy',
    newStudentsRoute: '/new-students',
  ),
  pearl(
    title: 'PEARL STAY',
    apiBase: '/pearlstay',
    hubRoute: '/pearl-stay',
    pendingRentRoute: '/pearl-stay/pending-rent',
    studentsRoute: '/pearl-stay/students',
    bedOccupancyRoute: '/pearl-stay/bed-occupancy',
    newStudentsRoute: '/pearl-stay/new-students',
  );

  const Stay({
    required this.title,
    required this.apiBase,
    required this.hubRoute,
    required this.pendingRentRoute,
    required this.studentsRoute,
    required this.bedOccupancyRoute,
    required this.newStudentsRoute,
  });

  /// Screen title of the hub.
  final String title;

  /// Prefix of the API endpoints, e.g. `/homestay` -> `/homestay/pending-rent/datatable`.
  final String apiBase;

  final String hubRoute;
  final String pendingRentRoute;
  final String studentsRoute;
  final String bedOccupancyRoute;
  final String newStudentsRoute;
}
