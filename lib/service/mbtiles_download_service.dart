import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Servicio para descargar archivos MBTiles grandes desde un servidor
class MbTilesDownloadService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  static final MbTilesDownloadService _instance =
      MbTilesDownloadService._internal();
  factory MbTilesDownloadService() => _instance;
  MbTilesDownloadService._internal();

  // CONFIGURACIÓN - CAMBIAR ESTA URL POR LA DE TU SERVIDOR

  /// URL del archivo MBTiles en GitHub Releases
  static const String _downloadUrl =
      'https://github.com/alexsanchezsa/mbtiles-spain/releases/download/v1.0/spain.mbtiles';

  /// Nombre del archivo local
  static const String _fileName = 'spain.mbtiles';

  /// Tamaño esperado en bytes (para validar descarga completa)
  /// 1.5 GB aproximadamente
  static const int _expectedSizeBytes = 1607000000;

  // ESTADO
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String? get error => _error;

  // Stream para notificar progreso
  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  final _statusController = StreamController<DownloadStatus>.broadcast();
  Stream<DownloadStatus> get statusStream => _statusController.stream;

  /// MÉTODOS PÚBLICOS

  /// Obtiene la ruta local del archivo MBTiles
  Future<String> getLocalPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$_fileName';
  }

  /// Verifica si el archivo ya está descargado y es válido
  Future<bool> isDownloaded() async {
    try {
      final path = await getLocalPath();
      final file = File(path);

      if (!await file.exists()) {
        print('[MbTilesDownload] ❌ Archivo no existe');
        return false;
      }

      final size = await file.length();
      print(
        '[MbTilesDownload] 📁 Archivo encontrado: ${(size / 1024 / 1024).toStringAsFixed(1)} MB',
      );

      // Verificar que el tamaño sea razonable (al menos 100 MB)
      if (size < 100 * 1024 * 1024) {
        print(
          '[MbTilesDownload] ⚠️ Archivo muy pequeño, posiblemente corrupto',
        );
        return false;
      }

      return true;
    } catch (e) {
      print('[MbTilesDownload] ❌ Error verificando archivo: $e');
      return false;
    }
  }

  /// Descarga el archivo MBTiles desde el servidor
  Future<bool> download({
    void Function(double progress)? onProgress,
    void Function(DownloadStatus status)? onStatus,
  }) async {
    if (_isDownloading) {
      print('[MbTilesDownload] ⚠️ Ya hay una descarga en curso');
      return false;
    }

    _isDownloading = true;
    _progress = 0.0;
    _error = null;

    _notifyStatus(DownloadStatus.starting, onStatus);

    try {
      final path = await getLocalPath();
      final file = File(path);

      // Crear directorio si no existe
      await file.parent.create(recursive: true);

      print('[MbTilesDownload] 📥 Iniciando descarga desde: $_downloadUrl');
      print('[MbTilesDownload] 📁 Guardando en: $path');

      // Hacer request HTTP
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? _expectedSizeBytes;
      print(
        '[MbTilesDownload] 📊 Tamaño total: ${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB',
      );

      _notifyStatus(DownloadStatus.downloading, onStatus);

      // Abrir archivo para escritura
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        // Actualizar progreso
        _progress = downloaded / contentLength;
        _progressController.add(_progress);
        onProgress?.call(_progress);

        // Log cada 10%
        if ((downloaded * 10 / contentLength).floor() >
            ((downloaded - chunk.length) * 10 / contentLength).floor()) {
          print(
            '[MbTilesDownload] 📥 ${(_progress * 100).toStringAsFixed(0)}% - '
            '${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB',
          );
        }
      }

      await sink.close();

      // Verificar descarga
      final finalSize = await file.length();
      print(
        '[MbTilesDownload] ✅ Descarga completada: ${(finalSize / 1024 / 1024).toStringAsFixed(1)} MB',
      );

      _notifyStatus(DownloadStatus.completed, onStatus);
      _isDownloading = false;
      return true;
    } catch (e) {
      print('[MbTilesDownload] ❌ Error en descarga: $e');
      _error = e.toString();
      _notifyStatus(DownloadStatus.error, onStatus);
      _isDownloading = false;
      return false;
    }
  }

  /// Elimina el archivo descargado
  Future<void> deleteDownload() async {
    try {
      final path = await getLocalPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('[MbTilesDownload] 🗑️ Archivo eliminado');
      }
    } catch (e) {
      print('[MbTilesDownload] ❌ Error eliminando archivo: $e');
    }
  }

  /// Obtiene el tamaño del archivo descargado en MB
  Future<double> getDownloadedSizeMB() async {
    try {
      final path = await getLocalPath();
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        return size / 1024 / 1024;
      }
    } catch (e) {
      // Ignorar
    }
    return 0;
  }

  void _notifyStatus(
    DownloadStatus status,
    void Function(DownloadStatus)? callback,
  ) {
    _statusController.add(status);
    callback?.call(status);
  }

  void dispose() {
    _progressController.close();
    _statusController.close();
  }
}

enum DownloadStatus { starting, downloading, completed, error }
