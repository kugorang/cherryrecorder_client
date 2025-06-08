/// 지도와 주변 장소 목록을 표시하는 메인 화면입니다.
///
/// `ChangeNotifierProvider`를 통해 `MapViewModel`의 상태 변화를 구독하고,
/// UI를 동적으로 업데이트합니다. 사용자의 상호작용(지도 이동, 검색, 목록 선택 등)을
/// `MapViewModel`에 전달하여 비즈니스 로직을 처리하도록 합니다.
///
/// **주요 기능:**
/// - Google 지도 표시 및 현재 위치 기능
/// - 지도 위에 주변 장소들을 마커로 표시
/// - 하단에 주변 장소들을 리스트로 표시
/// - 지도와 리스트 간의 상호작용 (마커 선택 시 리스트 스크롤, 리스트 선택 시 지도 이동)
/// - 장소 검색 기능
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/models/place_summary.dart';
import '../providers/map_view_model.dart';
import '../widgets/place_list_card.dart';

/// 지도와 장소 목록을 표시하는 메인 화면 위젯입니다.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();

  /// 리스트 자동 스크롤의 중복 실행을 방지하기 위해 마지막으로 스크롤된 장소 ID를 저장합니다.
  String? _lastScrolledPlaceId;

  /// 화면이 처음 빌드될 때 초기화 로직을 한 번만 실행하기 위한 플래그입니다.
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // initState에서는 context를 사용할 수 없으므로, 초기화 로직은 build 메서드 내에서
    // `WidgetsBinding.instance.addPostFrameCallback`을 사용하여 처리합니다.
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider.watch를 사용하여 MapViewModel의 변경사항을 구독합니다.
    final mapViewModel = context.watch<MapViewModel>();
    final places = mapViewModel.placesToShow;

    // --- 위젯 빌드 후 실행되는 콜백 ---
    // 이 콜백들은 UI가 그려진 후에 안전하게 실행됩니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 앱 시작 후 첫 프레임에서만 초기화 로직을 실행합니다.
      if (_isInitializing && mounted) {
        setState(() {
          _isInitializing = false;
        });
        // 초기화는 이제 지도 컨트롤러가 설정될 때 자동으로 실행됨
      }

      // ViewModel에서 선택된 장소가 변경되었을 때, 해당 장소가 보이도록 리스트를 스크롤합니다.
      _maybeScrollToSelectedPlace(mapViewModel, places);
    });

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(mapViewModel),
        // AppBar의 그림자를 없애고 지도와 경계가 없어 보이게 합니다.
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠 (지도 + 리스트)
          Column(
            children: [
              Expanded(
                flex: 3, // 지도 영역이 3의 비율을 가집니다.
                child: _buildGoogleMap(mapViewModel),
              ),
              Expanded(
                flex: 2, // 리스트 영역이 2의 비율을 가집니다.
                child: _buildPlaceList(context, mapViewModel, places),
              ),
            ],
          ),
          // 로딩 오버레이: ViewModel의 isLoading 상태에 따라 표시됩니다.
          if (mapViewModel.isLoading && !_isInitializing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          // 초기화 로딩 오버레이: 권한 요청 등 초기 작업 중에 표시됩니다.
          if (_isInitializing)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      '지도를 준비하고 있습니다...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // 커스텀 버튼들을 지도 위에 띄우기 위해 FloatingActionButton 관련 속성은 여기서 사용하지 않습니다.
      // 대신 _buildGoogleMap 내부의 Stack 위젯을 사용합니다.
    );
  }

  /// 상단의 장소 검색 바 위젯을 빌드합니다.
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

  /// Google Map 위젯과 그 위에 표시될 커스텀 버튼들을 빌드합니다.
  Widget _buildGoogleMap(MapViewModel mapViewModel) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: mapViewModel.currentMapCenter,
            zoom: 15,
          ),
          onMapCreated: mapViewModel.setMapController,
          markers: mapViewModel.markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // 커스텀 버튼을 사용하므로 비활성화
          zoomControlsEnabled: false, // 웹과 모바일 모두 기본 줌 컨트롤 비활성화
          compassEnabled: true, // 나침반 활성화
          // 지도 UI 요소들의 위치 조정을 위한 패딩 설정
          // 모바일: 줌 버튼이 채팅 버튼(bottom: 24 + 56)와 GPS 버튼(top: 16 + 40) 사이에 위치
          padding: EdgeInsets.only(
            top: kIsWeb ? 80 : 70, // GPS 버튼 아래 공간 확보
            right: 16, // 웹에서도 커스텀 컨트롤이 없으므로 모바일과 동일하게 조정
            bottom: kIsWeb ? 80 : 90, // 채팅 버튼 위 공간 확보 (24 + 56 + 10)
            left: 80, // 왼쪽 공간
          ),
          onCameraMove: (position) {
            // ViewModel에 지도 중심 위치 계속 업데이트 (Debounce는 ViewModel에서 처리)
            // mapViewModel.onCameraIdle(position.target);
          },
          onCameraIdle: () async {
            // 카메라 이동이 멈추면, 현재 보이는 영역의 중심 좌표를 계산하여
            // ViewModel에 알리고 주변 장소를 다시 검색하도록 합니다.
            if (mapViewModel.mapControllerReady) {
              final bounds =
                  await mapViewModel.mapController!.getVisibleRegion();
              final center = LatLng(
                (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
              );
              mapViewModel.onCameraIdle(center);
            }
          },
        ),
        // 현재 위치로 이동하는 커스텀 GPS 버튼
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            heroTag: 'gps_button',
            onPressed: mapViewModel.initializeAndFetchCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
        // 채팅 화면으로 이동하는 커스텀 버튼
        Positioned(
          bottom: 24,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'chat_button',
            onPressed: () => Navigator.pushNamed(context, '/chat'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ),
      ],
    );
  }

  /// 하단의 장소 목록 리스트 위젯을 빌드합니다.
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

  /// 선택된 장소가 화면에 보이도록 리스트를 스크롤하는 로직입니다.
  void _maybeScrollToSelectedPlace(
      MapViewModel mapViewModel, List<PlaceSummary> places) {
    final selectedId = mapViewModel.selectedPlaceId;
    if (selectedId == null || selectedId == _lastScrolledPlaceId) return;

    _lastScrolledPlaceId = selectedId;
    final index = places.indexWhere((p) => p.placeId == selectedId);

    if (index != -1 && _listScrollController.hasClients) {
      // 선택된 아이템의 크기와 위치를 고려하여 스크롤할 offset을 계산합니다.
      // 아이템이 뷰포트 하단에서 1/3 높이 위치에 오도록 계산합니다.
      // 실제 측정된 높이 값 사용 (padding, 텍스트, 버튼 포함)
      const unselectedItemHeight = 80.0; // padding 24 + content ~56
      const selectedItemHeight = 136.0; // unselected + 메모 버튼 영역
      final viewportHeight = _listScrollController.position.viewportDimension;

      double cumulativeHeight = 0;
      for (int i = 0; i < index; i++) {
        cumulativeHeight +=
            (places[i].placeId == mapViewModel.selectedPlaceIdBeforeChange
                ? selectedItemHeight
                : unselectedItemHeight);
      }

      // 선택된 아이템이 뷰포트 하단에서 1/4 높이 위치에 오도록 계산
      // targetPosition = 하단에서 1/4 지점 = viewportHeight * (3/4)
      final targetPositionInViewport = viewportHeight * (3.0 / 4.0);

      // 선택된 아이템의 상단이 targetPosition에 오도록 offset 계산
      final targetOffset = cumulativeHeight - targetPositionInViewport;

      // 스크롤 애니메이션 실행
      _listScrollController.animateTo(
        targetOffset.clamp(0.0, _listScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else if (selectedId == null) {
      _lastScrolledPlaceId = null;
    }
  }
}
