import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as native;
import '../config/app_config.dart';

/// Minimal locality + pincode resolved from GPS coordinates.
class GeoPlace {
  final String? locality;
  final String? pincode;
  const GeoPlace({this.locality, this.pincode});

  bool get isEmpty => (locality == null || locality!.isEmpty);
}

/// Reverse-geocode coordinates to a place name, choosing an implementation
/// that actually works on the current platform.
///
/// The `geocoding` plugin (`placemarkFromCoordinates`) only ships Android and
/// iOS implementations. On Flutter **web** and **desktop** it throws
/// `MissingPluginException`, which previously left the location label blank on
/// the Cloud Run web build. We keep the fast native path for mobile and fall
/// back to OpenStreetMap Nominatim (no API key) for web/desktop.
Future<GeoPlace?> reverseGeocode(double lat, double lng) async {
  final useNative = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (useNative) {
    final placemarks = await native.placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;
    return GeoPlace(
      locality: p.locality ?? p.subAdministrativeArea,
      pincode: p.postalCode,
    );
  }

  return _backendReverse(lat, lng);
}

/// Web + desktop reverse geocoding via our own backend proxy.
///
/// We can't call OpenStreetMap Nominatim from the browser — it returns no CORS
/// header (the browser blocks it) and its policy needs a User-Agent browsers
/// won't set. The backend (`/public/geo/reverse`) does the lookup server-side
/// and returns `{locality, pincode}` inside the standard `data` envelope.
Future<GeoPlace?> _backendReverse(double lat, double lng) async {
  try {
    final dio = Dio();
    final resp = await dio.get(
      '${AppConfig.apiBaseUrl}/public/geo/reverse',
      queryParameters: {'lat': lat, 'lng': lng},
      options: Options(responseType: ResponseType.json),
    );

    final body = resp.data;
    final data = (body is Map) ? body['data'] as Map? : null;
    if (data == null) return null;

    return GeoPlace(
      locality: data['locality']?.toString(),
      pincode: data['pincode']?.toString(),
    );
  } catch (_) {
    return null;
  }
}
