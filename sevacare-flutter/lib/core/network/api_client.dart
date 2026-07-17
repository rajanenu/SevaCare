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

  /// Called when the server returns HTTP 401 and the session could not be
  /// silently refreshed (or there was nothing to refresh with).
  VoidCallback? onUnauthorized;

  /// Called on a 401 to attempt a silent session refresh. Returns the new
  /// access token, or null when the session is truly over — then
  /// [onUnauthorized] runs and the user is signed out.
  Future<String?> Function()? onTokenRefresh;

  Future<String?>? _refreshInFlight;

  /// Single-flight: a burst of 401s (a dashboard fans out several calls the
  /// moment the token expires) must produce one refresh, not five — each
  /// rotation kills the previous refresh token, so parallel refreshes would
  /// revoke each other and log the user out of a perfectly good session.
  Future<String?> _refreshOnce() {
    return _refreshInFlight ??=
        onTokenRefresh!().whenComplete(() => _refreshInFlight = null);
  }

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
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode ?? 0;
        // A 401 first gets one shot at a silent refresh + retry. Never for
        // /auth/ calls (a failed login is not an expired session, and the
        // refresh call itself must not recurse), and never twice for the same
        // request — the `extra` flag survives into the retried options.
        if (statusCode == 401 &&
            onTokenRefresh != null &&
            !error.requestOptions.path.startsWith('/auth') &&
            error.requestOptions.extra['authRetried'] != true) {
          String? newToken;
          try {
            newToken = await _refreshOnce();
          } catch (_) {
            newToken = null;
          }
          if (newToken != null && newToken.isNotEmpty) {
            final retry = error.requestOptions;
            retry.extra['authRetried'] = true;
            retry.headers['Authorization'] = 'Bearer $newToken';
            try {
              handler.resolve(await _dio.fetch(retry));
            } on DioException catch (retryError) {
              // The retry re-entered this interceptor, which already converted
              // it (and fired onUnauthorized if it 401'd again).
              handler.reject(retryError);
            }
            return;
          }
        }
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

  /// A GET is idempotent, so a *transient* failure — a dropped connection or
  /// timeout on a spotty mobile network, or a 502/503/504 from a Cloud Run
  /// instance that is cold-starting or being relocated — is worth a couple of
  /// automatic retries with a short backoff before it ever reaches the caller.
  /// Writes (POST/PUT/PATCH/DELETE) are deliberately NOT retried here: their
  /// safety comes from the server-side Idempotency-Key, not blind resend.
  ///
  /// By the time an error surfaces it has passed through the interceptor above,
  /// which reduces every failure to an [ApiException] — statusCode 0 means the
  /// request never got an HTTP answer (network/timeout). A real 4xx (400/401/
  /// 403/404/409) is an answer, not a blip, and is surfaced immediately.
  static const int _getMaxAttempts = 3;

  bool _isTransient(Object error) {
    if (error is DioException && error.error is ApiException) {
      final code = (error.error as ApiException).statusCode;
      return code == 0 || code == 502 || code == 503 || code == 504;
    }
    return false;
  }

  Future<Response<dynamic>> _getWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await _dio.get(path, queryParameters: queryParameters, options: options);
      } on DioException catch (e) {
        // A malformed local path ("//") is a caller bug, not a blip — never retry it.
        final malformed = !path.startsWith('http') && path.contains('//');
        if (attempt >= _getMaxAttempts || malformed || !_isTransient(e)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  Future<T> get<T>(String path, {
    T Function(dynamic)? fromJson,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _getWithRetry(
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

    final response = await _getWithRetry(
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
