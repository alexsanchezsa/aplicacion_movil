import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplicacion_movil/models/dao/remote/markers_dao.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Modelo de marcador de persona para MapLibre
class PersonMarker {
  final String id;
  final LatLng position;
  final DateTime timestamp;
  final String estado;

  PersonMarker({
    required this.id,
    required this.position,
    required this.timestamp,
    required this.estado,
  });

  Color get color {
    switch (estado.toLowerCase()) {
      case 'critico':
        return Colors.red;
      case 'grave':
        return Colors.orange;
      case 'estable':
        return Colors.green;
      default:
        return Colors.yellow;
    }
  }
}

/// Manager de marcadores de personas para MapLibre
class MarkerManagerMapLibre {
  List<PersonMarker> markers = [];
  StreamSubscription<QuerySnapshot>? markersSubscription;
  final Function(List<PersonMarker>) onMarkersUpdated;
  final BuildContext context;
  final MarkersDao _dao = MarkersDao();

  MarkerManagerMapLibre({
    required this.context,
    required this.onMarkersUpdated,
  });

  void startListeningToMarkers() {
    print('[MarkerManager] 👥 Iniciando escucha de marcadores...');

    markersSubscription = _dao.streamMarkers().listen((snapshot) {
      List<PersonMarker> newMarkers = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final GeoPoint location = data['location'];
          final timestamp = data['timestamp'] as Timestamp;
          final estado = data['estado'] as String? ?? 'Desconocido';

          newMarkers.add(
            PersonMarker(
              id: doc.id,
              position: LatLng(location.latitude, location.longitude),
              timestamp: timestamp.toDate(),
              estado: estado,
            ),
          );
        } catch (e) {
          print('[MarkerManager] ⚠️ Error procesando marcador: $e');
        }
      }

      markers = newMarkers;
      onMarkersUpdated(markers);
      print('[MarkerManager] ✅ Marcadores actualizados: ${markers.length}');
    });
  }

  void dispose() {
    markersSubscription?.cancel();
  }

  /// Muestra opciones del marcador
  void showMarkerOptions(PersonMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones del marcador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Estado: ${marker.estado}'),
            Text('Fecha: ${marker.timestamp}'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Cambiar estado'),
              onTap: () {
                Navigator.pop(context);
                showStateChangeDialog(marker);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar marcador'),
              onTap: () {
                Navigator.pop(context);
                deleteMarker(marker.id);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void showStateChangeDialog(PersonMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stateOption('Estable', Colors.green, marker.id),
            _stateOption('Grave', Colors.orange, marker.id),
            _stateOption('Crítico', Colors.red, marker.id),
          ],
        ),
      ),
    );
  }

  Widget _stateOption(String state, Color color, String markerId) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(state),
      onTap: () {
        _dao.updateMarkerState(markerId, state.toLowerCase());
        Navigator.pop(context);
      },
    );
  }

  Future<void> deleteMarker(String markerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar este marcador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dao.deleteMarker(markerId);
    }
  }
}
