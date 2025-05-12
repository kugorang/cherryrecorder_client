import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../models/memo.dart';

/// 로컬 저장소 관리 서비스
///
/// Hive를 사용하여 메모 데이터를 로컬에 저장하고 관리한다.
/// 웹과 네이티브 플랫폼 모두 지원한다.
class StorageService {
  static final StorageService _instance = StorageService._internal();

  static StorageService get instance => _instance;

  final _logger = Logger();
  Box<Memo>? _memoBox; // Memo 데이터를 저장하는 Hive 박스
  String? _storagePath; // 저장소 경로 (네이티브 환경에서만 사용)
  bool _isInitialized = false; // 초기화 여부

  // Hive 박스 이름 상수
  static const String _memoBoxName = 'memos';

  // 싱글톤 패턴 구현
  StorageService._internal();

  /// 스토리지 서비스 초기화
  /// [forceReinitialize]가 true인 경우 이미 초기화되어 있어도 다시 초기화한다.
  Future<void> initialize({bool forceReinitialize = false}) async {
    // 이미 초기화되었다면 건너뜀
    if (_isInitialized && !forceReinitialize) {
      _logger.d('스토리지 서비스가 이미 초기화되어 있어 초기화를 건너뜁니다.');
      return;
    }

    _logger.d('스토리지 서비스 초기화 시작');

    try {
      // 플랫폼별 초기화
      if (kIsWeb) {
        _initializeWeb();
      } else {
        await _initializeNative();
      }

      // 모델 어댑터 등록
      if (!Hive.isAdapterRegistered(MemoAdapter().typeId)) {
        Hive.registerAdapter(MemoAdapter());
      }

      // 메모 박스 열기
      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
      _logger.d('메모 박스 열기 성공');

      // 데이터가 심각하게 손상되었을 경우를 처리
      if (_memoBox == null || !_memoBox!.isOpen) {
        _logger.e('메모 박스를 열 수 없습니다. 저장소를 초기화합니다.');
        await _resetStorage();
        return;
      }

      // 박스 무결성 검사
      await validateBoxIntegrity();

      // 초기화 완료 표시
      _isInitialized = true;
      _logger.d('스토리지 서비스 초기화 완료');

      // 데이터 무결성 검사 실행 (초기화 과정에서는 불필요한 순환 참조를 방지하기 위해 단순 검사만 수행)
      // 무한 루프 방지를 위해 직접 검사 로직 수행
      if (_memoBox != null && _memoBox!.isOpen) {
        _logger.d('초기화 후 간단한 박스 상태 점검: ${_memoBox!.keys.length}개 항목');
      }
    } catch (e) {
      _logger.e('스토리지 서비스 초기화 실패: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// 웹 환경에서의 Hive 초기화
  void _initializeWeb() {
    _logger.d('웹 환경 Hive 초기화');
    Hive.initFlutter();
  }

  /// 네이티브 환경에서의 Hive 초기화
  Future<void> _initializeNative() async {
    _logger.d('네이티브 환경 Hive 초기화 시작');

    // 모바일 플랫폼에서는 경로 설정이 필요
    final appDocumentDir =
        await path_provider.getApplicationDocumentsDirectory();
    _storagePath = appDocumentDir.path;
    _logger.d('네이티브 저장 경로: $_storagePath');

    // 저장 경로 확인
    if (_storagePath != null) {
      final dir = Directory(_storagePath!);
      if (await dir.exists()) {
        _logger.d('저장 디렉토리가 존재합니다.');
      } else {
        _logger.d('저장 디렉토리가 존재하지 않습니다. 생성합니다.');
        await dir.create(recursive: true);
      }
    }

    _logger.d('Hive.init 호출 (경로: $_storagePath)');
    Hive.init(_storagePath!);
    _logger.d('네이티브 환경 Hive 초기화 완료');
  }

  // 박스 내용 로깅 헬퍼 함수
  Future<void> _logBoxContents(String contextDesc) async {
    if (_memoBox != null && _memoBox!.isOpen) {
      final keys = _memoBox!.keys.toList();
      _logger.d(
        '[$contextDesc] 박스 상태: 열림, 항목 수: ${keys.length}, 저장된 키: ${keys.join(', ')}',
      );
      for (final key in keys) {
        try {
          final memo = _memoBox!.get(key);
          if (memo != null) {
            // Memo 객체의 toString() 메서드 활용 또는 주요 필드 출력
            _logger.d('[$contextDesc] 항목[$key]: ${memo.toString()}');
          } else {
            _logger.w('[$contextDesc] 항목[$key] 조회 결과가 null입니다.');
          }
        } catch (e) {
          _logger.e('[$contextDesc] 항목[$key] 조회 중 오류: $e');
        }
      }
    } else {
      _logger.w('[$contextDesc] 박스가 null이거나 닫혀있어 내용을 로깅할 수 없습니다.');
    }
  }

  /// 특정 좌표에 해당하는 메모 목록 가져오기
  ///
  /// 위도와 경도가 일치하는 메모들을 찾아 최신순으로 정렬하여 반환한다.
  ///
  /// * [latitude]: 찾으려는 장소의 위도.
  /// * [longitude]: 찾으려는 장소의 경도.
  Future<List<Memo>> getMemosForLocation(
    double latitude,
    double longitude,
  ) async {
    await _ensureBoxOpen(); // 박스가 열려있는지 확인

    try {
      final box = _memoBox!;
      _logger.d('getMemosForLocation 시작 (lat: $latitude, lng: $longitude)');
      await _logBoxContents("getMemosForLocation 시작 시점");

      // 위도/경도로 필터링
      final allItems = box.values.toList();
      final result =
          allItems
              .where(
                (memo) =>
                    memo.latitude == latitude && memo.longitude == longitude,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // 최신순 정렬

      _logger.d(
        'getMemosForLocation 완료: ${result.length}개의 메모 로드됨 (lat: $latitude, lng: $longitude)',
      );
      return result;
    } catch (e) {
      _logger.e(
        '특정 위치 메모 조회 중 오류 (lat: $latitude, lng: $longitude):',
        error: e,
      );
      return []; // 오류 시 빈 목록 반환
    }
  }

  /// 메모 저장
  ///
  /// [memo] 객체의 [id]를 키로 사용하여 Hive 박스에 저장한다.
  /// 저장 후 `flush()`를 호출하여 디스크에 즉시 기록한다.
  ///
  /// * [memo]: 저장할 [Memo] 객체.
  ///
  /// Throws: Hive 쓰기 작업 중 오류 발생 시 예외를 던질 수 있다.
  Future<bool> saveMemo(Memo memo) async {
    await _ensureBoxOpen();
    bool success = false;
    try {
      final box = _memoBox!;
      final beforeCount = box.length;
      await box.put(memo.id, memo);
      final afterCount = box.length;
      await box.flush(); // 플러시 보장
      success = box.containsKey(memo.id);

      _logger.d(
        '메모 저장 ${success ? "성공" : "실패"} (ID: ${memo.id})\n'
        '내용: ${memo.content.substring(0, memo.content.length > 20 ? 20 : memo.content.length)}...\n'
        '저장소 상태: $beforeCount → $afterCount\n'
        '저장 경로: ${_storagePath ?? "웹 스토리지"}',
      );
      if (success) await _logBoxContents("saveMemo 후");
      return success;
    } catch (e) {
      _logger.e('메모 저장 중 오류 (ID: ${memo.id}):', error: e);
      return false;
    }
  }

  /// 메모 수정
  Future<bool> updateMemo(Memo memo) async {
    // saveMemo가 flush를 포함하므로 별도 flush 불필요
    return saveMemo(memo);
  }

  /// 메모 삭제
  ///
  /// * [id]: 삭제할 메모의 ID.
  ///
  /// Throws: Hive 삭제 작업 중 오류 발생 시 예외를 던질 수 있다.
  Future<bool> deleteMemo(String id) async {
    await _ensureBoxOpen();
    bool success = false;
    try {
      final box = _memoBox!;
      final beforeCount = box.length;
      if (!box.containsKey(id)) {
        _logger.w('삭제할 메모 ID 없음: $id');
        return false;
      }
      await box.delete(id);
      final afterCount = box.length;
      await box.flush(); // 플러시 보장
      success = !box.containsKey(id) && beforeCount > afterCount;

      _logger.d(
        '메모 삭제 ${success ? "성공" : "실패"}: $id (항목 수: $beforeCount → $afterCount)',
      );
      if (success) await _logBoxContents("deleteMemo 후");
      return success;
    } catch (e) {
      _logger.e('메모 삭제 중 오류 (ID: $id):', error: e);
      return false;
    }
  }

  /// 모든 메모 가져오기
  Future<List<Memo>> getAllMemos() async {
    await _ensureBoxOpen();
    try {
      final box = _memoBox!;
      final result =
          box.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _logger.d('전체 ${result.length}개의 메모 로드됨');
      return result;
    } catch (e) {
      _logger.e('전체 메모 조회 중 오류:', error: e);
      return [];
    }
  }

  /// 메모 검색 (내용만 검색)
  ///
  /// 내용에 [query] 문자열을 포함하는 메모들을 찾아 최신순으로 정렬하여 반환한다.
  /// 검색은 대소문자를 구분하지 않는다.
  ///
  /// * [query]: 검색할 문자열.
  Future<List<Memo>> searchMemos(String query) async {
    await _ensureBoxOpen();

    try {
      final box = _memoBox!;
      final lowercaseQuery = query.toLowerCase();

      final result =
          box.values
              .where(
                (memo) => memo.content.toLowerCase().contains(lowercaseQuery),
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // 최신순 정렬

      _logger.d('검색 결과: ${result.length}개의 메모 (검색어: $query)');
      return result;
    } catch (e) {
      _logger.e('메모 검색 중 오류:', error: e);
      return []; // 오류 시 빈 목록 반환
    }
  }

  /// 특정 장소 ID에 해당하는 메모 목록 가져오기
  ///
  /// [placeId]가 일치하는 메모들을 찾아 최신순으로 정렬하여 반환한다.
  ///
  /// * [placeId]: 찾으려는 장소의 고유 식별자.
  Future<List<Memo>> getMemosByPlaceId(String placeId) async {
    await _ensureBoxOpen();
    try {
      final box = _memoBox!;
      _logger.d('getMemosByPlaceId 시작 (placeId: $placeId)');
      await _logBoxContents("getMemosByPlaceId 시작 시점");

      // placeId로 필터링
      final allItems = box.values.toList();
      final result =
          allItems.where((memo) => memo.placeId == placeId).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // 최신순 정렬

      _logger.d(
        'getMemosByPlaceId 완료: ${result.length}개의 메모 로드됨 (placeId: $placeId)',
      );
      return result;
    } catch (e) {
      _logger.e('특정 장소 ID 메모 조회 중 오류 (placeId: $placeId):', error: e);
      return []; // 오류 시 빈 목록 반환
    }
  }

  /// 스토리지가 초기화되었는지 확인
  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _memoBox == null) {
      await initialize();
    }
  }

  /// 박스가 열려있는지 확인하고, 필요시 열기
  Future<Box<Memo>> _ensureBoxOpen() async {
    await _ensureInitialized();

    if (_memoBox == null || !_memoBox!.isOpen) {
      _logger.d('메모 박스가 닫혀있어 다시 엽니다.');
      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
    }

    return _memoBox!;
  }

  /// 박스 무결성 검사 및 손상된 항목 삭제
  Future<void> validateBoxIntegrity() async {
    // 박스가 열려있는지 직접 확인
    if (_memoBox == null || !_memoBox!.isOpen) {
      _logger.w('박스가 열려있지 않아 무결성 검사를 건너뜁니다.');
      return;
    }

    final box = _memoBox!;

    int corruptedItems = 0;
    final allKeys = box.keys.toList();

    for (final key in allKeys) {
      try {
        // 각 항목을 시험적으로 읽어보기
        final item = box.get(key);
        if (item == null) {
          _logger.w('항목 $key의 값이 null입니다.');
          corruptedItems++;
        }
      } catch (e) {
        _logger.e('항목 $key 읽기 실패: $e');
        corruptedItems++;

        // 손상된 항목 삭제 시도
        try {
          await box.delete(key);
          _logger.d('손상된 항목 $key 삭제 성공');
        } catch (deleteError) {
          _logger.e('손상된 항목 $key 삭제 실패: $deleteError');
        }
      }
    }

    if (corruptedItems > 0) {
      _logger.w('$corruptedItems개의 손상된 항목이 발견되었습니다.');
    } else {
      _logger.d('무결성 검사 완료: 모든 항목이 정상입니다.');
    }
  }

  /// 모든 Hive 박스 닫기
  Future<void> closeBoxes() async {
    if (_memoBox != null && _memoBox!.isOpen) {
      await _memoBox!.close();
      _logger.d('메모 박스 닫기 성공');
    }
  }

  /// 저장소 완전 초기화 (모든 데이터 삭제)
  Future<void> _resetStorage() async {
    _logger.w('저장소 초기화 시작');

    try {
      // 이미 열린 박스가 있으면 닫기
      await closeBoxes();

      // Hive 박스 삭제
      await Hive.deleteBoxFromDisk(_memoBoxName);
      _logger.d('메모 박스 삭제 성공');

      // 재초기화
      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
      _logger.d('메모 박스 재생성 성공');

      _isInitialized = true;
    } catch (e) {
      _logger.e('저장소 초기화 실패: $e');
      _isInitialized = false;
      rethrow;
    }
  }
}
