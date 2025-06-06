import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/models/place_summary.dart';
import '../providers/map_view_model.dart';
import '../widgets/place_list_card.dart';
import 'package:location/location.dart';

/// 지도 화면 (ViewModel 기반)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _logger = Logger();
  final _searchController = TextEditingController();
  final Location _location = Location();
  bool _isSheetInteracting = false;

  // DraggableScrollableSheet 관련
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _sheetHeight = 0.2; // 현재 시트 높이 비율
  static const double _minSheetSize = 0.1;
  static const double _maxSheetSize = 0.5; // 최대 50%로 제한
  static const double _initialSheetSize = 0.2;

  // 스크롤 관련
  ScrollController? _listScrollController;
  String? _lastSelectedPlaceId;

  @override
  void initState() {
    super.initState();

    // 시트 크기 변화 감지
    _sheetController.addListener(_onSheetSizeChanged);

    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialLocationAndFetchPlaces();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _listScrollController?.dispose();
    super.dispose();
  }

  // 시트 크기 변화 감지
  void _onSheetSizeChanged() {
    if (_sheetController.size != _sheetHeight) {
      setState(() {
        _sheetHeight = _sheetController.size;
      });
    }
  }

  /// 초기 위치 파악 후, ViewModel을 통해 주변 장소 검색 요청
  Future<void> _loadInitialLocationAndFetchPlaces() async {
    final mapViewModel = context.read<MapViewModel>();
    LatLng initialLocation = mapViewModel.currentMapCenter;

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        _logger.w('위치 서비스가 비활성화되어 있습니다. 기본 위치로 검색합니다.');
        await mapViewModel.fetchInitialPlaces();
        return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
      }
      if (permissionGranted != PermissionStatus.granted) {
        _logger.w('위치 권한이 거부되었습니다. 기본 위치로 검색합니다.');
        await mapViewModel.fetchInitialPlaces();
        return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        initialLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        // 현재 위치로 지도 중심 이동
        mapViewModel.onCameraIdle(initialLocation);
      }
    } catch (e) {
      _logger.e('위치 로드 중 오류', error: e);
    } finally {
      if (mounted) {
        await mapViewModel.fetchNearbyPlaces(initialLocation);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapViewModel = context.watch<MapViewModel>();
    final places = mapViewModel.placesToShow;

    // 선택된 장소가 변경되면 시트 확장 및 스크롤
    if (mapViewModel.selectedPlaceId != null &&
        mapViewModel.selectedPlaceId != _lastSelectedPlaceId) {
      _lastSelectedPlaceId = mapViewModel.selectedPlaceId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _expandSheetAndScroll();
      });
    }

    // 화면 높이 계산
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * _sheetHeight;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: mapViewModel.currentMapCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              mapViewModel.setMapController(controller);
            },
            markers: mapViewModel.markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            scrollGesturesEnabled: !_isSheetInteracting,
            zoomGesturesEnabled: !_isSheetInteracting,
            rotateGesturesEnabled: !_isSheetInteracting,
            tiltGesturesEnabled: !_isSheetInteracting,
            zoomControlsEnabled: false,
            onCameraIdle: () {
              if (mapViewModel.mapControllerReady) {
                // 지도 조작이 끝났을 때 주변 장소 검색
                // onCameraMove에서 이미 중심 좌표를 업데이트하므로 여기서는 검색만 트리거
              }
            },
            onCameraMove: (position) {
              // 카메라 이동 시 중심 좌표 업데이트
              mapViewModel.onCameraIdle(position.target);
            },
            // 하단 시트 높이에 따라 지도 패딩 동적 조절
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 70,
              bottom: bottomPadding,
            ),
          ),

          // 상단 검색바
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: _buildSearchBar(mapViewModel),
          ),

          // 플로팅 버튼들
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 15,
            child: _buildFloatingButtons(),
          ),

          // 하단 시트
          _buildBottomSheet(mapViewModel, places),

          // 로딩 인디케이터
          if (mapViewModel.isLoading)
            Container(
              color: Colors.black.withAlpha(80),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // 하단 시트 위젯
  Widget _buildBottomSheet(MapViewModel viewModel, List<PlaceSummary> places) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // 시트 크기 변화는 _sheetController 리스너에서 처리
        return true;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _initialSheetSize,
        minChildSize: _minSheetSize,
        maxChildSize: _maxSheetSize,
        snap: true,
        snapSizes: const [0.1, 0.2, 0.5], // 스냅 포인트 설정
        builder: (context, scrollController) {
          _listScrollController = scrollController;

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                setState(() => _isSheetInteracting = true);
              } else if (notification is ScrollEndNotification) {
                setState(() => _isSheetInteracting = false);
              }
              return false;
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child:
                  _buildPlaceList(context, scrollController, viewModel, places),
            ),
          );
        },
      ),
    );
  }

  // 시트 확장 및 스크롤
  Future<void> _expandSheetAndScroll() async {
    try {
      // 시트를 40%로 확장
      if (_sheetController.size < 0.4) {
        await _sheetController.animateTo(
          0.4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // 스크롤은 _buildPlaceList에서 처리
    } catch (e) {
      _logger.e('시트 확장 중 오류', error: e);
    }
  }

  // 검색바 위젯
  Widget _buildSearchBar(MapViewModel viewModel) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(30.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          hintText: '장소 또는 주소 검색',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    viewModel.clearSelection();
                    viewModel.fetchNearbyPlaces(viewModel.currentMapCenter);
                    setState(() {}); // 검색창 상태 업데이트
                  },
                )
              : null,
        ),
        onChanged: (query) {
          setState(() {}); // 검색창 상태 업데이트 (X 버튼 표시/숨김)
          viewModel.performSearchDebounced(query);
        },
        onSubmitted: (query) {
          if (query.isNotEmpty) {
            viewModel.searchPlaces(query, viewModel.currentMapCenter);
          }
        },
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Column(
      children: [
        _buildFloatingButton(
          icon: Icons.my_location,
          onPressed: _loadInitialLocationAndFetchPlaces,
          tooltip: '현재 위치',
        ),
        const SizedBox(height: 10),
        _buildFloatingButton(
          icon: Icons.chat_bubble_outline,
          onPressed: () => Navigator.pushNamed(context, '/chat'),
          tooltip: '채팅',
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white,
      elevation: 4.0,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.black54),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildPlaceList(
    BuildContext context,
    ScrollController scrollController,
    MapViewModel viewModel,
    List<PlaceSummary> places,
  ) {
    // 선택된 장소로 스크롤
    if (viewModel.selectedPlaceId != null && _listScrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index =
            places.indexWhere((p) => p.placeId == viewModel.selectedPlaceId);
        if (index != -1 && _listScrollController!.hasClients) {
          final offset = index * 85.0; // 평균 아이템 높이
          _listScrollController!.animateTo(
            offset.clamp(0.0, _listScrollController!.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    if (places.isEmpty && !viewModel.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            viewModel.errorMessage ?? '주변에 장소가 없거나, 검색 결과가 없습니다.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 드래그 핸들
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // 장소 목록
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: places.length,
            padding: const EdgeInsets.only(bottom: 20),
            itemBuilder: (context, index) {
              final place = places[index];
              return PlaceListCard(
                place: place,
                isSelected: viewModel.selectedPlaceId == place.placeId,
                onTap: () => viewModel.onPlaceSelected(place.placeId),
                onMemoTap: () {
                  Navigator.pushNamed(
                    context,
                    '/place_detail',
                    arguments: place.toJson(),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
