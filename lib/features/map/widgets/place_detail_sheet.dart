import 'package:flutter/material.dart';

import '../../../core/models/place_detail.dart';

class PlaceDetailSheet extends StatelessWidget {
  final PlaceDetail placeDetail;
  final ScrollController scrollController;

  const PlaceDetailSheet({
    super.key,
    required this.placeDetail,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeDetail.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildRating(),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildInfoTile(
                    Icons.location_on_outlined,
                    '주소',
                    placeDetail.formattedAddress ??
                        placeDetail.vicinity ??
                        '정보 없음',
                  ),
                  if (placeDetail.formattedPhoneNumber != null)
                    _buildInfoTile(
                      Icons.phone_outlined,
                      '연락처',
                      placeDetail.formattedPhoneNumber!,
                    ),
                  if (placeDetail.website != null)
                    _buildInfoTile(
                      Icons.language_outlined,
                      '웹사이트',
                      placeDetail.website!,
                      isUrl: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating() {
    if (placeDetail.rating == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Text(
          placeDetail.rating.toString(),
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (index) {
          return Icon(
            index < placeDetail.rating! ? Icons.star : Icons.star_border,
            color: Colors.orange,
            size: 16,
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionButton(context, Icons.directions, '경로'),
        _actionButton(context, Icons.bookmark_border, '저장'),
        _actionButton(context, Icons.share_outlined, '공유'),
        if (placeDetail.formattedPhoneNumber != null)
          _actionButton(context, Icons.call_outlined, '전화'),
      ],
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Theme.of(context).primaryColor)),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle,
      {bool isUrl = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isUrl ? Colors.blue : Colors.black87,
                    decoration:
                        isUrl ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
