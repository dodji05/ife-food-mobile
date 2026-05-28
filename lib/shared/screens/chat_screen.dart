import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// Écran de chat générique utilisé par le client, le livreur et le professionnel.
/// [title] : titre affiché dans l'AppBar (ex: "Messagerie commande").
class ChatScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String title;
  const ChatScreen({super.key, required this.orderId, this.title = 'Messagerie'});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  io.Socket? _socket;
  final _msgCtrl  = TextEditingController();
  final _scroll   = ScrollController();
  final List<_Msg> _messages = [];
  bool _loadingHistory = true;
  bool _sending = false;

  String get _convId => 'order_${widget.orderId}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiClient.instance.get('/messages/$_convId');
      final list = (res['data'] as List? ?? []);
      if (mounted) {
        setState(() {
          _messages.addAll(list.map((m) => _Msg.fromJson(m)));
          _loadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _connectSocket() {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      '${AppConstants.wsUrl}/messages',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join', {'conversationId': _convId});
    });

    _socket!.on('message', (data) {
      if (!mounted) return;
      final msg = _Msg.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });

    _socket!.connect();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      _socket?.emit('send', {'conversationId': _convId, 'content': text});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authProvider).user?.id;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(widget.title),
        leading: const BackButton(),
      ),
      body: Column(children: [
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun message pour cette commande.',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: _messages[i],
                        isMine: _messages[i].senderId == myId,
                      ),
                    ),
        ),
        _InputBar(ctrl: _msgCtrl, sending: _sending, onSend: _send),
      ]),
    );
  }
}

class _Msg {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  _Msg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory _Msg.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] as Map<String, dynamic>? ?? {};
    final firstName = sender['firstName'] as String? ?? '';
    final name      = sender['name']      as String? ?? '';
    final fullName  = [firstName, name].where((s) => s.isNotEmpty).join(' ').trim();
    return _Msg(
      id:         j['id'] as String? ?? '',
      senderId:   j['senderId'] as String? ?? '',
      senderName: fullName.isEmpty ? 'Inconnu' : fullName,
      content:    j['content'] as String? ?? '',
      createdAt:  j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  final bool isMine;
  const _MessageBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.darkCard,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                msg.senderName,
                style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 11,
                  fontWeight: FontWeight.w800, color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              msg.content,
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 14,
                color: isMine ? Colors.white : AppColors.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.createdAt),
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 10,
                color: isMine ? Colors.white60 : AppColors.darkSubtext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText),
              decoration: InputDecoration(
                hintText: 'Votre message…',
                hintStyle: const TextStyle(fontFamily: 'Nunito', color: AppColors.darkSubtext),
                filled: true,
                fillColor: AppColors.darkBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: sending ? AppColors.darkBorder : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}
