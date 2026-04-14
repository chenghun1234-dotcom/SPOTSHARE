import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AdService {
  final adRequestsRef = FirebaseFirestore.instance.collection('ad_requests');

  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to request an ad.');
    }
    return user.uid;
  }

  String generateDepositCode() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString(); // 4자리 코드
  }

  Future<void> requestAd(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['userId'] = _requireUserId();
    await adRequestsRef.add(payload);
  }

  Stream<List<Map<String, dynamic>>> getActiveAds() {
    return adRequestsRef.where('status', isEqualTo: 'active').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
