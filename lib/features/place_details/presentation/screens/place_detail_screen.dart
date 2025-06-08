import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../../../../core/models/place.dart'; // 패키지 상대 경로 사용
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng 타입 사용을 위해 추가
import '../providers/place_detail_view_model.dart';
import 'memo_add_screen.dart'; // 메모 추가 화면
import 'package:cherryrecorder_client/core/services/google_maps_service.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_card.dart'; // MemoCard 임포트
import 'package:cherryrecorder_client/core/models/place_detail.dart';

/// 장소 상세 정보를 표시하는 화면 위젯
class PlaceDetailScreen extends StatefulWidget {
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
    placeId = widget.placeData['placeId']?.toString() ??
        widget.placeData['id']?.toString() ??
        '';

    if (placeId.isEmpty) {
      // placeId가 없는 경우 처리 (예: 에러 표시 또는 뒤로가기)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효하지 않은 장소 정보입니다.')),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    // 위젯 빌드 후 첫 프레임이 렌더링된 다음 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaceDetailViewModel>().loadData(placeId);
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
    // ViewModel 상태 변화 감지
    final viewModel = context.watch<PlaceDetailViewModel>();
    final placeDetail = viewModel.placeDetail;

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: CustomScrollView(
        slivers: [
          // 상단 이미지와 앱바 (ViewModel 데이터 사용)
          _buildSliverAppBar(context, viewModel),

          // 장소 정보 섹션
          if (placeDetail != null)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeDetail.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      placeDetail.formattedAddress ??
                          placeDetail.vicinity ??
                          '주소 정보 없음',
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
        onPressed: () {
          if (viewModel.placeDetail != null) {
            _navigateToAddMemo(context, viewModel.placeDetail!);
          }
        },
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

    if (viewModel.memos.isEmpty && !viewModel.isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
            child: Text(
              '아직 기록된 메모가 없습니다.\n첫 번째 혜택 메모를 추가해보세요!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
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
              onTap: () => _navigateToAddMemo(context, viewModel.placeDetail!,
                  existingMemo: memo),
              onTagTap: (tag) {
                // 태그 클릭 시 해당 태그의 메모 목록 화면으로 이동
                Navigator.pushNamed(
                  context,
                  '/memos_by_tag',
                  arguments: tag,
                );
              },
            ),
          );
        },
        childCount: viewModel.memos.length,
      ),
    );
  }

  void _navigateToAddMemo(BuildContext context, PlaceDetail placeDetail,
      {Memo? existingMemo}) {
    // ViewModel의 PlaceDetail 정보를 사용하여 Place 객체 생성
    final placeForMemo = Place(
      id: placeDetail.placeId,
      name: placeDetail.name,
      address:
          placeDetail.formattedAddress ?? placeDetail.vicinity ?? '주소 정보 없음',
      location: placeDetail.location,
      acceptsCreditCard: true,
      photoReferences: placeDetail.photoReferences ?? [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoAddScreen(
          place: placeForMemo,
          memoToEdit: existingMemo,
        ),
      ),
    ).then((_) {
      // 메모 추가/수정 화면에서 돌아왔을 때 목록 새로고침
      if (mounted) {
        context.read<PlaceDetailViewModel>().loadMemos(placeId);
      }
    });
  }
}
