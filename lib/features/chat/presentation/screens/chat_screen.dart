import 'dart:async';
import 'dart:io' show Platform; // Platform import

import 'package:cherryrecorder_client/core/utils/dialog_utils.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, kDebugMode import
import 'package:flutter/material.dart';
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
  final _logger = Logger(); // Logger 인스턴스 추가

  bool _hasShownNicknameDialog = false; // 닉네임 다이얼로그 표시 여부

  // --- 서버 주소 및 포트 설정 ---
  static const String _chatServerUrlFromEnv = String.fromEnvironment(
    'CHAT_SERVER_IP', // 변수명이 IP이지만 URL 전체를 받을 수 있음
    defaultValue: '',
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
        // 포트 번호가 없으면 기본 포트 사용
        _chatServerPort = _defaultChatServerPort;
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
      _chatServerPort = _defaultChatServerPort;
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
    if (_messageController.text.isNotEmpty) {
      _chatViewModel.sendMessage(_messageController.text);
      _messageController.clear();
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
      body: Column(
        children: [
          _buildConnectionStatusBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: chatViewModel.messages.length,
              itemBuilder: (context, index) {
                final message = chatViewModel.messages[index];
                return ChatMessageWidget(
                  message: message,
                );
              },
            ),
          ),
          if (chatViewModel.connectionStatus == ChatConnectionStatus.connecting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(),
            ),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  /// 연결 상태를 표시하는 배너 위젯 빌드.
  Widget _buildConnectionStatusBanner() {
    final chatViewModel = context.watch<ChatViewModel>();

    if (chatViewModel.connectionStatus == ChatConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    String message;
    IconData icon;

    switch (chatViewModel.connectionStatus) {
      case ChatConnectionStatus.connecting:
        backgroundColor = Colors.orange.shade100;
        message = '서버에 연결 중...';
        icon = Icons.sync;
        break;
      case ChatConnectionStatus.disconnected:
        backgroundColor = Colors.grey.shade200;
        message = '연결되지 않음';
        icon = Icons.wifi_off;
        break;
      case ChatConnectionStatus.error:
        backgroundColor = Colors.red.shade100;
        message = chatViewModel.errorMessage ?? '연결 오류';
        icon = Icons.error_outline;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (chatViewModel.connectionStatus != ChatConnectionStatus.connecting)
            TextButton(
              onPressed: _tryConnect, // 재연결 시도
              child: const Text('재연결'),
            ),
        ],
      ),
    );
  }

  /// 하단 메시지 입력 영역 위젯 빌드.
  Widget _buildMessageInputArea() {
    final chatViewModel = context.watch<ChatViewModel>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration.collapsed(
                  hintText: '메시지 입력...',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: chatViewModel.connectionStatus ==
                      ChatConnectionStatus.connected
                  ? _sendMessage
                  : null,
              color: chatViewModel.connectionStatus ==
                      ChatConnectionStatus.connected
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
