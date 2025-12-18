import 'package:cloud_firestore/cloud_firestore.dart';

class MarkersDao {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamMarkers() {
    return _db.collection('markers').snapshots();
  }

  Future<void> updateMarkerState(String markerId, String newState) {
    return _db.collection('markers').doc(markerId).update({'estado': newState});
  }

  Future<void> deleteMarker(String markerId) {
    return _db.collection('markers').doc(markerId).delete();
  }
}

