import 'package:chat_gemini/provider/chat_provider.dart';
import 'package:chat_gemini/widget/buttom_chat_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _State();
}

class _State extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return SafeArea(
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              title: const Text('Chat with Gemini'),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child:
                        chatProvider.inChatMessages.isEmpty
                            ? const Center(
                              child: Text('No messages yet. Start chatting!'),
                            )
                            : ListView.builder(
                              itemCount: chatProvider.inChatMessages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    chatProvider.inChatMessages[index];
                                return ListTile(
                                  title: Text(message.message.toString()),
                                );
                              },
                            ),
                  ),
                  BottomChatField(chatProvider: chatProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
