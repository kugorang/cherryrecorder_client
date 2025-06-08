import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/models/place_summary.dart';
import '../providers/map_view_model.dart';
import '../widgets/place_list_card.dart';

/// 지도 화면 (ViewModel 기반)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  String? _lastScrolledPlaceId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // 초기화는 build 메서드에서 처리
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapViewModel = context.watch<MapViewModel>();
    final places = mapViewModel.placesToShow;

    // 초기화 로직 - 최초 1회만 실행
    if (_isInitializing && !mapViewModel.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        setState(() {
          _isInitializing = false;
        });
        // 위치 권한 요청 및 초기화
        await mapViewModel.initializeAndFetchCurrentLocation();
      });
    }

    // 선택된 장소가 변경되면 목록 스크롤
    if (mapViewModel.selectedPlaceId != null &&
        mapViewModel.selectedPlaceId != _lastScrolledPlaceId) {
      _lastScrolledPlaceId = mapViewModel.selectedPlaceId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index =
            places.indexWhere((p) => p.placeId == mapViewModel.selectedPlaceId);
        if (index != -1 && _listScrollController.hasClients) {
          // 아이템의 예상 높이
          // 선택되지 않은 아이템: padding(24) + avatar(40) + gap(4) + 여백 = 약 72
          // 선택된 아이템: 72 + gap(8) + button(40) = 약 120
          const unselectedItemHeight = 72.0;
          const selectedItemHeight = 120.0;

          // 리스트뷰의 가시 영역 높이
          final viewportHeight =
              _listScrollController.position.viewportDimension;

          // 선택된 아이템까지의 누적 높이 계산
          double cumulativeHeight = 0;
          for (int i = 0; i < index; i++) {
            cumulativeHeight += unselectedItemHeight;
          }

          // 선택된 아이템을 뷰포트 중앙에 위치시키기
          // 선택된 아이템의 중심 = cumulativeHeight + (selectedItemHeight / 2)
          // 뷰포트 중심에서 아이템 중심까지의 거리를 빼면 스크롤 위치
          final itemCenter = cumulativeHeight + (selectedItemHeight / 2);
          final viewportCenter = viewportHeight / 2;
          final targetOffset = itemCenter - viewportCenter;

          // 최대/최소 스크롤 범위 내로 제한
          final maxScrollExtent =
              _listScrollController.position.maxScrollExtent;
          final scrollToOffset = targetOffset.clamp(0.0, maxScrollExtent);

          _listScrollController.animateTo(
            scrollToOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    } else if (mapViewModel.selectedPlaceId == null) {
      // 선택이 해제되면 추적 ID도 초기화
      _lastScrolledPlaceId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(mapViewModel),
        // 다른 AppBar 속성들...
      ),
      // Stack을 사용하여 body 위에 로딩 인디케이터를 오버레이
      body: Stack(
        children: [
          Column(
            children: [
              // 상단: 지도 영역
              Expanded(
                flex: 3, // 지도가 더 많은 공간을 차지하도록 설정
                child: _buildGoogleMap(mapViewModel),
              ),
              // 하단: 장소 목록 영역
              Expanded(
                flex: 2,
                child: _buildPlaceList(context, mapViewModel, places),
              ),
            ],
          ),
          // 로딩 인디케이터
          if (mapViewModel.isLoading)
            Container(
              color: Colors.black.withAlpha(128), // withOpacity 대체
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // 초기화 중 메시지
          if (_isInitializing)
            Container(
              color: Colors.white.withAlpha(240),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      '위치 권한을 확인하고 있습니다...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '권한을 허용하면 주변 장소를 찾아드립니다',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 상단 검색 바 위젯 생성
  Widget _buildSearchBar(MapViewModel viewModel) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '장소 또는 주소 검색',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  viewModel.performSearchDebounced('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      onChanged: (query) {
        setState(() {}); // suffixIcon을 다시 그리도록 상태 업데이트
        viewModel.performSearchDebounced(query);
      },
    );
  }

  /// 구글맵 위젯 생성
  Widget _buildGoogleMap(MapViewModel mapViewModel) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: mapViewModel.currentMapCenter,
            zoom: 15,
          ),
          onMapCreated: (controller) {
            mapViewModel.setMapController(controller);
          },
          markers: mapViewModel.markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // 커스텀 버튼 사용을 위해 비활성화
          zoomControlsEnabled: false, // 줌 컨트롤 비활성화
          compassEnabled: true, // 나침반 활성화
          // 지도 UI 요소들의 위치 조정을 위한 패딩 설정
          padding: const EdgeInsets.only(
            top: 80, // GPS 버튼 공간 확보
            right: 80, // 우측 버튼들과 나침반 공간 확보
            bottom: 80, // 하단 버튼 공간 확보
            left: 80, // 왼쪽 버튼 공간 확보
          ),
          onCameraMove: (position) {
            // ViewModel에 지도 중심 위치 계속 업데이트 (Debounce는 ViewModel에서 처리)
            // mapViewModel.onCameraIdle(position.target);
          },
          onCameraIdle: () async {
            // 이동이 멈추면 최종 위치로 검색
            if (mapViewModel.mapControllerReady) {
              final LatLng center = await (mapViewModel.mapController!
                  .getVisibleRegion()
                  .then((region) => LatLng(
                        (region.northeast.latitude +
                                region.southwest.latitude) /
                            2,
                        (region.northeast.longitude +
                                region.southwest.longitude) /
                            2,
                      )));
              mapViewModel.onCameraIdle(center);
            }
          },
        ),
        // GPS 버튼 (우측 상단)
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            heroTag: 'gps_button',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: () async {
              // 현재 위치로 이동
              await mapViewModel.initializeAndFetchCurrentLocation();
            },
            child: const Icon(Icons.my_location, color: Colors.black87),
          ),
        ),
        // 채팅 버튼 (좌측 하단 - 나침반과 겹치지 않음)
        Positioned(
          bottom: 24,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'chat_button',
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 4,
            onPressed: () {
              // 채팅 화면으로 이동
              Navigator.pushNamed(context, '/chat');
            },
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// 하단 장소 목록 리스트 위젯 생성
  Widget _buildPlaceList(
      BuildContext context, MapViewModel viewModel, List<PlaceSummary> places) {
    if (viewModel.errorMessage != null && places.isEmpty) {
      return Center(child: Text(viewModel.errorMessage!));
    }

    if (places.isEmpty) {
      return const Center(child: Text('주변 장소를 찾을 수 없습니다.'));
    }

    return ListView.builder(
      controller: _listScrollController, // 스크롤 컨트롤러 할당
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return PlaceListCard(
          place: place,
          isSelected: viewModel.selectedPlaceId == place.placeId,
          onTap: () {
            viewModel.onPlaceSelected(place.placeId);
          },
          onMemoTap: () {
            Navigator.pushNamed(
              context,
              '/place_detail',
              arguments: place.toJson(),
            );
          },
        );
      },
    );
  }
}
