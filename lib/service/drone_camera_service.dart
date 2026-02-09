import 'dart:async';
import 'dart:convert';
import 'package:aplicacion_movil/models/drone_camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar las cámaras de drones
/// Proporciona cámaras simuladas para desarrollo y soporte para API real
class DroneCameraService {
  static DroneCameraService? _instance;
  static DroneCameraService get instance => _instance ??= DroneCameraService._();
  
  DroneCameraService._();

  // URL base del servidor API (configurable)
  String? _apiBaseUrl;
  
  // Cache de cámaras
  List<DroneCamera> _cachedCameras = [];
  DateTime? _lastFetch;
  
  // Tiempo de cache en segundos
  static const int _cacheDuration = 30;

  /// Configurar URL del servidor API
  void setApiUrl(String url) {
    _apiBaseUrl = url;
    _cachedCameras = [];
    _lastFetch = null;
  }

  /// Obtener lista de cámaras disponibles
  /// Si no hay API configurada, devuelve cámaras simuladas
  Future<List<DroneCamera>> fetchCameras({bool forceRefresh = false}) async {
    // Usar cache si está disponible y no ha expirado
    if (!forceRefresh && 
        _cachedCameras.isNotEmpty && 
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inSeconds < _cacheDuration) {
      return _cachedCameras;
    }

    try {
      if (_apiBaseUrl != null && _apiBaseUrl!.isNotEmpty) {
        // Intentar obtener de API real
        _cachedCameras = await _fetchFromApi();
      } else {
        // Usar cámaras simuladas/guardadas localmente
        _cachedCameras = await _getLocalCameras();
      }
      
      _lastFetch = DateTime.now();
      return _cachedCameras;
    } catch (e) {
      print('Error fetching cameras: $e');
      // En caso de error, devolver cache o simuladas
      if (_cachedCameras.isNotEmpty) {
        return _cachedCameras;
      }
      return _getSimulatedCameras();
    }
  }

  /// Obtener cámaras desde API
  Future<List<DroneCamera>> _fetchFromApi() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/api/cameras'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => DroneCamera.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load cameras: ${response.statusCode}');
    }
  }

  /// Obtener cámaras guardadas localmente
  Future<List<DroneCamera>> _getLocalCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = prefs.getString('drone_cameras');
    
    if (camerasJson != null && camerasJson.isNotEmpty) {
      try {
        final List<dynamic> data = json.decode(camerasJson);
        final cameras = data.map((json) => DroneCamera.fromJson(json)).toList();
        if (cameras.isNotEmpty) {
          return cameras;
        }
      } catch (e) {
        print('Error parsing local cameras: $e');
      }
    }
    
    // Si no hay cámaras guardadas, usar simuladas
    return _getSimulatedCameras();
  }

  /// Guardar cámaras localmente
  Future<void> saveCamerasLocally(List<DroneCamera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = json.encode(cameras.map((c) => c.toJson()).toList());
    await prefs.setString('drone_cameras', camerasJson);
    _cachedCameras = cameras;
  }

  /// Agregar una nueva cámara
  Future<void> addCamera(DroneCamera camera) async {
    final cameras = await _getLocalCameras();
    
    // Verificar si ya existe
    final existingIndex = cameras.indexWhere((c) => c.id == camera.id);
    if (existingIndex >= 0) {
      cameras[existingIndex] = camera;
    } else {
      cameras.add(camera);
    }
    
    await saveCamerasLocally(cameras);
  }

  /// Eliminar una cámara
  Future<void> removeCamera(String cameraId) async {
    final cameras = await _getLocalCameras();
    cameras.removeWhere((c) => c.id == cameraId);
    await saveCamerasLocally(cameras);
  }

  /// Verificar si una cámara está online
  Future<bool> checkCameraStatus(DroneCamera camera) async {
    try {
      // Para cámaras RTSP/RTMP, no podemos hacer ping HTTP directamente
      // Retornamos el estado guardado o intentamos conexión si es HTTP
      if (camera.type == DroneCameraType.http || 
          camera.type == DroneCameraType.hls ||
          camera.type == DroneCameraType.mjpeg) {
        final response = await http.head(
          Uri.parse(camera.streamUrl),
        ).timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      }
      
      // Para RTSP/RTMP, asumimos online si está configurada
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cámaras simuladas para desarrollo y demostración
  List<DroneCamera> _getSimulatedCameras() {
    return [
      DroneCamera(
        id: 'drone_001',
        name: 'Dron Rescate Alpha',
        streamUrl: 'rtsp://demo.server.com/drone1',
        isOnline: true,
        lastSeen: DateTime.now(),
        location: 'Zona Norte - Sector A',
        description: 'Dron principal de búsqueda',
        type: DroneCameraType.rtsp,
      ),
      DroneCamera(
        id: 'drone_002',
        name: 'Dron Rescate Beta',
        streamUrl: 'rtsp://demo.server.com/drone2',
        isOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
        location: 'Zona Sur - Sector B',
        description: 'Dron de reconocimiento',
        type: DroneCameraType.rtsp,
      ),
      DroneCamera(
        id: 'drone_003',
        name: 'Dron Vigilancia Gamma',
        streamUrl: 'http://demo.server.com/stream/drone3.m3u8',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        location: 'Base Central',
        description: 'En mantenimiento',
        type: DroneCameraType.hls,
      ),
      DroneCamera(
        id: 'drone_004',
        name: 'Dron Exploración Delta',
        streamUrl: 'rtsp://demo.server.com/drone4',
        isOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
        location: 'Zona Este - Montaña',
        description: 'Área de difícil acceso',
        type: DroneCameraType.rtsp,
      ),
      DroneCamera(
        id: 'cam_fija_001',
        name: 'Cámara Fija Base',
        streamUrl: 'http://demo.server.com/cameras/base.mjpeg',
        isOnline: true,
        lastSeen: DateTime.now(),
        location: 'Centro de operaciones',
        description: 'Vigilancia 24/7',
        type: DroneCameraType.mjpeg,
      ),
    ];
  }

  /// Limpiar cache
  void clearCache() {
    _cachedCameras = [];
    _lastFetch = null;
  }
}
