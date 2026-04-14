import 'package:cloud_firestore/cloud_firestore.dart';

class PenaltyService {
  final reservationsRef = FirebaseFirestore.instance.collection('reservations');

  Future<void> applyPenalty() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final reservations = await reservationsRef
        .where('endTime', '<', now)
        .where('checkedOut', isEqualTo: false)
        .get();
    for (var doc in reservations.docs) {
      final data = doc.data();
      final overstayHours = ((now - DateTime.parse(data['endTime']).millisecondsSinceEpoch) / 3600000).ceil();
      final penalty = overstayHours * (data['penaltyRate'] ?? 0);
      await doc.reference.update({'penalty': penalty});
      // TODO: 푸시 알림 등 추가
    }
  }
}
