import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parking_spot.dart';
import 'error_handler.dart';

class ParkingSpotService {
  final spotsRef = FirebaseFirestore.instance.collection('parking_spots');

  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to create a parking spot.');
    }
    return user.uid;
  }

  Future<void> addSpot(ParkingSpot spot) async {
    try {
      final ownerId = _requireUserId();
      await spotsRef.doc(spot.id).set({
        'ownerId': ownerId,
        'region': spot.region,
        'title': spot.title,
        'price': spot.price,
        'bank': spot.bank,
        'accountNo': spot.accountNo,
        'depositCode': spot.depositCode,
        'isPremium': spot.isPremium,
        'imageUrl': spot.imageUrl,
        'lat': spot.lat,
        'lng': spot.lng,
        'isActive': true,
        'reportedBy': [],
      });
    } catch (e) {
      ErrorHandler.showError('주차 영역 등록에 실패했습니다: $e');
      rethrow;
    }
  }

  Future<void> updateSpot(ParkingSpot spot) async {
    try {
      await spotsRef.doc(spot.id).update({
        'region': spot.region,
        'title': spot.title,
        'price': spot.price,
        'bank': spot.bank,
        'accountNo': spot.accountNo,
        'depositCode': spot.depositCode,
        'isPremium': spot.isPremium,
        'imageUrl': spot.imageUrl,
        'lat': spot.lat,
        'lng': spot.lng,
      });
    } catch (e) {
      ErrorHandler.showError('주차 영역 수정에 실패했습니다: $e');
      rethrow;
    }
  }

  Future<void> deleteSpot(String id) async {
    try {
      await spotsRef.doc(id).delete();
    } catch (e) {
      ErrorHandler.showError('주차 영역 삭제에 실패했습니다: $e');
      rethrow;
    }
  }

  Future<void> reportSpot(String spotId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = spotsRef.doc(spotId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception('주차장을 찾을 수 없습니다.');

        final data = snapshot.data() as Map<String, dynamic>;
        final List<dynamic> reportedBy = data['reportedBy'] ?? [];

        if (reportedBy.contains(uid)) {
          throw Exception('이미 신고한 주차장입니다.');
        }

        reportedBy.add(uid);
        final updateData = <String, dynamic>{
          'reportedBy': reportedBy,
        };

        if (reportedBy.length >= 3) {
          updateData['isActive'] = false;
        }

        transaction.update(docRef, updateData);
      });
    } catch (e) {
      ErrorHandler.showError(e.toString());
      rethrow;
    }
  }

  Stream<List<ParkingSpot>> getSpotsStream() {
    return spotsRef.where('isActive', isEqualTo: true).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => ParkingSpot.fromJson(doc.data())).toList()
    );
  }

  Stream<List<ParkingSpot>> getMySpotsStream() {
    final uid = _requireUserId();
    return spotsRef
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ParkingSpot.fromJson(doc.data())).toList());
  }
}
