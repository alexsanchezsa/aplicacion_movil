import 'dart:async';
import 'dart:math' as math;
import 'package:aplicacion_movil/models/drone_camera.dart';
import 'package:livekit_client/livekit_client.dart' as livekit; // Solo para Room, Participant, etc. No importar ConnectionState de LiveKit
import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Pantalla de streaming en tiempo real del dron con detección de personas
/// Nota: Esta implementación usa un placeholder visual mientras no hay
/// conexión real a las cámaras. Cuando conectes las cámaras reales,
/// se puede integrar con media_kit o flutter_vlc_player.
class DroneStreamScreen extends StatefulWidget {
  final DroneCamera camera;

  const DroneStreamScreen({super.key, required this.camera});

  @override
  State<DroneStreamScreen> createState() => _DroneStreamScreenState();
}

class _DroneStreamScreenState extends State<DroneStreamScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDetectionEnabled = true;
  bool _isFullScreen = false;
  int _personCount = 0;
  List<DetectedPerson> _detectedPersons = [];
  Timer? _detectionTimer;
  Timer? _connectionTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  Widget _buildStreamArea() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_hasError) {
      return _buildErrorState();
    }
    // Integración con LiveKit
    return FutureBuilder<livekit.Room?>(
      future: _connectToLiveKit(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState();
        }
        final room = snapshot.data!;
        // Aquí deberías usar un widget de video de LiveKit, por ejemplo LiveKitVideoWidget(room: room)
        // Como ejemplo, solo mostramos el estado de la conexión:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, size: 64, color: Colors.blue),
              SizedBox(height: 16),
              Text('Conectado a LiveKit'),
              Text('URL: ${widget.camera.streamUrl}'),
              Text('Room state: ${room.connectionState}'),
            ],
          ),
        );
      },
    );
  }

  Future<livekit.Room?> _connectToLiveKit() async {
    final url = widget.camera.streamUrl;
    final token = widget.camera.description ?? "";
    try {
      livekit.Room room = livekit.Room();
      await room.connect(url, token);
      return room;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _simulateConnection();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(_scanController);
  }

  void _simulateConnection() {
    _connectionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!widget.camera.isOnline) {
            _hasError = true;
            _errorMessage = LangService.text('camera_offline_error');
          } else {
            _startDetectionSimulation();
          }
        });
      }
    });
  }

  void _startDetectionSimulation() {
    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _isDetectionEnabled) {
        _simulateDetection();
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isDetectionEnabled) {
        _simulateDetection();
      }
    });
  }

  void _simulateDetection() {
    final random = math.Random();

    // Generar entre 0 y 4 personas
    final count = random.nextInt(5);

    final newDetections = <DetectedPerson>[];
    for (int i = 0; i < count; i++) {
      newDetections.add(
        DetectedPerson(
          id: 'person_$i',
          x: 0.1 + random.nextDouble() * 0.6, // Posición X relativa
          y: 0.2 + random.nextDouble() * 0.5, // Posición Y relativa
          width: 0.08 + random.nextDouble() * 0.1,
          height: 0.15 + random.nextDouble() * 0.15,
          confidence: 0.7 + random.nextDouble() * 0.3,
        ),
      );
    }

    setState(() {
      _detectedPersons = newDetections;
      _personCount = count;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _detectionTimer?.cancel();
    _connectionTimer?.cancel();
    super.dispose();
  }

  void _toggleDetection() {
    setState(() {
      _isDetectionEnabled = !_isDetectionEnabled;
      if (!_isDetectionEnabled) {
        _detectedPersons = [];
        _personCount = 0;
      }
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _retryConnection() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    _simulateConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video/Stream area
            _buildStreamArea(),

            // Top bar (si no está en fullscreen)
            if (!_isFullScreen) _buildTopBar(),

            // Bottom controls
            if (!_isFullScreen) _buildBottomControls(),

            // Detection overlay
            if (_isDetectionEnabled && !_isLoading && !_hasError)
              _buildDetectionOverlay(),

            // Person count badge
            if (_isDetectionEnabled && _personCount > 0 && !_isLoading)
              _buildPersonCountBadge(),
          ],
        ),
      ),
    );
  }


  Widget _buildSimulatedDroneView() {
    return Stack(
      children: [
        // Grid pattern (simula vista aérea)
        CustomPaint(size: Size.infinite, painter: GridPainter()),

        // Center crosshair
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30, width: 1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Simulated terrain features
        ..._buildTerrainFeatures(),
      ],
    );
  }

  List<Widget> _buildTerrainFeatures() {
    final random = math.Random(42); // Seed fijo para consistencia
    return List.generate(8, (index) {
      final size = 20.0 + random.nextDouble() * 40;
      final left = random.nextDouble() * 0.8;
      final top = random.nextDouble() * 0.7;

      return Positioned(
        left: left * MediaQuery.of(context).size.width,
        top: (top * MediaQuery.of(context).size.height) + 100,
        child: Opacity(
          opacity: 0.3,
          child: Container(
            width: size,
            height: size * 1.5,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStreamInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.red, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.camera.type.value.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: _detectedPersons.map((person) {
            return Positioned(
              left: person.x * constraints.maxWidth,
              top: person.y * constraints.maxHeight,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: person.width * constraints.maxWidth,
                      height: person.height * constraints.maxHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          // Corner markers
                          ..._buildCornerMarkers(),

                          // Label
                          Positioned(
                            top: -20,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${LangService.text('person')} ${(person.confidence * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<Widget> _buildCornerMarkers() {
    const cornerSize = 10.0;
    const cornerWidth = 2.0;

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerWidth,
          color: Colors.green,
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerWidth,
          height: cornerSize,
          color: Colors.green,
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerWidth,
          color: Colors.green,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerWidth,
          height: cornerSize,
          color: Colors.green,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerWidth,
          color: Colors.green,
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerWidth,
          height: cornerSize,
          color: Colors.green,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerWidth,
          color: Colors.green,
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerWidth,
          height: cornerSize,
          color: Colors.green,
        ),
      ),
    ];
  }

  Widget _buildPersonCountBadge() {
    return Positioned(
      top: _isFullScreen ? 16 : 80,
      right: 16,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.accountAlert, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$_personCount ${_personCount == 1 ? LangService.text('person_detected') : LangService.text('persons_detected')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.camera.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.camera.location != null)
                    Text(
                      widget.camera.location!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // AI Detection toggle
            _buildControlButton(
              icon: _isDetectionEnabled
                  ? MdiIcons.brain
                  : MdiIcons.headRemoveOutline,
              label: _isDetectionEnabled
                  ? LangService.text('detection_on')
                  : LangService.text('detection_off'),
              isActive: _isDetectionEnabled,
              onTap: _toggleDetection,
            ),

            // Record button (placeholder)
            _buildControlButton(
              icon: MdiIcons.record,
              label: LangService.text('record'),
              isActive: false,
              activeColor: Colors.red,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LangService.text('feature_coming_soon')),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),

            // Screenshot button (placeholder)
            _buildControlButton(
              icon: MdiIcons.camera,
              label: LangService.text('screenshot'),
              isActive: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LangService.text('feature_coming_soon')),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),

            // Settings
            _buildControlButton(
              icon: Icons.settings,
              label: LangService.text('settings'),
              isActive: false,
              onTap: () => _showSettings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = isActive ? (activeColor ?? Colors.green) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                color: const Color(0xFF1A73E8),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LangService.text('connecting_to_camera'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.camera.streamUrl,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.videoOff, size: 80, color: Colors.red[400]),
              const SizedBox(height: 24),
              Text(
                LangService.text('connection_error'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? LangService.text('unable_to_connect'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retryConnection,
                icon: const Icon(Icons.refresh),
                label: Text(LangService.text('retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              LangService.text('stream_settings'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingItem(
              icon: MdiIcons.brain,
              title: LangService.text('ai_detection'),
              subtitle: LangService.text('detect_persons_in_stream'),
              trailing: Switch(
                value: _isDetectionEnabled,
                onChanged: (value) {
                  Navigator.pop(context);
                  _toggleDetection();
                },
                activeColor: Colors.green,
              ),
            ),
            _buildSettingItem(
              icon: MdiIcons.information,
              title: LangService.text('stream_info'),
              subtitle: widget.camera.streamUrl,
              trailing: const Icon(Icons.copy, color: Colors.white54, size: 20),
              onTap: () {
                // Copy URL
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

/// Modelo para representar una persona detectada
class DetectedPerson {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  DetectedPerson({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });
}

/// Custom painter para dibujar grid de fondo
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Líneas verticales
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Líneas horizontales
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
