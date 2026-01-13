import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';

void main() {
  runApp(const ZeroTrustApp());
}

class ZeroTrustApp extends StatelessWidget {
  const ZeroTrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const ChatPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ServerSocket? _server;
  Socket? _connection;
  String name = "";
  String peerName = "???";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConnection());
  }

  void _initConnection() async {
    final mode = await _askInput(context, 'Select mode') ?? '';
    name = await _askInput(context, 'Enter your pseudonym') ?? '';
    final ip =
        await _askInput(context, 'Enter server IP (tailnet or local)') ?? '';
    final portText =
        await _askInput(context, 'Enter server port (default 12002)') ??
        '12002';
    final port = int.tryParse(portText) ?? 12002;

    if (mode == 'server') {
      _server = await ServerSocket.bind(ip, port);
      _server!.listen((client) {
        _connection = client;
        client.listen((data) {
          final msg = String.fromCharCodes(data);
          if (peerName == "???") {
            peerName = msg;
            _connection!.write(name);
            _addMessage(
              "INFO",
              "$peerName joined the conversation",
              false,
              isInfo: true,
            );
          } else {
            _addMessage(peerName, msg, false);
          }
        });
      });
    } else {
      _connection = await Socket.connect(ip, port);
      _connection!.write(name);
      _connection!.listen((data) {
        final msg = String.fromCharCodes(data);
        if (peerName == "???") {
          peerName = msg;
          _addMessage(
            "INFO",
            "$peerName joined the conversation",
            false,
            isInfo: true,
          );
        } else {
          _addMessage(peerName, msg, false);
        }
      });
    }
  }

  void _sendMessage(String msg) {
    if (_connection != null && msg.trim().isNotEmpty) {
      _addMessage(name, msg, true);
      _connection!.write(msg);
      _controller.clear();
    }
  }

  void _addMessage(
    String sender,
    String msg,
    bool isMe, {
    bool isInfo = false,
  }) {
    final timestamp = DateFormat.Hm().format(DateTime.now());
    setState(() {
      _messages.add({
        'sender': sender,
        'msg': msg,
        'time': timestamp,
        'isMe': isMe,
        'isInfo': isInfo,
      });
    });
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 60,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<String?> _askInput(BuildContext context, String label) async {
    String? result;

    if (label.toLowerCase().contains("mode")) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(label, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () {
                  result = "server";
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "Server",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  result = "client";
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "Client",
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          );
        },
      );
    } else {
      final inputController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(label, style: const TextStyle(color: Colors.white)),
            content: TextField(
              controller: inputController,
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  result = inputController.text;
                  Navigator.of(context).pop();
                },
                child: const Text("OK", style: TextStyle(color: Colors.blue)),
              ),
            ],
          );
        },
      );
    }

    return result;
  }

  void _exitApp() async {
    await _connection?.close();
    await _server?.close();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome on the Zerotrust Network.'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitApp,
            tooltip: "Exit Chat",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];

                if (msg['isInfo'] == true) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "[${msg['time']}] ${msg['msg']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: msg['isMe']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: msg['isMe']
                          ? Colors.blueAccent
                          : Colors.green[700],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(msg['isMe'] ? 12 : 0),
                        bottomRight: Radius.circular(msg['isMe'] ? 0 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['msg'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "[${msg['time']}]",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              onSubmitted: _sendMessage,
              decoration: const InputDecoration(
                labelText: 'Write something...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
