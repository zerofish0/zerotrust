import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7FC9F9),
          secondary: Color(0xFF14FFEC),
          surface: Color(0xFF1A1F2B),
        ),
        textTheme: GoogleFonts.orbitronTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1F2633),
          labelStyle: TextStyle(color: Color(0xFF4EC6F9)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1F2B),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Color(0xFF14FFEC),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF14FFEC)),
        splashColor: Color(0xFF14FFEC),
      ),
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

    _addMessage(
      "INFO",
      "You are $name operating as $mode on $ip:$port",
      false,
      isInfo: true,
    );

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

  void _sendMessage() {
    final msg = _controller.text;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
        title: const Text('ZeroTrust Chat'),
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _exitApp),
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
                          shadows: [Shadow(color: Colors.black, blurRadius: 1)],
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
                      vertical: 6,
                      horizontal: 12,
                    ),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      gradient: msg['isMe']
                          ? const LinearGradient(
                              colors: [Color(0xFF00ACDA), Color(0xFF00799a)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: msg['isMe'] ? null : const Color(0xFF1F2B3A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (msg['isMe'])
                          BoxShadow(
                            color: const Color(0xFF14FFEC).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['msg'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "[${msg['time']}]",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white60,
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Write something...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
