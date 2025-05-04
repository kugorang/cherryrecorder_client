import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../../../place_details/presentation/providers/place_detail_view_model.dart';

class MemoEditScreen extends StatefulWidget {
  final String placeId;
  final Memo? existingMemo;

  const MemoEditScreen({super.key, required this.placeId, this.existingMemo});

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.existingMemo?.content,
    );
    _tagsController = TextEditingController(text: widget.existingMemo?.tags);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메모 내용을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final viewModel = context.read<PlaceDetailViewModel>();
      final newLatitude = widget.existingMemo?.latitude ?? 0.0;
      final newLongitude = widget.existingMemo?.longitude ?? 0.0;

      final memo = Memo(
        id: widget.existingMemo?.id,
        placeId: widget.placeId,
        latitude: newLatitude,
        longitude: newLongitude,
        content: _contentController.text.trim(),
        tags: _tagsController.text.trim(),
        createdAt: widget.existingMemo?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingMemo != null) {
        await viewModel.updateMemo(memo);
      } else {
        await viewModel.addMemo(memo);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메모 저장 중 오류가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingMemo != null ? '메모 수정' : '새 메모'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveMemo),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: '메모 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: '태그를 입력하세요 (쉼표로 구분)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
