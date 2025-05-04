import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅
import '../../domain/entities/chat_message.dart'; // ChatMessage 엔티티

/// 개별 채팅 메시지를 표시하는 위젯.
///
/// 메시지 유형([ChatMessage.type])에 따라 다른 스타일을 적용한다.
class ChatMessageWidget extends StatelessWidget {
  /// 표시할 채팅 메시지 객체.
  final ChatMessage message;

  /// [ChatMessageWidget] 생성자.
  const ChatMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // 메시지 유형에 따라 다른 위젯 반환
    switch (message.type) {
      case 'info': // 시스템 정보 메시지 (연결, 입장/퇴장 등)
        return _buildInfoMessage(context);
      case 'error': // 오류 메시지
        return _buildErrorMessage(context);
      case 'message': // 일반 사용자 메시지
        return _buildUserMessage(context);
      default:
        return const SizedBox.shrink(); // 알 수 없는 타입은 표시하지 않음
    }
  }

  /// 시스템 정보 메시지 위젯 빌드.
  Widget _buildInfoMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Text(
        message.content,
        style: TextStyle(
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 시스템 오류 메시지 위젯 빌드.
  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 사용자 메시지 위젯 빌드 (내 메시지 / 다른 사용자 메시지 구분).
  Widget _buildUserMessage(BuildContext context) {
    final bool isMyMessage = message.isMine;
    final alignment =
        isMyMessage ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = isMyMessage ? Colors.blue[100] : Colors.grey[200];
    final textColor = isMyMessage ? Colors.black87 : Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16.0),
      topRight: const Radius.circular(16.0),
      bottomLeft:
          isMyMessage ? const Radius.circular(16.0) : const Radius.circular(0),
      bottomRight:
          isMyMessage ? const Radius.circular(0) : const Radius.circular(16.0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      alignment: alignment,
      child: Column(
        crossAxisAlignment:
            isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 보낸 사람 닉네임 (내 메시지가 아닐 때만 표시)
          if (!isMyMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 8.0), // 여백 조정
              child: Text(
                message.sender ?? '알 수 없음',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          // 메시지 내용 컨테이너 (말풍선 모양)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7, // 최대 너비 제한
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 14.0,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 15),
            ),
          ),
          // 보낸 시간
          Padding(
            padding: EdgeInsets.only(
              top: 4.0,
              left: isMyMessage ? 0 : 8.0, // 내 메시지 아닐 때만 왼쪽에 여백
              right: isMyMessage ? 8.0 : 0, // 내 메시지일 때만 오른쪽에 여백
            ),
            child: Text(
              DateFormat(
                'HH:mm',
              ).format(message.timestamp), // 중복 제거, 시간만 표시 (예: 14:30)
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}
