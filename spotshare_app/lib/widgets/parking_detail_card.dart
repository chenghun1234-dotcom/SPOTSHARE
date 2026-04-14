import 'package:flutter/material.dart';
import '../models/parking_spot.dart';
import '../services/toss_service.dart';

class ParkingDetailCard extends StatelessWidget {
  final ParkingSpot spot;
  const ParkingDetailCard({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String typeLabel;
    Color typeColor;
    if (spot.isPremium) {
      typeLabel = '프리미엄 광고';
      typeColor = Colors.amber;
    } else if (spot.region == 'PUBLIC' || spot.title.contains('공영')) {
      typeLabel = '공영주차장';
      typeColor = Colors.blue;
    } else {
      typeLabel = '개인/공유';
      typeColor = Colors.green;
    }

    // 다국어/접근성 대응 예시 (실제 서비스에서는 intl/localization 적용)
    String priceUnitLabel = spot.priceUnit == '일' ? '일당' : (spot.priceUnit == '월' ? '월당' : '시간당');
    String penaltyInfo = spot.penaltyRate > 0
        ? '예약 종료 후 미출차 시 ${spot.priceUnit}당 ${spot.penaltyRate}원 할증'
        : '';

    // 다국어 적용 예시 (실제 서비스에서는 flutter_localizations, intl 패키지 사용)
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${spot.region} ${spot.title}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              spot.imageUrl.isNotEmpty ? spot.address ?? '' : '',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            if (spot.imageUrl.isNotEmpty)
              Image.network(spot.imageUrl, height: 120),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.grey[700]),
                SizedBox(width: 4),
                Text(
                  '$priceUnitLabel ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                Text(
                  '${spot.price}원',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                ),
              ],
            ),
            if (penaltyInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  penaltyInfo,
                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            SizedBox(height: 12),
            if (spot.isPremium)
              ElevatedButton(
                onPressed: () {
                  // 예약/송금 로직 연결
                },
                child: Text("즉시 예약/송금"),
              ),
            // 출차 인증 UI (사진 업로드, Firebase Storage 연동, 인증 후 푸시)
            OutlinedButton(
              onPressed: () async {
                // 실제 서비스에서는 아래 패키지 추가 필요:
                // image_picker, firebase_storage, firebase_messaging
                // 예시 코드:
                // final picker = ImagePicker();
                // final picked = await picker.pickImage(source: ImageSource.camera);
                // if (picked != null) {
                //   final ref = FirebaseStorage.instance.ref('checkout/${spot.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                //   await ref.putFile(File(picked.path));
                //   final url = await ref.getDownloadURL();
                //   await CheckoutService().certifyCheckout(reservationId, url);
                //   // 푸시 알림 예시
                //   await FirebaseMessaging.instance.subscribeToTopic('checkout_${spot.id}');
                // }
              },
              child: Text("출차 인증"),
            ),
            if (typeLabel == '공영주차장')
              OutlinedButton(
                onPressed: null,
                child: Text("공영주차장 안내"),
              )
            else if (!spot.isPremium)
              OutlinedButton(
                onPressed: null,
                child: Text("공유주차장 안내"),
              ),
          ],
        ),
      ),
    );
  }
}
