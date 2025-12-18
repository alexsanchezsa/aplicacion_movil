import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplicacion_movil/models/dao/remote/markers_dao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MarkerManager {
  Set<Marker> markers = {};
  StreamSubscription<QuerySnapshot>? markersSubscription;
  final Function(Set<Marker>) onMarkersUpdated;
  final BuildContext context;
  final MarkersDao _dao = MarkersDao();

  MarkerManager({required this.context, required this.onMarkersUpdated});

  void startListeningToMarkers() {
    markersSubscription = _dao.streamMarkers().listen((snapshot) {
      Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final GeoPoint location = data['location'];
        final timestamp = data['timestamp'] as Timestamp;
        final estado = data['estado'] as String? ?? 'Desconocido';

        newMarkers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 40,
            height: 40,
            key: ValueKey(doc.id),
            child: GestureDetector(
              onTap: () => showMarkerOptions(doc.id, estado),
              child: Tooltip(
                message:
                    'Persona encontrada\nEstado: $estado\nFecha: ${timestamp.toDate().toString()}',
                child: Icon(
                  Icons.location_on,
                  color: getMarkerColor(estado),
                  size: 35,
                ),
              ),
            ),
          ),
        );
      }
      markers = newMarkers;
      onMarkersUpdated(markers);
    });
  }

  void dispose() {
    markersSubscription?.cancel();
  }

  Color getMarkerColor(String estado) {
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

  void showMarkerOptions(String markerId, String currentState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones del marcador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Cambiar estado'),
              onTap: () => showStateChangeDialog(markerId, currentState),
            ),
            ListTile(
              title: const Text('Eliminar marcador'),
              onTap: () => deleteMarker(markerId),
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

  void showStateChangeDialog(String markerId, String currentState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Crítico'),
              onTap: () => updateMarkerState(markerId, 'Critico'),
            ),
            ListTile(
              title: const Text('Grave'),
              onTap: () => updateMarkerState(markerId, 'Grave'),
            ),
            ListTile(
              title: const Text('Estable'),
              onTap: () => updateMarkerState(markerId, 'Estable'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> updateMarkerState(String markerId, String newState) async {
    try {
      await _dao.updateMarkerState(markerId, newState);
      Navigator.pop(context); // Cierra el diálogo de estados
      Navigator.pop(context); // Cierra el diálogo de opciones
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  Future<void> deleteMarker(String markerId) async {
    try {
      await _dao.deleteMarker(markerId);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }
}
