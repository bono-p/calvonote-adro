import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  ÉCRAN OUTILS IA — Groq LLM
//  Actions rapides + Chat avec contexte
// ─────────────────────────────────────────────────────────────

class AiScreen extends StatefulWidget {
  final GroqService groqService;
  final String      initialText;

  const AiScreen({
    super.key,
    required this.groqService,
    required this.initialText,
  });

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _chatCtrl = TextEditingController();

  String _actionResult = '';
  String _activeAction = '';
  bool   _actionLoading = false;

  final List<_ChatMessage> _messages = [];
  bool   _chatLoading = false;
  final  _scrollCtrl  = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _runAction(String key) async {
    if (!widget.groqService.isConfigured) {
      _showError('Clé API Groq non configurée (Paramètres)');
      return;
    }

    setState(() {
      _actionLoading = true;
      _activeAction  = key;
      _actionResult  = '';
    });

    final r = await widget.groqService.runAction(key, widget.initialText);

    setState(() {
      _actionLoading = false;
      _actionResult  = r.success ? r.text : '❌ ${r.error}';
    });
  }

  // ── Chat ──────────────────────────────────────────────────────

  Future<void> _sendChat() async {
    final msg = _chatCtrl.text.trim();
    if (msg.isEmpty) return;

    if (!widget.groqService.isConfigured) {
      _showError('Clé API Groq non configurée (Paramètres)');
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: msg, isUser: true));
      _chatCtrl.clear();
      _chatLoading = true;
    });
    _scrollToBottom();

    final r = await widget.groqService.chat(
      msg,
      editorContext: widget.initialText,
    );

    setState(() {
      _chatLoading = false;
      _messages.add(_ChatMessage(
        text:   r.success ? r.text : '❌ ${r.error}',
        isUser: false,
        isError: !r.success,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Outils IA'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Actions rapides'),
            Tab(text: 'Chat IA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildActionsTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  // ── Onglet Actions ────────────────────────────────────────────

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Texte source
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEXTE SOURCE',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.initialText.length > 300
                      ? '${widget.initialText.substring(0, 300)}…'
                      : widget.initialText,
                  style: const TextStyle(
                    fontSize: 13, color: AppColors.text, height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Boutons actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAIActions.map((action) {
              final isActive = _activeAction == action.key && _actionLoading;
              return GestureDetector(
                onTap: _actionLoading ? null : () => _runAction(action.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _activeAction == action.key
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeAction == action.key
                          ? AppColors.accent
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent,
                          ),
                        )
                      else
                        Text(action.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        action.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: _activeAction == action.key
                              ? AppColors.accent
                              : AppColors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Résultat
          if (_actionResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'RÉSULTAT',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.accent, letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _actionResult));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Résultat copié'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _actionResult,
                    style: const TextStyle(
                      fontSize: 14, color: AppColors.text, height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Onglet Chat ───────────────────────────────────────────────

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Pose une question sur ton texte transcrit',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_chatLoading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(message: _messages[i]);
                  },
                ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Écris ton message…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
              onSubmitted: (_) => _sendChat(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _chatLoading ? null : _sendChat,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _chatLoading
                    ? AppColors.cardBorder
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _chatLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle de chat ─────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool   isUser;
  final bool   isError;
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.accent.withOpacity(0.2)
              : message.isError
                  ? AppColors.error.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14).copyWith(
            bottomRight: message.isUser
                ? const Radius.circular(4)
                : const Radius.circular(14),
            bottomLeft: message.isUser
                ? const Radius.circular(14)
                : const Radius.circular(4),
          ),
          border: Border.all(
            color: message.isUser
                ? AppColors.accent.withOpacity(0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: message.isError ? AppColors.error : AppColors.text,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          '⏳ Réflexion en cours…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
