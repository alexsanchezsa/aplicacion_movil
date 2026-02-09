import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Modelo Hospital para MapLibre
class Hospital {
  Hospital({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  double latitude;
  double longitude;
  String name;

  LatLng get position => LatLng(latitude, longitude);
}

/// Manager de hospitales para MapLibre
/// Almacena datos de hospitales que serán dibujados como symbols en MapLibre
class HospitalManagerMapLibre {
  List<Hospital> hospitals = [];
  final Function(List<Hospital>) onHospitalsLoaded;
  final BuildContext context;

  HospitalManagerMapLibre({
    required this.context,
    required this.onHospitalsLoaded,
  });

  /// Carga los hospitales desde el archivo GeoJSON
  Future<void> loadHospitals() async {
    try {
      print('[HospitalManager] 🏥 Cargando hospitales desde GeoJSON...');
      final data = await rootBundle.loadString('lib/data/export.geojson');

      final geojson = json.decode(data);
      List<Hospital> newHospitals = [];

      if (geojson['features'] != null) {
        for (var feature in geojson['features']) {
          try {
            final properties = feature['properties'];
            final geometry = feature['geometry'];

            if (geometry != null && geometry['coordinates'] != null) {
              final coords = geometry['coordinates'];
              final lon = coords[0] as num;
              final lat = coords[1] as num;

              String name = 'Hospital sin nombre';
              if (properties != null && properties['name'] != null) {
                name = properties['name'] as String;
              }

              newHospitals.add(
                Hospital(
                  latitude: lat.toDouble(),
                  longitude: lon.toDouble(),
                  name: name,
                ),
              );
            }
          } catch (e) {
            print('[HospitalManager]  Error procesando feature: $e');
            continue;
          }
        }
      }

      hospitals = newHospitals;
      onHospitalsLoaded(hospitals);
      print('[HospitalManager] Hospitales cargados: ${hospitals.length}');
    } catch (e) {
      print('[HospitalManager]  Error cargando hospitales: $e');
    }
  }

  /// Muestra información de un hospital
  void showHospitalInfo(Hospital hospital) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_hospital, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(child: Text(hospital.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

  /// Encuentra el hospital más cercano a una posición
  Hospital? findNearestHospital(LatLng position) {
    if (hospitals.isEmpty) return null;

    Hospital? nearest;
    double minDistance = double.infinity;
    final distance = const Distance();

    for (final hospital in hospitals) {
      final d = distance.as(LengthUnit.Kilometer, position, hospital.position);
      if (d < minDistance) {
        minDistance = d;
        nearest = hospital;
      }
    }

    return nearest;
  }

  void dispose() {
    // Nada que limpiar
  }
}
