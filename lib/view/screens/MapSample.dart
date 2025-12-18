import 'dart:async';
import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/map_service.dart';
import 'package:aplicacion_movil/view/screens/mainScreen.dart';
import 'package:aplicacion_movil/view/components/MarkerManager.dart';
import 'package:aplicacion_movil/view/components/HospitalMarker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  // Servicio singleton del mapa
  final MapService _mapService = MapService();

  // Controller del mapa
  late final MapController _mapController;

  // Estado local
  bool _isLoading = true;
  bool _mapReady = false;
  bool _showHospitals = true;

  // Marcadores
  final Set<Marker> _markers = {};
  Set<Marker> _personMarkers = {};
  Set<Marker> _hospitalMarkers = {};
  Marker? _myLocationMarker;

  // Managers
  late MarkerManager _markerManager;
  late HospitalManager _hospitalManager;

  // Subscripciones
  StreamSubscription<LatLng>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Inicializar managers
    _hospitalManager = HospitalManager(
      context: context,
      onHospitalsLoaded: (markers) {
        if (mounted) {
          setState(() {
            _hospitalMarkers = markers;
            _rebuildMarkers();
          });
        }
      },
    );

    _markerManager = MarkerManager(
      context: context,
      onMarkersUpdated: (markers) {
        if (mounted) {
          setState(() {
            _personMarkers = markers;
            _rebuildMarkers();
          });
        }
      },
    );

    // Escuchar cambios de ubicación del servicio
    _locationSubscription = _mapService.locationStream.listen((position) {
      print(
        '[MapScreen] 📡 Stream ubicación recibida: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
      if (mounted) {
        setState(() {
          _myLocationMarker = _buildLocationMarker(position);
          _rebuildMarkers();
        });
      }
    });

    _init();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _markerManager.dispose();
    _hospitalManager.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Inicialización principal
  Future<void> _init() async {
    print('[MapScreen] 🚀 Iniciando pantalla de mapa...');
    final sw = Stopwatch()..start();

    // Esperar a que el servicio esté listo (esto también lo inicializa si no lo está)
    print('[MapScreen] ⏳ Esperando MapService...');
    await _mapService.waitUntilReady();

    print(
      '[MapScreen] 📍 Ubicación actual: ${_mapService.currentPosition.latitude.toStringAsFixed(6)}, ${_mapService.currentPosition.longitude.toStringAsFixed(6)}',
    );

    // Crear marcador de ubicación inicial
    _myLocationMarker = _buildLocationMarker(_mapService.currentPosition);
    _rebuildMarkers();

    // Mostrar mapa y actualizar estado
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Cargar hospitales y marcadores en paralelo (no bloqueante)
    _loadBackgroundData();

    sw.stop();
    print('[MapScreen] ✅ Pantalla lista en ${sw.elapsedMilliseconds}ms');
    print('[MapScreen] 📌 Marcador de ubicación: $_myLocationMarker');
    print('[MapScreen] 📌 Total marcadores: ${_markers.length}');
  }

  /// Carga datos secundarios sin bloquear
  void _loadBackgroundData() {
    // Cargar hospitales
    _hospitalManager.loadHospitals();

    // Escuchar marcadores de Firebase
    _markerManager.startListeningToMarkers();
  }

  /// Reconstruye la lista de marcadores
  void _rebuildMarkers() {
    _markers.clear();

    // 1. Mi ubicación (siempre primero y visible)
    if (_myLocationMarker != null) {
      _markers.add(_myLocationMarker!);
      print(
        '[MapScreen] ✅ Marcador de ubicación añadido: ${_myLocationMarker!.point}',
      );
    } else {
      print('[MapScreen] ⚠️ _myLocationMarker es null!');
    }

    // 2. Personas encontradas
    _markers.addAll(_personMarkers);

    // 3. Hospitales (si están activados)
    if (_showHospitals) {
      _markers.addAll(_hospitalMarkers);
    }

    print(
      '[MapScreen] 📊 Total marcadores: ${_markers.length} (ubicación: ${_myLocationMarker != null ? 1 : 0}, personas: ${_personMarkers.length}, hospitales: ${_showHospitals ? _hospitalMarkers.length : 0})',
    );
  }

  /// Construye el marcador de "Mi ubicación"
  Marker _buildLocationMarker(LatLng position) {
    print(
      '[MapScreen] 🔵 Construyendo marcador en: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
    );
    return Marker(
      key: const ValueKey('my_location'),
      point: position,
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Centra el mapa en la ubicación actual
  void _centerOnLocation() {
    final pos = _mapService.currentPosition;
    _mapController.move(pos, 15);
  }

  /// Actualiza la ubicación y centra el mapa
  Future<void> _refreshAndCenter() async {
    await _mapService.refreshLocation();
    _myLocationMarker = _buildLocationMarker(_mapService.currentPosition);
    _rebuildMarkers();
    if (mounted) setState(() {});
    _centerOnLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Mapa
          if (!_isLoading) _buildMap(),

          // Botones flotantes
          if (!_isLoading && _mapReady) _buildFloatingButtons(),

          // Pantalla de carga
          if (_isLoading) _buildLoadingScreen(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: AppBar(
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [Icon(Icons.shield), Icon(Icons.favorite)],
          ),
        ),
        title: Text(LangService.text('app_title')),
        centerTitle: true,
        backgroundColor: const Color(0xFF2DA8E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Mainscreen()),
              );
            },
            icon: const Icon(Icons.home),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    print(
      '[MapScreen] 🗺️ Construyendo mapa con ${_markers.length} marcadores',
    );
    final markerList = _markers.toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapService.currentPosition,
        initialZoom: 12.0, // Zoom inicial dentro del rango offline
        minZoom: MapService.minTileZoom.toDouble(),
        maxZoom: MapService.maxTileZoom.toDouble(),
        onMapReady: () {
          print('[MapScreen] 🗺️ FlutterMap ready - centrando en ubicación');
          if (mounted) {
            setState(() => _mapReady = true);
          }
          // Forzar centrado después de que el mapa esté listo
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _centerOnLocation();
              print(
                '[MapScreen] 📍 Mapa centrado en: ${_mapService.currentPosition}',
              );
            }
          });
        },
      ),
      children: [
        // Capa de tiles SOLO OFFLINE (sin internet)
        Builder(
          builder: (context) {
            final provider = _mapService.tileProvider;
            print(
              '[MapScreen] 🗺️ TileProvider: ${provider?.runtimeType ?? "NULL"}',
            );

            if (provider != null) {
              return TileLayer(
                tileProvider: provider,
                minZoom: MapService.minTileZoom.toDouble(),
                maxZoom: MapService.maxTileZoom.toDouble(),
                keepBuffer: 8,
                tileSize: 256,
                // No mostrar errores si falta un tile
                errorTileCallback: (tile, error, stackTrace) {
                  // Silenciar errores de tiles faltantes
                },
              );
            } else {
              // Fallback: fondo gris si no hay tiles
              return Container(
                color: const Color(0xFFE0E0E0),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Mapa offline no disponible',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Descarga spain.mbtiles desde la pantalla principal',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
        // Capa de marcadores
        MarkerLayer(markers: markerList),
      ],
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      bottom: 30,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de centrar ubicación
          _FloatingButton(
            icon: Icons.my_location,
            tooltip: LangService.text('center_map'),
            onTap: _refreshAndCenter,
          ),
          const SizedBox(height: 12),
          // Botón de hospitales
          _FloatingButton(
            icon: _showHospitals
                ? Icons.local_hospital
                : Icons.local_hospital_outlined,
            tooltip: LangService.text('toggle_hospitals'),
            color: _showHospitals ? const Color(0xFF2DA8E2) : Colors.grey,
            onTap: () {
              setState(() {
                _showHospitals = !_showHospitals;
                _rebuildMarkers();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 150),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFF2DA8E2)),
            const SizedBox(height: 12),
            Text(
              LangService.text('loading_map'),
              style: const TextStyle(
                color: Color(0xFF2DA8E2),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón flotante reutilizable
class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final Color color;

  const _FloatingButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color = const Color(0xFF2DA8E2),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
