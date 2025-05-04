import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/chat_message.dart';

/// 채팅 연결 상태
enum ChatConnectionStatus {
  disconnected, // 연결 끊김
  connecting, // 연결 중
  connected, // 연결됨
  error, // 오류 발생
}

/// 채팅 기능의 상태 및 로직을 관리하는 ViewModel.
class ChatViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  Socket? _socket; // 서버와 통신할 TCP 소켓
  String? _nickname; // 사용자의 현재 닉네임
  final List<ChatMessage> _messages = []; // 채팅 메시지 목록
  final List<String> _users = []; // 접속 중인 사용자 닉네임 목록
  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  String? _errorMessage; // 연결 또는 통신 중 발생한 오류 메시지
  StreamSubscription? _socketSubscription; // 소켓 데이터 수신 리스너
  bool _isDisposed = false; // ViewModel 소멸 여부

  // --- Getters ---
  String? get nickname => _nickname;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get users => List.unmodifiable(_users);
  ChatConnectionStatus get connectionStatus => _connectionStatus;
  String? get errorMessage => _errorMessage;

  /// ViewModel 소멸 시 소켓 연결 해제 및 리스너 정리.
  @override
  void dispose() {
    _logger.i('[ChatViewModel] Disposing...');
    _isDisposed = true;
    disconnect();
    super.dispose();
  }

  /// 채팅 서버에 연결 시도.
  /// [host]: 서버 호스트 주소 (IP 또는 도메인)
  /// [port]: 서버 포트 번호
  Future<void> connect(String host, int port) async {
    if (_connectionStatus == ChatConnectionStatus.connected ||
        _connectionStatus == ChatConnectionStatus.connecting) {
      _logger.w('이미 연결 중이거나 연결된 상태입니다.');
      return;
    }

    _logger.i('채팅 서버 연결 시도 중... ($host:$port)');
    _connectionStatus = ChatConnectionStatus.connecting;
    _errorMessage = null;
    _messages.clear(); // 연결 시 메시지 초기화
    _users.clear(); // 연결 시 사용자 목록 초기화
    _addSystemMessage('서버에 연결 중...');
    notifyListeners();

    try {
      // 지정된 시간(예: 10초) 내에 연결 시도
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );
      _logger.i('소켓 연결 성공!');
      _connectionStatus = ChatConnectionStatus.connected;
      _errorMessage = null;
      _addSystemMessage('서버에 연결되었습니다. 닉네임을 설정해주세요.');
      notifyListeners();

      // 소켓 데이터 수신 리스너 설정
      _socketSubscription = _socket!.listen(
        _handleServerData, // 데이터 수신 시 호출될 핸들러
        onError: _handleError, // 오류 발생 시 호출될 핸들러
        onDone: _handleDisconnect, // 연결 종료 시 호출될 핸들러
        cancelOnError: true, // 오류 발생 시 자동으로 구독 취소
      );
      _socket!.encoding = utf8; // UTF-8 인코딩 설정
    } catch (e) {
      _logger.e('소켓 연결 오류', error: e);
      _handleError(e);
    }
  }

  /// 서버 연결 해제.
  void disconnect() {
    if (_connectionStatus == ChatConnectionStatus.disconnected) return;

    _logger.i('서버 연결 해제 중...');
    _connectionStatus = ChatConnectionStatus.disconnected;
    _errorMessage = null;
    _nickname = null; // 닉네임 초기화
    _socketSubscription?.cancel(); // 리스너 구독 취소
    _socket?.destroy(); // 소켓 리소스 해제
    _socket = null;
    if (!_isDisposed) {
      _addSystemMessage('서버 연결이 끊어졌습니다.');
      notifyListeners();
    }
  }

  /// 닉네임 설정 요청 전송.
  void setNickname(String nickname) {
    if (_connectionStatus != ChatConnectionStatus.connected ||
        _socket == null) {
      _logger.w('닉네임 설정 실패: 서버에 연결되지 않음.');
      _addSystemMessage('오류: 서버에 연결되지 않았습니다.', isError: true);
      return;
    }
    if (nickname.isEmpty || nickname.length > 16) {
      _addSystemMessage('오류: 닉네임은 1~16자 사이여야 합니다.', isError: true);
      return;
    }

    _logger.i("닉네임 설정 요청: $nickname");
    final message = {'type': 'set_nickname', 'nickname': nickname};
    _sendMessage(jsonEncode(message));
    // 임시 닉네임 설정 (서버 응답 기다리지 않고 UI 우선 업데이트)
    // 실제 닉네임 확정은 서버 응답(nickname_ok)에서 이루어져야 함
    // _nickname = nickname;
    // notifyListeners();
  }

  /// 채팅 메시지 전송.
  void sendMessage(String content) {
    if (_connectionStatus != ChatConnectionStatus.connected ||
        _socket == null) {
      _logger.w('메시지 전송 실패: 서버에 연결되지 않음.');
      _addSystemMessage('오류: 메시지를 보내려면 서버에 연결해야 합니다.', isError: true);
      return;
    }
    if (_nickname == null || _nickname!.isEmpty) {
      _logger.w('메시지 전송 실패: 닉네임이 설정되지 않음.');
      _addSystemMessage('오류: 메시지를 보내려면 먼저 닉네임을 설정해야 합니다.', isError: true);
      return;
    }
    if (content.isEmpty) {
      return; // 빈 메시지 무시
    }

    _logger.i("메시지 전송: $content");
    final message = {'type': 'message', 'content': content};
    _sendMessage(jsonEncode(message));

    // 보낸 메시지를 즉시 UI에 표시 (isMine=true)
    _addChatMessage(
      ChatMessage(
        type: 'message',
        sender: _nickname!, // 내 닉네임
        content: content,
        isMine: true,
      ),
    );
  }

  /// 소켓으로 메시지(JSON 문자열) 전송.
  void _sendMessage(String jsonMessage) {
    if (_socket != null &&
        _connectionStatus == ChatConnectionStatus.connected) {
      try {
        _socket!.writeln(jsonMessage); // writeln 사용 (개행 문자 자동 추가)
        _logger.d('Sent: $jsonMessage');
      } catch (e) {
        _logger.e('메시지 전송 오류', error: e);
        _handleError('메시지 전송 중 오류가 발생했습니다.');
      }
    }
  }

  /// 서버로부터 데이터 수신 처리.
  void _handleServerData(dynamic data) {
    // data는 보통 Uint8List 타입, 문자열로 디코딩
    String receivedStr;
    try {
      receivedStr = utf8.decode(data);
    } catch (e) {
      _logger.e('데이터 디코딩 오류', error: e, stackTrace: StackTrace.current);
      _addSystemMessage('오류: 서버 메시지 해석 실패', isError: true);
      return;
    }

    _logger.d('Received Raw: $receivedStr');

    // 여러 JSON 메시지가 붙어 올 수 있으므로 개행으로 분리
    final lines = receivedStr.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue; // 빈 줄 무시

      try {
        final json = jsonDecode(line.trim()) as Map<String, dynamic>;
        _logger.i('Parsed JSON: $json');
        final type = json['type'] as String? ?? 'unknown';

        // 메시지 타입에 따라 처리
        switch (type) {
          case 'message':
            final sender = json['sender'] as String? ?? 'Unknown';
            final content = json['content'] as String? ?? '';
            _addChatMessage(
              ChatMessage(
                type: type,
                sender: sender,
                content: content,
                isMine: sender == _nickname, // 내가 보낸 메시지인지 확인
              ),
            );
            break;
          case 'user_joined':
            final joinedNickname = json['nickname'] as String? ?? 'Someone';
            if (!_users.contains(joinedNickname)) {
              _users.add(joinedNickname);
            }
            _addSystemMessage('$joinedNickname 님이 입장했습니다.');
            break;
          case 'user_left':
            final leftNickname = json['nickname'] as String? ?? 'Someone';
            _users.remove(leftNickname);
            _addSystemMessage('$leftNickname 님이 퇴장했습니다.');
            break;
          case 'nickname_ok':
            // 서버에서 닉네임 설정을 최종 확인
            // 이전에 임시로 UI에 반영했다면 여기서 확정 상태로 변경 가능
            // 또는, setNickname 함수에서 _nickname을 설정하지 않고 여기서 설정
            final previouslySetNickname = json['nickname'] as String?;
            if (previouslySetNickname != null) {
              _nickname = previouslySetNickname;
              _logger.i('닉네임 확정: $_nickname');
              _addSystemMessage("닉네임 '$_nickname' (으)로 설정되었습니다.");
            } else {
              // setNickname 요청 시 보낸 닉네임을 알 수 없으면 오류 처리 필요
              _logger.w('nickname_ok 메시지에 닉네임 정보 누락');
            }
            break;
          case 'user_list':
            final userList =
                (json['users'] as List<dynamic>? ?? []).cast<String>();
            _users.clear();
            _users.addAll(userList);
            _logger.i('접속 중인 사용자 목록 업데이트: ${_users.join(', ')}');
            break;
          case 'error':
            final errorMessage = json['message'] as String? ?? '알 수 없는 서버 오류';
            _addSystemMessage('서버 오류: $errorMessage', isError: true);
            break;
          default:
            _logger.w('알 수 없는 메시지 타입 수신: $type');
            _addSystemMessage('알 수 없는 서버 메시지 수신: $line', isError: true);
        }
      } catch (e) {
        _logger.e('JSON 파싱 또는 처리 오류', error: e, stackTrace: StackTrace.current);
        _addSystemMessage('오류: 서버 메시지 처리 실패 ($line)', isError: true);
      }
    }
    // 상태 변경 후 UI 업데이트 알림
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// 소켓 오류 처리.
  void _handleError(dynamic error) {
    _logger.e('소켓 오류 발생', error: error);
    _errorMessage = '서버와 통신 중 오류가 발생했습니다: ${error.toString()}';
    _connectionStatus = ChatConnectionStatus.error;
    _addSystemMessage('오류: $_errorMessage', isError: true);
    disconnect(); // 오류 발생 시 연결 종료
  }

  /// 소켓 연결 종료 처리.
  void _handleDisconnect() {
    _logger.i('소켓 연결 종료됨 (onDone)');
    if (_connectionStatus != ChatConnectionStatus.error) {
      _addSystemMessage('서버 연결이 종료되었습니다.');
    }
    disconnect();
  }

  /// 시스템 메시지 추가 (UI 표시용).
  void _addSystemMessage(String content, {bool isError = false}) {
    if (_isDisposed) return;
    _messages.add(
      isError ? ChatMessage.error(content) : ChatMessage.system(content),
    );
    // 메시지 목록 제한 (선택적)
    // if (_messages.length > 100) {
    //   _messages.removeRange(0, _messages.length - 100);
    // }
    notifyListeners();
  }

  /// 일반 채팅 메시지 추가 (UI 표시용).
  void _addChatMessage(ChatMessage message) {
    if (_isDisposed) return;
    _messages.add(message);
    // 메시지 목록 제한 (선택적)
    // if (_messages.length > 100) {
    //   _messages.removeRange(0, _messages.length - 100);
    // }
    notifyListeners();
  }
}
