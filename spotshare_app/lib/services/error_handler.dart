import 'package:flutter/material.dart';

/// 앱 전체에서 사용할 글로벌 스낵바 제어 키
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ErrorHandler {
  /// 스크린 하단에 에러 메시지를 표시합니다.
  static void showError(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  /// 스크린 하단에 성공/정보 메시지를 표시합니다.
  static void showSuccess(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }
}
