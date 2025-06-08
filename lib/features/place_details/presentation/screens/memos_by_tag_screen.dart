import 'package:flutter/material.dart';
import '../../../../core/models/memo.dart';
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_card.dart';
import '../../../../core/services/storage_service.dart';

/// 특정 태그가 포함된 모든 메모 목록을 보여주는 화면
class MemosByTagScreen extends StatefulWidget {
  final String tag;

  const MemosByTagScreen({
    super.key,
    required this.tag,
  });

  @override
  State<MemosByTagScreen> createState() => _MemosByTagScreenState();
}

class _MemosByTagScreenState extends State<MemosByTagScreen> {
  List<Memo> memos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemosByTag();
  }

  Future<void> _loadMemosByTag() async {
    try {
      final allMemos = await StorageService.instance.getAllMemos();
      // 태그를 포함하는 메모만 필터링
      final filteredMemos = allMemos.where((memo) {
        final tags = memo.tags?.trim().split(RegExp(r'\s+')) ?? [];
        return tags.contains(widget.tag);
      }).toList();

      if (mounted) {
        setState(() {
          memos = filteredMemos;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모를 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("'${widget.tag}' 태그 검색 결과"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : memos.isEmpty
              ? const Center(
                  child: Text(
                    '해당 태그를 포함하는 메모가 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: memos.length,
                  itemBuilder: (context, index) {
                    // MemoCard 위젯 사용, placeName 표시
                    return MemoCard(
                      memo: memos[index],
                      showPlaceName: true, // 장소 이름 표시 옵션 활성화
                    );
                  },
                ),
    );
  }
}

class MemoWithPlace {
  final Memo memo;
  final String placeName;

  MemoWithPlace({
    required this.memo,
    required this.placeName,
  });
}
