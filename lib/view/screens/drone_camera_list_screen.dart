import 'package:aplicacion_movil/models/drone_camera.dart';
import 'package:aplicacion_movil/service/drone_camera_service.dart';
import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:aplicacion_movil/view/components/medical_background.dart';
import 'package:aplicacion_movil/view/screens/drone_stream_screen.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Pantalla que muestra la lista de cámaras de drones disponibles
class DroneCameraListScreen extends StatefulWidget {
  const DroneCameraListScreen({super.key});

  @override
  State<DroneCameraListScreen> createState() => _DroneCameraListScreenState();
}

class _DroneCameraListScreenState extends State<DroneCameraListScreen> {
  final DroneCameraService _cameraService = DroneCameraService.instance;
  List<DroneCamera> _cameras = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cameras = await _cameraService.fetchCameras();
      setState(() {
        _cameras = cameras;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCameras() async {
    try {
      final cameras = await _cameraService.fetchCameras(forceRefresh: true);
      setState(() {
        _cameras = cameras;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LangService.text('error_loading_cameras')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openCameraStream(DroneCamera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DroneStreamScreen(camera: camera),
      ),
    );
  }

  void _showAddCameraDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final locationController = TextEditingController();
    DroneCameraType selectedType = DroneCameraType.rtsp;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(MdiIcons.cameraPlus, color: const Color(0xFF1A73E8)),
              const SizedBox(width: 10),
              Text(LangService.text('add_camera')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: LangService.text('camera_name'),
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: LangService.text('stream_url'),
                    hintText: 'rtsp://192.168.1.100:554/stream',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: LangService.text('location'),
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DroneCameraType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: LangService.text('stream_type'),
                    prefixIcon: const Icon(Icons.settings_input_antenna),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: DroneCameraType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.value.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value ?? DroneCameraType.rtsp;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LangService.text('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || urlController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LangService.text('fill_required_fields')),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final camera = DroneCamera(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text,
                  streamUrl: urlController.text,
                  location: locationController.text.isNotEmpty 
                      ? locationController.text 
                      : null,
                  isOnline: true,
                  lastSeen: DateTime.now(),
                  type: selectedType,
                );

                await _cameraService.addCamera(camera);
                Navigator.pop(context);
                _refreshCameras();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
              child: Text(LangService.text('add')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: MedicalBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? _buildErrorState()
                        : _cameras.isEmpty
                            ? _buildEmptyState()
                            : _buildCameraList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCameraDialog,
        backgroundColor: const Color(0xFF1A73E8),
        child: Icon(MdiIcons.cameraPlus, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.drone, size: 40, color: const Color(0xFF1A73E8)),
              const SizedBox(width: 12),
              Text(
                LangService.text('drone_cameras'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3A5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LangService.text('select_camera'),
            style: const TextStyle(fontSize: 14, color: Color(0xFF4A6080)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _refreshCameras,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Color(0xFF1A73E8), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    LangService.text('refresh'),
                    style: const TextStyle(
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1A73E8)),
          SizedBox(height: 16),
          Text(
            'Cargando cámaras...',
            style: TextStyle(color: Color(0xFF1A3A5C), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircle, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              LangService.text('error_loading_cameras'),
              style: const TextStyle(
                color: Color(0xFF1A3A5C),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(color: Color(0xFF4A6080)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCameras,
              icon: const Icon(Icons.refresh),
              label: Text(LangService.text('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.cameraOff, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              LangService.text('no_cameras'),
              style: const TextStyle(
                color: Color(0xFF1A3A5C),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              LangService.text('add_camera_hint'),
              style: const TextStyle(color: Color(0xFF4A6080)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraList() {
    // Separar online y offline
    final onlineCameras = _cameras.where((c) => c.isOnline).toList();
    final offlineCameras = _cameras.where((c) => !c.isOnline).toList();

    return RefreshIndicator(
      onRefresh: _refreshCameras,
      color: const Color(0xFF1A73E8),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Cámaras online
          if (onlineCameras.isNotEmpty) ...[
            _buildSectionHeader(
              LangService.text('cameras_online'),
              Icons.wifi,
              Colors.green,
              onlineCameras.length,
            ),
            ...onlineCameras.map((camera) => _buildCameraCard(camera)),
          ],
          
          // Cámaras offline
          if (offlineCameras.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(
              LangService.text('cameras_offline'),
              Icons.wifi_off,
              Colors.red,
              offlineCameras.length,
            ),
            ...offlineCameras.map((camera) => _buildCameraCard(camera)),
          ],
          
          const SizedBox(height: 80), // Espacio para FAB
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A3A5C),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard(DroneCamera camera) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _openCameraStream(camera),
        onLongPress: () => _showCameraOptions(camera),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail o icono
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: camera.isOnline
                      ? const Color(0xFF1A73E8).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      MdiIcons.drone,
                      size: 36,
                      color: camera.isOnline 
                          ? const Color(0xFF1A73E8)
                          : Colors.grey,
                    ),
                    // Indicador de estado
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: camera.isOnline ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: camera.isOnline 
                            ? const Color(0xFF1A73E8)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (camera.location != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              camera.location!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Tipo de stream
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(camera.type).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            camera.type.value.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTypeColor(camera.type),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Última conexión
                        if (camera.lastSeen != null)
                          Text(
                            _formatLastSeen(camera.lastSeen!),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.chevron_right,
                color: camera.isOnline ? const Color(0xFF1A73E8) : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(DroneCameraType type) {
    switch (type) {
      case DroneCameraType.rtsp:
        return Colors.purple;
      case DroneCameraType.rtmp:
        return Colors.orange;
      case DroneCameraType.hls:
        return Colors.green;
      case DroneCameraType.http:
        return Colors.blue;
      case DroneCameraType.mjpeg:
        return Colors.teal;
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} h';
    } else {
      return 'Hace ${diff.inDays} días';
    }
  }

  void _showCameraOptions(DroneCamera camera) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              camera.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(MdiIcons.play, color: const Color(0xFF1A73E8)),
              title: Text(LangService.text('open_stream')),
              onTap: () {
                Navigator.pop(context);
                _openCameraStream(camera);
              },
            ),
            ListTile(
              leading: Icon(MdiIcons.pencil, color: Colors.orange),
              title: Text(LangService.text('edit_camera')),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementar edición
              },
            ),
            ListTile(
              leading: Icon(MdiIcons.delete, color: Colors.red),
              title: Text(LangService.text('delete_camera')),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(LangService.text('confirm_delete')),
                    content: Text('${LangService.text('delete_camera_confirm')} "${camera.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(LangService.text('cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(LangService.text('delete')),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _cameraService.removeCamera(camera.id);
                  _refreshCameras();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
