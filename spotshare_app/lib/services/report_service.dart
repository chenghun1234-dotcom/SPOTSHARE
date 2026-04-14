import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  final reportsRef = FirebaseFirestore.instance.collection('reports');

  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to submit a report.');
    }
    return user.uid;
  }

  Future<void> report(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['userId'] = _requireUserId();
    await reportsRef.add(payload);
  }

  Stream<List<Map<String, dynamic>>> getReportsBySpot(String spotId) {
    return reportsRef.where('spotId', isEqualTo: spotId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
