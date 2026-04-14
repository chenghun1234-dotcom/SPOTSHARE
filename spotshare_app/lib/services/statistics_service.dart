import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsService {
  final spotsRef = FirebaseFirestore.instance.collection('parking_spots');
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  Future<Map<String, int>> getPopularRegions() async {
    final snapshot = await reservationsRef.get();
    final regionCount = <String, int>{};
    for (var doc in snapshot.docs) {
      final region = doc.data()['region'] ?? '기타';
      regionCount[region] = (regionCount[region] ?? 0) + 1;
    }
    return regionCount;
  }

  Future<List<Map<String, dynamic>>> getTopSpots({int limit = 5}) async {
    final snapshot = await reservationsRef.get();
    final spotCount = <String, int>{};
    for (var doc in snapshot.docs) {
      final spotId = doc.data()['spotId'];
      spotCount[spotId] = (spotCount[spotId] ?? 0) + 1;
    }
    final sorted = spotCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = sorted.take(limit).map((e) => e.key).toList();
    final spots = await spotsRef.where('id', whereIn: topIds).get();
    return spots.docs.map((doc) => doc.data()).toList();
  }
}
