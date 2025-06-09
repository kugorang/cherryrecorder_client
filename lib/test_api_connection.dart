import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'core/models/place_summary.dart';
import 'core/services/google_maps_service.dart';

/// API 연결 테스트를 위한 위젯
///
/// 서버 상태, 주변 장소 검색, 장소 검색, 장소 상세 정보를 조회하는
/// API 엔드포인트 동작을 검증한다.
class ApiConnectionTest extends StatefulWidget {
  const ApiConnectionTest({super.key});

  @override
  State<ApiConnectionTest> createState() => _ApiConnectionTestState();
}

class _ApiConnectionTestState extends State<ApiConnectionTest> {
  late final ApiClient _apiClient;
  String _resultText = '테스트 결과가 여기에 표시됩니다.';
  bool _isLoading = false;
  final _logger = Logger();

  // 지도 관련 변수
  GoogleMapController? _mapController;
  static const LatLng _defaultLocation = LatLng(37.5665, 126.9780); // 서울
  Set<Marker> _markers = {};
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    // 플랫폼에 맞는 서버 URL 가져오기
    final googleMapsService = GoogleMapsService();
    final serverUrl = googleMapsService.getServerUrl();
    _logger.i('API 테스트 페이지 - URL: $serverUrl');

    _apiClient = ApiClient(client: http.Client(), baseUrl: serverUrl);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  /// 서버 상태 확인 API 호출
  Future<void> _testServerStatus() async {
    setState(() {
      _isLoading = true;
      _resultText = '서버 상태 확인 중...';
      _showMap = false;
    });

    try {
      final result = await _apiClient.get('/health');
      setState(() {
        _resultText = '서버 응답: $result';
      });
    } catch (e) {
      final errorMessage = '오류 발생: $e';
      _logger.e(errorMessage, error: e);
      setState(() {
        _resultText = errorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 주변 장소 검색 API 호출 및 지도에 표시
  Future<void> _testNearbySearch() async {
    setState(() {
      _isLoading = true;
      _resultText = '주변 장소 검색 중...';
      _markers = {};
      _showMap = true;
    });

    try {
      // 테스트용 위치 데이터 (서울 중심부 좌표)
      final testData = {
        'latitude': 37.5665,
        'longitude': 126.9780,
        'radius': 500.0, // 반경을 1km에서 500m로 축소
        'type': 'restaurant', // 음식점 검색
      };

      final result = await _apiClient.post(
        ApiConstants.nearbySearchEndpoint,
        body: testData,
      );

      // 결과 처리
      if (result.containsKey('places') && result['places'] is List) {
        final places = result['places'] as List;
        final resultText = StringBuffer(
          '주변 장소 검색 결과: ${places.length}개 발견\n\n',
        );

        // 마커 생성
        final markers = <Marker>{};
        for (var i = 0; i < places.length; i++) {
          try {
            final place = PlaceSummary.fromJson(places[i]);
            resultText.write('${i + 1}. ${place.name} (${place.vicinity})\n');

            markers.add(
              Marker(
                markerId: MarkerId(place.placeId),
                position: place.location,
                infoWindow: InfoWindow(
                  title: place.name,
                  snippet: place.vicinity,
                ),
              ),
            );
          } catch (e) {
            resultText.write('${i + 1}. 데이터 파싱 오류: $e\n');
            _logger.e('장소 데이터 파싱 오류', error: e);
          }
        }

        setState(() {
          _markers = markers;
          _resultText = resultText.toString();
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_defaultLocation, 14),
            );
          }
        });
      } else {
        setState(() {
          _resultText = '주변 장소 검색 결과 없음: $result';
        });
      }
    } catch (e) {
      final errorMessage = '오류 발생: $e';
      _logger.e(errorMessage, error: e);
      setState(() {
        _resultText = errorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 장소 검색 API 호출 및 지도에 표시
  Future<void> _testPlaceSearch() async {
    setState(() {
      _isLoading = true;
      _resultText = '장소 검색 중...';
      _markers = {};
      _showMap = true;
    });

    try {
      // 테스트용 검색 데이터
      final testData = {'query': '서울역', 'language': 'ko'};

      final result = await _apiClient.post(
        ApiConstants.textSearchEndpoint,
        body: testData,
      );

      // 결과 처리
      if (result.containsKey('places') && result['places'] is List) {
        final places = result['places'] as List;
        final resultText = StringBuffer('장소 검색 결과: ${places.length}개 발견\n\n');

        // 마커 생성
        final markers = <Marker>{};
        LatLng? firstLocation;

        for (var i = 0; i < places.length; i++) {
          try {
            final place = PlaceSummary.fromJson(places[i]);
            resultText.write('${i + 1}. ${place.name} (${place.vicinity})\n');

            markers.add(
              Marker(
                markerId: MarkerId(place.placeId),
                position: place.location,
                infoWindow: InfoWindow(
                  title: place.name,
                  snippet: place.vicinity,
                ),
              ),
            );

            // 첫 번째 위치 저장 (카메라 이동용)
            if (i == 0) {
              firstLocation = place.location;
            }
          } catch (e) {
            resultText.write('${i + 1}. 데이터 파싱 오류: $e\n');
            _logger.e('장소 데이터 파싱 오류', error: e);
          }
        }

        setState(() {
          _markers = markers;
          _resultText = resultText.toString();

          // 첫 번째 결과로 카메라 이동
          if (_mapController != null && firstLocation != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(firstLocation, 15),
            );
          }
        });
      } else {
        setState(() {
          _resultText = '장소 검색 결과 없음: $result';
        });
      }
    } catch (e) {
      final errorMessage = '오류 발생: $e';
      _logger.e(errorMessage, error: e);
      setState(() {
        _resultText = errorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 장소 상세 정보 API 호출
  Future<void> _testPlaceDetails() async {
    setState(() {
      _isLoading = true;
      _resultText = '장소 상세 정보 조회 중...';
      _markers = {};
      _showMap = true;
    });

    try {
      // 1. 텍스트 검색으로 "서울역"의 최신 Place ID 가져오기
      _resultText = '서울역 Place ID 검색 중...';
      setState(() {}); // 로딩 상태 반영

      final searchResult = await _apiClient.post(
        ApiConstants.textSearchEndpoint,
        body: {'query': '서울역', 'language': 'ko'},
      );

      // 검색 결과에서 Place ID 추출 시도 (첫 번째 유효한 ID 사용)
      String? placeId;
      PlaceSummary? place;

      if (searchResult.containsKey('places') &&
          searchResult['places'] is List &&
          (searchResult['places'] as List).isNotEmpty) {
        final placesList = searchResult['places'] as List;
        for (var placeData in placesList) {
          try {
            place = PlaceSummary.fromJson(placeData);
            if (place.placeId.isNotEmpty) {
              placeId = place.placeId;
              _logger.i('Place ID 찾음: $placeId (${place.name})');
              break; // 첫 번째 유효한 ID를 찾으면 반복 중단
            }
          } catch (e) {
            _logger.e('장소 데이터 파싱 오류', error: e);
            // 파싱 오류 시 다음 항목으로 계속 진행
          }
        }
      }

      if (placeId == null || placeId.isEmpty) {
        throw Exception('서울역 Place ID를 찾을 수 없습니다.');
      }

      _resultText = '서울역 Place ID 찾음 ($placeId), 상세 정보 조회 중...';
      setState(() {}); // 상태 업데이트

      // 2. 찾은 Place ID로 상세 정보 요청 (GET)
      final String endpoint = '${ApiConstants.placeDetailsEndpoint}/$placeId';
      final detailsResult = await _apiClient.get(endpoint);

      // 지도에 마커 추가
      if (place != null) {
        setState(() {
          _markers = {
            Marker(
              markerId: MarkerId(placeId!),
              position: place!.location,
              infoWindow: InfoWindow(
                title: place.name,
                snippet: place.vicinity,
              ),
            ),
          };

          // 위치로 카메라 이동
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(place.location, 16),
            );
          }
        });
      }

      setState(() {
        _resultText = '장소 상세 정보 (서울역): $detailsResult';
      });
    } catch (e) {
      final errorMessage = '오류 발생: $e';
      _logger.e(errorMessage, error: e);
      setState(() {
        _resultText = errorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 연결 테스트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: '메인 앱으로 돌아가기',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testServerStatus,
              child: const Text('서버 상태 확인'),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text(
              'Google Maps API 프록시 테스트:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testNearbySearch,
              child: const Text('주변 장소 검색'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testPlaceSearch,
              child: const Text('장소 검색'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testPlaceDetails,
              child: const Text('장소 상세 정보'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // 지도 표시 영역 (조건부 렌더링)
            if (_showMap)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _defaultLocation,
                        zoom: 14,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;
                        });
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // 결과 텍스트 영역
            Expanded(
              flex: _showMap ? 1 : 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(child: Text(_resultText)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
