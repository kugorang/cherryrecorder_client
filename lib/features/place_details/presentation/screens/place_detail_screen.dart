import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import 'package:cherryrecorder_client/core/models/place.dart'; // 패키지 상대 경로 사용
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng 타입 사용을 위해 추가
import '../providers/place_detail_view_model.dart';
import '../widgets/memo_form_dialog.dart'; // 경로 수정
import 'package:intl/intl.dart'; // 날짜 포맷팅

/// 장소 상세 정보를 표시하는 화면 위젯
class PlaceDetailScreen extends StatefulWidget {
  // Place 객체 대신 Map<String, dynamic>을 받도록 변경
  final Map<String, dynamic> placeData;
  late final Place place; // 내부적으로 Place 객체로 변환

  PlaceDetailScreen({super.key, required this.placeData}) {
    // Map에서 LatLng 객체 생성
    final locationMap = placeData['location'] as Map<String, dynamic>;
    final latLng = LatLng(
      locationMap['latitude'] as double,
      locationMap['longitude'] as double,
    );

    // Place 객체 생성
    place = Place(
      id: placeData['id'] as String,
      name: placeData['name'] as String,
      address: placeData['address'] as String,
      location: latLng,
      acceptsCreditCard: placeData['acceptsCreditCard'] as bool? ?? true,
    );
  }

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 위젯 빌드 후 첫 프레임이 렌더링된 다음 loadMemos 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider를 통해 ViewModel 접근 및 메모 로드
      context.read<PlaceDetailViewModel>().loadMemos(widget.place.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 변화 감지
    final viewModel = context.watch<PlaceDetailViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name), // 장소 이름 표시
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // 장소 정보 표시 영역 (간단하게)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              key: const Key('place_detail_body_column'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.place.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.place.address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(),

          // 메모 목록 또는 로딩/오류 상태 표시 (웹 제한 제거)
          Expanded(child: _buildMemoList(viewModel)),
        ],
      ),
      // 웹 제한 제거
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemoDialog(context),
        tooltip: '메모 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMemoList(PlaceDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '오류: ${viewModel.error}',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (viewModel.memos.isEmpty) {
      return const Center(
        child: Text(
          '저장된 메모가 없습니다.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: viewModel.memos.length,
      itemBuilder: (context, index) {
        final memo = viewModel.memos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(
              memo.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '최종 수정: ${DateFormat('yyyy-MM-dd HH:mm').format(memo.updatedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: Colors.grey.shade700),
                  onPressed: () => _showEditMemoDialog(context, memo),
                  tooltip: '수정',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () => _showDeleteConfirmationDialog(context, memo),
                  tooltip: '삭제',
                ),
              ],
            ),
            onTap: () => _showMemoDetailDialog(context, memo),
          ),
        );
      },
    );
  }

  // 메모 추가 다이얼로그 표시
  void _showAddMemoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => MemoFormDialog(
            placeId: widget.place.id,
            latitude: widget.place.location.latitude, // 위도 전달
            longitude: widget.place.location.longitude, // 경도 전달
          ),
    );
  }

  // 메모 수정 다이얼로그 표시
  void _showEditMemoDialog(BuildContext context, Memo memo) {
    showDialog(
      context: context,
      builder:
          (context) => MemoFormDialog(
            placeId: widget.place.id,
            memoToEdit: memo,
            latitude:
                widget.place.location.latitude, // 위도 전달 (수정 시에도 장소 좌표는 동일)
            longitude: widget.place.location.longitude, // 경도 전달
          ),
    );
  }

  // 메모 상세 보기 다이얼로그
  void _showMemoDetailDialog(BuildContext context, Memo memo) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('메모 내용'),
            content: SingleChildScrollView(child: Text(memo.content)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  // 메모 삭제 확인 다이얼로그
  void _showDeleteConfirmationDialog(BuildContext context, Memo memo) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('메모 삭제'),
            content: const Text('정말로 이 메모를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  final viewModel = context.read<PlaceDetailViewModel>();
                  // Store the context before the async gap
                  final currentContext = context;
                  // ignore: unnecessary_non_null_assertion
                  await viewModel.deleteMemo(memo.id!, widget.place.id!);

                  // Check if mounted AFTER the await
                  if (!currentContext.mounted) return;

                  Navigator.of(currentContext).pop(); // 다이얼로그 닫기
                  // 스낵바로 결과 알림 (선택 사항)
                  // The existing mounted checks here are fine
                  if (viewModel.error == null) {
                    // Already checked mounted
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(content: Text('메모가 삭제되었습니다.')),
                    );
                  } else {
                    // Already checked mounted
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(content: Text('메모 삭제 실패: ${viewModel.error}')),
                    );
                  }
                },
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
