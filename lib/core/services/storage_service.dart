/// 로컬 데이터 저장을 중앙에서 관리하는 서비스 클래스 파일입니다.
///
/// Hive 데이터베이스를 사용하여 앱의 주요 데이터(`Memo`)를 디바이스에 저장하고
/// 관리(CRUD)하는 역할을 합니다. **싱글턴(Singleton)** 패턴으로 구현되어
/// 앱 전체에서 단 하나의 인스턴스만 사용하도록 보장합니다.
///
/// **주요 기능:**
/// - 플랫폼(웹/모바일)에 맞는 Hive 초기화 수행
/// - `Memo` 데이터의 추가, 조회, 수정, 삭제 기능 제공
/// - 태그, 위치, 장소 ID 등 다양한 조건에 따른 메모 검색 기능 제공
/// - 데이터베이스 파일의 무결성 검사 및 복구 기능
library;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../models/memo.dart';

/// Hive를 사용하여 메모 데이터를 로컬에 저장하고 관리하는 서비스 클래스입니다.
///
/// 웹과 네이티브 플랫폼 모두 지원한다.
class StorageService {
  /// 싱글턴 인스턴스. `_internal` 생성자를 통해 한 번만 생성됩니다.
  static final StorageService _instance = StorageService._internal();

  /// `StorageService`의 싱글턴 인스턴스에 접근하기 위한 getter입니다.
  static StorageService get instance => _instance;

  final _logger = Logger();

  /// `Memo` 객체를 저장하는 Hive의 데이터베이스 인스턴스입니다. 'Box'라고 불립니다.
  Box<Memo>? _memoBox;

  /// 데이터베이스 파일이 저장될 경로입니다. (네이티브 플랫폼에서만 사용)
  String? _storagePath;

  /// 서비스가 성공적으로 초기화되었는지 여부를 나타냅니다.
  bool _isInitialized = false;

  /// 메모 데이터가 저장될 Hive Box의 이름입니다.
  static const String _memoBoxName = 'memos';

  /// 외부에서 인스턴스 생성을 막기 위한 private 생성자입니다.
  StorageService._internal();

  /// 스토리지 서비스를 초기화합니다.
  ///
  /// Hive 데이터베이스를 사용하기 전에 반드시 호출되어야 합니다.
  /// 플랫폼(웹/모바일)에 따라 다른 초기화 절차를 수행하고,
  /// `Memo` 모델을 Hive가 인식할 수 있도록 어댑터를 등록한 후,
  /// `_memoBox`를 엽니다.
  ///
  /// [forceReinitialize]가 `true`이면, 이미 초기화되었더라도 강제로 다시 초기화합니다.
  Future<void> initialize({bool forceReinitialize = false}) async {
    if (_isInitialized && !forceReinitialize) {
      _logger.d('스토리지 서비스가 이미 초기화되어 있어 초기화를 건너뜁니다.');
      return;
    }

    _logger.d('스토리지 서비스 초기화 시작');

    try {
      if (kIsWeb) {
        await _initializeWeb();
      } else {
        await _initializeNative();
      }

      // Hive가 Memo 객체를 직렬화/역직렬화할 수 있도록 어댑터를 등록합니다.
      // 한 번만 등록해야 하므로 isAdapterRegistered로 확인합니다.
      if (!Hive.isAdapterRegistered(MemoAdapter().typeId)) {
        Hive.registerAdapter(MemoAdapter());
      }

      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
      _logger.d('메모 박스 열기 성공');

      // 데이터 파일의 무결성을 검사하고 손상된 항목을 정리합니다.
      await _validateBoxIntegrity();

      _isInitialized = true;
      _logger.d('스토리지 서비스 초기화 완료');
    } catch (e) {
      _logger.e('스토리지 서비스 초기화 실패: $e');
      _isInitialized = false;
      // 초기화 실패는 앱의 심각한 문제이므로 예외를 다시 던집니다.
      rethrow;
    }
  }

  /// 웹 환경을 위한 Hive 초기화를 수행합니다.
  Future<void> _initializeWeb() async {
    _logger.d('웹 환경 Hive 초기화');
    await Hive.initFlutter();
  }

  /// 모바일(네이티브) 환경을 위한 Hive 초기화를 수행합니다.
  ///
  /// 앱의 문서 디렉토리 경로를 얻어와 Hive의 저장 경로로 설정합니다.
  Future<void> _initializeNative() async {
    _logger.d('네이티브 환경 Hive 초기화 시작');
    final appDocumentDir =
        await path_provider.getApplicationDocumentsDirectory();
    _storagePath = appDocumentDir.path;
    _logger.d('네이티브 저장 경로: $_storagePath');
    Hive.init(_storagePath!);
  }

  /// 특정 장소 ID에 해당하는 모든 메모를 최신순으로 정렬하여 반환합니다.
  ///
  /// [placeId] : 메모를 필터링할 장소의 고유 ID.
  Future<List<Memo>> getMemosByPlaceId(String placeId) async {
    await _ensureBoxOpen();

    final allMemos = _memoBox!.values.toList();
    final result = allMemos.where((memo) => memo.placeId == placeId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _logger.d('${result.length}개의 메모 로드됨 (placeId: $placeId)');
    return result;
  }

  /// 새로운 메모를 저장하거나 기존 메모를 수정합니다.
  ///
  /// [memo] 객체의 `id`를 키로 사용하여 Hive Box에 저장합니다.
  /// Hive의 `put` 메서드는 해당 키가 존재하면 데이터를 덮어쓰므로,
  /// 저장과 수정 로직을 통합하여 사용합니다.
  Future<bool> saveMemo(Memo memo) async {
    await _ensureBoxOpen();
    try {
      await _memoBox!.put(memo.id, memo);
      // `flush`는 디스크에 즉시 변경사항을 기록하도록 보장하지만,
      // 성능에 영향을 줄 수 있으므로 중요한 데이터 변경 시에만 사용합니다.
      await _memoBox!.flush();
      _logger.d('메모 저장 성공 (ID: ${memo.id})');
      return true;
    } catch (e) {
      _logger.e('메모 저장 중 오류 (ID: ${memo.id}):', error: e);
      return false;
    }
  }

  /// 메모를 삭제합니다.
  ///
  /// [id] : 삭제할 메모의 고유 ID.
  Future<bool> deleteMemo(String id) async {
    await _ensureBoxOpen();
    try {
      await _memoBox!.delete(id);
      await _memoBox!.flush();
      _logger.d('메모 삭제 성공 (ID: $id)');
      return true;
    } catch (e) {
      _logger.e('메모 삭제 중 오류 (ID: $id):', error: e);
      return false;
    }
  }

  /// 저장된 모든 메모를 최신순으로 정렬하여 반환합니다.
  Future<List<Memo>> getAllMemos() async {
    await _ensureBoxOpen();
    final result = _memoBox!.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _logger.d('전체 ${result.length}개의 메모 로드됨');
    return result;
  }

  /// 메모 내용에서 특정 검색어로 검색합니다.
  ///
  /// [query] : 검색할 문자열. 대소문자를 구분하지 않습니다.
  Future<List<Memo>> searchMemos(String query) async {
    await _ensureBoxOpen();
    final lowercaseQuery = query.toLowerCase();
    final result = _memoBox!.values
        .where((memo) => memo.content.toLowerCase().contains(lowercaseQuery))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _logger.d('검색 결과: ${result.length}개 (검색어: $query)');
    return result;
  }

  /// 서비스 및 Box가 사용 가능한 상태인지 확인하고, 아니면 초기화/재오픈합니다.
  ///
  /// 다른 모든 public 메서드 시작 부분에서 호출되어 안정성을 보장합니다.
  Future<void> _ensureBoxOpen() async {
    if (!_isInitialized) {
      _logger.w('서비스가 초기화되지 않아 강제 초기화를 시도합니다.');
      await initialize();
    }
    if (_memoBox == null || !_memoBox!.isOpen) {
      _logger.w('메모 박스가 닫혀있어 다시 엽니다.');
      _memoBox = await Hive.openBox<Memo>(_memoBoxName);
    }
  }

  /// 데이터베이스 파일의 무결성을 검사하고 손상된 데이터를 정리합니다.
  ///
  /// Box의 모든 항목을 읽어보면서, 읽기에 실패하는(손상된) 항목이 있으면
  /// 해당 항목을 삭제하여 데이터베이스의 안정성을 높입니다.
  Future<void> _validateBoxIntegrity() async {
    if (_memoBox == null || !_memoBox!.isOpen) {
      _logger.w('박스가 열려있지 않아 무결성 검사를 건너뜁니다.');
      return;
    }
    final box = _memoBox!;
    int corruptedCount = 0;
    // 키 목록을 복사하여 순회 중 삭제가 일어나도 안전하도록 합니다.
    final allKeys = box.keys.toList();

    for (final key in allKeys) {
      try {
        box.get(key); // 데이터 읽기 시도
      } catch (e) {
        corruptedCount++;
        _logger.e('손상된 항목 발견 (key: $key). 삭제를 시도합니다.', error: e);
        await box.delete(key);
      }
    }
    if (corruptedCount > 0) {
      _logger.w('$corruptedCount 개의 손상된 항목을 정리했습니다.');
    } else {
      _logger.d('무결성 검사 완료: 모든 항목이 정상입니다.');
    }
  }
}
