import 'dart:async';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart' as loc;

/// Servicio singleton para gestionar MapLibre de forma global
/// Soporta tiles vectoriales (PBF) offline con MBTiles
class MapLibreService {
  // SINGLETON
  static final MapLibreService _instance = MapLibreService._internal();
  factory MapLibreService() => _instance;
  MapLibreService._internal();

  // ESTADO

  // Ubicación
  LatLng _currentPosition = const LatLng(
    40.416775,
    -3.703790,
  ); // Madrid default
  LatLng get currentPosition => _currentPosition;

  // MBTiles path
  String? _mbtilesPath;
  String? get mbtilesPath => _mbtilesPath;

  // Estado del archivo MBTiles
  bool _hasMbTiles = false;
  bool get hasMbTiles => _hasMbTiles;

  // Rango de zoom del archivo spain.mbtiles
  static const int minTileZoom = 0;
  static const int maxTileZoom = 14;

  // Estado de descarga del mapa
  bool _needsDownload = false;
  bool get needsMapDownload => _needsDownload;

  // Estado de carga
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool get isReady => _isInitialized;
  bool get isLoading => _isInitializing;

  // Completers para esperar inicialización
  Completer<void>? _initCompleter;

  // Stream para notificar cambios
  final _locationController = StreamController<LatLng>.broadcast();
  Stream<LatLng> get locationStream => _locationController.stream;

  // Suscripción al GPS en tiempo real
  StreamSubscription<loc.LocationData>? _gpsSubscription;
  loc.Location? _locationInstance;

  // INICIALIZACIÓN

  Future<void> initialize() async {
    if (_isInitialized) {
      print('[MapLibreService] ✅ Ya inicializado, usando cache');
      return;
    }

    if (_isInitializing && _initCompleter != null) {
      print('[MapLibreService] ⏳ Esperando inicialización en curso...');
      await _initCompleter!.future;
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    final stopwatch = Stopwatch()..start();
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║     MAPLIBRE SERVICE - INICIALIZACIÓN (Vector Tiles)      ║');
    print('╚═══════════════════════════════════════════════════════════╝');

    try {
      // PASO 1: Obtener ubicación GPS
      print('[MapLibreService] 📍 Paso 1/3: Obteniendo ubicación GPS...');
      await _fetchLocation();
      print(
        '[MapLibreService] ✅ Ubicación: ${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
      );

      // PASO 2: Verificar MBTiles
      print('[MapLibreService] 🗺️ Paso 2/3: Verificando MBTiles...');
      await _checkMbTiles();

      // PASO 3: Iniciar GPS continuo
      print('[MapLibreService] 📡 Paso 3/3: Iniciando GPS continuo...');
      await startContinuousLocationUpdates();

      _isInitialized = true;
      stopwatch.stop();
      print('╔═══════════════════════════════════════════════════════════╗');
      print(
        '║  ✅ MAPLIBRE SERVICE LISTO - ${stopwatch.elapsedMilliseconds}ms                        ║',
      );
      print('╚═══════════════════════════════════════════════════════════╝\n');
    } catch (e) {
      print('[MapLibreService] ❌ Error en inicialización: $e');
      _isInitialized = true;
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
    }
  }

  Future<void> waitUntilReady() async {
    if (_isInitialized) return;
    if (!_isInitializing) {
      await initialize();
      return;
    }
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UBICACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchLocation() async {
    try {
      final location = loc.Location();

      if (!await location.serviceEnabled()) {
        if (!await location.requestService()) {
          print('[MapLibreService] ⚠️ Servicio GPS desactivado');
          return;
        }
      }

      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) {
          print('[MapLibreService] ⚠️ Permiso GPS denegado');
          return;
        }
      }

      await location.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );

      final locationData = await location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        _currentPosition = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        _locationController.add(_currentPosition);
      }
    } catch (e) {
      print('[MapLibreService] ⚠️ Error GPS: $e');
      _locationController.add(_currentPosition);
    }
  }

  Future<void> startContinuousLocationUpdates() async {
    if (_gpsSubscription != null) return;

    try {
      _locationInstance ??= loc.Location();

      await _locationInstance!.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 2000,
        distanceFilter: 1,
      );

      _gpsSubscription = _locationInstance!.onLocationChanged.listen(
        (loc.LocationData locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            _currentPosition = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
            _locationController.add(_currentPosition);
          }
        },
        onError: (e) {
          print('[MapLibreService] ⚠️ Error GPS continuo: $e');
        },
      );

      print('[MapLibreService] ✅ GPS continuo iniciado');
    } catch (e) {
      print('[MapLibreService] ⚠️ Error iniciando GPS continuo: $e');
    }
  }

  void stopContinuousLocationUpdates() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  Future<void> refreshLocation() async {
    await _fetchLocation();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MBTILES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _checkMbTiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _mbtilesPath = '${appDir.path}/spain.mbtiles';
      final file = File(_mbtilesPath!);

      if (await file.exists()) {
        final size = await file.length();
        print(
          '[MapLibreService] 📂 MBTiles encontrado (${(size / 1024 / 1024).toStringAsFixed(1)} MB)',
        );

        if (size < 100 * 1024 * 1024) {
          print('[MapLibreService] ⚠️ Archivo muy pequeño, requiere descarga');
          await file.delete();
          _needsDownload = true;
          _hasMbTiles = false;
          return;
        }

        _hasMbTiles = true;
        _needsDownload = false;
        print('[MapLibreService] ✅ MBTiles listo para usar offline');
      } else {
        print('[MapLibreService] ⚠️ MBTiles no encontrado - requiere descarga');
        _needsDownload = true;
        _hasMbTiles = false;
      }
    } catch (e) {
      print('[MapLibreService] ❌ Error verificando MBTiles: $e');
      _hasMbTiles = false;
      _needsDownload = true;
    }
  }

  Future<bool> reloadAfterDownload() async {
    await _checkMbTiles();
    return _hasMbTiles;
  }

  /// Alias para compatibilidad - Recarga el MBTiles después de descarga
  Future<void> loadTileProviderAfterDownload() async {
    await reloadAfterDownload();
  }

  /// Genera el JSON de estilo para MapLibre usando MBTiles offline
  String getOfflineStyleJson() {
    if (_mbtilesPath == null) return '';

    // Estilo básico para tiles vectoriales OpenMapTiles
    return '''
{
  "version": 8,
  "name": "Offline Spain",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "mbtiles://$_mbtilesPath"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f8f4f0"
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": "#a0c8f0"
      }
    },
    {
      "id": "landcover-grass",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["==", "class", "grass"],
      "paint": {
        "fill-color": "#d8e8c8"
      }
    },
    {
      "id": "landcover-wood",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landcover",
      "filter": ["==", "class", "wood"],
      "paint": {
        "fill-color": "#c0d8a0"
      }
    },
    {
      "id": "landuse-residential",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landuse",
      "filter": ["==", "class", "residential"],
      "paint": {
        "fill-color": "#f0e8e0"
      }
    },
    {
      "id": "landuse-commercial",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "landuse",
      "filter": ["==", "class", "commercial"],
      "paint": {
        "fill-color": "#f8e8e0"
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "building",
      "paint": {
        "fill-color": "#d8d0c8",
        "fill-opacity": 0.8
      }
    },
    {
      "id": "road-motorway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["==", "class", "motorway"],
      "paint": {
        "line-color": "#ffa040",
        "line-width": 3
      }
    },
    {
      "id": "road-primary",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["==", "class", "primary"],
      "paint": {
        "line-color": "#ffc080",
        "line-width": 2
      }
    },
    {
      "id": "road-secondary",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["==", "class", "secondary"],
      "paint": {
        "line-color": "#ffffff",
        "line-width": 1.5
      }
    },
    {
      "id": "road-street",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["in", "class", "minor", "service", "street"],
      "paint": {
        "line-color": "#ffffff",
        "line-width": 1
      }
    },
    {
      "id": "railway",
      "type": "line",
      "source": "openmaptiles",
      "source-layer": "transportation",
      "filter": ["==", "class", "rail"],
      "paint": {
        "line-color": "#808080",
        "line-width": 1,
        "line-dasharray": [3, 3]
      }
    },
    {
      "id": "place-city",
      "type": "symbol",
      "source": "openmaptiles",
      "source-layer": "place",
      "filter": ["==", "class", "city"],
      "layout": {
        "text-field": "{name}",
        "text-size": 14,
        "text-anchor": "center"
      },
      "paint": {
        "text-color": "#333333",
        "text-halo-color": "#ffffff",
        "text-halo-width": 1
      }
    },
    {
      "id": "place-town",
      "type": "symbol",
      "source": "openmaptiles",
      "source-layer": "place",
      "filter": ["==", "class", "town"],
      "layout": {
        "text-field": "{name}",
        "text-size": 12,
        "text-anchor": "center"
      },
      "paint": {
        "text-color": "#444444",
        "text-halo-color": "#ffffff",
        "text-halo-width": 1
      }
    },
    {
      "id": "place-village",
      "type": "symbol",
      "source": "openmaptiles",
      "source-layer": "place",
      "filter": ["==", "class", "village"],
      "layout": {
        "text-field": "{name}",
        "text-size": 10,
        "text-anchor": "center"
      },
      "paint": {
        "text-color": "#555555",
        "text-halo-color": "#ffffff",
        "text-halo-width": 1
      }
    }
  ]
}
''';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  void reset() {
    stopContinuousLocationUpdates();
    _locationInstance = null;
    _isInitialized = false;
    _isInitializing = false;
    _initCompleter = null;
    _hasMbTiles = false;
    _needsDownload = false;
    print('[MapLibreService] 🔄 Servicio reiniciado');
  }

  void dispose() {
    stopContinuousLocationUpdates();
    _locationController.close();
  }
}
