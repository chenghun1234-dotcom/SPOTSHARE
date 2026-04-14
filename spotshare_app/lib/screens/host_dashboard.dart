import 'package:flutter/material.dart';

class HostDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 실제 광고 효과, 예약 현황 등은 Firestore 연동 필요
    return Scaffold(
      appBar: AppBar(title: Text('호스트 대시보드')),
      body: Center(child: Text('내 광고 효과, 예약 현황, 상태 변경 등 구현')),
    );
  }
}
