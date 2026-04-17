import 'package:flutter/material.dart';
import '../models/parking_spot.dart';
import '../services/toss_service.dart';
import '../services/reservation_service.dart';

class ReservationDialog extends StatefulWidget {
  final ParkingSpot spot;

  const ReservationDialog({Key? key, required this.spot}) : super(key: key);

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  double _hours = 1;
  bool _isLoading = false;

  int get _totalPrice => (_hours * widget.spot.price).toInt();

  Future<void> _processReservation() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final endTime = now.add(Duration(minutes: (_hours * 60).toInt()));

      // 1. Create the reservation in Firestore
      await ReservationService().createReservation({
        'spotId': widget.spot.id,
        'startTime': now,
        'endTime': endTime,
        'amount': _totalPrice,
        'checkedOut': false,
        'createdAt': now,
        'penalty': 0, // initial penalty
      });

      // 2. Open Toss P2P transfer (deep link)
      // Pass the computed total price, the Host's bank, and Host's account.
      // Use the Spot ID as a memo/depositCode.
      await TossService.openTossTransfer(
        bank: widget.spot.bank,
        accountNo: widget.spot.accountNo,
        amount: _totalPrice,
        depositCode: widget.spot.id,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Signal success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예약 처리 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.spot.title} 예약'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('몇 시간 동안 이용하시겠습니까?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('이용 시간', style: TextStyle(color: Colors.grey[700])),
              Text('${_hours.toInt()} 시간', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Slider(
            value: _hours,
            min: 1,
            max: 24,
            divisions: 23,
            label: '${_hours.toInt()}시간',
            onChanged: (val) {
              setState(() {
                _hours = val;
              });
            },
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('최종 결제 금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '$_totalPrice원',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '확인을 누르면 예약이 확정되고 토스 송금 화면으로 연결됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processReservation,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('예약 확정 및 결제'),
        ),
      ],
    );
  }
}
