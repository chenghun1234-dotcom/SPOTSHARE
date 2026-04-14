import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 실제 통계/신고/블랙리스트 등은 Firestore 연동 필요
    return Scaffold(
      appBar: AppBar(title: Text('관리자 대시보드')),
      body: Center(child: Text('광고/예약/신고 통계, 블랙리스트 관리 등 구현')),
    );
  }
}
