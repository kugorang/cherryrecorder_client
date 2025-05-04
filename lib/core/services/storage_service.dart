import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
// import '../models/memo.dart'; // 기존 상대 경로 주석 처리
// import 'package:cherryrecorder_client/features/memo/models/memo.dart'; // 잘못된 경로 주석 처리
import 'package:cherryrecorder_client/core/models/memo.dart'; // 올바른 패키지 경로 사용
import 'package:logger/logger.dart';
// memo_adapter.dart 대신 memo.dart에서 자동 생성된 어댑터 사용

/// 앱의 로컬 데이터 저장을 관리하는 서비스.
///
/// Hive 데이터베이스를 사용하여 메모([Memo]) 데이터를 저장, 조회, 수정, 삭제한다.
/// 웹과 네이티브 환경 모두에서 작동하도록 구현되었다.
class StorageService {
  static const String _memoBoxName = 'memos_box_v2';
  static final StorageService instance = StorageService._internal();
  bool _initialized = false;
  final Logger _logger = Logger();
  Box<Memo>? _memoBox;
  String? _storagePath;

  StorageService._internal();

  /// Hive 초기화
  ///
  /// Hive 데이터베이스를 초기화하고 [MemoAdapter]를 등록하며,
  /// 메모 데이터를 저장할 박스([_memoBox])를 연다.
  /// 웹 환경에서는 경로 설정 없이 Hive를 초기화한다.
  ///
  /// Throws: Hive 초기화 또는 박스 열기 중 오류 발생 시 예외를 던질 수 있다.
  Future<void> initialize() async {
    if (_initialized && _memoBox != null && _memoBox!.isOpen) {
      _logger.d(
        'Hive는 이미 초기화되었습니다. 박스: ${_memoBox?.name}, 항목: ${_memoBox?.length}',
      );
      return;
    }

    try {
      _logger.d('Hive 초기화 시작...');

      if (!kIsWeb) {
        // 모바일 플랫폼에서는 경로 설정이 필요
        final appDocumentDir =
            await path_provider.getApplicationDocumentsDirectory();
        _storagePath = appDocumentDir.path;
        _logger.d('모바일 저장 경로: $_storagePath');

        // 저장 경로 확인
        if (_storagePath != null) {
          final dir = Directory(_storagePath!);
          if (await dir.exists()) {
            _logger.d('저장 디렉토리가 존재합니다.');
            final contents = await dir.list().toList();
            _logger.d(
              '디렉토리 내용: ${contents.map((e) => e.path.split('/').last).join(', ')}',
            );
          } else {
            _logger.d('저장 디렉토리가 존재하지 않습니다. 생성합니다.');
            await dir.create(recursive: true);
          }
        }

        _logger.d('Hive.init 호출 (경로: ${_storagePath ?? "웹"})');
        Hive.init(_storagePath!);
      } else {
        // 웹에서는 IndexedDB를 자동으로 사용
        _logger.d('웹 환경 Hive 초기화');
        await Hive.initFlutter();
      }
      _logger.d('Hive.init 완료');

      // Memo 어댑터 등록 확인
      _logger.d('어댑터 등록 상태 확인');
      final typeId = 1;
      final isRegistered = Hive.isAdapterRegistered(typeId);
      _logger.d('MemoAdapter(typeId: $typeId) 등록 여부: $isRegistered');

      if (!isRegistered) {
        _logger.d('MemoAdapter 등록 중...');
        try {
          Hive.registerAdapter(MemoAdapter());
          _logger.d('MemoAdapter 등록 성공');
        } catch (e) {
          _logger.e('MemoAdapter 등록 오류: $e');
          // 등록 실패 시 초기화 중단 또는 오류 처리
          rethrow;
        }
      } else {
        _logger.d('MemoAdapter가 이미 등록되어 있습니다.');
      }

      // 메모 박스 열기 시도
      _logger.d('$_memoBoxName 박스 열기 시도...');
      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
      _logger.d(
        '$_memoBoxName 박스 열기 완료. isOpen: ${_memoBox?.isOpen}, path: ${_memoBox?.path}',
      );

      if (_memoBox == null || !_memoBox!.isOpen) {
        _logger.e('박스를 여는 데 실패했습니다!');
        throw Exception('Failed to open Hive box: $_memoBoxName');
      }

      _initialized = true;
      _logger.d('Hive 초기화 완료: 박스에 ${_memoBox?.length}개의 항목이 있습니다.');

      // 초기화 직후 박스 내용 상세 로깅
      await _logBoxContents("초기화 직후");
    } catch (e, stackTrace) {
      _logger.e('Hive 초기화 중 심각한 오류:', error: e, stackTrace: stackTrace);
      _initialized = false; // 초기화 실패 상태 명시
      _memoBox = null;
      // 앱 실행에 필수적이므로 오류를 다시 던짐
      rethrow;
    }
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

  /// 초기화 확인 및 필요시 초기화
  Future<void> _ensureInitialized() async {
    if (!_initialized || _memoBox == null) {
      // _memoBox null 체크 추가
      _logger.d('저장소가 초기화되지 않았거나 박스가 null입니다. 지금 초기화합니다.');
      await initialize();
    }
  }

  /// 박스가 열려 있는지 확인 및 다시 열기
  Future<void> _ensureBoxOpen() async {
    await _ensureInitialized();

    if (!_memoBox!.isOpen) {
      // Null check operator 사용 (초기화 보장 후)
      _logger.w('메모 박스가 닫혀 있습니다. 다시 엽니다.');
      try {
        _memoBox = await Hive.openBox<Memo>(_memoBoxName);
        _logger.d('박스 다시 열기 성공.');
      } catch (e) {
        _logger.e('박스 다시 열기 실패:', error: e);
        // 필요시 오류 전파 또는 기본값 처리
        rethrow;
      }
    }
  }

  /// 앱 종료 전 Hive 박스 닫기 (더 이상 필수 아님, 하지만 유지)
  Future<void> closeBoxes() async {
    if (_initialized) {
      _logger.d('Hive 박스 닫기 시작');
      if (_memoBox != null && _memoBox!.isOpen) {
        // 닫기 전에 마지막으로 플러시 시도 (선택적)
        // await _memoBox!.flush();
        await _memoBox!.close();
      }
      // Hive.close()는 모든 박스를 닫으므로 개별 close 후에는 필요 없을 수 있음
      // await Hive.close();
      _memoBox = null;
      _initialized = false;
      _logger.d('Hive 박스 닫힘');
    }
  }
}
