import 'package:dio/dio.dart';
import '../network/api_client.dart';

/// Extracts a user-friendly error message from any exception thrown by [ApiClient].
///
/// [ApiClient] wraps Dio errors so that `DioException.error` is an [ApiException]
/// carrying the clean `message` field from the server's JSON response body.
/// If the exception is not a [DioException] with an [ApiException], a
/// generic [fallback] message is returned instead.
String extractErrorMessage(Object e, {String fallback = 'Something went wrong. Please try again.'}) {
  if (e is DioException && e.error is ApiException) {
    return (e.error as ApiException).message;
  }
  return fallback;
}
