import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/parking_spot.dart';
import '../services/ad_service.dart';
import '../services/parking_spot_service.dart';
import '../services/toss_service.dart';

class HostDashboard extends StatefulWidget {
  const HostDashboard({super.key});

  @override
  State<HostDashboard> createState() => _HostDashboardState();
}

class _HostDashboardState extends State<HostDashboard> {
  final _adService = AdService();
  final _spotService = ParkingSpotService();
  final _durationController = TextEditingController(text: '7');
  final _amountController = TextEditingController(text: '30000');
  String? _selectedSpotId;
  bool _submitting = false;

  @override
  void dispose() {
    _durationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _requestAndPay() async {
    if (_selectedSpotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 적용할 주차장을 먼저 선택해 주세요.')),
      );
      return;
    }

    final durationDays = int.tryParse(_durationController.text.trim()) ?? 0;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (durationDays <= 0 || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기간/금액은 1 이상 숫자로 입력해 주세요.')),
      );
      return;
    }

    final adminBank = dotenv.env['AD_ADMIN_BANK'] ?? '토스뱅크';
    final adminAccountNo = dotenv.env['AD_ADMIN_ACCOUNT_NO'] ?? '0000-0000-0000';

    setState(() => _submitting = true);
    try {
      final depositCode = await _adService.requestAd(
        spotId: _selectedSpotId!,
        durationDays: durationDays,
        amount: amount,
        adminBank: adminBank,
        adminAccountNo: adminAccountNo,
      );

      await TossService.openTossForAd(
        bank: adminBank,
        accountNo: adminAccountNo,
        amount: amount,
        depositCode: depositCode,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('광고 신청 완료. 입금코드: $depositCode (입금 확인 후 자동/수동 승인)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('광고 신청 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('호스트 대시보드')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '프리미엄 광고 신청',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ParkingSpot>>(
            stream: _spotService.getMySpotsStream(),
            builder: (context, snapshot) {
              final spots = snapshot.data ?? const <ParkingSpot>[];
              if (snapshot.hasError) {
                return Text('내 주차장 조회 실패: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                );
              }
              if (spots.isEmpty) {
                return const Text('등록된 내 주차장이 없습니다. 주차장 등록 후 광고 신청이 가능합니다.');
              }

              _selectedSpotId ??= spots.first.id;
              return DropdownButtonFormField<String>(
                value: _selectedSpotId,
                decoration: const InputDecoration(labelText: '광고 대상 주차장'),
                items: spots
                    .map((spot) => DropdownMenuItem<String>(
                          value: spot.id,
                          child: Text('${spot.title} (${spot.region})'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSpotId = value),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '광고 기간(일)',
              hintText: '예: 7',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '광고 결제 금액(원)',
              hintText: '예: 30000',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _submitting ? null : _requestAndPay,
              child: Text(_submitting ? '처리 중...' : '광고 신청 + 토스 송금 열기'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '내 광고 신청 상태',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _adService.getMyAdRequests(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('광고 상태 조회 실패: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                );
              }

              final docs = snapshot.data!;
              if (docs.isEmpty) {
                return const Text('아직 광고 신청 내역이 없습니다.');
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'unknown';
                  final amount = data['amount']?.toString() ?? '-';
                  final duration = data['durationDays']?.toString() ?? '-';
                  final code = data['depositCode']?.toString() ?? '-';
                  return Card(
                    child: ListTile(
                      title: Text('상태: $status / ${amount}원 / ${duration}일'),
                      subtitle: Text('입금코드: $code | spotId: ${data['spotId']}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
