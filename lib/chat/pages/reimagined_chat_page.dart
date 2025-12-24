import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';

class ReimaginedChatPage extends StatelessWidget {
  const ReimaginedChatPage({super.key});

  static const _warmCharcoal = Color(0xFF1C1917);
  static const _warmSurface = Color(0xFF292524);
  static const _warmIvory = Color(0xFFFAFAF9);
  static const _warmAmber = Color(0xFFF59E0B);
  static const _warmMuted = Color(0xFFA8A29E);
  static const _userMessageBg = Color(0xFF3D3835);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _warmAmber,
          brightness: Brightness.dark,
        ).copyWith(
          surface: _warmCharcoal,
          onSurface: _warmIvory,
        ),
        scaffoldBackgroundColor: _warmCharcoal,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_warmCharcoal, Color(0xFF171412)],
              stops: [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _ChatHeader(),
                const Expanded(child: _ChatMessagesList()),
                _ChatInputField(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: ReimaginedChatPage._warmIvory,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversation',
                  style: GoogleFonts.lora(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: ReimaginedChatPage._warmIvory,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'with your personal assistant',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: ReimaginedChatPage._warmMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: ReimaginedChatPage._warmAmber,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _ChatMessagesList extends StatefulWidget {
  const _ChatMessagesList();

  @override
  State<_ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<_ChatMessagesList> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _animatedMessageIds = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: 300.ms,
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  bool _shouldShowThinkingIndicator(ChatState state) {
    if (!state.isLoading) return false;
    return state.streamingMessageId == null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (previous, current) => previous.messages.length < current.messages.length,
      listener: (context, state) => _scrollToBottom(),
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          final messages = state.messages;
          final showThinking = _shouldShowThinkingIndicator(state);

          if (messages.isEmpty && !showThinking) {
            return _EmptyState();
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: messages.length + (showThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && showThinking) {
                return _ReimaginedThinkingIndicator();
              }

              final message = messages[index];
              final isStreaming = message.id == state.streamingMessageId;
              final shouldAnimate = !_animatedMessageIds.contains(message.id);

              if (shouldAnimate) {
                _animatedMessageIds.add(message.id);
              }

              return _MessageItem(
                message: message,
                isStreaming: isStreaming,
                shouldAnimate: shouldAnimate,
                index: index,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(
                color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.4),
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: ReimaginedChatPage._warmMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about your logged entries',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 600.ms);
  }
}

class _MessageItem extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final bool shouldAnimate;
  final int index;

  const _MessageItem({
    required this.message,
    required this.isStreaming,
    required this.shouldAnimate,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;
    final timeFormatter = DateFormat('h:mm a');

    Widget messageWidget = isUser
        ? _UserMessage(message: message, timeFormatter: timeFormatter)
        : _AiMessage(message: message, timeFormatter: timeFormatter, isStreaming: isStreaming);

    if (shouldAnimate) {
      messageWidget = messageWidget
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(
            begin: isUser ? 0.1 : -0.05,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOut,
          );
    }

    return messageWidget;
  }
}

class _UserMessage extends StatelessWidget {
  final ChatMessage message;
  final DateFormat timeFormatter;

  const _UserMessage({required this.message, required this.timeFormatter});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: ReimaginedChatPage._userMessageBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.lora(
                fontSize: 18,
                height: 1.7,
                color: ReimaginedChatPage._warmIvory,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeFormatter.format(message.timestamp),
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessage extends StatelessWidget {
  final ChatMessage message;
  final DateFormat timeFormatter;
  final bool isStreaming;

  const _AiMessage({
    required this.message,
    required this.timeFormatter,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: ReimaginedChatPage._warmAmber.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ASSISTANT',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: ReimaginedChatPage._warmAmber.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
              if (isStreaming) ...[
                const SizedBox(width: 8),
                _StreamingDot(),
              ],
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: message.text,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.lora(
                fontSize: 18,
                height: 1.7,
                color: ReimaginedChatPage._warmIvory.withValues(alpha: 0.95),
                fontWeight: FontWeight.w400,
              ),
              strong: GoogleFonts.lora(
                fontSize: 18,
                height: 1.7,
                color: ReimaginedChatPage._warmIvory,
                fontWeight: FontWeight.w700,
              ),
              em: GoogleFonts.lora(
                fontSize: 18,
                height: 1.7,
                color: ReimaginedChatPage._warmIvory.withValues(alpha: 0.95),
                fontStyle: FontStyle.italic,
              ),
              code: GoogleFonts.spaceMono(
                fontSize: 14,
                color: ReimaginedChatPage._warmAmber,
                backgroundColor: ReimaginedChatPage._warmSurface,
              ),
              codeblockDecoration: BoxDecoration(
                color: ReimaginedChatPage._warmSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              listBullet: GoogleFonts.lora(
                fontSize: 18,
                color: ReimaginedChatPage._warmAmber,
              ),
              h1: GoogleFonts.lora(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: ReimaginedChatPage._warmIvory,
              ),
              h2: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: ReimaginedChatPage._warmIvory,
              ),
              h3: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ReimaginedChatPage._warmIvory,
              ),
            ),
          ),
          if (!isStreaming) ...[
            const SizedBox(height: 12),
            Text(
              timeFormatter.format(message.timestamp),
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreamingDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: ReimaginedChatPage._warmAmber,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fadeIn(duration: 600.ms)
        .then()
        .fadeOut(duration: 600.ms);
  }
}

class _ReimaginedThinkingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: ReimaginedChatPage._warmAmber.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .fadeIn(duration: 600.ms)
          .then()
          .fadeOut(duration: 600.ms),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ChatInputField extends StatefulWidget {
  @override
  State<_ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<_ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChatCubit>().addUserMessageStreaming(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ReimaginedChatPage._warmCharcoal.withValues(alpha: 0),
            ReimaginedChatPage._warmCharcoal,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: ReimaginedChatPage._warmSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _focusNode.hasFocus
                ? ReimaginedChatPage._warmAmber.withValues(alpha: 0.3)
                : ReimaginedChatPage._warmMuted.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.lora(
                  fontSize: 18,
                  color: ReimaginedChatPage._warmIvory,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask anything about your entries...',
                  hintStyle: GoogleFonts.lora(
                    fontSize: 18,
                    color: ReimaginedChatPage._warmMuted.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSubmit(),
                onTap: () => setState(() {}),
                onTapOutside: (_) {
                  _focusNode.unfocus();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _hasText ? _handleSubmit : null,
              child: AnimatedContainer(
                duration: 200.ms,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hasText
                      ? ReimaginedChatPage._warmAmber
                      : ReimaginedChatPage._warmMuted.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward,
                  size: 20,
                  color: _hasText
                      ? ReimaginedChatPage._warmCharcoal
                      : ReimaginedChatPage._warmMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
