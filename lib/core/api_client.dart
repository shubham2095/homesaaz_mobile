// lib/core/api_client.dart
import 'package:dio/dio.dart';

import 'auth_store.dart';
import 'config.dart';

/// Normalised error surfaced to the UI.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isAuth = false});

  final String message;
  final int? statusCode;
  final bool isAuth;

  @override
  String toString() => message;
}

/// Thin wrapper over Dio that:
///  * injects the bearer token
///  * turns non-2xx / network failures into [ApiException]
///  * unwraps the `{ success, data, meta }` envelope
class ApiClient {
  ApiClient(this._auth, {this.onUnauthorized}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {'Accept': 'application/json'},
        // we handle status codes ourselves
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AuthStore _auth;
  final Future<void> Function()? onUnauthorized;
  late final Dio dio;

  // ---- verbs -------------------------------------------------------------

  Future<Map<String, dynamic>> getRaw(
    String path, {
    Map<String, dynamic>? query,
    bool logoutOn401 = true,
    // Lets a caller give a slow, unfiltered report-style query (e.g.
    // Attendance with no location picked) more room than the default.
    Duration? receiveTimeout,
  }) async {
    return _send(
      () => dio.get(
        path,
        queryParameters: _clean(query),
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      ),
      logoutOn401: logoutOn401,
    );
  }

  /// GET a paginated list. Always sends `page` / `per_page` and the
  /// DataTables `start` / `length` / `draw`, so it fits every list endpoint.
  ///
  /// The search term goes out as `search[value]` (DataTables controllers)
  /// unless [dataTableSearch] is false, in which case it goes as a plain
  /// scalar `search` (the Stock controller). The two must never be sent
  /// together — PHP would coerce `search` into an array.
  Future<Map<String, dynamic>> listRaw(
    String path, {
    required int page,
    required int perPage,
    String search = '',
    bool dataTableSearch = true,
    bool logoutOn401 = true,
    Map<String, dynamic>? extra,
  }) async {
    final start = (page - 1) * perPage;
    final q = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'start': start,
      'length': perPage,
      'draw': page,
      if (dataTableSearch) 'search[value]': search else 'search': search,
      ...?extra,
    };
    return _send(() => dio.get(path, queryParameters: _clean(q)),
        logoutOn401: logoutOn401);
  }

  Future<Map<String, dynamic>> postRaw(
    String path, {
    Object? body,
  }) async {
    return _send(() => dio.post(path, data: body));
  }

  /// Multipart upload: sends [fields] + one file [filePath] under [fileField].
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, dynamic> fields = const {},
  }) async {
    final form = FormData.fromMap({
      ...fields,
      fileField: await MultipartFile.fromFile(filePath),
    });
    return _send(() => dio.post(path, data: form));
  }

  /// Multipart POST with [fields] and an OPTIONAL file. Use when a file
  /// may or may not be attached (e.g. editing a record).
  Future<Map<String, dynamic>> postForm(
    String path, {
    Map<String, dynamic> fields = const {},
    String? filePath,
    String fileField = 'file',
  }) async {
    final map = <String, dynamic>{...fields};
    if (filePath != null && filePath.isNotEmpty) {
      map[fileField] = await MultipartFile.fromFile(filePath);
    }
    // ListFormat.multi (FormData.fromMap's default) sends every item of a
    // scalar list under the exact same bare field name with no `[]`
    // suffix (e.g. repeated `field_permissions[Accounts]`) — PHP keeps
    // only the last one, so Laravel sees a string instead of an array.
    // multiCompatible appends `[]` to each item so the array survives.
    return _send(
      () => dio.post(
        path,
        data: FormData.fromMap(map, ListFormat.multiCompatible),
      ),
    );
  }

  /// DELETE returning the `{ success, message }` envelope.
  Future<Map<String, dynamic>> deleteRaw(String path) async {
    return _send(() => dio.delete(path));
  }

  /// GET that returns just the `data` payload (object or list).
  Future<dynamic> getData(String path, {Map<String, dynamic>? query}) async {
    final body = await getRaw(path, query: query);
    return body['data'];
  }

  /// GET a binary file (e.g. a PDF). Returns the raw bytes.
  ///
  /// Server-rendered PDFs (GRN) can take well over a minute — the backend
  /// itself allows up to 180s — so this uses a longer receive timeout than
  /// the default JSON calls.
  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? query,
    Duration receiveTimeout = const Duration(seconds: 150),
  }) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
        ),
      );
      if (res.statusCode == 200 && res.data != null) return res.data!;
      throw ApiException(
        'Download failed (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  // ---- internals -------------------------------------------------------

  Future<Map<String, dynamic>> _send(
    Future<Response> Function() request, {
    bool logoutOn401 = true,
  }) async {
    Response res;
    try {
      res = await request();
    } on DioException catch (e) {
      throw _fromDio(e);
    }

    final code = res.statusCode ?? 0;
    final data = res.data;
    final body = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{'data': data};

    if (code == 401) {
      // Only tear down the session if the caller allows it AND we still
      // hold a token (a genuine reject, not a transient missing header /
      // a flaky endpoint).
      if (logoutOn401) {
        final tok = await _auth.readToken();
        if (tok != null && tok.isNotEmpty) {
          await onUnauthorized?.call();
        }
      }
      throw ApiException(
        _msg(body) ?? 'Your session has expired. Please sign in again.',
        statusCode: 401,
        isAuth: true,
      );
    }

    if (code < 200 || code >= 300 || body['success'] == false) {
      throw ApiException(
        _msg(body) ?? 'Request failed (HTTP $code).',
        statusCode: code,
      );
    }

    return body;
  }

  String? _msg(Map<String, dynamic> body) {
    final m = body['message'];
    if (m is String && m.trim().isNotEmpty) return m;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return null;
  }

  ApiException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('The server took too long to respond.');
      case DioExceptionType.connectionError:
        return ApiException(
          'Cannot reach the server. Check your connection and the API URL.',
        );
      default:
        return ApiException(e.message ?? 'Network error.');
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}
