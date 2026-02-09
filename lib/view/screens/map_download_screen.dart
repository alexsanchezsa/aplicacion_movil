import 'package:flutter/material.dart';
import 'package:aplicacion_movil/service/mbtiles_download_service.dart';
import 'package:aplicacion_movil/service/maplibre_service.dart';

/// Pantalla para descargar el mapa de España
class MapDownloadScreen extends StatefulWidget {
  final VoidCallback onDownloadComplete;

  const MapDownloadScreen({super.key, required this.onDownloadComplete});

  @override
  State<MapDownloadScreen> createState() => _MapDownloadScreenState();
}

class _MapDownloadScreenState extends State<MapDownloadScreen> {
  final _downloadService = MbTilesDownloadService();
  final _mapService = MapLibreService();

  bool _isDownloading = false;
  bool _isComplete = false;
  double _progress = 0.0;
  String _statusText = 'Preparando descarga...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyDownloaded();
  }

  Future<void> _checkIfAlreadyDownloaded() async {
    final isDownloaded = await _downloadService.isDownloaded();
    if (isDownloaded) {
      setState(() {
        _isComplete = true;
        _statusText = 'Mapa ya descargado';
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
      _statusText = 'Conectando al servidor...';
    });

    final success = await _downloadService.download(
      onProgress: (progress) {
        setState(() {
          _progress = progress;
          _statusText =
              'Descargando... ${(progress * 100).toStringAsFixed(1)}%';
        });
      },
      onStatus: (status) {
        setState(() {
          switch (status) {
            case DownloadStatus.starting:
              _statusText = 'Iniciando descarga...';
              break;
            case DownloadStatus.downloading:
              _statusText = 'Descargando mapa de España...';
              break;
            case DownloadStatus.completed:
              _statusText = '¡Descarga completada!';
              _isComplete = true;
              break;
            case DownloadStatus.error:
              _statusText = 'Error en la descarga';
              _error = _downloadService.error;
              break;
          }
        });
      },
    );

    setState(() {
      _isDownloading = false;
    });

    if (success) {
      // Cargar el TileProvider
      await _mapService.loadTileProviderAfterDownload();

      // Esperar un momento para mostrar el mensaje de éxito
      await Future.delayed(const Duration(seconds: 1));

      // Continuar a la app
      widget.onDownloadComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono
              Icon(
                _isComplete ? Icons.check_circle : Icons.map_outlined,
                size: 100,
                color: _isComplete ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 32),

              // Título
              Text(
                _isComplete ? '¡Mapa listo!' : 'Mapa de España Offline',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              Text(
                _isComplete
                    ? 'El mapa está descargado y listo para usar sin conexión.'
                    : 'Para usar la aplicación sin conexión, necesitas descargar el mapa de España.\n\nTamaño aproximado: 1.5 GB',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Barra de progreso
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                Text(_statusText, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 1500).toStringAsFixed(0)} MB de 1500 MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Botones
              if (!_isDownloading) ...[
                if (_isComplete)
                  ElevatedButton.icon(
                    onPressed: widget.onDownloadComplete,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _startDownload,
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar mapa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: widget.onDownloadComplete,
                        child: const Text('Continuar sin mapa offline'),
                      ),
                    ],
                  ),
              ],

              // Nota sobre WiFi
              if (!_isComplete && !_isDownloading) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recomendamos usar WiFi',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
