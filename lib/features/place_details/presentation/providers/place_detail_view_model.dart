import 'package:flutter/material.dart';
// import '../../../../core/models/memo.dart'; // 이 경로 사용
// import '../../../../features/memo/models/memo.dart'; // 사용하지 않음
import 'package:cherryrecorder_client/core/models/memo.dart'; // 패키지 경로 사용
import '../../../../core/services/storage_service.dart'; // 추가
import 'package:logger/logger.dart'; // 로거 추가

class PlaceDetailViewModel extends ChangeNotifier {
  List<Memo> _memos = [];
  bool _isLoading = false;
  String? _error;
  final Logger _logger = Logger(); // 로거 인스턴스

  List<Memo> get memos => _memos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMemos(String placeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 신규 스토리지 서비스 사용
      _memos = await StorageService.instance.getMemosByPlaceId(placeId);
    } catch (e) {
      _error = '메모를 불러오는 중 오류가 발생했습니다: $e';
      _logger.e('메모 로드 오류 (placeId: $placeId):', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMemo(Memo memo) async {
    bool success = false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 신규 스토리지 서비스 사용
      _logger.d('메모 추가 시도: ${memo.id}');
      success = await StorageService.instance.saveMemo(memo);
      if (!success) {
        _error = '메모 저장에 실패했습니다.';
        _logger.e('StorageService.saveMemo 실패 (addMemo)');
      } else {
        _logger.d('메모 추가 성공: ${memo.id}');
      }
      await loadMemos(memo.placeId);
      return success;
    } catch (e) {
      _error = '메모를 저장하는 중 오류가 발생했습니다: $e';
      _logger.e('메모 추가 중 예외 발생:', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMemo(Memo memo) async {
    bool success = false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 신규 스토리지 서비스 사용
      _logger.d('메모 업데이트 시도: ${memo.id}');
      success = await StorageService.instance.updateMemo(memo);
      if (!success) {
        _error = '메모 수정에 실패했습니다.';
        _logger.e('StorageService.updateMemo 실패');
      } else {
        _logger.d('메모 업데이트 성공: ${memo.id}');
      }
      await loadMemos(memo.placeId);
      return success;
    } catch (e) {
      _error = '메모를 수정하는 중 오류가 발생했습니다: $e';
      _logger.e('메모 수정 중 예외 발생:', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMemo(String id, String placeId) async {
    bool success = false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 신규 스토리지 서비스 사용
      _logger.d('메모 삭제 시도: $id');
      success = await StorageService.instance.deleteMemo(id);
      if (!success) {
        _error = '메모 삭제에 실패했습니다.';
        _logger.e('StorageService.deleteMemo 실패 (ID: $id)');
      } else {
        _logger.d('메모 삭제 성공: $id');
      }
      await loadMemos(placeId);
      return success;
    } catch (e) {
      _error = '메모를 삭제하는 중 오류가 발생했습니다: $e';
      _logger.e('메모 삭제 중 예외 발생:', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
