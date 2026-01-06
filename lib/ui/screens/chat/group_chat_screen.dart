import 'dart:async';

import 'package:equb/models/chat_message.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      _updateTypingStatus(hasText);
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_isTyping == isTyping) return;

    _isTyping = isTyping;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final chatService = ref.read(chatServiceProvider);
    chatService.updateTypingStatus(
      groupId: widget.groupId,
      userId: user.id,
      userName: user.name,
      isTyping: isTyping,
    );

    // Auto-stop typing after 3 seconds of inactivity
    if (isTyping) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isTyping) {
          _updateTypingStatus(false);
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        groupId: widget.groupId,
        senderId: user.id,
        senderName: user.name,
        content: text,
      );

      _controller.clear();
      _updateTypingStatus(false);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final messagesAsync = ref.watch(groupChatMessagesProvider(widget.groupId));
    final typingUsersAsync = ref.watch(groupTypingStatusProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group chat'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Group info',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: AppSpacing.pagePaddingMobile,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = currentUser != null && message.senderId == currentUser.id;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isMe ? scheme.primary : scheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: isMe
                                ? null
                                : Border.all(color: scheme.outline.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!message.isSystem)
                                Text(
                                  message.senderName,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: isMe ? scheme.onPrimary : scheme.onSurface,
                                      ),
                                ),
                              if (!message.isSystem) const SizedBox(height: 6),
                              Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isMe ? scheme.onPrimary : scheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTimestamp(message.timestamp),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: (isMe ? scheme.onPrimary : scheme.onSurface)
                                          .withOpacity(0.75),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Typing indicator
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: typingUsersAsync.when(
                      data: (typingUsers) {
                        final currentUserId = currentUser?.id;
                        final otherTypingUsers = typingUsers.entries
                            .where((entry) => entry.key != currentUserId)
                            .toList();

                        if (otherTypingUsers.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final typingNames = otherTypingUsers.map((e) => e.value).join(', ');
                        final isPlural = otherTypingUsers.length > 1;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: scheme.surface.withOpacity(0.9),
                          child: Text(
                            '$typingNames ${isPlural ? 'are' : 'is'} typing...',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load messages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(groupChatMessagesProvider(widget.groupId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _controller.text.trim().isEmpty ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else if (difference.inDays < 7) {
      // This week - show day and time
      return DateFormat('E HH:mm').format(timestamp);
    } else {
      // Older - show date and time
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}

