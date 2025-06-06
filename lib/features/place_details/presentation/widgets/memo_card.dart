import 'package:flutter/material.dart';
import 'package:cherryrecorder_client/core/models/memo.dart';

/// 메모 정보를 표시하는 카드 위젯
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback? onTap;
  final ValueChanged<String>? onTagTap;
  final bool showPlaceName; // 장소 이름 표시 여부

  const MemoCard({
    super.key,
    required this.memo,
    this.onTap,
    this.onTagTap,
    this.showPlaceName = false, // 기본값은 false
  });

  @override
  Widget build(BuildContext context) {
    final tags = _parseTags(memo.tags);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 장소 이름 표시 (showPlaceName이 true일 때)
              if (showPlaceName && memo.placeName != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFFDE3B3B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        memo.placeName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDE3B3B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Text(
                memo.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 11,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return GestureDetector(
                      onTap: () => onTagTap?.call(tag),
                      child: _buildTag(tag),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 태그 문자열을 파싱하여 리스트로 반환
  List<String> _parseTags(String? tagsString) {
    if (tagsString == null || tagsString.isEmpty) return [];
    return tagsString
        .trim()
        .split(RegExp(r'\s+'))
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  /// 개별 태그를 표시하는 위젯
  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ),
    );
  }
}
