import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  Future<void> createReservation(Map<String, dynamic> data) async {
    await reservationsRef.add(data);
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
