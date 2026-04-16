import 'package:cloud_firestore/cloud_firestore.dart';

class PenaltyService {
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> applyPenalty() async {
    final now = DateTime.now();
    // Use checkedOut as the primary filter to avoid type mismatch in Firestore
    final reservations = await reservationsRef
        .where('checkedOut', isEqualTo: false)
        .get();
        
    for (var doc in reservations.docs) {
      final data = doc.data();
      final endTime = _parseDateTime(data['endTime']);
      
      if (endTime != null && endTime.isBefore(now)) {
        final overstayHours = now.difference(endTime).inHours + 1; // +1 to ceil up slightly or use exact ceil
        final penalty = overstayHours * (data['penaltyRate'] ?? 0);
        await doc.reference.update({'penalty': penalty});
        
        // TODO: FCM Local Push / Cloud Function Trigger
        print('FCM Push: Overstay penalty applied for reservation ${doc.id}');
      }
    }
  }
}
