import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:cherryrecorder_client/core/services/storage_service.dart';
// import 'package:cherryrecorder_client/features/memo/models/memo.dart'; // 잘못된 경로 주석 처리
import 'package:cherryrecorder_client/core/models/memo.dart'; // 올바른 패키지 경로 사용

/// 장소 상세 정보 및 관련 메모를 관리하는 ViewModel.
///
/// 사용자가 선택한 장소([LatLng])에 대한 정보를 표시하고,
/// 해당 장소와 관련된 메모 목록을 로드하며, 메모 추가/수정/삭제 기능을 제공한다.
/// UI 상태 변경을 알리기 위해 [ChangeNotifier]를 사용한다.
class PlaceDetailViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final Logger _logger;

  /// 현재 선택된 장소의 좌표.
  LatLng? _selectedPlace;

  /// 로드된 메모 목록.
  List<Memo> _memos = [];

  /// 현재 로딩 상태.
  bool _isLoading = false;

  /// 오류 메시지.
  String? _errorMessage;

  /// [PlaceDetailViewModel] 인스턴스를 생성한다.
  ///
  /// * [storageService]: 메모 데이터 관리를 위한 [StorageService].
  /// * [logger]: 로깅을 위한 [Logger].
  PlaceDetailViewModel({
    required StorageService storageService,
    required Logger logger,
  }) : _storageService = storageService,
       _logger = logger;

  /// 현재 선택된 장소의 좌표를 반환한다.
  LatLng? get selectedPlace => _selectedPlace;

  /// 현재 로드된 메모 목록을 반환한다.
  List<Memo> get memos => _memos;

  /// 현재 로딩 상태를 반환한다.
  bool get isLoading => _isLoading;

  /// 현재 오류 메시지를 반환한다.
  String? get errorMessage => _errorMessage;

  /// 새로운 장소를 선택하고 관련 메모를 로드한다.
  ///
  /// * [place]: 사용자가 선택한 장소의 [LatLng].
  Future<void> selectPlace(LatLng place) async {
    _logger.i('장소 선택됨: $place');
    _selectedPlace = place;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      // 변경된 StorageService 메서드 사용
      _memos = await _storageService.getMemosForLocation(
        place.latitude,
        place.longitude,
      );
      _logger.d(
        '선택된 장소 (${place.latitude}, ${place.longitude})에 대한 메모 로드 완료: ${_memos.length}개',
      );
    } catch (e, stackTrace) {
      _logger.e('메모 로드 실패', error: e, stackTrace: stackTrace);
      _errorMessage = '메모를 불러오는 데 실패했습니다: $e';
      _memos = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 새로운 메모를 추가한다.
  ///
  /// 현재 선택된 장소가 있어야만 메모를 추가할 수 있다.
  /// 성공적으로 추가되면 메모 목록을 갱신하고 UI에 알린다.
  ///
  /// * [content]: 추가할 메모의 내용.
  Future<void> addMemo(String content) async {
    if (_selectedPlace == null) {
      _logger.w('메모 추가 시도: 선택된 장소 없음');
      _errorMessage = '메모를 추가할 장소를 먼저 선택해주세요.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 임시 placeId 생성 (추후 개선 필요)
      final placeId =
          '${_selectedPlace!.latitude}_${_selectedPlace!.longitude}';

      final newMemo = Memo(
        placeId: placeId,
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        content: content,
      );
      // StorageService.saveMemo는 Future<bool> 반환
      final success = await _storageService.saveMemo(newMemo);
      if (success) {
        _logger.i('새 메모 추가 완료: ${newMemo.id}');
        await selectPlace(_selectedPlace!); // 목록 갱신
      } else {
        throw Exception('StorageService에서 메모 저장 실패');
      }
    } catch (e, stackTrace) {
      _logger.e('메모 추가 실패', error: e, stackTrace: stackTrace);
      _errorMessage = '메모 추가 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
    // 성공 시에는 selectPlace 내부에서 finally 호출됨
  }

  /// 기존 메모를 업데이트한다.
  ///
  /// * [updatedMemo]: 업데이트할 정보가 담긴 [Memo] 객체.
  Future<void> updateMemo(Memo updatedMemo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // updatedMemo.updatedAt = DateTime.now(); // final 필드이므로 제거
      // StorageService.updateMemo는 Future<bool> 반환
      final success = await _storageService.updateMemo(updatedMemo);
      if (success) {
        _logger.i('메모 업데이트 완료: ${updatedMemo.id}');
        if (_selectedPlace != null) {
          await selectPlace(_selectedPlace!); // 목록 갱신
        } else {
          // 선택된 장소 없을 시 getAllMemos (Future) 호출
          _memos = await _storageService.getAllMemos(); // await 추가
          _isLoading = false;
          notifyListeners();
        }
      } else {
        throw Exception('StorageService에서 메모 업데이트 실패');
      }
    } catch (e, stackTrace) {
      _logger.e(
        '메모 업데이트 실패: ${updatedMemo.id}',
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = '메모 업데이트 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
    // 성공 시에는 selectPlace 내부에서 finally 호출됨 (선택된 장소 있을 시)
  }

  /// 지정된 ID의 메모를 삭제한다.
  ///
  /// * [memoId]: 삭제할 메모의 ID.
  Future<void> deleteMemo(String memoId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // StorageService.deleteMemo는 Future<bool> 반환
      final success = await _storageService.deleteMemo(memoId);
      if (success) {
        _logger.i('메모 삭제 완료: $memoId');
        if (_selectedPlace != null) {
          await selectPlace(_selectedPlace!); // 목록 갱신
        } else {
          // 선택된 장소 없을 시 getAllMemos (Future) 호출
          _memos = await _storageService.getAllMemos(); // await 추가
          _isLoading = false;
          notifyListeners();
        }
      } else {
        throw Exception('StorageService에서 메모 삭제 실패');
      }
    } catch (e, stackTrace) {
      _logger.e('메모 삭제 실패: $memoId', error: e, stackTrace: stackTrace);
      _errorMessage = '메모 삭제 중 오류가 발생했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
    // 성공 시에는 selectPlace 내부에서 finally 호출됨 (선택된 장소 있을 시)
  }
}
