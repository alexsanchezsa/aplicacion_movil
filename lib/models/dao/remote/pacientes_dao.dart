import 'package:cloud_firestore/cloud_firestore.dart';

class PacientesDao {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamPacientes() {
    return _db.collection('pacientes').snapshots();
  }

  Future<QuerySnapshot> getPacientesOnce() {
    return _db.collection('pacientes').get();
  }

  /// Fuerza la consulta directamente al servidor, sin caché local.
  Future<QuerySnapshot> getPacientesFromServer() {
    return _db
        .collection('pacientes')
        .get(const GetOptions(source: Source.server));
  }

  Future<void> updatePacienteState(String pacienteId, String newState) {
    return _db
        .collection('pacientes')
        .doc(pacienteId)
        .update({'estado': newState});
  }

  Future<void> deletePaciente(String pacienteId) {
    return _db.collection('pacientes').doc(pacienteId).delete();
  }
}
