import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parking_spot.dart';

class ParkingSpotService {
  final spotsRef = FirebaseFirestore.instance.collection('parking_spots');

  Future<void> addSpot(ParkingSpot spot) async {
    await spotsRef.doc(spot.id).set({
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
  }

  Future<void> updateSpot(ParkingSpot spot) async {
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
  }

  Future<void> deleteSpot(String id) async {
    await spotsRef.doc(id).delete();
  }

  Stream<List<ParkingSpot>> getSpotsStream() {
    return spotsRef.snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => ParkingSpot.fromJson(doc.data())).toList()
    );
  }
}
