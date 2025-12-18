import 'package:cloud_firestore/cloud_firestore.dart';

class PacientesDao {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamPacientes() {
    return _db.collection('pacientes').snapshots();
  }

  Future<QuerySnapshot> getPacientesOnce() {
    return _db.collection('pacientes').get();
  }
}

