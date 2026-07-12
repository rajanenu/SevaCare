import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The result of a conditional GET: either a fresh body with the tag it carries,
/// or word that the tag the caller sent is still current and it should use what it
/// already has.
class Revalidated<T> {
  final T? data;
  final String? etag;
  final bool notModified;

  const Revalidated({this.data, this.etag, this.notModified = false});
}

class ApiClient {
  late final Dio _dio;
  String? _token;
  String? _tenantId;

  /// Called when the server returns HTTP 401 (session expired / unauthorized).
  VoidCallback? onUnauthorized;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.connectTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // A path built from a missing id collapses an empty segment into the URL
        // ('/admin//overview'). The server matches no handler and answers 401, which
        // the error branch below reads as "your token died" and signs the user out —
        // so one unset id silently destroys a perfectly good session. Refuse to send
        // it: fail here, loudly and locally, where the caller's bug is visible.
        final isAbsolute = options.path.startsWith('http');
        if (!isAbsolute && options.path.contains('//')) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: ApiException(0,
                  'Malformed request: "${options.path}" is missing a path parameter.'),
              message: 'Malformed request path: ${options.path}',
            ),
            true,
          );
          return;
        }
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        if (_tenantId != null) {
          options.headers['X-Tenant-Id'] = _tenantId;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 401 && onUnauthorized != null) {
          onUnauthorized!();
        }
        final message = _extractMessage(error.response?.data) ??
            error.message ??
            'Request failed ($statusCode)';
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: ApiException(statusCode, message),
          message: message,
        ));
      },
    ));
  }

  void setAuth(String token, String tenantId) {
    _token = token;
    _tenantId = tenantId;
  }

  void clearAuth() {
    _token = null;
    _tenantId = null;
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) return data['message'] as String?;
    return null;
  }

  Future<T> get<T>(String path, {
    T Function(dynamic)? fromJson,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.get(
      path,
      queryParameters: queryParams,
      options: Options(headers: extraHeaders),
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return fromJson != null ? fromJson(data) : data as T;
  }

  /// A conditional GET: sends the [etag] the caller already holds and lets the
  /// server answer "still current" instead of resending the body.
  ///
  /// Needs its own method because Dio counts any non-2xx as a failure, and a 304
  /// is the opposite of a failure — it is the cheapest possible success.
  Future<Revalidated<T>> getIfChanged<T>(String path, {
    T Function(dynamic)? fromJson,
    String? etag,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{...?extraHeaders};
    if (etag != null) headers['If-None-Match'] = etag;

    final response = await _dio.get(
      path,
      options: Options(
        headers: headers,
        validateStatus: (s) => s != null && ((s >= 200 && s < 300) || s == 304),
      ),
    );
    if (response.statusCode == 304) {
      return Revalidated<T>(notModified: true, etag: etag);
    }
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return Revalidated<T>(
      data: fromJson != null ? fromJson(data) : data as T,
      etag: response.headers.value('etag'),
    );
  }

  Future<T> post<T>(String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.post(
      path,
      data: body,
      options: Options(headers: extraHeaders),
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return fromJson != null ? fromJson(data) : data as T;
  }

  Future<T> put<T>(String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.put(
      path,
      data: body,
      options: Options(headers: extraHeaders),
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return fromJson != null ? fromJson(data) : data as T;
  }

  Future<T> patch<T>(String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.patch(
      path,
      data: body,
      options: Options(headers: extraHeaders),
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return fromJson != null ? fromJson(data) : data as T;
  }

  Future<T> delete<T>(String path, {
    T Function(dynamic)? fromJson,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.delete(
      path,
      options: Options(headers: extraHeaders),
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'];
    return fromJson != null ? fromJson(data) : data as T;
  }
}

// Singleton
final apiClient = ApiClient();
