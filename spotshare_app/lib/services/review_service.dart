import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  final reviewsRef = FirebaseFirestore.instance.collection('reviews');

  Future<void> addReview(Map<String, dynamic> data) async {
    await reviewsRef.add(data);
  }

  Stream<List<Map<String, dynamic>>> getReviewsBySpot(String spotId) {
    return reviewsRef.where('spotId', isEqualTo: spotId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
