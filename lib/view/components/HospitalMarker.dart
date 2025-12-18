import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Modelo Hospital
class Hospital {
  Hospital({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  double latitude;
  double longitude;
  String name;
}

class HospitalManager {
  Set<Marker> hospitalMarkers = {};
  List<Hospital> hospitals = [];
  final Function(Set<Marker>) onHospitalsLoaded;
  final BuildContext context;

  HospitalManager({required this.context, required this.onHospitalsLoaded});

  /// Carga los hospitales desde el archivo GeoJSON
  Future<void> loadHospitals() async {
    try {
      // ✅ RUTA CORREGIDA: Utilizando la ubicación dentro de lib/data/
      print('DEBUG: Intentando cargar lib/data/export.geojson...');
      final data = await rootBundle.loadString('lib/data/export.geojson');
      print('DEBUG: Archivo GeoJSON cargado correctamente. Decodificando...');

      final geojson = json.decode(data);

      Set<Marker> newMarkers = {};
      List<Hospital> newHospitals = [];

      // Procesar features del GeoJSON
      if (geojson['features'] != null) {
        for (var feature in geojson['features']) {
          try {
            final properties = feature['properties'];
            final geometry = feature['geometry'];

            // Validar que tenga coordenadas
            if (geometry != null && geometry['coordinates'] != null) {
              final coords = geometry['coordinates'];

              // GeoJSON usa [longitud, latitud]
              final lon = coords[0] as num;
              final lat = coords[1] as num;

              // Obtener el nombre del hospital
              String name = 'Hospital sin nombre';
              if (properties != null && properties['name'] != null) {
                name = properties['name'] as String;
              }

              // Crear objeto Hospital
              final hospital = Hospital(
                latitude: lat.toDouble(),
                longitude: lon.toDouble(),
                name: name,
              );
              newHospitals.add(hospital);

              // Crear marcador
              newMarkers.add(
                Marker(
                  point: LatLng(hospital.latitude, hospital.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => showHospitalInfo(hospital),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.purple,
                      size: 30,
                    ),
                  ),
                ),
              );
            }
          } catch (e) {
            print('Error procesando feature: $e');
            continue;
          }
        }
      }

      hospitals = newHospitals;
      hospitalMarkers = newMarkers;
      onHospitalsLoaded(hospitalMarkers);

      print('✅ Hospitales cargados y parseados: ${hospitals.length}');
    } catch (e) {
      // Si este error aparece, es un problema de pubspec.yaml o permisos del archivo.
      print('❌ Erwror al cargar hospitales: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar hospitales: $e')));
    }
  }

  /// Muestra información del hospital
  void showHospitalInfo(Hospital hospital) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hospital'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hospital.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Latitud: ${hospital.latitude.toStringAsFixed(6)}'),
            Text('Longitud: ${hospital.longitude.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Buscar hospital más cercano a una ubicación
  Hospital? findNearestHospital(double lat, double lon) {
    if (hospitals.isEmpty) return null;

    Hospital? nearest;
    double minDistance = double.infinity;

    for (var hospital in hospitals) {
      final distance = _calculateDistance(
        lat,
        lon,
        hospital.latitude,
        hospital.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = hospital;
      }
    }

    return nearest;
  }

  /// Calcular distancia aproximada entre dos puntos (fórmula de Haversine simplificada)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  void dispose() {
    // Limpiar recursos si es necesario
  }
}
