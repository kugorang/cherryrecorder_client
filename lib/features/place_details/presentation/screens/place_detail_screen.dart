/// 특정 장소에 대한 상세 정보와 관련 메모 목록을 보여주는 화면입니다.
///
/// `CustomScrollView`와 `Sliver` 위젯들을 사용하여 스크롤에 따라
/// 상단 이미지가 동적으로 변하는 UI를 구현합니다. `PlaceDetailViewModel`의 상태를
/// 구독하여 UI를 렌더링하고, 사용자의 액션(메모 추가/수정/삭제)을 ViewModel에 전달합니다.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../../../../core/models/place.dart'; // 패키지 상대 경로 사용
// LatLng 타입 사용을 위해 추가
import '../providers/place_detail_view_model.dart';
import 'memo_add_screen.dart'; // 메모 추가 화면
import 'package:cherryrecorder_client/core/services/google_maps_service.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_card.dart'; // MemoCard 임포트
import 'package:cherryrecorder_client/core/models/place_detail.dart';

/// 장소 상세 정보를 표시하는 화면 위젯입니다.
///
/// `CustomScrollView`와 `Sliver` 위젯들을 사용하여 스크롤에 따라
/// 상단 이미지가 동적으로 변하는 UI를 구현합니다. `PlaceDetailViewModel`의 상태를
/// 구독하여 UI를 렌더링하고, 사용자의 액션(메모 추가/수정/삭제)을 ViewModel에 전달합니다.
class PlaceDetailScreen extends StatefulWidget {
  /// 이전 화면(`MapScreen`)으로부터 전달받은 장소 데이터입니다.
  /// `placeId`, `name` 등의 최소한의 정보를 포함합니다.
  final Map<String, dynamic> placeData;

  const PlaceDetailScreen({super.key, required this.placeData});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final String placeId;

  @override
  void initState() {
    super.initState();
    // 전달받은 데이터에서 장소 ID를 추출합니다.
    placeId = widget.placeData['placeId']?.toString() ??
        widget.placeData['id']?.toString() ??
        '';

    // 위젯이 완전히 빌드된 후 첫 프레임에서 데이터 로딩을 시작합니다.
    // 이렇게 하면 initState에서 context를 안전하게 사용할 수 있습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (placeId.isEmpty) {
        // 유효하지 않은 placeId인 경우 사용자에게 알리고 이전 화면으로 돌아갑니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유효하지 않은 장소 정보입니다.')),
        );
        Navigator.of(context).pop();
      } else {
        // ViewModel을 통해 장소 상세 정보와 메모 목록을 로드합니다.
        context.read<PlaceDetailViewModel>().loadData(placeId);
      }
    });
  }

  Widget _buildSliverAppBar(
      BuildContext context, PlaceDetailViewModel viewModel) {
    String? imageUrl;
    final placeDetail = viewModel.placeDetail;

    if (placeDetail != null &&
        placeDetail.photoReferences != null &&
        placeDetail.photoReferences!.isNotEmpty) {
      final photoReference = placeDetail.photoReferences!.first;
      // 서버의 사진 프록시 엔드포인트를 사용
      final serverUrl = GoogleMapsService().getServerUrl();
      imageUrl = '$serverUrl/place/photo/$photoReference';
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
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패 시 로그 출력 (디버그용)
                  debugPrint('이미지 로드 실패: $imageUrl, 에러: $error');
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
    // `context.watch`를 사용하여 ViewModel의 상태 변화를 감지하고 UI를 다시 빌드합니다.
    final viewModel = context.watch<PlaceDetailViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6), // 화면 전체 배경색
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, viewModel),
          // ViewModel로부터 상세 정보를 성공적으로 가져온 경우에만 표시합니다.
          if (viewModel.placeDetail != null)
            _buildPlaceInfoSection(viewModel.placeDetail!),
          _buildMemoHeader(),
          _buildMemoList(viewModel),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (viewModel.placeDetail != null) {
            _navigateToAddOrEditMemo(context, viewModel.placeDetail!);
          }
        },
        backgroundColor: const Color(0xFFDE3B3B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 장소의 이름과 주소를 표시하는 섹션을 빌드합니다.
  Widget _buildPlaceInfoSection(PlaceDetail placeDetail) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(placeDetail.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              placeDetail.formattedAddress ??
                  placeDetail.vicinity ??
                  '주소 정보 없음',
              style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }

  /// "혜택 메모"라는 제목을 가진 헤더 섹션을 빌드합니다.
  Widget _buildMemoHeader() {
    return SliverToBoxAdapter(
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
    );
  }

  /// `ViewModel`의 상태에 따라 메모 목록, 로딩 인디케이터, 또는 에러 메시지를 표시합니다.
  Widget _buildMemoList(PlaceDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    if (viewModel.error != null) {
      return SliverFillRemaining(
          child: Center(child: Text('오류: ${viewModel.error}')));
    }
    if (viewModel.memos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Center(child: Text('아직 기록된 메모가 없습니다.')),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final memo = viewModel.memos[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: MemoCard(
              memo: memo,
              onTap: () => _navigateToAddOrEditMemo(
                  context, viewModel.placeDetail!,
                  existingMemo: memo),
              onTagTap: (tag) =>
                  Navigator.pushNamed(context, '/memos_by_tag', arguments: tag),
            ),
          );
        },
        childCount: viewModel.memos.length,
      ),
    );
  }

  /// 메모 추가 또는 수정 화면으로 이동합니다.
  ///
  /// [existingMemo]가 제공되면 수정 모드로, `null`이면 추가 모드로 화면을 엽니다.
  /// 화면이 닫힌 후에는 메모 목록을 새로고침하여 변경사항을 반영합니다.
  void _navigateToAddOrEditMemo(BuildContext context, PlaceDetail placeDetail,
      {Memo? existingMemo}) {
    // `PlaceDetail` 모델을 `MemoAddScreen`이 요구하는 `Place` 모델로 변환합니다.
    final placeForMemo = Place(
      id: placeDetail.placeId,
      name: placeDetail.name,
      address: placeDetail.formattedAddress ?? placeDetail.vicinity ?? '',
      location: placeDetail.location,
      acceptsCreditCard: true, // 기본값 혹은 placeDetail에서 가져온 값
      photoReferences: placeDetail.photoReferences ?? [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MemoAddScreen(place: placeForMemo, memoToEdit: existingMemo),
      ),
    ).then((_) {
      // `then` 콜백은 화면이 `pop`으로 닫힐 때 호출됩니다.
      if (mounted) {
        context.read<PlaceDetailViewModel>().loadMemos(placeId);
      }
    });
  }
}
