import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  final reportsRef = FirebaseFirestore.instance.collection('reports');

  Future<void> report(Map<String, dynamic> data) async {
    await reportsRef.add(data);
  }

  Stream<List<Map<String, dynamic>>> getReportsBySpot(String spotId) {
    return reportsRef.where('spotId', isEqualTo: spotId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
