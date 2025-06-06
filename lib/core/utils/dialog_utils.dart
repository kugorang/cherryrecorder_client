import 'package:flutter/material.dart';

/// API 오류 발생 시 사용자에게 표시할 공통 다이얼로그
///
/// [context] : 다이얼로그를 표시할 BuildContext
/// [message] : 다이얼로그에 표시할 메시지 (기본값: "잠시 뒤에 다시 시도해주세요.")
///
/// '확인'을 누르면 모든 이전 화면이 스택에서 제거되고, 앱의 첫 화면('/map')으로 이동한다.
/// 이 기능은 `main.dart`의 `MaterialApp`에 named route가 올바르게 설정되어 있다고 가정한다.
/// 예: routes: { '/map': (context) => MapScreen() }
void showApiErrorDialog(BuildContext context,
    {String message = '잠시 뒤에 다시 시도해주세요.'}) {
  // 위젯이 아직 트리에 있는지(mounted) 확인하여 안전하게 다이얼로그를 호출
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false, // 사용자가 다이얼로그 바깥을 탭하여 닫는 것을 방지
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('요청 실패'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('확인'),
            onPressed: () {
              // 다이얼로그를 먼저 닫음
              Navigator.of(dialogContext).pop();
              // 앱의 첫 화면으로 이동하고, 그 이전의 모든 경로를 스택에서 제거
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/map', // MapScreen의 named route
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      );
    },
  );
}
