import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'data_service.dart';

/// Chat privata di un evento: host + partecipanti approvati.
/// La visibilità è garantita dalle RLS su `messages` (inclusi i blocchi
/// utente), qui si gestisce solo la presentazione.
class ChatScreen extends StatefulWidget {
  final SupabaseEvent event;

  const ChatScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<ChatMessage>>? _subscription;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subscription = EcoraDataService.instance
        .messagesStream(widget.event.id)
        .listen((messages) {
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      _resolveSenderProfiles(messages);
      _scrollToBottom();
    }, onError: (e) {
      debugPrint("Errore stream chat: $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossibile caricare la chat. Riprova più tardi.";
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveSenderProfiles(List<ChatMessage> messages) async {
    final ids = messages.map((m) => m.senderId).toSet().toList();
    await EcoraDataService.instance.fetchProfilesByIds(ids);
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error =
        await EcoraDataService.instance.sendMessage(widget.event.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: slateSurface,
        iconTheme: const IconThemeData(color: premiumGold),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CHAT EVENTO",
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
                color: premiumGold,
              ),
            ),
            Text(
              widget.event.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: premiumGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textSecondary),
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum, color: premiumGold, size: 48),
              SizedBox(height: 16),
              Text(
                "Nessun messaggio ancora.\nRompi il ghiaccio con discrezione.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final myId = EcoraDataService.instance.currentProfileNotifier.value?.id;
    final bool isMine = message.senderId == myId;
    final sender =
        EcoraDataService.instance.getProfileById(message.senderId);
    final String senderName = sender?.fullName ?? "Utente";
    final created = message.createdAt;
    final String time = created == null
        ? ""
        : "${created.hour.toString().padLeft(2, '0')}:"
            "${created.minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? premiumGold.withValues(alpha: 0.15)
              : slateSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: Border.all(
            color: isMine
                ? premiumGold.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: premiumGold,
                  ),
                ),
              ),
            Text(
              message.content,
              style: const TextStyle(
                  color: textPrimary, fontSize: 14, height: 1.4),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time,
                  style:
                      const TextStyle(fontSize: 10, color: textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: slateSurface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 1,
              maxLength: 1000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                counterText: "",
                hintText: "Scrivi un messaggio…",
                hintStyle:
                    const TextStyle(color: textSecondary, fontSize: 14),
                filled: true,
                fillColor: matteDark,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: premiumGold,
              disabledBackgroundColor:
                  premiumGold.withValues(alpha: 0.3),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.send, color: Colors.black, size: 20),
          ),
        ],
      ),
    );
  }
}
