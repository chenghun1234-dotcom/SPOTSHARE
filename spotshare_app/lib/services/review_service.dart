import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final reviewsRef = FirebaseFirestore.instance.collection('reviews');

  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication required to create a review.');
    }
    return user.uid;
  }

  Future<void> addReview(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['userId'] = _requireUserId();
    await reviewsRef.add(payload);
  }

  Stream<List<Map<String, dynamic>>> getReviewsBySpot(String spotId) {
    return reviewsRef.where('spotId', isEqualTo: spotId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.data()).toList()
    );
  }
}
