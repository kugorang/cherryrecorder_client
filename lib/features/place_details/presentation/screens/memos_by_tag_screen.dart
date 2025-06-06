import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/memo.dart';
import '../providers/place_detail_view_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/google_maps_service.dart';
import 'package:http/http.dart' as http;
import 'package:cherryrecorder_client/features/place_details/presentation/widgets/memo_card.dart';

/// 특정 태그가 포함된 모든 메모 목록을 보여주는 화면
class MemosByTagScreen extends StatelessWidget {
  final String tag;
  final List<Memo> memos;

  const MemosByTagScreen({
    super.key,
    required this.tag,
    required this.memos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("'$tag' 태그 검색 결과"),
      ),
      body: memos.isEmpty
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
