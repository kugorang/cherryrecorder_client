import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/map_view_model.dart';
import '../../../place_details/presentation/screens/place_detail_screen.dart';
import '../../../../core/models/place_summary.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapViewModel>().getCurrentLocation().then((_) {
        _moveCameraToCurrentLocation();
      });
    });

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        if (context.read<MapViewModel>().searchResults.isEmpty) {
          // setState(() {}); // UI 갱신 트리거 (필요 시)
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _moveCameraToCurrentLocation() {
    final viewModel = context.read<MapViewModel>();
    if (viewModel.currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            viewModel.currentPosition!.latitude,
            viewModel.currentPosition!.longitude,
          ),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final viewModel = context.read<MapViewModel>();
    if (viewModel.searchResults.isNotEmpty) {
      setState(() {
        _searchController.clear();
        viewModel.clearSearchResults();
        _searchFocusNode.unfocus();
      });
      return false; // 앱 종료 방지
    }
    return true; // 앱 종료 허용
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MapViewModel>();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            _buildMapContent(viewModel),

            if (viewModel.searchResults.isNotEmpty)
              _buildSearchResultsContent(viewModel),

            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 15,
              right: 15,
              child: _buildSearchBar(viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContent(MapViewModel viewModel) {
    if (viewModel.isLoading && viewModel.currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null && viewModel.currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(viewModel.error!),
            ElevatedButton(
              onPressed: () => viewModel.getCurrentLocation(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              viewModel.currentPosition?.latitude ?? 37.5665,
              viewModel.currentPosition?.longitude ?? 126.9780,
            ),
            zoom: 15,
          ),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          markers: viewModel.markers,
          padding: const EdgeInsets.only(bottom: 200, top: 70),
          onTap: (_) {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            }
          },
        ),
        _buildPlaceListSheet(viewModel, true),
        Positioned(
          bottom: 220,
          right: 15,
          child: FloatingActionButton(
            mini: true,
            onPressed: _moveCameraToCurrentLocation,
            backgroundColor: Colors.white,
            child: SvgPicture.asset(
              'assets/images/gps_icon.svg',
              width: 24,
              height: 24,
              placeholderBuilder:
                  (context) => const Icon(Icons.gps_fixed, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsContent(MapViewModel viewModel) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70),
      child: ListView.builder(
        itemCount: viewModel.searchResults.length,
        itemBuilder: (context, index) {
          final place = viewModel.searchResults[index];
          return ListTile(
            title: Text(
              place.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              place.vicinity ?? '주소 정보 없음',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PlaceDetailScreen(
                        placeId: place.placeId,
                        placeName: place.name,
                      ),
                ),
              ).then((_) {
                setState(() {
                  viewModel.clearSearchResults();
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                });
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(MapViewModel viewModel) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: '지역, 매장을 검색해보세요',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15.0,
              horizontal: 20.0,
            ),
            suffixIcon:
                _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          viewModel.clearSearchResults();
                        });
                      },
                    )
                    : null,
          ),
          onTap: () {},
          onSubmitted: (query) {
            if (query.isNotEmpty) {
              viewModel.searchPlaces(query);
            } else {
              viewModel.clearSearchResults();
            }
          },
          onChanged: (query) {
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildPlaceListSheet(MapViewModel viewModel, bool isNearby) {
    if (!isNearby && viewModel.searchResults.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        final places =
            isNearby ? viewModel.nearbyPlaces : viewModel.searchResults;
        final title = isNearby ? '주변 장소' : '검색 결과';

        if (isNearby && viewModel.searchResults.isNotEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child:
                    places.isEmpty
                        ? Center(child: Text('$title이 없습니다.'))
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: places.length,
                          itemBuilder: (context, index) {
                            final place = places[index];
                            return ListTile(
                              title: Text(
                                place.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(place.vicinity ?? '주소 정보 없음'),
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  viewModel.clearSearchResults();
                                  _searchFocusNode.unfocus();
                                });
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => PlaceDetailScreen(
                                          placeId: place.placeId,
                                          placeName: place.name,
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
