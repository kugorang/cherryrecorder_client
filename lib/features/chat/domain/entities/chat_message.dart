/// 채팅 메시지를 나타내는 클래스.
class ChatMessage {
  /// 메시지 유형 ('message', 'user_joined', 'user_left', 'error', 'info').
  final String type;
  /// 메시지를 보낸 사람의 닉네임 (일반 메시지용).
  final String? sender;
  /// 메시지 내용.
  final String content;
  /// 메시지가 자신에게서 보내진 것인지 여부 (UI 표시용).
  final bool isMine;
  /// 메시지 수신 시간 (로컬).
  final DateTime timestamp;

  ChatMessage({
    required this.type,
    this.sender,
    required this.content,
    this.isMine = false, // 기본값은 false
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 시스템 메시지 (참가/퇴장/오류 등) 생성용 팩토리 생성자.
  factory ChatMessage.system(String message) {
    return ChatMessage(type: 'info', content: message);
  }
   factory ChatMessage.error(String message) {
    return ChatMessage(type: 'error', content: message);
  }
}
