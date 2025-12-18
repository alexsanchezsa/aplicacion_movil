import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:aplicacion_movil/service/custom_mbtiles_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart' as loc;

/// Servicio singleton para gestionar el mapa de forma global
/// Se precarga al iniciar sesión y mantiene el estado durante toda la app
class MapService {
  // SINGLETON
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  // ESTADO

  // Ubicación
  LatLng _currentPosition = const LatLng(
    40.416775,
    -3.703790,
  ); // Madrid default
  LatLng get currentPosition => _currentPosition;

  // MBTiles
  String? _mbtilesPath;
  TileProvider? _tileProvider;

  // Siempre usar tiles offline - NO hacer fallback a online
  TileProvider? get tileProvider => _tileProvider;
  bool get hasOfflineTiles => _tileProvider != null;

  // Rango de zoom del archivo spain.mbtiles (AJUSTAR según tu archivo)
  // Típicamente OpenStreetMap: zoom 5-14 o 5-16
  static const int minTileZoom = 5;
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

  // INICIALIZACIÓN (llamar después del login)

  /// Inicializa el servicio de mapa en segundo plano
  /// Llamar inmediatamente después del login exitoso
  Future<void> initialize() async {
    // Si ya está listo, no hacer nada
    if (_isInitialized) {
      print('[MapService] ✅ Ya inicializado, usando cache');
      return;
    }

    // Si ya está inicializando, esperar
    if (_isInitializing && _initCompleter != null) {
      print('[MapService] ⏳ Esperando inicialización en curso...');
      await _initCompleter!.future;
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    final stopwatch = Stopwatch()..start();
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║       MAP SERVICE - INICIALIZACIÓN EN SEGUNDO PLANO       ║');
    print('╚═══════════════════════════════════════════════════════════╝');

    try {
      // PASO 1: Obtener ubicación GPS (rápido, ~1-2s)
      print('[MapService] 📍 Paso 1/3: Obteniendo ubicación GPS...');
      await _fetchLocation();
      print(
        '[MapService] ✅ Ubicación: ${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
      );

      // PASO 2: Preparar MBTiles (puede tardar si es primera vez)
      print('[MapService] 🗺️ Paso 2/3: Preparando tiles offline...');
      await _prepareMbTiles();
      if (_tileProvider != null) {
        print('[MapService] ✅ Tiles offline listos');
      } else {
        print('[MapService] ⚠️ Usando tiles online (fallback)');
      }

      // PASO 3: Iniciar GPS continuo para actualizaciones en tiempo real
      print('[MapService] 📡 Paso 3/3: Iniciando GPS continuo...');
      await startContinuousLocationUpdates();

      _isInitialized = true;
      stopwatch.stop();
      print('╔═══════════════════════════════════════════════════════════╗');
      print(
        '║  ✅ MAP SERVICE LISTO - ${stopwatch.elapsedMilliseconds}ms                            ║',
      );
      print('╚═══════════════════════════════════════════════════════════╝\n');
    } catch (e) {
      print('[MapService] ❌ Error en inicialización: $e');
      _isInitialized = true; // Marcar como listo para evitar loops
    } finally {
      _isInitializing = false;
      _initCompleter?.complete();
    }
  }

  /// Espera a que el servicio esté listo
  /// Si no se ha iniciado, lo inicia automáticamente
  Future<void> waitUntilReady() async {
    if (_isInitialized) return;

    // Si no se está inicializando, iniciar ahora
    if (!_isInitializing) {
      await initialize();
      return;
    }

    // Si está inicializando, esperar
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

      // Verificar y solicitar servicio
      if (!await location.serviceEnabled()) {
        if (!await location.requestService()) {
          print('[MapService] ⚠️ Servicio GPS desactivado');
          return;
        }
      }

      // Verificar y solicitar permisos
      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) {
          print('[MapService] ⚠️ Permiso GPS denegado');
          return;
        }
      }

      // Configurar máxima precisión GPS
      await location.changeSettings(
        accuracy:
            loc.LocationAccuracy.high, // Máxima precisión (GPS + WiFi + Cell)
        interval: 1000, // Actualizar cada 1 segundo
        distanceFilter: 0, // Notificar cualquier cambio de distancia
      );
      print('[MapService] ⚙️ GPS configurado: alta precisión, intervalo 1s');

      // Obtener ubicación con timeout más largo para mejor precisión
      final locationData = await location.getLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        _currentPosition = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        final accuracy = locationData.accuracy ?? -1;
        print(
          '[MapService] 📍 Nueva ubicación: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)} (precisión: ${accuracy.toStringAsFixed(1)}m)',
        );
        _locationController.add(_currentPosition);
      } else {
        print('[MapService] ⚠️ GPS devolvió coordenadas nulas');
      }
    } catch (e) {
      print('[MapService] ⚠️ Error GPS: $e');
      // Mantener ubicación por defecto (Madrid)
      // Emitir la ubicación por defecto para que al menos se muestre algo
      _locationController.add(_currentPosition);
    }
  }

  /// Inicia la escucha continua del GPS para actualizaciones en tiempo real
  Future<void> startContinuousLocationUpdates() async {
    if (_gpsSubscription != null) {
      print('[MapService] 📡 GPS continuo ya está activo');
      return;
    }

    try {
      _locationInstance ??= loc.Location();

      // Configurar alta precisión
      await _locationInstance!.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 2000, // Cada 2 segundos
        distanceFilter: 1, // Mínimo 1 metro de cambio
      );

      _gpsSubscription = _locationInstance!.onLocationChanged.listen(
        (loc.LocationData locationData) {
          if (locationData.latitude != null && locationData.longitude != null) {
            _currentPosition = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
            final accuracy = locationData.accuracy ?? -1;
            print(
              '[MapService] 📡 GPS actualizado: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)} (±${accuracy.toStringAsFixed(1)}m)',
            );
            _locationController.add(_currentPosition);
          }
        },
        onError: (e) {
          print('[MapService] ⚠️ Error GPS continuo: $e');
        },
      );

      print('[MapService] ✅ GPS continuo iniciado (alta precisión)');
    } catch (e) {
      print('[MapService] ⚠️ Error iniciando GPS continuo: $e');
    }
  }

  /// Detiene la escucha continua del GPS
  void stopContinuousLocationUpdates() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    print('[MapService] 🛑 GPS continuo detenido');
  }

  /// Actualiza la ubicación actual (llamar cuando se necesite refresh)
  Future<void> refreshLocation() async {
    await _fetchLocation();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MBTILES - Usando spain.mbtiles (descargado desde servidor)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _prepareMbTiles() async {
    print('[MapService] 🗺️ Iniciando preparación de MBTiles...');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _mbtilesPath = '${appDir.path}/spain.mbtiles';
      final file = File(_mbtilesPath!);
      print('[MapService] 📁 Ruta MBTiles: $_mbtilesPath');

      // Verificar si ya existe el archivo descargado
      if (await file.exists()) {
        final size = await file.length();
        print(
          '[MapService] 📂 MBTiles existente (${(size / 1024 / 1024).toStringAsFixed(1)} MB)',
        );

        // Verificar que no sea muy pequeño (descarga incompleta)
        if (size < 100 * 1024 * 1024) {
          // Menos de 100 MB = incompleto
          print('[MapService] ⚠️ Archivo muy pequeño, marcando para descarga');
          await file.delete();
          _needsDownload = true;
          _tileProvider = null;
          return;
        }

        _tileProvider = CustomMbTilesTileProvider.fromPath(_mbtilesPath!);
        if (_tileProvider != null) {
          print('[MapService] ✅ TileProvider creado desde archivo existente');
          _needsDownload = false;
          return;
        } else {
          // Si falla, borrar el archivo corrupto
          print('[MapService] ⚠️ Archivo corrupto, borrando...');
          await file.delete();
        }
      }

      // Marcar que necesita descarga
      print('[MapService] ⚠️ spain.mbtiles no encontrado - requiere descarga');
      _needsDownload = true;
      _tileProvider = null;
    } catch (e, stackTrace) {
      print('[MapService] ❌ Error MBTiles: $e');
      print('[MapService] StackTrace: $stackTrace');
      _tileProvider = null;
      _needsDownload = true;
    }

    print(
      '[MapService] 📊 TileProvider: ${_tileProvider != null ? "OK" : "REQUIERE DESCARGA"}',
    );
  }

  /// Carga el TileProvider después de la descarga
  Future<bool> loadTileProviderAfterDownload() async {
    if (_mbtilesPath == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _mbtilesPath = '${appDir.path}/spain.mbtiles';
    }

    final file = File(_mbtilesPath!);
    if (!await file.exists()) {
      print('[MapService] ❌ Archivo no existe después de descarga');
      return false;
    }

    _tileProvider = CustomMbTilesTileProvider.fromPath(_mbtilesPath!);
    if (_tileProvider != null) {
      print('[MapService] ✅ TileProvider cargado después de descarga');
      _needsDownload = false;
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reinicia el servicio (usar en logout)
  void reset() {
    stopContinuousLocationUpdates();
    _tileProvider?.dispose();
    _tileProvider = null;
    _locationInstance = null;
    _isInitialized = false;
    _isInitializing = false;
    _initCompleter = null;
    _currentPosition = const LatLng(40.416775, -3.703790);
    print('[MapService] 🔄 Servicio reiniciado');
  }

  void dispose() {
    stopContinuousLocationUpdates();
    _tileProvider?.dispose();
    _locationController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ISOLATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _FileWriteParams {
  final String path;
  final Uint8List bytes;
  _FileWriteParams(this.path, this.bytes);
}

Future<void> _writeFile(_FileWriteParams params) async {
  await File(params.path).writeAsBytes(params.bytes, flush: true);
}
