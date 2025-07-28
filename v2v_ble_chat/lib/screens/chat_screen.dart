import 'package:flutter/material.dart';
import 'dart:async';
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
  late final StreamSubscription<String> _msgSub;
  late final StreamSubscription<double> _rangeSub;
  late final StreamSubscription<bool> _connectionSub;
  
  double _currentRange = 0.0;
  bool _isInRange = false;

  @override
  void initState() {
    super.initState();
    _bluetoothService = BluetoothService();
    _bluetoothService.startAdvertising();
    _bluetoothService.startScanning();
    
    // Listen to messages
    _msgSub = _bluetoothService.messages.listen((msg) {
      setState(() {
        _messages.add(msg);
      });
    });
    
    // Listen to range updates
    _rangeSub = _bluetoothService.range.listen((range) {
      setState(() {
        _currentRange = range;
      });
    });
    
    // Listen to connection status
    _connectionSub = _bluetoothService.connectionStatus.listen((connected) {
      setState(() {
        _isInRange = connected;
      });
    });
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      await _bluetoothService.sendMessage(_controller.text);
      _controller.clear();
    }
  }

  void _sendSafetyAlert(String alertType) async {
    await _bluetoothService.sendSafetyAlert(alertType);
  }

  String _getSignalStrength() {
    if (_currentRange <= 30) return 'Excellent';
    if (_currentRange <= 50) return 'Good';
    if (_currentRange <= 70) return 'Fair';
    if (_currentRange <= 90) return 'Poor';
    return 'Weak';
  }

  Color _getSignalColor() {
    if (_currentRange <= 50) return Colors.green;
    if (_currentRange <= 80) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _msgSub.cancel();
    _rangeSub.cancel();
    _connectionSub.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2V Safety Communication'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Range and connection status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _isInRange ? Colors.green.shade100 : Colors.red.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isInRange ? Icons.wifi : Icons.wifi_off,
                      color: _isInRange ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isInRange ? '🚗 CONNECTED' : '🚗 OUT OF RANGE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isInRange ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (_currentRange > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Range: ${_currentRange.toInt()}m',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Signal: ${_getSignalStrength()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSignalColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Safety Alert Buttons
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Quick Safety Alerts:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isInRange ? () => _sendSafetyAlert('pothole') : null,
                        icon: const Text('🕳️', style: TextStyle(fontSize: 16)),
                        label: const Text('Pothole\nAhead', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isInRange ? () => _sendSafetyAlert('speedbreaker') : null,
                        icon: const Text('🚧', style: TextStyle(fontSize: 16)),
                        label: const Text('Speed Breaker\nAhead', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isInRange ? () => _sendSafetyAlert('accident') : null,
                        icon: const Text('🚨', style: TextStyle(fontSize: 16)),
                        label: const Text('Accident\nReported', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.startsWith('Me:');
                final isSystem = message.startsWith('System:');
                final isAlert = message.contains('⚠️ ALERT:') || message.contains('🕳️') || message.contains('🚧') || message.contains('🚨');
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: isMe 
                        ? MainAxisAlignment.end 
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                        ),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isSystem 
                              ? Colors.grey.shade200
                              : isAlert
                                  ? (isMe ? Colors.orange.shade600 : Colors.red.shade100)
                                  : isMe 
                                      ? Colors.blue.shade500
                                      : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12.0),
                          border: isAlert ? Border.all(color: Colors.red, width: 2) : null,
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isMe && !isAlert ? Colors.white : Colors.black87,
                            fontWeight: isSystem || isAlert ? FontWeight.bold : FontWeight.normal,
                            fontSize: isAlert ? 14 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Text Input (Optional)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Optional: Type custom message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _isInRange ? _sendMessage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 