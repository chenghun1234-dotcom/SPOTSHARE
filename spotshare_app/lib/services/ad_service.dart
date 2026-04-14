import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AdService {
  final adRequestsRef = FirebaseFirestore.instance.collection('ad_requests');

  String generateDepositCode() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString(); // 4자리 코드
  }

  Future<void> requestAd(Map<String, dynamic> data) async {
    await adRequestsRef.add(data);
  }

  Stream<List<Map<String, dynamic>>> getActiveAds() {
    return adRequestsRef.where('status', isEqualTo: 'active').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
