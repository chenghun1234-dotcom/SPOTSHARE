import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parking_spot.dart';
import '../services/ad_service.dart';
import '../services/parking_spot_service.dart';
import 'host_spot_registration_screen.dart';

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

    setState(() => _submitting = true);
    try {
      final response = await _adService.createAdVirtualAccount(
        spotId: _selectedSpotId!,
        durationDays: durationDays,
        amount: amount,
      );

      if (!mounted) return;
      final virtualAccount = Map<String, dynamic>.from(
        (response['virtualAccount'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      );

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('가상계좌 발급 완료'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('주문번호: ${response['orderId'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('상태: ${response['status'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('은행 코드: ${virtualAccount['bankCode'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('가상계좌: ${virtualAccount['accountNumber'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('입금자명: ${virtualAccount['customerName'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('입금기한: ${virtualAccount['dueDate'] ?? '-'}'),
                const SizedBox(height: 8),
                const Text('입금 완료 시 토스 webhook으로 자동 승인됩니다.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
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
                return const Text('등록된 내 주차장이 없습니다. 우측 하단의 [+] 버튼을 눌러 주차장을 등록해주세요.');
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
              child: Text(_submitting ? '처리 중...' : '광고 신청 + 가상계좌 발급'),
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
                  final orderId = data['orderId']?.toString() ?? '-';
                  final accountNumber = (data['virtualAccount'] is Map)
                      ? data['virtualAccount']['accountNumber']?.toString() ?? '-'
                      : '-';
                  return Card(
                    child: ListTile(
                      title: Text('상태: $status / ${amount}원 / ${duration}일'),
                      subtitle: Text('주문번호: $orderId | 가상계좌: $accountNumber | spotId: ${data['spotId']}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HostSpotRegistrationScreen()),
          );
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('주차장 인증/등록'),
      ),
    );
  }
}
