import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:provider/provider.dart'; // Provider 사용을 위해 추가
import '../../../../core/services/google_maps_service.dart';
// 웹 스크롤 인터셉터를 위해 추가
import 'package:pointer_interceptor/pointer_interceptor.dart';
// ViewModel 임포트
import '../providers/map_view_model.dart';

/// 지도를 표시하는 화면 (ViewModel 사용)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // 검색창 포커스 관리

  // API 클라이언트, 상태 변수, 로직 메서드 등은 ViewModel로 이동

  @override
  void initState() {
    super.initState();
    // 위젯 빌드 후 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapViewModel>().fetchInitialPlaces();
    });

    // 검색창 포커스 리스너 추가
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // 포커스 잃었을 때 특별한 동작이 필요하다면 여기에 추가
      }
      setState(() {}); // 검색창 포커스 상태에 따라 UI 변경이 필요할 수 있음 (예: 아이콘 변경)
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    // ViewModel의 dispose는 Provider가 관리하므로 여기서 호출 X
    super.dispose();
  }

  // 지도 생성 시 컨트롤러 저장
  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  // 검색어 변경 시 ViewModel의 디바운스 메서드 호출
  void _performSearch(String query) {
    // 검색 시 현재 지도 중심을 함께 전달
    context.read<MapViewModel>().performSearchDebounced(
      query,
      context.read<MapViewModel>().currentMapCenter,
    );
  }

  // 지도 카메라 이동 멈춤 시 ViewModel의 메서드 호출
  void _onCameraIdle() {
    final viewModel = context.read<MapViewModel>();
    final currentQuery = _searchController.text.trim();
    viewModel.onCameraIdle(currentQuery, viewModel.currentMapCenter);
  }

  // 지도 카메라 이동 중 ViewModel의 메서드 호출
  void _onCameraMove(CameraPosition position) {
    context.read<MapViewModel>().onCameraMove(position.target);
  }

  // 기본 위치로 이동 (지도 컨트롤러 직접 사용)
  void _moveToDefaultLocation() {
    final defaultLocation =
        context.read<MapViewModel>().currentMapCenter; // ViewModel의 기본 위치 사용
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(defaultLocation, 15),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 감지
    final viewModel = context.watch<MapViewModel>();
    // GoogleMapsService 가져오기 (createMap 위젯 사용)
    final mapsService = context.read<GoogleMapsService>();

    return Scaffold(
      body: Stack(
        children: [
          // 지도 영역 (GoogleMapsService 사용)
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: mapsService.createMap(
              initialPosition: viewModel.currentMapCenter,
              initialZoom: 15.0,
              onMapCreated: _onMapCreated,
              markers: viewModel.markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              onTap: (_) => FocusScope.of(context).unfocus(),
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            ),
          ),

          // 검색 바
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(64),
                    spreadRadius: 0,
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  hintText: '지역, 매장을 검색해보세요',
                  hintStyle: const TextStyle(color: Color(0xFF939393)),
                  border: InputBorder.none,
                  // 검색창 포커스 시 X 버튼 표시 (선택적)
                  suffixIcon:
                      _focusNode.hasFocus && _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              // 검색어 비우면 검색 결과도 초기화 (ViewModel 호출)
                              viewModel.searchPlaces(
                                '',
                                viewModel.currentMapCenter,
                              );
                            },
                          )
                          : null,
                ),
                onChanged: _performSearch,
                onSubmitted: (query) => _performSearch(query), // 엔터 시 즉시 검색
              ),
            ),
          ),

          // 현재 위치 버튼
          Positioned(
            right: 20,
            // 하단 시트 높이를 고려하여 동적으로 위치 조정 필요 (임시값)
            bottom: MediaQuery.of(context).size.height * 0.45 + 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(64),
                    spreadRadius: 0,
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _moveToDefaultLocation,
                icon: const Icon(Icons.my_location),
                color: const Color(0xFF2A2A2A),
              ),
            ),
          ),

          // 임시 테스트 페이지 이동 버튼 (디버그 모드에서만 표시)
          if (kDebugMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 20,
              child: FloatingActionButton(
                mini: true,
                tooltip: 'API 테스트 페이지로 이동',
                onPressed: () {
                  Navigator.pushNamed(context, '/test');
                },
                child: const Icon(Icons.biotech),
              ),
            ),

          // 로딩 인디케이터 (ViewModel 상태 사용)
          if (viewModel.isLoading)
            Container(
              color: Colors.black.withAlpha(88),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // 오류 메시지 (ViewModel 상태 사용)
          if (viewModel.errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          // 하단 장소 목록
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child:
                kIsWeb
                    ? PointerInterceptor(
                      child: _buildPlaceListContainer(viewModel),
                    )
                    : _buildPlaceListContainer(viewModel),
          ),
        ],
      ),
    );
  }

  // 장소 목록 컨테이너 빌드 (ViewModel 전달 받음)
  Widget _buildPlaceListContainer(MapViewModel viewModel) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSheetHeight = screenHeight * 0.45;

    return Container(
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
            child: Text(
              '주변 장소', // 제목은 상황에 맞게 동적으로 변경 가능
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // 장소가 없는 경우 메시지 표시 (ViewModel 상태 사용)
          if (viewModel.placesToShow.isEmpty && !viewModel.isLoading)
            const Expanded(
              child: Center(
                child: Text(
                  '표시할 장소가 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),

          // 장소 목록 (ViewModel 상태 사용)
          if (viewModel.placesToShow.isNotEmpty)
            Expanded(
              child: ListView.builder(
                // ViewModel의 ScrollController 사용
                controller: viewModel.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: viewModel.placesToShow.length,
                itemBuilder: (context, index) {
                  final place = viewModel.placesToShow[index];
                  // 선택 상태도 ViewModel에서 가져옴
                  final isSelected = place.id == viewModel.selectedPlaceId;

                  return GestureDetector(
                    onTap: () {
                      // 상세 페이지 이동 시 Place 객체 대신 Map으로 변환하여 전달
                      Navigator.pushNamed(
                        context,
                        '/place_detail',
                        arguments: {
                          'id': place.id,
                          'name': place.name,
                          'address': place.address,
                          'location': {
                            'latitude': place.location.latitude,
                            'longitude': place.location.longitude,
                          },
                          'acceptsCreditCard': place.acceptsCreditCard,
                        },
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            isSelected
                                ? Border.all(
                                  color: const Color(0xFFDE3B3B),
                                  width: 2,
                                )
                                : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            place.address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 로딩 인디케이터 (목록 영역 안에 표시, ViewModel 상태 사용)
          if (viewModel.isLoading && viewModel.placesToShow.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          // 오류 메시지 (목록 영역 안에 표시, ViewModel 상태 사용)
          if (viewModel.errorMessage != null &&
              !viewModel.isLoading &&
              viewModel.placesToShow.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
