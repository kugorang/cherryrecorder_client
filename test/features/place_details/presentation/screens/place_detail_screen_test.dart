import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
// import 'package:cherryrecorder_client/features/map/presentation/screens/map_screen.dart' show Place; // Remove this old import
import 'package:cherryrecorder_client/core/models/place.dart'; // Import Place from core/models
import 'package:cherryrecorder_client/features/place_details/presentation/providers/place_detail_view_model.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/screens/place_detail_screen.dart';
import 'package:cherryrecorder_client/core/models/memo.dart'; // Memo 모델 임포트
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng 임포트
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_form_dialog.dart';

// ViewModel 모의 객체 생성
@GenerateMocks([PlaceDetailViewModel])
import 'place_detail_screen_test.mocks.dart';

void main() {
  late MockPlaceDetailViewModel mockViewModel;

  // 테스트용 데이터
  final testPlace = Place(
    id: 'test_place_id',
    name: 'Test Place',
    address: 'Test Address',
    location: const LatLng(37.5, 127.0),
    acceptsCreditCard: true,
  );
  final testMemo = Memo(
    id: 'memo1',
    placeId: testPlace.id,
    latitude: testPlace.location.latitude,
    longitude: testPlace.location.longitude,
    content: 'Test memo content',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // 각 테스트 전에 실행될 설정
  setUp(() {
    mockViewModel = MockPlaceDetailViewModel();

    // 기본 Mock 동작 설정 (필요에 따라 각 테스트에서 override)
    when(mockViewModel.isLoading).thenReturn(false);
    when(mockViewModel.error).thenReturn(null);
    when(mockViewModel.memos).thenReturn([]); // 기본적으로 빈 목록
    when(mockViewModel.loadMemos(any)).thenAnswer((_) async {});
    when(mockViewModel.deleteMemo(any, any)).thenAnswer((_) async => true);
  });

  // 테스트 위젯을 빌드하는 헬퍼 함수
  Widget createTestWidget() {
    return ChangeNotifierProvider<PlaceDetailViewModel>.value(
      value: mockViewModel,
      child: MaterialApp(
        home: PlaceDetailScreen(
          placeData: {
            'id': testPlace.id,
            'name': testPlace.name,
            'address': testPlace.address,
            'location': {
              'latitude': testPlace.location.latitude,
              'longitude': testPlace.location.longitude,
            },
            'acceptsCreditCard': testPlace.acceptsCreditCard,
          },
        ),
      ),
    );
  }

  testWidgets(
    'PlaceDetailScreen shows place name and address in AppBar and Body',
    (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // AppBar의 제목 확인
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(testPlace.name),
        ),
        findsOneWidget,
        reason: 'AppBar should contain the place name',
      );

      // Body의 제목 확인 (Key 사용)
      expect(
        find.descendant(
          of: find.byKey(
            const Key('place_detail_body_column'),
          ), // Key로 Column 찾기
          matching: find.text(testPlace.name),
        ),
        findsOneWidget,
        reason: 'Body column should contain the place name',
      );

      // 주소 확인 (Key 사용)
      expect(
        find.descendant(
          of: find.byKey(
            const Key('place_detail_body_column'),
          ), // Key로 Column 찾기
          matching: find.text(testPlace.address),
        ),
        findsOneWidget,
        reason: 'Body column should contain the place address',
      );
    },
  );

  testWidgets('Shows loading indicator when isLoading is true', (
    WidgetTester tester,
  ) async {
    when(mockViewModel.isLoading).thenReturn(true);
    await tester.pumpWidget(createTestWidget());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Shows error message when error is not null', (
    WidgetTester tester,
  ) async {
    const errorMessage = 'Failed to load memos';
    when(mockViewModel.error).thenReturn(errorMessage);
    await tester.pumpWidget(createTestWidget());
    expect(find.textContaining(errorMessage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Shows "no memos" message when memos list is empty', (
    WidgetTester tester,
  ) async {
    when(mockViewModel.isLoading).thenReturn(false);
    when(mockViewModel.memos).thenReturn([]);
    await tester.pumpWidget(createTestWidget());
    expect(find.text('저장된 메모가 없습니다.'), findsOneWidget);
  });

  testWidgets('Shows memo list when memos are available', (
    WidgetTester tester,
  ) async {
    when(mockViewModel.isLoading).thenReturn(false);
    when(mockViewModel.memos).thenReturn([testMemo]);
    await tester.pumpWidget(createTestWidget());
    expect(find.widgetWithText(ListTile, testMemo.content), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('FloatingActionButton is present on non-web', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestWidget());
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  // 웹 환경 테스트는 kIsWeb 값을 제어하기 어려워 별도 설정이나 조건부 로직 필요
  // testWidgets('FloatingActionButton is hidden on web', (WidgetTester tester) async { ... });

  testWidgets('Tapping delete button shows confirmation dialog', (
    WidgetTester tester,
  ) async {
    when(mockViewModel.memos).thenReturn([testMemo]);
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('메모 삭제'), findsOneWidget);
    expect(find.text('정말로 이 메모를 삭제하시겠습니까?'), findsOneWidget);
  });

  testWidgets('Confirming delete calls deleteMemo and closes dialog', (
    WidgetTester tester,
  ) async {
    when(mockViewModel.memos).thenReturn([testMemo]);
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    verify(mockViewModel.deleteMemo(testMemo.id, testPlace.id)).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Tapping FAB shows MemoFormDialog', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    // Find and tap the FloatingActionButton
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(); // Wait for dialog transition

    // Verify MemoFormDialog is shown
    expect(find.byType(MemoFormDialog), findsOneWidget);
  });
}
