// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cherryrecorder_client/app.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CherryRecorderApp());

    // 앱 시작 시 초기화 화면(로딩)이 보이는지 확인
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('데이터를 준비 중입니다...'), findsOneWidget);
  });
}
