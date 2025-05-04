import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../providers/place_detail_view_model.dart';

class MemoFormDialog extends StatefulWidget {
  final String placeId;
  final Memo? memoToEdit;
  final double latitude;
  final double longitude;

  const MemoFormDialog({
    super.key,
    required this.placeId,
    this.memoToEdit,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MemoFormDialog> createState() => _MemoFormDialogState();
}

class _MemoFormDialogState extends State<MemoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.memoToEdit?.content ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<PlaceDetailViewModel>(); // listen: false 불필요

    return AlertDialog(
      title: Text(widget.memoToEdit == null ? '새 메모 작성' : '메모 수정'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // 내용 길어질 경우 스크롤
          child: Column(
            mainAxisSize: MainAxisSize.min, // 컬럼 크기를 내용에 맞게 조절
            children: [
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '메모 내용'),
                maxLines: 5, // 여러 줄 입력 가능하도록
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '메모 내용을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Place ID: ${widget.placeId}'), // 디버깅용
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          // 주요 액션 버튼 강조
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              // Store context before async gap
              final currentContext = context;
              final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
              final navigator = Navigator.of(currentContext);

              final now = DateTime.now();
              // 수정 시 기존 좌표 사용, 새 메모 시 전달받은 좌표 사용
              final double memoLatitude =
                  widget.memoToEdit?.latitude ?? widget.latitude;
              final double memoLongitude =
                  widget.memoToEdit?.longitude ?? widget.longitude;

              final memo = Memo(
                id: widget.memoToEdit?.id,
                placeId: widget.placeId,
                latitude: memoLatitude, // 위도 추가
                longitude: memoLongitude, // 경도 추가
                content: _contentController.text.trim(),
                createdAt: widget.memoToEdit?.createdAt, // 수정 시 기존 값 유지
                updatedAt: now,
              );

              bool success = false;
              if (widget.memoToEdit == null) {
                success = await viewModel.addMemo(memo);
              } else {
                success = await viewModel.updateMemo(memo);
              }

              // Use stored context and check mounted
              if (!currentContext.mounted) return;

              if (success) {
                navigator.pop(true); // 성공 시 true 반환
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '메모가 ${widget.memoToEdit == null ? "저장" : "수정"}되었습니다.',
                    ),
                  ),
                );
              } else {
                navigator.pop(false); // 실패 시 false 반환
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '메모 ${widget.memoToEdit == null ? "저장" : "수정"} 실패: ${viewModel.error}',
                    ),
                  ),
                );
              }
            }
          },
          child: Text(widget.memoToEdit == null ? '저장' : '수정'),
        ),
      ],
    );
  }
}
