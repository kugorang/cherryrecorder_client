import 'dart:io' show Platform; // Platform 확인
import 'package:flutter/foundation.dart'; // kIsWeb, kDebugMode 확인
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_view_model.dart';
import '../widgets/chat_message_widget.dart';
import 'package:logger/logger.dart'; // Logger import 추가

/// 실시간 채팅 기능을 제공하는 화면 위젯.
class ChatScreen extends StatefulWidget {
  /// 기본 생성자.
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// [ChatScreen]의 상태 관리 클래스.
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late ChatViewModel _chatViewModel; // initState에서 Provider를 통해 초기화
  final _logger = Logger(); // Logger 인스턴스 추가

  // --- 서버 주소 및 포트 설정 (dart-define 사용) ---
  // 서버 IP는 런타임에 플랫폼을 확인해야 하므로 final로 선언
  late final String _chatServerIp;
  static const int _chatServerPort = int.fromEnvironment(
    'CHAT_SERVER_PORT',
    defaultValue: 33334,
  );
  // ------------------------------------------------

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();

    // initState에서 플랫폼별 IP 설정
    _chatServerIp = String.fromEnvironment(
      'CHAT_SERVER_IP',
      // 웹이면 localhost, 아니면 Android인지 확인하여 10.0.2.2 또는 localhost
      defaultValue:
          kIsWeb
              ? 'localhost'
              : (Platform.isAndroid ? '10.0.2.2' : 'localhost'),
    );

    _logger.i(
      'Connecting to Chat Server: $_chatServerIp:$_chatServerPort',
    ); // 로그 추가

    // 화면 시작 시 서버 연결 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatViewModel.connect(_chatServerIp, _chatServerPort);
    });

    // 메시지 목록 변경 시 자동으로 맨 아래로 스크롤
    _chatViewModel.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    // 화면 종료 시 ViewModel 리스너 제거 및 연결 해제
    _chatViewModel.removeListener(_scrollToBottom);
    // 필요 시 연결 해제 로직 추가 (앱 전체 연결 유지가 아니라면)
    // _chatViewModel.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  /// 입력된 텍스트 메시지를 서버로 전송한다.
  void _sendMessage() {
    if (_textController.text.isNotEmpty) {
      _chatViewModel.sendMessage(_textController.text);
      _textController.clear(); // 입력창 비우기
      _focusNode.requestFocus(); // 전송 후에도 키보드 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    // ViewModel 상태 변화 감지
    final chatViewModel = context.watch<ChatViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        // 연결 상태 표시 (선택적)
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              // isConnected -> connectionStatus 체크
              chatViewModel.connectionStatus == ChatConnectionStatus.connected
                  ? Icons.wifi
                  : Icons.wifi_off,
              // isConnected -> connectionStatus 체크
              color:
                  chatViewModel.connectionStatus ==
                          ChatConnectionStatus.connected
                      ? Colors.green
                      : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
          // 오류 메시지 표시
          if (chatViewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chatViewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          // 메시지 입력 영역
          _buildMessageInputArea(),
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
                controller: _textController,
                focusNode: _focusNode,
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
              onPressed:
                  chatViewModel.connectionStatus ==
                          ChatConnectionStatus.connected
                      ? _sendMessage
                      : null,
              color:
                  chatViewModel.connectionStatus ==
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
