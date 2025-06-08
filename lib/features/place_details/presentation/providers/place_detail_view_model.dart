/// 장소 상세 정보 화면의 상태와 비즈니스 로직을 관리하는 ViewModel입니다.
///
/// `ChangeNotifier`를 상속받아 UI에 상태 변경을 알립니다.
///
/// **주요 역할:**
/// - **상태 관리**: 특정 장소의 상세 정보(`PlaceDetail`), 해당 장소에 대한 메모 목록(`memos`),
///   로딩 상태, 에러 메시지 등 UI 렌더링에 필요한 상태를 관리합니다.
/// - **데이터 로딩**: `ApiClient`를 통해 서버로부터 장소 상세 정보를,
///   `StorageService`를 통해 로컬 DB로부터 메모 목록을 비동기적으로 로드합니다.
/// - **데이터 CRUD**: 사용자의 요청에 따라 `StorageService`를 사용하여 메모를
///   추가, 수정, 삭제하는 로직을 수행하고, 변경된 결과를 UI에 반영합니다.
library;

import 'package:flutter/material.dart';
import 'package:cherryrecorder_client/core/models/memo.dart';
import '../../../../core/services/storage_service.dart';
import 'package:logger/logger.dart';
import 'package:cherryrecorder_client/core/constants/api_constants.dart';
import 'package:cherryrecorder_client/core/models/place_detail.dart';
import 'package:cherryrecorder_client/core/network/api_client.dart';
import 'package:cherryrecorder_client/core/services/google_maps_service.dart';
import 'package:http/http.dart' as http;

/// 장소 상세 화면의 상태와 로직을 담당하는 ViewModel.
class PlaceDetailViewModel extends ChangeNotifier {
  late final ApiClient _apiClient;
  List<Memo> _memos = [];
  PlaceDetail? _placeDetail; // 장소 상세 정보 상태
  bool _isLoading = false;
  String? _error;
  final Logger _logger = Logger(); // 로거 인스턴스

  /// 현재 장소에 대한 메모 목록입니다.
  List<Memo> get memos => _memos;

  /// 현재 장소의 상세 정보입니다.
  PlaceDetail? get placeDetail => _placeDetail;

  /// 데이터 로딩 상태 여부입니다.
  bool get isLoading => _isLoading;

  /// 작업 중 발생한 에러 메시지입니다.
  String? get error => _error;

  /// 생성자에서 `ApiClient`를 초기화합니다.
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

  /// 특정 장소에 대한 모든 데이터(상세 정보, 메모)를 로드합니다.
  ///
  /// `Future.wait`를 사용하여 장소 정보 API 호출과 로컬 DB 조회를 병렬로 처리하여
  /// 로딩 시간을 단축합니다.
  /// [placeId] : 데이터를 조회할 장소의 고유 ID.
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

  /// 서버로부터 장소의 상세 정보를 비동기적으로 가져옵니다.
  /// [placeId] : 상세 정보를 조회할 장소의 고유 ID.
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

  /// 로컬 저장소에서 특정 장소에 대한 메모 목록을 로드합니다.
  /// [placeId] : 메모를 조회할 장소의 고유 ID.
  Future<void> loadMemos(String placeId) async {
    try {
      // 신규 스토리지 서비스 사용
      _memos = await StorageService.instance.getMemosByPlaceId(placeId);
    } catch (e) {
      _error = '메모를 불러오는 중 오류가 발생했습니다: $e';
      _logger.e('메모 로드 오류 (placeId: $placeId):', error: e);
    }
  }

  /// 새로운 메모를 로컬 저장소에 추가합니다.
  ///
  /// [memo] : 추가할 메모 객체.
  /// 성공 시 `true`, 실패 시 `false`를 반환합니다.
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

  /// 기존 메모를 수정합니다.
  ///
  /// [memo] : 수정할 내용을 담은 메모 객체.
  Future<bool> updateMemo(Memo memo) async {
    bool success = false;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 신규 스토리지 서비스 사용 (updateMemo -> saveMemo로 변경)
      _logger.d('메모 업데이트 시도: ${memo.id}');
      success = await StorageService.instance.saveMemo(memo);
      if (!success) {
        _error = '메모 수정에 실패했습니다.';
        _logger.e('StorageService.saveMemo 실패 (updateMemo)');
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

  /// 특정 메모를 삭제합니다.
  ///
  /// [id] : 삭제할 메모의 고유 ID.
  /// [placeId] : 메모 목록을 다시 로드하기 위한 장소 ID.
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
