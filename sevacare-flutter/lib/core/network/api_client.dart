import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  late final Dio _dio;
  String? _token;
  String? _tenantId;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
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
