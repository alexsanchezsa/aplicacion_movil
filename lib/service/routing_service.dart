import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Origen de la ruta devuelta
enum RouteSource {
  /// Calculada ahora mismo desde OSRM (online)
  online,
  /// Recuperada de caché en memoria (calculada previamente online)
  cached,
}

class RouteResult {
  final List<LatLng> points;
  final RouteSource source;

  const RouteResult({required this.points, required this.source});
}

/// Se lanza cuando no hay conexión y tampoco existe ruta en caché.
class OfflineRoutingException implements Exception {
  final String message;
  const OfflineRoutingException(this.message);
  @override
  String toString() => message;
}

/// Servicio de routing.
///
/// Con cobertura: consulta OSRM (gratuito, sin API key) para la ruta real
/// por carreteras evitando obstáculos.
/// Sin cobertura: devuelve la última ruta guardada en caché para ese paciente.
/// Si no existe caché, lanza [OfflineRoutingException].
///
/// La caché es en memoria (dura mientras la app esté activa). Si se necesita
/// persistencia entre sesiones se puede migrar a SharedPreferences.
class RoutingService {
  static const String _osrmBase = 'http://router.project-osrm.org';

  // Caché en memoria: clave = ID del paciente, valor = puntos de la ruta
  static final Map<String, List<LatLng>> _cache = {};

  /// Devuelve la ruta desde [origin] hasta [destination].
  ///
  /// [cacheKey] es el ID del paciente para cachear/recuperar la ruta.
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    required bool isOnline,
    required String cacheKey,
  }) async {
    if (isOnline) {
      try {
        final points = await _fetchOsrmRoute(origin, destination);
        _cache[cacheKey] = points; // guardar en caché
        return RouteResult(points: points, source: RouteSource.online);
      } catch (e) {
        print('[Routing] ⚠️ OSRM falló: $e');
        // Intentar caché antes de fallar
        final cached = _cache[cacheKey];
        if (cached != null) {
          return RouteResult(points: cached, source: RouteSource.cached);
        }
        rethrow;
      }
    }

    // Sin cobertura: intentar caché
    final cached = _cache[cacheKey];
    if (cached != null) {
      return RouteResult(points: cached, source: RouteSource.cached);
    }

    throw const OfflineRoutingException(
      'Sin conexión y sin ruta guardada.\n'
      'Conéctate a internet para calcular la ruta.',
    );
  }

  Future<List<LatLng>> _fetchOsrmRoute(LatLng o, LatLng d) async {
    final uri = Uri.parse(
      '$_osrmBase/route/v1/driving/'
      '${o.longitude},${o.latitude};'
      '${d.longitude},${d.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) throw Exception('Sin ruta');

    // OSRM devuelve [longitude, latitude]
    final coords = routes[0]['geometry']['coordinates'] as List;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }
}
