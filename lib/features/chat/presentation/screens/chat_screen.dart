import 'dart:async';
import 'dart:io' show Platform; // Platform import

import 'package:cherryrecorder_client/core/utils/dialog_utils.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, kDebugMode import
import 'package:flutter/material.dart';
// RawKeyboardListener 사용을 위해 추가
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../providers/chat_view_model.dart';
import '../widgets/chat_message_widget.dart';

/// 채팅 기능을 제공하는 화면.
/// WebSocket을 통해 실시간 메시지 송수신을 처리한다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatViewModel _chatViewModel;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode(); // 메시지 입력창의 포커스 관리
  final _logger = Logger(); // Logger 인스턴스 추가

  bool _hasShownNicknameDialog = false; // 닉네임 다이얼로그 표시 여부

  // --- 서버 주소 및 포트 설정 ---
  static const String _chatServerUrlFromEnv = String.fromEnvironment(
    'CHAT_SERVER_IP', // 변수명이 IP이지만 URL 전체를 받을 수 있음
    defaultValue: '',
  );

  static const int _chatServerPortFromEnv = int.fromEnvironment(
    'CHAT_SERVER_PORT',
    defaultValue: 0,
  );

  static const bool _useSecureWebSocket = bool.fromEnvironment(
    'USE_WSS',
    defaultValue: false,
  );

  // WSS 사용 여부에 따라 기본 포트를 다르게 설정
  static const int _defaultChatServerPort = _useSecureWebSocket ? 33335 : 33334;
  // ------------------------------------------------

  // State 멤버 변수로 IP와 포트를 저장하여 위젯 트리 전체에서 접근 가능하도록 함
  late final String _chatServerIp;
  late final int _chatServerPort;

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();

    // 환경 변수 파싱 로직을 initState에서 한 번만 수행
    // 환경 변수(_chatServerUrlFromEnv)가 제공되었는지 확인
    if (_chatServerUrlFromEnv.isNotEmpty) {
      // URL에서 프로토콜(http, https)을 제거
      final urlWithoutProtocol = _chatServerUrlFromEnv
          .replaceAll('https://', '')
          .replaceAll('http://', '');

      // ':'를 기준으로 호스트와 포트를 분리
      final parts = urlWithoutProtocol.split(':');
      _chatServerIp = parts.first; // 첫 번째 부분은 IP 또는 호스트

      if (parts.length > 1) {
        // 포트 번호가 있으면 파싱해서 사용
        _chatServerPort = int.tryParse(parts[1]) ?? _defaultChatServerPort;
      } else {
        // 포트 번호가 없으면 환경 변수에서 전달된 포트 또는 기본 포트 사용
        _chatServerPort = _chatServerPortFromEnv != 0
            ? _chatServerPortFromEnv
            : _defaultChatServerPort;
      }
    } else {
      // 환경 변수가 없을 때 플랫폼별 기본값 설정
      if (kIsWeb) {
        _chatServerIp = 'localhost';
      } else {
        try {
          _chatServerIp = Platform.isAndroid ? '10.0.2.2' : 'localhost';
        } catch (e) {
          _chatServerIp = 'localhost';
        }
      }
      _chatServerPort = _chatServerPortFromEnv != 0
          ? _chatServerPortFromEnv
          : _defaultChatServerPort;
    }

    _logger.i(
      'Connecting to Chat Server: $_chatServerIp:$_chatServerPort',
    );

    _chatViewModel.addListener(_scrollToBottom);
    _chatViewModel.addListener(_checkConnectionStatus);

    // 화면 시작 시 서버 연결 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryConnect();
      _checkConnectionStatus();
    });
  }

  @override
  void dispose() {
    _chatViewModel.removeListener(_scrollToBottom);
    _chatViewModel.removeListener(_checkConnectionStatus);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose(); // FocusNode dispose 추가
    super.dispose();
  }

  /// 서버 연결을 시도하는 메서드
  void _tryConnect() {
    _chatViewModel.connect(
      _chatServerIp,
      _chatServerPort,
      useSecure: _useSecureWebSocket,
    );
  }

  /// 메시지 목록의 맨 아래로 스크롤한다.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 연결 상태를 확인하고 필요시 닉네임 설정 다이얼로그를 표시한다.
  void _checkConnectionStatus() {
    if (mounted &&
        _chatViewModel.connectionStatus == ChatConnectionStatus.connected &&
        !_hasShownNicknameDialog &&
        _chatViewModel.nickname == null) {
      _hasShownNicknameDialog = true;
      Future.microtask(() {
        if (mounted) {
          _showNicknameDialog();
        }
      });
    }
  }

  /// 닉네임 설정 다이얼로그를 표시한다.
  Future<void> _showNicknameDialog() async {
    final TextEditingController nicknameController =
        TextEditingController(text: _chatViewModel.nickname);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('닉네임 설정'),
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              hintText: '사용할 닉네임을 입력하세요',
              labelText: '닉네임',
            ),
            autofocus: true,
            maxLength: 20,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                final nickname = nicknameController.text.trim();
                if (nickname.isNotEmpty) {
                  _chatViewModel.changeNickname(nickname);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 입력된 텍스트 메시지를 서버로 전송한다.
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _chatViewModel.sendMessage(message);
      _messageController.clear();
      // 메시지 전송 후에도 입력창에 포커스를 유지합니다.
      _messageFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatViewModel = context.watch<ChatViewModel>();

    if (chatViewModel.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showApiErrorDialog(context, message: chatViewModel.errorMessage!);
          chatViewModel.clearErrorMessage();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatViewModel.nickname != null
            ? '채팅 - ${_chatViewModel.nickname}'
            : '채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '닉네임 변경',
            onPressed: _chatViewModel.connectionStatus ==
                    ChatConnectionStatus.connected
                ? () => _showNicknameDialog()
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              chatViewModel.connectionStatus == ChatConnectionStatus.connected
                  ? Icons.wifi
                  : Icons.wifi_off,
              color: chatViewModel.connectionStatus ==
                      ChatConnectionStatus.connected
                  ? Colors.green
                  : Colors.red,
            ),
          ),
        ],
      ),
      body: _buildBody(chatViewModel),
    );
  }

  Widget _buildBody(ChatViewModel chatViewModel) {
    switch (chatViewModel.connectionStatus) {
      case ChatConnectionStatus.disconnected:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('서버와 연결이 끊겼습니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _tryConnect,
                child: const Text('재연결'),
              ),
            ],
          ),
        );
      case ChatConnectionStatus.connecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('서버에 연결 중입니다...'),
            ],
          ),
        );
      case ChatConnectionStatus.connected:
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: chatViewModel.messages.length,
                itemBuilder: (context, index) {
                  final message = chatViewModel.messages[index];
                  return ChatMessageWidget(message: message);
                },
              ),
            ),
            const Divider(height: 1.0),
            _buildInputArea(),
          ],
        );
      default:
        return const Center(child: Text('알 수 없는 오류가 발생했습니다.'));
    }
  }

  /// 메시지 입력 및 전송 버튼이 있는 하단 영역을 빌드합니다.
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode, // FocusNode 연결
                maxLines: 1, // 한 줄 입력만 허용
                textInputAction: TextInputAction.send, // 키보드 액션을 '전송'으로 설정
                decoration: const InputDecoration(
                  hintText: '메시지 입력...',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) {
                  _sendMessage(); // 엔터 키를 누르면 메시지 전송
                },
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
              tooltip: '메시지 전송',
            ),
          ],
        ),
      ),
    );
  }
}
