import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import 'package:cherryrecorder_client/core/models/place.dart'; // 패키지 상대 경로 사용
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng 타입 사용을 위해 추가
import '../providers/place_detail_view_model.dart';
import 'memo_add_screen.dart'; // 메모 추가 화면
import 'package:cherryrecorder_client/core/services/google_maps_service.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/screens/memos_by_tag_screen.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_card.dart'; // MemoCard 임포트

/// 장소 상세 정보를 표시하는 화면 위젯
class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> placeData;

  const PlaceDetailScreen({super.key, required this.placeData});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final Place place;

  @override
  void initState() {
    super.initState();
    _initializePlace();

    // 위젯 빌드 후 첫 프레임이 렌더링된 다음 loadMemos 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider를 통해 ViewModel 접근 및 메모 로드
      context.read<PlaceDetailViewModel>().loadMemos(place.id);
    });
  }

  void _initializePlace() {
    final placeData = widget.placeData;

    // Map에서 LatLng 객체 생성 (안전하게)
    final locationMap =
        placeData['location'] is Map ? placeData['location'] as Map : {};
    final lat = locationMap['lat'] ?? locationMap['latitude'];
    final lng = locationMap['lng'] ?? locationMap['longitude'];

    // 위도, 경도 값이 유효한지 확인
    if (lat == null || lng == null) {
      throw ArgumentError(
        '장소 데이터에 유효한 위도/경도 정보가 없습니다. 받은 데이터: $placeData',
      );
    }

    final latLng = LatLng(lat as double, lng as double);

    // 사진 참조 목록 파싱 (place_summary.dart 와 place.dart 형식 모두 호환)
    List<String> photos = [];
    if (placeData.containsKey('photos') && placeData['photos'] is List) {
      final photosData = placeData['photos'] as List;
      photos = photosData
          .map((photo) =>
              (photo is Map<String, dynamic> && photo.containsKey('name'))
                  ? photo['name'] as String
                  : null)
          .where((ref) => ref != null)
          .cast<String>()
          .toList();
    }

    // Place 객체 생성 (안전하게)
    place = Place(
      id: placeData['placeId']?.toString() ?? placeData['id']?.toString() ?? '',
      name: placeData['name']?.toString() ?? '이름 없음',
      address: placeData['vicinity']?.toString() ??
          placeData['address']?.toString() ??
          '주소 정보 없음',
      location: latLng,
      acceptsCreditCard: placeData['acceptsCreditCard'] as bool? ?? true,
      photoReferences: photos,
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    String? imageUrl;
    if (place.photoReferences.isNotEmpty) {
      // 사진 참조와 API 키를 사용하여 이미지 URL 생성
      final photoReference = place.photoReferences.first;
      // GoogleMapsService 인스턴스를 직접 생성하여 사용
      final apiKey = GoogleMapsService().getApiKey();

      // API 키가 있는 경우에만 URL 생성
      if (apiKey.isNotEmpty) {
        // photoReference가 이미 'places/...' 형식인지 확인
        String resourceName = photoReference;
        if (!photoReference.startsWith('places/')) {
          // 'places/' 접두사가 없으면 추가
          resourceName = 'places/$photoReference';
        }

        // Google Places Photo API URL 형식
        // v1 API는 {resourceName}/media 형식을 사용
        imageUrl =
            'https://places.googleapis.com/v1/$resourceName/media?maxHeightPx=1000&maxWidthPx=1000&key=$apiKey';
      }
    }

    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                // 로딩 중 및 에러 발생 시 처리
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultImageBackground();
                },
              )
            : _buildDefaultImageBackground(),
      ),
    );
  }

  // 기본 배경 위젯 (사진 없을 때 또는 로드 실패 시)
  Widget _buildDefaultImageBackground() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image,
          size: 80,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 변화 감지
    final viewModel = context.watch<PlaceDetailViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: CustomScrollView(
        slivers: [
          // 상단 이미지와 앱바 (위에서 만든 함수 사용)
          _buildSliverAppBar(context),

          // 장소 정보 섹션
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
          ),

          // 혜택 메모 헤더
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDE3B3B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '혜택 메모',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 메모 목록
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: _buildMemoList(viewModel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddMemo(context),
        backgroundColor: const Color(0xFFDE3B3B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMemoList(PlaceDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (viewModel.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '오류: ${viewModel.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (viewModel.memos.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            '저장된 메모가 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final memo = viewModel.memos[index];
          // 새로 만든 MemoCard 위젯 사용
          return MemoCard(
            memo: memo,
            onTap: () => _navigateToEditMemo(context, memo),
            // 태그를 탭했을 때의 동작을 여기에 추가
            onTagTap: (tag) => _showMemosWithTag(tag),
          );
        },
        childCount: viewModel.memos.length,
      ),
    );
  }

  // 메모 추가 화면으로 이동
  void _navigateToAddMemo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoAddScreen(
          place: place,
        ),
      ),
    ).then((_) {
      // 메모 추가 후 돌아왔을 때 목록 새로고침
      context.read<PlaceDetailViewModel>().loadMemos(place.id);
    });
  }

  // 메모 수정 화면으로 이동
  void _navigateToEditMemo(BuildContext context, Memo memo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoAddScreen(
          place: place,
          memoToEdit: memo,
        ),
      ),
    ).then((_) {
      // 메모 수정 후 돌아왔을 때 목록 새로고침
      context.read<PlaceDetailViewModel>().loadMemos(place.id);
    });
  }

  // 특정 태그를 포함하는 메모 필터링 (전역 검색)
  void _showMemosWithTag(String tag) async {
    final viewModel = context.read<PlaceDetailViewModel>();

    // ViewModel을 통해 모든 장소에서 해당 태그를 가진 메모를 검색
    final List<Memo> memos = await viewModel.getAllMemosWithTag(tag);

    // 검색된 결과를 새 화면으로 전달
    if (mounted) {
      Navigator.pushNamed(
        context,
        '/memos_by_tag',
        arguments: {
          'tag': tag,
          'memos': memos, // 'allMemos' 대신 'memos' 키 사용
        },
      );
    }
  }
}
