import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../domain/entities/chat_message.dart';

/// 채팅 연결 상태
enum ChatConnectionStatus {
  disconnected, // 연결 안됨
  connecting, // 연결 중
  connected, // 연결됨
  error, // 오류 발생
}

/// 채팅 기능의 상태 및 로직을 관리하는 ViewModel.
class ChatViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  WebSocketChannel? _channel; // 서버와 통신할 WebSocket 채널
  String? _nickname; // 사용자의 현재 닉네임
  final List<ChatMessage> _messages = []; // 채팅 메시지 목록
  final Set<String> _users = {}; // 현재 접속자 목록
  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  String? _errorMessage; // 마지막 오류 메시지
  bool _isDisposed = false; // dispose 여부
  StreamSubscription? _messageSubscription; // WebSocket 메시지 구독
  bool _isFirstJoin = true; // 첫 입장 여부

  // 읽기 전용 getter
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Set<String> get users => Set.unmodifiable(_users);
  ChatConnectionStatus get connectionStatus => _connectionStatus;
  String? get errorMessage => _errorMessage;
  String? get nickname => _nickname;
  bool get isFirstJoin => _isFirstJoin;

  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    super.dispose();
  }

  /// 서버에 연결한다.
  /// 이미 연결되어 있으면 아무 작업도 하지 않는다.
  Future<void> connect(String host, int port, {bool useSecure = true}) async {
    if (_connectionStatus == ChatConnectionStatus.connected) {
      _logger.w('Already connected to the server');
      return;
    }

    _logger.i('Attempting to connect to $host:$port (secure: $useSecure)');
    _setConnectionStatus(ChatConnectionStatus.connecting);

    try {
      // WebSocket 연결 (WS 또는 WSS)
      final protocol = useSecure ? 'wss' : 'ws';
      final wsPath = '/ws'; // nginx 경로
      
      // 포트 번호가 기본 포트인 경우 생략
      String wsUrl;
      if ((useSecure && port == 443) || (!useSecure && port == 80)) {
        wsUrl = '$protocol://$host$wsPath';
      } else {
        wsUrl = '$protocol://$host:$port$wsPath';
      }
      
      final wsUri = Uri.parse(wsUrl);

      _logger.i('WebSocket URL: $wsUrl');
      _logger.i('Protocol: $protocol, Host: $host, Port: $port');

      // 서브프로토콜 없이 연결 (모든 환경에서 동일하게)
      _logger.i('Connecting to server without subprotocol');
      _channel = WebSocketChannel.connect(wsUri);

      _logger.i('WebSocket connecting to $wsUrl');

      // 연결 완료를 기다림
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket 연결 시간 초과');
        },
      );

      _logger.i('WebSocket connected successfully');
      _setConnectionStatus(ChatConnectionStatus.connected);
      _addSystemMessage('채팅 서버에 연결되었습니다. 닉네임을 설정해주세요.');

      // 서버로부터 메시지 수신 리스너 설정
      _messageSubscription = _channel!.stream.listen(
        (dynamic data) {
          final message = data.toString();
          _handleServerData(message);
        },
        onError: (error) {
          _logger.e('WebSocket error', error: error);
          _handleError(error);
        },
        onDone: () {
          _logger.i('WebSocket connection closed');
          _setConnectionStatus(ChatConnectionStatus.disconnected);
          _addSystemMessage('채팅 서버와의 연결이 끊어졌습니다.');
        },
        cancelOnError: false,
      );
    } catch (e) {
      _logger.e('Failed to connect', error: e);
      _handleError(e);
    }
  }

  /// 서버와의 연결을 해제한다.
  void disconnect() {
    _logger.i('Disconnecting from server');
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _setConnectionStatus(ChatConnectionStatus.disconnected);
    _messages.clear();
    _users.clear();
    _isFirstJoin = true; // 다음 연결 시 다시 첫 입장으로 처리
    _nickname = null; // 닉네임도 초기화
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// 메시지를 서버로 전송한다.
  void sendMessage(String message) {
    if (_channel == null ||
        _connectionStatus != ChatConnectionStatus.connected) {
      _logger.w('Not connected, cannot send message');
      return;
    }

    try {
      // WebSocket으로 메시지 전송
      _channel!.sink.add(message);
      _logger.i('Sent message: $message');

      // 사용자가 보낸 메시지를 즉시 채팅 목록에 추가
      // 닉네임 변경과 같은 명령어는 UI에 표시하지 않음
      if (!message.startsWith('/')) {
        _addChatMessage(
          ChatMessage(
            type: 'message',
            sender: _nickname ?? 'Me', // 현재 닉네임 또는 기본값
            content: message,
            isMine: true, // 내가 보낸 메시지
          ),
        );
        if (!_isDisposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      _logger.e('Failed to send message', error: e);
      _handleError(e);
    }
  }

  /// 닉네임 변경 명령을 전송한다.
  void changeNickname(String newNickname) {
    sendMessage('/nick $newNickname');
  }

  /// 서버로부터 데이터 수신 처리.
  void _handleServerData(String data) {
    // 서버에서는 \r\n으로 줄을 구분하므로 각 줄별로 처리
    final lines = data.split('\n');
    for (final line in lines) {
      final message = line.trim();
      if (message.isEmpty) continue;

      _logger.i('Received: $message');

      // 서버에서 받은 메시지를 그대로 ChatMessage로 변환하여 목록에 추가
      _addChatMessage(
        ChatMessage(
          type: _extractType(message),
          sender: _extractSender(message),
          content: message,
          isMine: _checkIfMine(message),
        ),
      );

      // 닉네임 변경 성공 메시지 감지
      if (message.contains('닉네임이') && message.contains('(으)로 변경되었습니다')) {
        final regex = RegExp(r"닉네임이 '(.+)'\(으\)로 변경되었습니다");
        final match = regex.firstMatch(message);
        if (match != null) {
          final oldNickname = _nickname;
          _nickname = match.group(1);
          _logger.i('Nickname changed to: $_nickname');

          // 첫 입장인 경우 입장 메시지 추가
          if (_isFirstJoin && oldNickname == null) {
            _isFirstJoin = false;
            // 닉네임 변경 메시지 다음에 입장 메시지 추가
            _addChatMessage(
              ChatMessage(
                type: 'info',
                sender: 'System',
                content: '$_nickname님이 입장하셨습니다.',
                isMine: false,
              ),
            );
          }
        }
      }
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  String _extractType(String message) {
    if (message.startsWith('[')) {
      return 'message';
    }
    if (message.startsWith('Error:')) {
      return 'error';
    }
    // 'info' or other system-level messages
    return 'info';
  }

  // 임시: 메시지에서 보낸 사람 파싱 (서버 포맷에 맞춰야 함)
  String _extractSender(String message) {
    if (message.startsWith('[')) {
      final match = RegExp(r'^\[([^\]]+)\]').firstMatch(message);
      if (match != null) {
        final senderPart = match.group(1)!;
        // "닉네임 @ 방이름" 또는 "닉네임" 형식 처리
        final parts = senderPart.split(' @ ');
        final sender = parts.first;

        // IP:포트 형식의 닉네임인 경우 "익명" 으로 표시
        if (RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$').hasMatch(sender)) {
          return '익명';
        }

        return sender;
      }
    }
    return 'System';
  }

  // 메시지가 내가 보낸 것인지 확인
  bool _checkIfMine(String message) {
    if (_nickname != null && message.startsWith('[$_nickname')) {
      return true;
    }
    return false;
  }

  /// 시스템 메시지를 추가한다.
  void _addSystemMessage(String content) {
    _addChatMessage(ChatMessage.system(content));
  }

  /// 채팅 메시지를 목록에 추가한다.
  void _addChatMessage(ChatMessage message) {
    _messages.add(message);
    // 최대 메시지 수 제한 (메모리 관리)
    if (_messages.length > 1000) {
      _messages.removeAt(0);
    }
  }

  /// 에러 처리
  void _handleError(dynamic error) {
    _logger.e('Chat error', error: error);
    _errorMessage = error.toString();
    _setConnectionStatus(ChatConnectionStatus.error);
    _addSystemMessage('오류 발생: ${error.toString()}');
  }

  /// 화면에 표시된 오류 메시지를 지운다.
  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      // 오류 상태였다면 연결 끊김으로 상태를 변경하여 UI가 다시 연결을 시도하도록 유도할 수 있음
      if (_connectionStatus == ChatConnectionStatus.error) {
        _setConnectionStatus(ChatConnectionStatus.disconnected);
      } else {
        // 오류 상태가 아닌 다른 상태에서 에러 메시지만 지울 경우, 리스너에게 알려 UI를 갱신
        if (!_isDisposed) {
          notifyListeners();
        }
      }
    }
  }

  void _setConnectionStatus(ChatConnectionStatus status) {
    _connectionStatus = status;
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
