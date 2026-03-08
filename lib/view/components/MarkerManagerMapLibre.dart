import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplicacion_movil/models/dao/remote/pacientes_dao.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Modelo completo de un paciente/persona a rescatar.
class PersonMarker {
  final String id;
  final LatLng position;
  final DateTime timestamp;
  final String estado;
  final String herida;
  final String recomendacion;
  final String address;
  /// 0 = Pendiente, 1 = En camino, 2 = Evacuado
  final int evacuacion;

  PersonMarker({
    required this.id,
    required this.position,
    required this.timestamp,
    required this.estado,
    this.herida = '',
    this.recomendacion = '',
    this.address = '',
    this.evacuacion = 0,
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

  String get evacuacionLabel {
    switch (evacuacion) {
      case 1:
        return 'En camino';
      case 2:
        return 'Evacuado';
      default:
        return 'Pendiente';
    }
  }
}

/// Manager de marcadores de pacientes para MapLibre.
/// Escucha la colección 'pacientes' de Firestore en tiempo real.
/// Expone [forceRefresh] para forzar una sincronización con el servidor
/// (útil tras recibir un mensaje FCM mientras la app estaba en segundo plano).
class MarkerManagerMapLibre {
  List<PersonMarker> markers = [];
  StreamSubscription<QuerySnapshot>? markersSubscription;
  final Function(List<PersonMarker>) onMarkersUpdated;
  final void Function(PersonMarker)? onRouteRequested;
  final BuildContext context;
  final PacientesDao _dao = PacientesDao();

  MarkerManagerMapLibre({
    required this.context,
    required this.onMarkersUpdated,
    this.onRouteRequested,
  });

  void startListeningToMarkers() {
    print('[MarkerManager] 👥 Iniciando escucha de pacientes...');
    markersSubscription = _dao.streamPacientes().listen(_processsnapshot);
  }

  void _processsnapshot(QuerySnapshot snapshot) {
    final newMarkers = <PersonMarker>[];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final evacuacion = (data['evacuacion'] as num?)?.toInt() ?? 0;

        // Evacuados (2) no se muestran en el mapa
        if (evacuacion == 2) continue;

        final GeoPoint location = data['location'];
        final timestamp = data['timestamp'] as Timestamp;
        final estado = data['estado'] as String? ?? 'desconocido';

        newMarkers.add(
          PersonMarker(
            id: doc.id,
            position: LatLng(location.latitude, location.longitude),
            timestamp: timestamp.toDate(),
            estado: estado,
            herida: data['herida'] as String? ?? '',
            recomendacion: data['recomendacion'] as String? ?? '',
            address: data['address'] as String? ?? '',
            evacuacion: evacuacion,
          ),
        );
      } catch (e) {
        print('[MarkerManager] ⚠️ Error procesando paciente: $e');
      }
    }

    markers = newMarkers;
    onMarkersUpdated(markers);
    print('[MarkerManager] ✅ Pacientes actualizados: ${markers.length}');
  }

  /// Fuerza una consulta directa al servidor Firestore (evita la caché local).
  /// Se llama cuando llega un FCM data message para asegurar datos frescos.
  Future<void> forceRefresh() async {
    print('[MarkerManager] 🔄 Forzando sincronización con servidor...');
    try {
      final snapshot = await _dao.getPacientesFromServer();
      _processsnapshot(snapshot);
    } catch (e) {
      print('[MarkerManager] ⚠️ Error en forceRefresh: $e');
    }
  }

  void dispose() {
    markersSubscription?.cancel();
  }

  /// Muestra opciones del marcador
  void showMarkerOptions(PersonMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones del paciente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Estado: ${marker.estado}'),
            if (marker.herida.isNotEmpty) Text('Herida: ${marker.herida}'),
            if (marker.recomendacion.isNotEmpty)
              Text('Recomendación: ${marker.recomendacion}'),
            if (marker.address.isNotEmpty)
              Text('Dirección: ${marker.address}'),
            Text('Fecha: ${marker.timestamp}'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.directions, color: Colors.blue),
              title: const Text('Trazar ruta'),
              onTap: () {
                Navigator.pop(context);
                onRouteRequested?.call(marker);
              },
            ),
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
        _dao.updatePacienteState(markerId, state.toLowerCase());
        Navigator.pop(context);
      },
    );
  }

  Future<void> deleteMarker(String markerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar este paciente?'),
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
      await _dao.deletePaciente(markerId);
    }
  }
}
