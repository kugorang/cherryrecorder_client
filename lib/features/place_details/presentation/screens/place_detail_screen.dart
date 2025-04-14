import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/place_detail_view_model.dart';
import '../../../memo_management/presentation/screens/memo_edit_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String placeId;
  final String placeName;

  const PlaceDetailScreen({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaceDetailViewModel>().loadMemos(widget.placeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.placeName)),
      body: Consumer<PlaceDetailViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(viewModel.error!),
                  ElevatedButton(
                    onPressed: () => viewModel.loadMemos(widget.placeId),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (viewModel.memos.isEmpty) {
            return const Center(child: Text('아직 저장된 메모가 없습니다.'));
          }

          return ListView.builder(
            itemCount: viewModel.memos.length,
            itemBuilder: (context, index) {
              final memo = viewModel.memos[index];
              return Dismissible(
                key: Key(memo.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('삭제 확인'),
                        content: const Text('이 메모를 삭제하시겠습니까?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('취소'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            child: const Text('삭제'),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  viewModel.deleteMemo(memo.id!, widget.placeId);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(memo.content),
                    subtitle:
                        memo.tags != null && memo.tags!.isNotEmpty
                            ? Wrap(
                              spacing: 4,
                              children:
                                  memo.tags!.split(',').map((tag) {
                                    return Chip(
                                      label: Text(tag),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                            )
                            : null,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MemoEditScreen(
                                placeId: widget.placeId,
                                existingMemo: memo,
                              ),
                        ),
                      );
                      if (result == true) {
                        viewModel.loadMemos(widget.placeId);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemoEditScreen(placeId: widget.placeId),
            ),
          );
          if (result == true) {
            if (!mounted) return;
            context.read<PlaceDetailViewModel>().loadMemos(widget.placeId);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
