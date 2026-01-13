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
  final List<String> _infoLines = [
    "###[ZeroTrust Chat App]###",
    " - Never trust anyone",
    "===[Initialization]===",
  ];

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

    _addInfo("Enter your name (leave blank for random): $name");
    _addInfo("Enter mode (client/server): $mode");
    _addInfo("Enter server IP (leave blank for local): $ip");
    _addInfo("Enter server port (default : 12002): $port");
    _addInfo("Initialization complete");
    _addInfo("===[Starting]===");

    if (mode == 'server') {
      _server = await ServerSocket.bind(ip, port);
      _addInfo("[*] The server : $name is listening on $ip:$port");
      _server!.listen((client) {
        _connection = client;
        _addInfo(
          "[+] Connection from ${client.remoteAddress.address}:${client.remotePort} accepted",
        );
        client.listen((data) {
          final msg = String.fromCharCodes(data);
          if (peerName == "???") {
            peerName = msg;
            _addInfo("[+] Client identified as $peerName");
            _addInfo("[*] Authenticating ourselves...");
            _connection!.write(name);
            _addInfo("[+] Authentication successful, conversation can start");
            _addMessage("INFO", "$peerName joined the conversation", true);
            _addInfo("==============================");
          } else {
            _addMessage("$peerName", msg, false);
          }
        });
      });
    } else {
      _connection = await Socket.connect(ip, port);
      _addInfo("[+] Client : $name connected to $ip:$port");
      _addInfo("[*] Authenticating ourselves...");
      _connection!.write(name);
      _connection!.listen((data) {
        final msg = String.fromCharCodes(data);
        if (peerName == "???") {
          peerName = msg;
          _addInfo("[+] Server identified as $peerName");
          _addInfo("[+] Authentication successful, conversation can start");
          _addMessage("INFO", "$peerName joined the conversation", true);
          _addInfo("==============================");
        } else {
          _addMessage("$peerName", msg, false);
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

  void _addMessage(String sender, String msg, bool isMe) {
    final timestamp = DateFormat.Hm().format(DateTime.now());
    setState(() {
      _messages.add({
        'sender': sender,
        'msg': msg,
        'time': timestamp,
        'isMe': isMe,
      });
    });
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 60,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _addInfo(String line) {
    setState(() {
      _infoLines.add(line);
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
        title: const Text('Welcome on the Zerotrust Network.'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitApp,
            tooltip: "Exit Chat",
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          "[${msg['time']}] ${msg['sender']}: ${msg['msg']}",
                          style: TextStyle(
                            color: msg['isMe']
                                ? Colors.lightBlueAccent
                                : Colors.greenAccent,
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
          ),
          Container(
            width: 300,
            color: Colors.grey[850],
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _infoLines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
