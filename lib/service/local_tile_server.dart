import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';

/// Servidor local HTTP que sirve tiles desde un archivo MBTiles
/// Esto permite usar tiles vectoriales offline en MapLibre GL
class LocalTileServer {
  static final LocalTileServer _instance = LocalTileServer._internal();
  factory LocalTileServer() => _instance;
  LocalTileServer._internal();

  HttpServer? _server;
  Database? _database;
  String? _mbtilesPath;
  int _port = 8765;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int get port => _port;
  // Usar 127.0.0.1 en lugar de localhost para mejor compatibilidad con MapLibre
  String get baseUrl => 'http://127.0.0.1:$_port';

  /// Inicia el servidor de tiles
  Future<bool> start() async {
    if (_isRunning) {
      print('[TileServer] ✅ Ya está corriendo en puerto $_port');
      return true;
    }

    try {
      // Aplicar workaround para versiones antiguas de Android
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      print('[TileServer] 🔧 SQLite3 workaround aplicado');

      // Obtener path del MBTiles
      final appDir = await getApplicationDocumentsDirectory();
      _mbtilesPath = '${appDir.path}/spain.mbtiles';
      print('[TileServer] 📂 Buscando MBTiles en: $_mbtilesPath');

      // Verificar que existe
      final mbtilesFile = File(_mbtilesPath!);
      if (!mbtilesFile.existsSync()) {
        print('[TileServer] ❌ MBTiles no encontrado: $_mbtilesPath');
        return false;
      }

      final fileSize = mbtilesFile.lengthSync();
      print(
        '[TileServer] 📂 MBTiles encontrado: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
      );

      // Abrir base de datos
      _database = sqlite3.open(_mbtilesPath!);
      print('[TileServer] 📂 Base de datos MBTiles abierta');

      // Verificar contenido de la base de datos
      try {
        final tileCount = _database!.select(
          'SELECT COUNT(*) as count FROM tiles',
        );
        print(
          '[TileServer] 📊 Total de tiles en DB: ${tileCount.first['count']}',
        );

        final metadata = _database!.select('SELECT name, value FROM metadata');
        for (final row in metadata) {
          print('[TileServer] 📋 Metadata: ${row['name']} = ${row['value']}');

          // Si es el campo json, parsearlo para ver las capas disponibles
          if (row['name'] == 'json') {
            try {
              final jsonData = row['value'] as String;
              print('[TileServer] 🗺️ JSON completo: $jsonData');
              final Map<String, dynamic> parsed = Map<String, dynamic>.from(
                const JsonDecoder().convert(jsonData) as Map,
              );
              if (parsed.containsKey('vector_layers')) {
                final layers = parsed['vector_layers'] as List;
                print('[TileServer] 📑 Vector layers disponibles:');
                for (final layer in layers) {
                  print('[TileServer]   - ${layer['id']}');
                }
              }
            } catch (e) {
              print('[TileServer] ⚠️ Error parseando JSON metadata: $e');
            }
          }
        }

        // Verificar un tile de ejemplo para ver su contenido
        final sampleTile = _database!.select(
          'SELECT zoom_level, tile_column, tile_row, length(tile_data) as size FROM tiles LIMIT 5',
        );
        for (final row in sampleTile) {
          print(
            '[TileServer] 🔍 Sample tile: z=${row['zoom_level']} x=${row['tile_column']} y=${row['tile_row']} size=${row['size']}',
          );
        }

        // Verificar rango de zoom disponible
        final zoomRange = _database!.select(
          'SELECT MIN(zoom_level) as min_zoom, MAX(zoom_level) as max_zoom FROM tiles',
        );
        if (zoomRange.isNotEmpty) {
          print(
            '[TileServer] 🔍 Zoom range: ${zoomRange.first['min_zoom']} - ${zoomRange.first['max_zoom']}',
          );
        }
      } catch (e) {
        print('[TileServer] ⚠️ Error leyendo metadata: $e');
      }

      // Buscar puerto disponible
      for (int tryPort = 8765; tryPort < 8800; tryPort++) {
        try {
          _server = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            tryPort,
          );
          _port = tryPort;
          break;
        } catch (e) {
          // Puerto ocupado, probar siguiente
        }
      }

      if (_server == null) {
        print('[TileServer] ❌ No se pudo encontrar puerto disponible');
        return false;
      }

      // Manejar peticiones
      _server!.listen(_handleRequest);
      _isRunning = true;

      print('[TileServer] ✅ Servidor iniciado en $baseUrl');
      return true;
    } catch (e) {
      print('[TileServer] ❌ Error iniciando servidor: $e');
      return false;
    }
  }

  /// Maneja las peticiones HTTP
  void _handleRequest(HttpRequest request) async {
    print('[TileServer] 📥 Request: ${request.method} ${request.uri.path}');

    // Habilitar CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // Ruta de tiles: /tiles/{z}/{x}/{y}.pbf
    if (path.startsWith('/tiles/')) {
      await _serveTile(request);
    }
    // Ruta de metadatos: /metadata
    else if (path == '/metadata') {
      await _serveMetadata(request);
    }
    // Ruta de estilo: /style.json
    else if (path == '/style.json') {
      await _serveStyle(request);
    }
    // No encontrado
    else {
      request.response.statusCode = 404;
      request.response.write('Not Found');
      await request.response.close();
    }
  }

  // Zoom máximo disponible en el MBTiles (spain.mbtiles tiene hasta zoom 14)
  static const int _maxTileZoom = 14;

  /// Sirve un tile específico
  /// Implementa overzooming: si se pide zoom > 15, devuelve el tile del nivel 15
  Future<void> _serveTile(HttpRequest request) async {
    try {
      // Parsear coordenadas de la URL: /tiles/{z}/{x}/{y}.pbf
      final segments = request.uri.pathSegments;
      if (segments.length < 4) {
        print('[TileServer] ⚠️ URL inválida: ${request.uri.path}');
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }

      final z = int.parse(segments[1]);
      final x = int.parse(segments[2]);
      final yStr = segments[3].replaceAll('.pbf', '').replaceAll('.mvt', '');
      final y = int.parse(yStr);

      // Calcular coordenadas del tile para overzoom
      int queryZ = z;
      int queryX = x;
      int queryY = y;

      // Si el zoom solicitado es mayor que el máximo disponible,
      // calcular el tile padre en el nivel máximo
      if (z > _maxTileZoom) {
        final zoomDiff = z - _maxTileZoom;
        queryZ = _maxTileZoom;
        queryX = x >> zoomDiff; // Dividir por 2^zoomDiff
        queryY = y >> zoomDiff;
        print(
          '[TileServer] 🔍 Overzoom: z$z -> z$queryZ, ($x,$y) -> ($queryX,$queryY)',
        );
      }

      // MBTiles usa TMS, necesitamos convertir Y
      final tmsY = (1 << queryZ) - 1 - queryY;

      print(
        '[TileServer] 🎯 Solicitando tile z=$queryZ x=$queryX y=$queryY (tmsY=$tmsY)',
      );

      // Consultar tile
      final result = _database!.select(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
        [queryZ, queryX, tmsY],
      );

      if (result.isEmpty) {
        print(
          '[TileServer]  Tile no encontrado: z=$queryZ x=$queryX tmsY=$tmsY',
        );
        request.response.statusCode = 204; // No Content
        await request.response.close();
        return;
      }

      final tileData = result.first['tile_data'] as Uint8List;
      print('[TileServer]  Tile encontrado: ${tileData.length} bytes');

      // Detectar si está comprimido con gzip
      final isGzip =
          tileData.length > 2 && tileData[0] == 0x1f && tileData[1] == 0x8b;

      // Detectar si es PNG (tiles raster)
      final isPng =
          tileData.length > 8 &&
          tileData[0] == 0x89 &&
          tileData[1] == 0x50 &&
          tileData[2] == 0x4E &&
          tileData[3] == 0x47;

      // Detectar si es JPEG
      final isJpeg =
          tileData.length > 3 &&
          tileData[0] == 0xFF &&
          tileData[1] == 0xD8 &&
          tileData[2] == 0xFF;

      if (isPng) {
        print('[TileServer] 📸 Tile es imagen PNG (raster)');
      } else if (isJpeg) {
        print('[TileServer] 📸 Tile es imagen JPEG (raster)');
      } else if (isGzip) {
        print('[TileServer] 🗜️ Tile está comprimido con gzip (vector/pbf)');
      } else {
        print(
          '[TileServer] 📦 Tile raw (primeros bytes: ${tileData.take(10).map((b) => b.toRadixString(16)).join(" ")})',
        );
      }

      request.response.statusCode = 200;

      // Si es imagen PNG o JPEG, usar content-type apropiado
      if (isPng) {
        request.response.headers.contentType = ContentType('image', 'png');
      } else if (isJpeg) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
      } else {
        request.response.headers.contentType = ContentType(
          'application',
          'x-protobuf',
        );
        if (isGzip) {
          request.response.headers.add('Content-Encoding', 'gzip');
        }
      }
      request.response.add(tileData);
      await request.response.close();
    } catch (e) {
      print('[TileServer] ⚠️ Error sirviendo tile: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Sirve los metadatos del MBTiles
  Future<void> _serveMetadata(HttpRequest request) async {
    try {
      final result = _database!.select('SELECT name, value FROM metadata');
      final metadata = <String, dynamic>{};
      for (final row in result) {
        metadata[row['name'] as String] = row['value'];
      }

      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write('$metadata');
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Sirve el archivo de estilo JSON
  Future<void> _serveStyle(HttpRequest request) async {
    final styleJson = getStyleJson();
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;
    request.response.write(styleJson);
    await request.response.close();
  }

  /// Genera el JSON de estilo para MapLibre
  /// Estilo adaptado a las capas reales del MBTiles IGN España
  /// NOTA: Este MBTiles es un overlay, no un mapa base completo
  String getStyleJson() {
    return '''
{
  "version": 8,
  "name": "IGN Spain Offline",
  "sources": {
    "ign": {
      "type": "vector",
      "tiles": ["$baseUrl/tiles/{z}/{x}/{y}.pbf"],
      "minzoom": 3,
      "maxzoom": 14
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#e8e4d8"
      }
    },
    {
      "id": "fondo-fill",
      "type": "fill",
      "source": "ign",
      "source-layer": "fondo",
      "paint": {
        "fill-color": "#f0ece0",
        "fill-opacity": 1
      }
    },
    {
      "id": "siglim-peninsula",
      "type": "fill",
      "source": "ign",
      "source-layer": "siglim_peninbal",
      "paint": {
        "fill-color": "#f8f4e8",
        "fill-outline-color": "#666666"
      }
    },
    {
      "id": "siglim-canarias",
      "type": "fill",
      "source": "ign",
      "source-layer": "siglim_canarias",
      "paint": {
        "fill-color": "#f8f4e8",
        "fill-outline-color": "#666666"
      }
    },
    {
      "id": "siose-cobertura",
      "type": "fill",
      "source": "ign",
      "source-layer": "siose",
      "paint": {
        "fill-color": "#d8e8c8",
        "fill-opacity": 0.6
      }
    },
    {
      "id": "zonas-protegidas",
      "type": "fill",
      "source": "ign",
      "source-layer": "0107s_zon_pro",
      "minzoom": 8,
      "maxzoom": 11,
      "paint": {
        "fill-color": "#88cc88",
        "fill-opacity": 0.4,
        "fill-outline-color": "#448844"
      }
    },
    {
      "id": "humedal",
      "type": "fill",
      "source": "ign",
      "source-layer": "0319s_humeda",
      "paint": {
        "fill-color": "#99ccbb",
        "fill-opacity": 0.5
      }
    },
    {
      "id": "embalse",
      "type": "fill",
      "source": "ign",
      "source-layer": "0325s_embalse",
      "paint": {
        "fill-color": "#88bbdd"
      }
    },
    {
      "id": "laguna",
      "type": "fill",
      "source": "ign",
      "source-layer": "0316s_laguna",
      "paint": {
        "fill-color": "#88ccdd"
      }
    },
    {
      "id": "salina",
      "type": "fill",
      "source": "ign",
      "source-layer": "0358s_salina",
      "paint": {
        "fill-color": "#ccddee"
      }
    },
    {
      "id": "agua-marina",
      "type": "fill",
      "source": "ign",
      "source-layer": "0306s_agu_mar",
      "paint": {
        "fill-color": "#aaccee"
      }
    },
    {
      "id": "rio-superficie",
      "type": "fill",
      "source": "ign",
      "source-layer": "0302s_rio",
      "paint": {
        "fill-color": "#88bbdd"
      }
    },
    {
      "id": "cauce-artificial-s",
      "type": "fill",
      "source": "ign",
      "source-layer": "0305s_cau_art",
      "paint": {
        "fill-color": "#99ccdd"
      }
    },
    {
      "id": "rio-linea",
      "type": "line",
      "source": "ign",
      "source-layer": "0302l_rio",
      "minzoom": 8,
      "paint": {
        "line-color": "#4488cc",
        "line-width": 2
      }
    },
    {
      "id": "cauce-artificial-l",
      "type": "line",
      "source": "ign",
      "source-layer": "0305l_cau_art",
      "paint": {
        "line-color": "#5599cc",
        "line-width": 1.5,
        "line-dasharray": [4, 2]
      }
    },
    {
      "id": "linea-costa",
      "type": "line",
      "source": "ign",
      "source-layer": "0352l_lin_cos",
      "paint": {
        "line-color": "#3366aa",
        "line-width": 2
      }
    },
    {
      "id": "isla",
      "type": "fill",
      "source": "ign",
      "source-layer": "0355s_isla",
      "paint": {
        "fill-color": "#f8f4e8",
        "fill-outline-color": "#3366aa"
      }
    },
    {
      "id": "zona-verde",
      "type": "fill",
      "source": "ign",
      "source-layer": "0561s_zon_ver",
      "paint": {
        "fill-color": "#aaddaa",
        "fill-opacity": 0.7
      }
    },
    {
      "id": "instalacion-deportiva",
      "type": "fill",
      "source": "ign",
      "source-layer": "0564s_ins_dep",
      "paint": {
        "fill-color": "#bbddaa",
        "fill-outline-color": "#88aa77"
      }
    },
    {
      "id": "entidad-poblacion",
      "type": "fill",
      "source": "ign",
      "source-layer": "0502s_ent_pob",
      "paint": {
        "fill-color": "#f0e0d0",
        "fill-opacity": 0.6
      }
    },
    {
      "id": "agregacion-edificios",
      "type": "fill",
      "source": "ign",
      "source-layer": "0504s_agr_edi",
      "paint": {
        "fill-color": "#e8d8c8",
        "fill-outline-color": "#c8b8a8"
      }
    },
    {
      "id": "edificios",
      "type": "fill",
      "source": "ign",
      "source-layer": "0509s_ed",
      "paint": {
        "fill-color": "#d8c8b8",
        "fill-outline-color": "#a89888"
      }
    },
    {
      "id": "cementerio",
      "type": "fill",
      "source": "ign",
      "source-layer": "0522s_cement",
      "paint": {
        "fill-color": "#cccccc",
        "fill-outline-color": "#888888"
      }
    },
    {
      "id": "explotacion-minera",
      "type": "fill",
      "source": "ign",
      "source-layer": "0540s_exp_min_s",
      "paint": {
        "fill-color": "#ddcc99",
        "fill-outline-color": "#aa9966"
      }
    },
    {
      "id": "pista-aterrizaje",
      "type": "fill",
      "source": "ign",
      "source-layer": "0662s_pis_ater",
      "paint": {
        "fill-color": "#cccccc",
        "fill-outline-color": "#888888"
      }
    },
    {
      "id": "zona-aterrizaje",
      "type": "fill",
      "source": "ign",
      "source-layer": "0665s_zon_ater_s",
      "paint": {
        "fill-color": "#ddddcc",
        "fill-outline-color": "#999988"
      }
    },
    {
      "id": "infraestructura-transporte",
      "type": "fill",
      "source": "ign",
      "source-layer": "0613s_inf_trans_s",
      "paint": {
        "fill-color": "#ddccbb",
        "fill-outline-color": "#aa9988"
      }
    },
    {
      "id": "central-electrica",
      "type": "fill",
      "source": "ign",
      "source-layer": "0713s_cen_elec",
      "paint": {
        "fill-color": "#ddddaa",
        "fill-outline-color": "#999966"
      }
    },
    {
      "id": "transformador-electrico",
      "type": "fill",
      "source": "ign",
      "source-layer": "0719s_tra_elec",
      "paint": {
        "fill-color": "#eeeecc",
        "fill-outline-color": "#aaaa88"
      }
    },
    {
      "id": "carretera",
      "type": "line",
      "source": "ign",
      "source-layer": "0605l_carretera",
      "paint": {
        "line-color": "#ff8844",
        "line-width": 3
      }
    },
    {
      "id": "via-urbana",
      "type": "line",
      "source": "ign",
      "source-layer": "0622l_urbana",
      "paint": {
        "line-color": "#ffffff",
        "line-width": 2,
        "line-opacity": 0.9
      }
    },
    {
      "id": "camino",
      "type": "line",
      "source": "ign",
      "source-layer": "0623l_camino",
      "paint": {
        "line-color": "#cc9966",
        "line-width": 1.5,
        "line-dasharray": [4, 2]
      }
    },
    {
      "id": "senda",
      "type": "line",
      "source": "ign",
      "source-layer": "0626l_senda",
      "paint": {
        "line-color": "#aa7744",
        "line-width": 1,
        "line-dasharray": [2, 2]
      }
    },
    {
      "id": "carril-bici",
      "type": "line",
      "source": "ign",
      "source-layer": "0629l_car_bic",
      "paint": {
        "line-color": "#44aa44",
        "line-width": 1.5
      }
    },
    {
      "id": "itinerario",
      "type": "line",
      "source": "ign",
      "source-layer": "0632l_itiner",
      "paint": {
        "line-color": "#aa44aa",
        "line-width": 1,
        "line-dasharray": [3, 3]
      }
    },
    {
      "id": "via-pecuaria",
      "type": "line",
      "source": "ign",
      "source-layer": "0635l_via_pec",
      "paint": {
        "line-color": "#997755",
        "line-width": 1.5,
        "line-dasharray": [6, 3]
      }
    },
    {
      "id": "ferrocarril-alta-vel",
      "type": "line",
      "source": "ign",
      "source-layer": "0638l_fc_alt_vel",
      "paint": {
        "line-color": "#333333",
        "line-width": 3
      }
    },
    {
      "id": "ferrocarril-conv",
      "type": "line",
      "source": "ign",
      "source-layer": "0641l_fc_conv",
      "paint": {
        "line-color": "#555555",
        "line-width": 2,
        "line-dasharray": [4, 2]
      }
    },
    {
      "id": "transporte-especial",
      "type": "line",
      "source": "ign",
      "source-layer": "0644l_tra_esp",
      "paint": {
        "line-color": "#666666",
        "line-width": 1.5
      }
    },
    {
      "id": "transporte-suspension",
      "type": "line",
      "source": "ign",
      "source-layer": "0647l_tran_susp",
      "paint": {
        "line-color": "#777777",
        "line-width": 1
      }
    },
    {
      "id": "puerto",
      "type": "line",
      "source": "ign",
      "source-layer": "0656l_puerto",
      "paint": {
        "line-color": "#445588",
        "line-width": 2
      }
    },
    {
      "id": "linea-electrica",
      "type": "line",
      "source": "ign",
      "source-layer": "0710l_lin_elec",
      "paint": {
        "line-color": "#888888",
        "line-width": 0.5
      }
    },
    {
      "id": "conduccion-combustible",
      "type": "line",
      "source": "ign",
      "source-layer": "0701l_con_comb",
      "paint": {
        "line-color": "#aa6644",
        "line-width": 1
      }
    },
    {
      "id": "curvas-nivel",
      "type": "line",
      "source": "ign",
      "source-layer": "0201l_cur_niv",
      "minzoom": 13,
      "paint": {
        "line-color": "#c4a882",
        "line-width": 0.5
      }
    },
    {
      "id": "cortafuegos",
      "type": "line",
      "source": "ign",
      "source-layer": "0401l_cortaf",
      "paint": {
        "line-color": "#cc6633",
        "line-width": 1,
        "line-dasharray": [3, 3]
      }
    },
    {
      "id": "cerramiento",
      "type": "line",
      "source": "ign",
      "source-layer": "0528l_cerram",
      "paint": {
        "line-color": "#888866",
        "line-width": 0.5
      }
    },
    {
      "id": "acueducto",
      "type": "line",
      "source": "ign",
      "source-layer": "0549l_acuedu",
      "paint": {
        "line-color": "#6699aa",
        "line-width": 1.5
      }
    },
    {
      "id": "presa",
      "type": "line",
      "source": "ign",
      "source-layer": "0552l_presa",
      "paint": {
        "line-color": "#446688",
        "line-width": 2
      }
    },
    {
      "id": "tuberia-servicio",
      "type": "line",
      "source": "ign",
      "source-layer": "0308l_tub_serv",
      "paint": {
        "line-color": "#7799aa",
        "line-width": 1
      }
    },
    {
      "id": "paso-elevado",
      "type": "line",
      "source": "ign",
      "source-layer": "0546l_pas_ele",
      "paint": {
        "line-color": "#999999",
        "line-width": 2
      }
    },
    {
      "id": "construccion-historica-l",
      "type": "line",
      "source": "ign",
      "source-layer": "0555l_con_his_l",
      "paint": {
        "line-color": "#aa8866",
        "line-width": 2
      }
    },
    {
      "id": "construccion-historica-s",
      "type": "fill",
      "source": "ign",
      "source-layer": "0555s_con_his_s",
      "paint": {
        "fill-color": "#ddccaa",
        "fill-outline-color": "#aa8866"
      }
    },
    {
      "id": "yacimiento-arqueologico",
      "type": "fill",
      "source": "ign",
      "source-layer": "0558s_yac_arq_s",
      "paint": {
        "fill-color": "#ddbb99",
        "fill-outline-color": "#aa8855"
      }
    },
    {
      "id": "limite-label-peninsula",
      "type": "line",
      "source": "ign",
      "source-layer": "siglim_label_peninbal",
      "paint": {
        "line-color": "#996699",
        "line-width": 1
      }
    },
    {
      "id": "limite-label-canarias",
      "type": "line",
      "source": "ign",
      "source-layer": "siglim_label_canarias",
      "paint": {
        "line-color": "#996699",
        "line-width": 1
      }
    }
  ]
}
''';
  }

  /// Detiene el servidor
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      await _server?.close(force: true);
      _database?.dispose();
      _server = null;
      _database = null;
      _isRunning = false;
      print('[TileServer] 🛑 Servidor detenido');
    } catch (e) {
      print('[TileServer] ⚠️ Error deteniendo servidor: $e');
    }
  }
}
