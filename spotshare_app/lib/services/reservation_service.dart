import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReservationService {
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to create a reservation.');
    }
    return user.uid;
  }

  Future<void> createReservation(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['userId'] = _requireUserId();
    await reservationsRef.add(payload);
  }

  Future<void> cancelReservation(String id) async {
    await reservationsRef.doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> getReservationsByUser(String userId) {
    return reservationsRef.where('userId', isEqualTo: userId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
