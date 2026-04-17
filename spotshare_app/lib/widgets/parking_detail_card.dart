import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parking_spot.dart';
import '../services/reservation_service.dart';
import '../services/parking_spot_service.dart';
import 'reservation_dialog.dart';
import 'auth_dialog.dart';

class ParkingDetailCard extends StatelessWidget {
  final ParkingSpot spot;
  const ParkingDetailCard({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String typeLabel;
    Color typeColor;
    if (spot.isPremium) {
      typeLabel = 'Premium';
      typeColor = const Color(0xFFFFD700);
    } else if (spot.region == 'PUBLIC' || spot.title.contains('공영')) {
      typeLabel = 'Public';
      typeColor = const Color(0xFF03DAC6);
    } else {
      typeLabel = 'Private / Shared';
      typeColor = const Color(0xFF6C63FF);
    }

    String priceUnit = spot.priceUnit == '일' ? '/ day' : (spot.priceUnit == '월' ? '/ month' : '/ hour');
    String penaltyInfo = spot.penaltyRate > 0
        ? 'Overstay penalty: ₩${spot.penaltyRate} per ${spot.priceUnit}'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withOpacity(0.4)),
                  ),
                  child: Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spot.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (spot.address != null && spot.address!.isNotEmpty)
              Text(
                spot.address!,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            const SizedBox(height: 10),
            if (spot.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  spot.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: double.infinity,
                      color: const Color(0xFF2A2A3E),
                      child: const Icon(Icons.car_rental, size: 40, color: Colors.white24),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  '₩${spot.price}  $priceUnit',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            if (penaltyInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  penaltyInfo,
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            if (typeLabel != 'Public')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Book Now  ·  Pay via Toss'),
                  onPressed: () {
                    if (FirebaseAuth.instance.currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to continue.')));
                      showDialog(context: context, builder: (_) => const AuthDialog());
                      return;
                    }
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ReservationDialog(spot: spot),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              label: const Text('Check-Out Certification'),
              onPressed: () async {
                if (FirebaseAuth.instance.currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to continue.')));
                  showDialog(context: context, builder: (_) => const AuthDialog());
                  return;
                }
                try {
                  final activeResId = await ReservationService().getActiveReservationId(spot.id);
                  if (activeResId == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('현재 예약 중인 내역이 없습니다.')),
                      );
                    }
                    return;
                  }

                  final ImagePicker picker = ImagePicker();
                  final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);
                  
                  if (pickedFile != null && context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogCtx) => const AlertDialog(
                        backgroundColor: Color(0xFF1E1E2E),
                        content: Row(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF6C63FF)),
                            SizedBox(width: 16),
                            Text('Uploading photo...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );

                    try {
                      final ref = FirebaseStorage.instance.ref('checkouts/${spot.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                      await ref.putFile(File(pickedFile.path));
                      final url = await ref.getDownloadURL();

                      await ReservationService().certifyCheckout(activeResId, url);

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Check-out certified successfully!')),
                      );
                    }
                    } catch (uploadError) {
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('업로드 실패: $uploadError')),
                        );
                      }
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('출차 인증 처리 중 오류: $e')),
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF03DAC6),
                side: const BorderSide(color: Color(0xFF03DAC6), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (typeLabel == 'Public')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Public Parking Info'),
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white38,
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (typeLabel != 'Public' && FirebaseAuth.instance.currentUser?.uid != spot.ownerId)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    if (FirebaseAuth.instance.currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to continue.')));
                      showDialog(context: context, builder: (_) => const AuthDialog());
                      return;
                    }
                    try {
                      await ParkingSpotService().reportSpot(spot.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.flag_outlined, color: Color(0xFFFF6B6B), size: 14),
                  label: const Text('Report this spot', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
