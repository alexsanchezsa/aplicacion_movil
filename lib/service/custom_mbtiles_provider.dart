import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sqlite3/sqlite3.dart';

/// TileProvider personalizado para leer MBTiles sin validación de metadata
class CustomMbTilesTileProvider extends TileProvider {
  final Database _db;

  CustomMbTilesTileProvider._(this._db);

  /// Crea un provider desde la ruta del archivo MBTiles
  static CustomMbTilesTileProvider? fromPath(String path) {
    try {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);

      // Verificar que la tabla tiles existe
      final result = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tiles'",
      );

      if (result.isEmpty) {
        print('[CustomMbTiles] ❌ No se encontró la tabla "tiles"');
        db.dispose();
        return null;
      }

      // Obtener información de diagnóstico
      _printDiagnostics(db);

      print('[CustomMbTiles] ✅ Base de datos abierta correctamente');
      return CustomMbTilesTileProvider._(db);
    } catch (e) {
      print('[CustomMbTiles] ❌ Error abriendo DB: $e');
      return null;
    }
  }

  /// Imprime información de diagnóstico sobre el MBTiles
  static void _printDiagnostics(Database db) {
    try {
      // Contar tiles totales
      final countResult = db.select('SELECT COUNT(*) as count FROM tiles');
      final tileCount = countResult.first['count'] as int;
      print('[CustomMbTiles] 📊 Total tiles en DB: $tileCount');

      // Obtener rango de zoom
      final zoomResult = db.select(
        'SELECT MIN(zoom_level) as min_z, MAX(zoom_level) as max_z FROM tiles',
      );
      if (zoomResult.isNotEmpty) {
        print(
          '[CustomMbTiles] 📊 Zoom range: ${zoomResult.first['min_z']} - ${zoomResult.first['max_z']}',
        );
      }

      // Ver muestra de un tile para detectar formato
      final sampleResult = db.select(
        'SELECT tile_data, zoom_level, tile_column, tile_row FROM tiles LIMIT 1',
      );
      if (sampleResult.isNotEmpty) {
        final sampleTile = sampleResult.first['tile_data'] as Uint8List?;
        final z = sampleResult.first['zoom_level'];
        final x = sampleResult.first['tile_column'];
        final y = sampleResult.first['tile_row'];

        if (sampleTile != null && sampleTile.length >= 4) {
          final header = sampleTile.sublist(0, 4);
          String format = 'desconocido';

          // Detectar formato por magic bytes
          if (header[0] == 0x89 && header[1] == 0x50) {
            format = 'PNG ✅';
          } else if (header[0] == 0xFF && header[1] == 0xD8) {
            format = 'JPEG ✅';
          } else if (header[0] == 0x52 &&
              header[1] == 0x49 &&
              header[2] == 0x46 &&
              header[3] == 0x46) {
            // RIFF = WebP format
            format = 'WebP ✅';
          } else if (header[0] == 0x1f && header[1] == 0x8b) {
            format = 'GZIP (comprimido) 📦';
            // Descomprimir para ver formato real
            try {
              final decompressed = gzip.decode(sampleTile);
              if (decompressed.length >= 2) {
                if (decompressed[0] == 0x89 && decompressed[1] == 0x50) {
                  format = 'GZIP -> PNG ✅';
                } else if (decompressed[0] == 0xFF && decompressed[1] == 0xD8) {
                  format = 'GZIP -> JPEG ✅';
                } else {
                  format = 'GZIP -> PBF/Vector ❌ (no soportado)';
                }
              }
            } catch (e) {
              format = 'GZIP (error al descomprimir)';
            }
          } else {
            // Podría ser PBF sin comprimir
            format =
                'PBF/Vector ❌ (no soportado) - bytes: ${header.map((b) => '0x${b.toRadixString(16)}').join(', ')}';
          }

          print('[CustomMbTiles] 📊 Formato tiles: $format');
          print(
            '[CustomMbTiles] 📊 Tile muestra: z=$z, x=$x, y=$y, ${sampleTile.length} bytes',
          );
        }
      }

      // Leer metadata si existe
      final metaResult = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'",
      );
      if (metaResult.isNotEmpty) {
        final metadata = db.select('SELECT name, value FROM metadata');
        for (final row in metadata) {
          final name = row['name'] as String;
          final value = row['value'] as String?;
          if (['format', 'name', 'bounds', 'center'].contains(name)) {
            print('[CustomMbTiles] 📊 Metadata $name: $value');
          }
        }
      }
    } catch (e) {
      print('[CustomMbTiles] ⚠️ Error en diagnóstico: $e');
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CustomMbTilesImageProvider(db: _db, coordinates: coordinates);
  }

  @override
  void dispose() {
    _db.dispose();
    super.dispose();
  }
}

/// ImageProvider que carga tiles desde SQLite
class _CustomMbTilesImageProvider
    extends ImageProvider<_CustomMbTilesImageProvider> {
  final Database db;
  final TileCoordinates coordinates;

  _CustomMbTilesImageProvider({required this.db, required this.coordinates});

  @override
  Future<_CustomMbTilesImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CustomMbTilesImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<TileCoordinates>('Coordinates', coordinates);
      },
    );
  }

  Future<ui.Codec> _loadTile(ImageDecoderCallback decode) async {
    // Log para verificar que se está llamando
    if (_loadCounter < 5) {
      _loadCounter++;
      print(
        '[CustomMbTiles] 🔄 _loadTile llamado para z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}',
      );
    }

    final bytes = await _getTileBytes();

    if (bytes == null || bytes.isEmpty) {
      // Devolver tile transparente si no existe
      return _createTransparentTile(decode);
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  // Contadores estáticos para logs (solo primeros tiles)
  static int _logCounter = 0;
  static int _loadCounter = 0;
  static const int _maxLogs = 20;

  Future<Uint8List?> _getTileBytes() async {
    try {
      // MBTiles usa TMS (y invertido en Y): tmsY = (2^zoom - 1) - y
      final tmsY = (1 << coordinates.z) - 1 - coordinates.y;

      final result = db.select(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
        [coordinates.z, coordinates.x, tmsY],
      );

      if (result.isEmpty) {
        // Log para debug - solo primeros tiles no encontrados
        if (_logCounter < _maxLogs) {
          _logCounter++;
          print(
            '[CustomMbTiles] ⚠️ Tile NO encontrado: z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}, tmsY=$tmsY',
          );
        }
        return null;
      }

      final blob = result.first['tile_data'] as Uint8List?;

      if (blob == null || blob.isEmpty) {
        return null;
      }

      // Detectar si está comprimido con gzip (magic bytes: 0x1f 0x8b)
      if (blob.length > 2 && blob[0] == 0x1f && blob[1] == 0x8b) {
        try {
          final decompressed = Uint8List.fromList(gzip.decode(blob));
          if ((coordinates.x + coordinates.y) % 100 == 0) {
            print(
              '[CustomMbTiles] 📦 Tile descomprimido: z=${coordinates.z}, ${blob.length} -> ${decompressed.length} bytes',
            );
          }
          return decompressed;
        } catch (e) {
          print('[CustomMbTiles] ❌ Error descomprimiendo tile: $e');
          return blob; // Intentar usar el blob original
        }
      }

      // Log de éxito para debug (solo primeros tiles)
      if (_logCounter < _maxLogs) {
        _logCounter++;
        print(
          '[CustomMbTiles] ✅ Tile ENCONTRADO: z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}, tmsY=$tmsY, ${blob.length} bytes',
        );
      }

      return blob;
    } catch (e) {
      print(
        '[CustomMbTiles] Error leyendo tile ${coordinates.z}/${coordinates.x}/${coordinates.y}: $e',
      );
      return null;
    }
  }

  Future<ui.Codec> _createTransparentTile(ImageDecoderCallback decode) async {
    // Crear imagen transparente de 256x256
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 256, 256),
      ui.Paint()..color = const ui.Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      byteData!.buffer.asUint8List(),
    );
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CustomMbTilesImageProvider &&
        other.coordinates == coordinates;
  }

  @override
  int get hashCode => coordinates.hashCode;
}
