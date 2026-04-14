import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ad_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adService = AdService();
  String? _processingId;

  Future<void> _approve(String adRequestId) async {
    setState(() => _processingId = adRequestId);
    try {
      await _adService.approveAdRequestByAdmin(adRequestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고 승인이 완료되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('승인 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 대시보드')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _adService.getPendingAdRequestsForAdmin(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('대기 광고 조회 실패: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return const Center(child: Text('승인 대기 중인 광고가 없습니다.'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final isLoading = _processingId == doc.id;

                return Card(
                  child: ListTile(
                    title: Text('spotId: ${data['spotId']} / ${data['amount']}원'),
                    subtitle: Text(
                      '기간: ${data['durationDays']}일 | 입금코드: ${data['depositCode']}\n요청자: ${data['userId']}',
                    ),
                    trailing: ElevatedButton(
                      onPressed: isLoading ? null : () => _approve(doc.id),
                      child: Text(isLoading ? '승인 중...' : '승인'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
