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

  // --- 서버 주소 및 포트 설정 (dart-define 사용) ---
  // compile-time constant로 선언
  static const String _chatServerIpFromEnv = String.fromEnvironment(
    'CHAT_SERVER_IP',
    defaultValue: '',
  );

  // 실제 사용할 서버 IP (runtime에 결정)
  late final String _chatServerIp;

  static const int _chatServerPort = int.fromEnvironment(
    'CHAT_SERVER_PORT',
    defaultValue: 33334, // WS 포트 (기본값)
  );

  static const bool _useSecureWebSocket = bool.fromEnvironment(
    'USE_WSS',
    defaultValue: false, // 개발 환경에서는 기본적으로 WS 사용 (프로덕션에서는 true로 설정)
  );
  // ------------------------------------------------

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();

    // 환경 변수가 설정되어 있으면 사용, 아니면 플랫폼별 기본값 사용
    if (_chatServerIpFromEnv.isNotEmpty) {
      _chatServerIp = _chatServerIpFromEnv;
    } else {
      // 플랫폼별 기본 IP 설정
      if (kIsWeb) {
        _chatServerIp = 'localhost';
      } else {
        // 네이티브 플랫폼에서만 Platform 클래스 사용
        try {
          _chatServerIp = Platform.isAndroid ? '10.0.2.2' : 'localhost';
        } catch (e) {
          // Platform 사용 실패 시 기본값
          _chatServerIp = 'localhost';
        }
      }
    }

    _logger.i(
      'Connecting to Chat Server: $_chatServerIp:$_chatServerPort',
    ); // 로그 추가

    _chatViewModel.addListener(_scrollToBottom);
    _chatViewModel.addListener(_checkConnectionStatus);

    // 화면 시작 시 서버 연결 시도 및 현재 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chatViewModel.connect(_chatServerIp, _chatServerPort,
          useSecure: _useSecureWebSocket);
      _checkConnectionStatus(); // 재진입 시 이미 연결된 상태일 수 있으므로 즉시 확인
    });
  }

  @override
  void dispose() {
    // 화면 종료 시 ViewModel 리스너 제거
    _chatViewModel.removeListener(_scrollToBottom);
    _chatViewModel.removeListener(_checkConnectionStatus);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 메시지 목록의 맨 아래로 스크롤한다.
  void _scrollToBottom() {
    // 약간의 딜레이 후 스크롤해야 최신 메시지가 렌더링된 후 이동됨
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
    // 위젯이 아직 마운트 상태이고, 연결되었으며, 다이얼로그가 표시된 적 없고, 닉네임이 없을 때
    if (mounted &&
        _chatViewModel.connectionStatus == ChatConnectionStatus.connected &&
        !_hasShownNicknameDialog &&
        _chatViewModel.nickname == null) {
      _hasShownNicknameDialog = true; // 다이얼로그가 표시되었음을 기록
      // build life-cycle 중에 UI를 업데이트하지 않도록 microtask로 예약
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
      barrierDismissible: false, // 다이얼로그 밖 클릭으로 닫기 비활성화
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
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pop(); // 채팅 화면 닫고 맵으로 돌아가기
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
      _messageController.clear(); // 입력창 비우기
    }
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 변화 감지
    final chatViewModel = context.watch<ChatViewModel>();

    // 오류 발생 시 다이얼로그 표시
    if (chatViewModel.errorMessage != null) {
      // 위젯 빌드가 완료된 후에 다이얼로그를 표시하기 위해 addPostFrameCallback 사용
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showApiErrorDialog(context, message: chatViewModel.errorMessage!);
          // 다이얼로그가 다시 표시되지 않도록 ViewModel의 오류 상태를 초기화
          chatViewModel.clearErrorMessage();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatViewModel.nickname != null
            ? '채팅 - ${_chatViewModel.nickname}'
            : '채팅'),
        // 연결 상태 표시 (선택적)
        actions: [
          // 닉네임 변경 버튼
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
              // isConnected -> connectionStatus 체크
              chatViewModel.connectionStatus == ChatConnectionStatus.connected
                  ? Icons.wifi
                  : Icons.wifi_off,
              // isConnected -> connectionStatus 체크
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
          // 연결 상태 배너
          _buildConnectionStatusBanner(),
          // 메시지 목록 영역
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: chatViewModel.messages.length,
              itemBuilder: (context, index) {
                final message = chatViewModel.messages[index];
                // 각 메시지를 ChatMessageWidget으로 표시
                return ChatMessageWidget(
                  message: message,
                  // currentUserNickname prop 제거 (isMine 사용)
                );
              },
            ),
          ),
          // 로딩 인디케이터 (연결 중)
          // isConnecting -> connectionStatus 체크
          if (chatViewModel.connectionStatus == ChatConnectionStatus.connecting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(),
            ),
          // 메시지 입력 영역
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  /// 연결 상태를 표시하는 배너 위젯 빌드.
  Widget _buildConnectionStatusBanner() {
    final chatViewModel = context.watch<ChatViewModel>();

    if (chatViewModel.connectionStatus == ChatConnectionStatus.connected) {
      return const SizedBox.shrink(); // 연결된 경우 배너 숨김
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
              onPressed: () {
                _chatViewModel.connect(_chatServerIp, _chatServerPort,
                    useSecure: _useSecureWebSocket);
              },
              child: const Text('재연결'),
            ),
        ],
      ),
    );
  }

  /// 하단 메시지 입력 영역 위젯 빌드.
  Widget _buildMessageInputArea() {
    // ViewModel 상태 변화 감지 (버튼 활성화 등에 사용)
    final chatViewModel = context.watch<ChatViewModel>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: SafeArea(
        child: Row(
          children: [
            // 텍스트 입력 필드
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration.collapsed(
                  hintText: '메시지 입력...',
                ),
                textInputAction: TextInputAction.send, // 키보드 엔터키 '보내기'로 변경
                onSubmitted: (_) => _sendMessage(), // 엔터 입력 시 메시지 전송
                maxLines: null, // 여러 줄 입력 가능
              ),
            ),
            // 전송 버튼 (연결되었을 때만 활성화)
            IconButton(
              icon: const Icon(Icons.send),
              // 연결 상태 확인하여 버튼 활성화/비활성화
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
