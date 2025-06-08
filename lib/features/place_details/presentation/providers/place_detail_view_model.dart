import 'package:flutter/material.dart';
import 'package:cherryrecorder_client/core/models/memo.dart';
import '../../../../core/services/storage_service.dart';
import 'package:logger/logger.dart';
import 'package:cherryrecorder_client/core/constants/api_constants.dart';
import 'package:cherryrecorder_client/core/models/place_detail.dart';
import 'package:cherryrecorder_client/core/network/api_client.dart';
import 'package:cherryrecorder_client/core/services/google_maps_service.dart';
import 'package:http/http.dart' as http;

class PlaceDetailViewModel extends ChangeNotifier {
  late final ApiClient _apiClient;
  List<Memo> _memos = [];
  PlaceDetail? _placeDetail; // 장소 상세 정보 상태
  bool _isLoading = false;
  String? _error;
  final Logger _logger = Logger(); // 로거 인스턴스

  List<Memo> get memos => _memos;
  PlaceDetail? get placeDetail => _placeDetail; // Getter 추가
  bool get isLoading => _isLoading;
  String? get error => _error;

  PlaceDetailViewModel() {
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl();
    _apiClient = ApiClient(client: http.Client(), baseUrl: serverUrl);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> loadData(String placeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 장소 상세 정보와 메모를 동시에 로드
      await Future.wait([
        loadPlaceDetails(placeId),
        loadMemos(placeId),
      ]);
    } catch (e) {
      _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      _logger.e('데이터 로드 오류 (placeId: $placeId):', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlaceDetails(String placeId) async {
    try {
      final String endpoint = '${ApiConstants.placeDetailsEndpoint}/$placeId';
      _logger.d('장소 상세 정보 요청: $endpoint');

      final result = await _apiClient.get(endpoint);
      _logger.i('서버 응답 받음: ${result.toString()}');

      _placeDetail = PlaceDetail.fromJson(result);

      // 주소 정보 로그
      _logger.d(
          '파싱된 주소 정보: formattedAddress=${_placeDetail?.formattedAddress}, vicinity=${_placeDetail?.vicinity}');
    } catch (e) {
      _error = '장소 상세 정보를 불러오는 중 오류가 발생했습니다: $e';
      _logger.e('장소 상세 정보 로드 오류 (placeId: $placeId):', error: e);
      // 오류가 발생해도 리스너에게 알려서 UI가 멈추지 않도록 함
    }
  }

  Future<void> loadMemos(String placeId) async {
    try {
      // 신규 스토리지 서비스 사용
      _memos = await StorageService.instance.getMemosByPlaceId(placeId);
    } catch (e) {
      _error = '메모를 불러오는 중 오류가 발생했습니다: $e';
      _logger.e('메모 로드 오류 (placeId: $placeId):', error: e);
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

  Future<List<Memo>> getAllMemosWithTag(String tag) async {
    try {
      // 모든 메모를 가져온 후 태그로 필터링
      final allMemos = await StorageService.instance.getAllMemos();
      return allMemos.where((memo) {
        if (memo.tags == null || memo.tags!.isEmpty) return false;
        final tags = memo.tags!.split(' ').map((t) => t.trim()).toList();
        return tags.contains(tag);
      }).toList();
    } catch (e) {
      _logger.e('태그별 메모 조회 오류 (tag: $tag):', error: e);
      return [];
    }
  }
}
