import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  List<_Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/messages/conversations');
      final list = (res['data'] as List? ?? []);
      if (mounted) {
        setState(() {
          _conversations = list.map((c) => _Conversation.fromJson(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: const BackButton(),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Erreur de chargement', style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkSubtext)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                  ]),
                )
              : _conversations.isEmpty
                  ? const Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('💬', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text('Aucune conversation', style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 16,
                          fontWeight: FontWeight.w700, color: AppColors.darkSubtext)),
                        SizedBox(height: 6),
                        Text('Vos échanges avec les livreurs apparaîtront ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 72, color: AppColors.darkBorder),
                        itemBuilder: (_, i) => _ConversationTile(
                          conv: _conversations[i],
                          onTap: () => context.push('/chat/${_conversations[i].orderId}'),
                        ),
                      ),
                    ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final _Conversation conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withOpacity(0.15),
        backgroundImage: conv.otherAvatar != null ? NetworkImage(conv.otherAvatar!) : null,
        child: conv.otherAvatar == null
            ? Text(
                conv.otherName.isNotEmpty ? conv.otherName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                  color: AppColors.primary, fontSize: 18),
              )
            : null,
      ),
      title: Row(children: [
        Expanded(
          child: Text(conv.otherName,
            style: TextStyle(
              fontFamily: 'Nunito', fontSize: 14,
              fontWeight: conv.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.darkText),
            overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(_formatTime(conv.lastMessageAt),
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkSubtext)),
      ]),
      subtitle: Row(children: [
        Expanded(
          child: Text(conv.lastMessageContent,
            style: TextStyle(
              fontFamily: 'Nunito', fontSize: 13,
              fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
              color: conv.unreadCount > 0 ? AppColors.darkText : AppColors.darkSubtext),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        ),
        if (conv.unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${conv.unreadCount > 99 ? '99+' : conv.unreadCount}',
              style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 11,
                fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ]),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _Conversation {
  final String conversationId;
  final String orderId;
  final String otherName;
  final String? otherAvatar;
  final String lastMessageContent;
  final DateTime lastMessageAt;
  final int unreadCount;

  _Conversation({
    required this.conversationId,
    required this.orderId,
    required this.otherName,
    this.otherAvatar,
    required this.lastMessageContent,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory _Conversation.fromJson(Map<String, dynamic> j) {
    final last = j['lastMessage'] as Map<String, dynamic>? ?? {};
    return _Conversation(
      conversationId: j['conversationId'] as String? ?? '',
      orderId: j['orderId'] as String? ?? '',
      otherName: j['otherName'] as String? ?? 'Inconnu',
      otherAvatar: j['otherAvatar'] as String?,
      lastMessageContent: last['content'] as String? ?? '',
      lastMessageAt: last['createdAt'] != null
          ? DateTime.tryParse(last['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: j['unreadCount'] as int? ?? 0,
    );
  }
}
