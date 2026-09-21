// lib/core/config.dart
//
// Base URL of the Laravel API, including the /api/v1 prefix.
//
// Override at run/build time:
//   flutter run   --dart-define=API_BASE_URL=http://192.168.1.5:8000/api
//   flutter build apk --release --dart-define=API_BASE_URL=https://api.homesaaz.in/api
//
// Notes:
//  * Android emulator reaches the host machine's localhost as 10.0.2.2
//  * A physical phone must use the PC's LAN IP (same Wi-Fi), e.g. 192.168.x.x
//  * Release builds should always point at an https:// host
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://web.homesaaz.in:84/api',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  // Gate Entry / GRN run heavy SQL Server stored procs — give them room.
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Default page size for list screens.
  static const int pageSize = 20;
}
