import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutService {
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  Future<void> certifyCheckout(String reservationId, String imageUrl) async {
    await reservationsRef.doc(reservationId).update({
      'checkedOut': true,
      'checkoutImageUrl': imageUrl,
      'checkoutTime': DateTime.now().toIso8601String(),
    });
  }
}
