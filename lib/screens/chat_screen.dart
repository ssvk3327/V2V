import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  late final BluetoothService _bluetoothService;
  late final Stream<String> _messageStream;
  late final StreamSubscription<String> _msgSub;

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _messageStream = _bluetoothService.messages;
    _msgSub = _messageStream.listen((msg) {
      setState(() {
        _messages.add(msg);
      });
    });
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      await _bluetoothService.sendMessage(_controller.text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _msgSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_messages[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Enter message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 