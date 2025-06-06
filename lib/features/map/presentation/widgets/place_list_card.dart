import 'package:flutter/material.dart';
import '../../../../core/models/place_summary.dart';

/// 하단 시트에 표시될 개별 장소 카드 위젯
class PlaceListCard extends StatelessWidget {
  final PlaceSummary place;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onMemoTap;

  const PlaceListCard({
    super.key,
    required this.place,
    this.isSelected = false,
    required this.onTap,
    required this.onMemoTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // 장소 아이콘
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.place),
                ),
                const SizedBox(width: 16),
                // 장소 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.vicinity ?? '주소 정보 없음',
                        style: TextStyle(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 메모 추가 버튼 (선택된 상태일 때만 표시)
            if (isSelected) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onMemoTap,
                    icon: const Icon(Icons.note_add),
                    label: const Text('메모 관리'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
