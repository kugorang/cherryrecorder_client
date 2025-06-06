import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../../../../core/models/place.dart';
import '../providers/place_detail_view_model.dart';

class MemoAddScreen extends StatefulWidget {
  final Place place;
  final Memo? memoToEdit;

  const MemoAddScreen({
    super.key,
    required this.place,
    this.memoToEdit,
  });

  @override
  State<MemoAddScreen> createState() => _MemoAddScreenState();
}

class _MemoAddScreenState extends State<MemoAddScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  late TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.memoToEdit?.content ?? '',
    );
    _tagsController = TextEditingController(
      text: widget.memoToEdit?.tags ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<PlaceDetailViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDE3B3B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.memoToEdit == null ? '새로운 혜택 메모' : '혜택 메모 수정',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 장소 정보 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFFAFAFA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.place.address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),

            // 혜택 내용 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        '혜택 내용',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _contentController,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        hintText: '이 장소의 결제 혜택을 입력해주세요.',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '혜택 내용을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 태그 추가 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        '태그 추가',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        hintText: '예시) #현대카드 #적립',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 저장 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saveMemo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDE3B3B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    widget.memoToEdit == null ? '저장' : '수정',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMemo() async {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<PlaceDetailViewModel>();
      final now = DateTime.now();

      // 태그 처리: 공백으로 구분하고, 각 태그 앞에 # 붙이기
      String processedTags = _tagsController.text
          .trim()
          .split(RegExp(r'\s+')) // 공백 기준으로 분리
          .where((tag) => tag.isNotEmpty)
          .map((tag) => tag.startsWith('#') ? tag : '#$tag') // #이 없으면 붙이기
          .join(' '); // 다시 공백으로 합치기

      if (widget.memoToEdit == null) {
        // 새 메모 추가
        final newMemo = Memo(
          placeId: widget.place.id,
          placeName: widget.place.name,
          content: _contentController.text,
          tags: processedTags,
          createdAt: now,
          updatedAt: now,
          // place 정보는 view model이나 storage service에서 처리
          latitude: widget.place.location.latitude,
          longitude: widget.place.location.longitude,
        );
        await viewModel.addMemo(newMemo);
      } else {
        // 기존 메모 수정
        final updatedMemo = widget.memoToEdit!.copyWith(
          content: _contentController.text,
          tags: processedTags,
          updatedAt: now,
          placeName: widget.place.name,
        );
        await viewModel.updateMemo(updatedMemo);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }
}
