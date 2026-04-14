import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    return (100000 + rand.nextInt(900000)).toString(); // 6자리 코드
  }

  Future<String> requestAd({
    required String spotId,
    required int durationDays,
    required int amount,
    required String adminBank,
    required String adminAccountNo,
  }) async {
    final userId = _requireUserId();
    final depositCode = generateDepositCode();

    await adRequestsRef.add({
      // Standardized core fields.
      'userId': userId,
      'spotId': spotId,
      'durationDays': durationDays,
      'amount': amount,
      'depositCode': depositCode,
      'status': 'pending',
      // Operational metadata.
      'adminBank': adminBank,
      'adminAccountNo': adminAccountNo,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return depositCode;
  }

  Stream<List<Map<String, dynamic>>> getActiveAds() {
    return adRequestsRef.where('status', isEqualTo: 'active').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMyAdRequests() {
    final uid = _requireUserId();
    return adRequestsRef
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getPendingAdRequestsForAdmin() {
    return adRequestsRef
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
  }

  Future<void> approveAdRequestByAdmin(String adRequestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to approve ads.');
    }

    final token = await user.getIdToken();
    final projectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? 'spotshare-5103d';
    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/approveAdRequestByAdmin',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'adRequestId': adRequestId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Approval failed: ${response.statusCode} ${response.body}');
    }
  }
}
