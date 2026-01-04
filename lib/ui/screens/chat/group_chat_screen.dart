import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();

  final _messages = <_ChatMessage>[...
    const [
      _ChatMessage(
        isMe: false,
        sender: 'Admin',
        text: 'Welcome to your Equb group chat. Keep messages respectful.',
        time: '09:12',
      ),
      _ChatMessage(
        isMe: true,
        sender: 'You',
        text: 'Got it. When is the next round?',
        time: '09:13',
      ),
      _ChatMessage(
        isMe: false,
        sender: 'Sara',
        text: 'Next round is on Friday. Please confirm your contribution.',
        time: '09:14',
      ),
    ],
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(isMe: true, sender: 'You', text: text, time: 'Now'),
      );
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            child: ListView.builder(
              padding: AppSpacing.pagePaddingMobile,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: m.isMe ? scheme.primary : scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: m.isMe
                          ? null
                          : Border.all(color: scheme.outline.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.sender,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: m.isMe ? scheme.onPrimary : scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: m.isMe ? scheme.onPrimary : scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.time,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: (m.isMe ? scheme.onPrimary : scheme.onSurface)
                                    .withOpacity(0.75),
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                    onPressed: _send,
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
}

class _ChatMessage {
  const _ChatMessage({
    required this.isMe,
    required this.sender,
    required this.text,
    required this.time,
  });

  final bool isMe;
  final String sender;
  final String text;
  final String time;
}
