import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/bluetooth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  late final BluetoothService _bluetoothService;
  late final StreamSubscription<String> _msgSub;
  late final StreamSubscription<double> _rangeSub;
  late final StreamSubscription<bool> _connectionSub;
  late final StreamSubscription<Map<String, String>> _vehicleInfoSub;
  late final StreamSubscription<bool> _manualConnectionSub;
  
  double _currentRange = 0.0;
  bool _isInRange = false;
  bool _isManuallyConnected = false;
  String _myVehicle = 'Initializing...';
  String _connectedVehicle = 'None';
  String _connectionStatus = 'Disconnected';

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
        _isInRange = _currentRange <= 100; // Only in range if <= 100m
      });
    });
    
    // Listen to connection status
    _connectionSub = _bluetoothService.connectionStatus.listen((connected) {
      setState(() {
        _isInRange = connected;
      });
    });
    
    // Listen to vehicle information
    _vehicleInfoSub = _bluetoothService.vehicleInfo.listen((info) {
      setState(() {
        _myVehicle = info['myVehicle'] ?? 'Unknown';
        _connectedVehicle = info['connectedVehicle'] ?? 'None';
        _connectionStatus = info['status'] ?? 'Disconnected';
      });
    });

    // Listen to manual connection status
    _manualConnectionSub = _bluetoothService.manualConnectionStatus.listen((connected) {
      setState(() {
        _isManuallyConnected = connected;
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

  // Real image processing methods
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        await _bluetoothService.detectAndAlertHazards(imageFile);
      }
    } catch (e) {
      setState(() {
        _messages.add('System: ❌ Camera error: $e');
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        await _bluetoothService.detectAndAlertHazards(imageFile);
      }
    } catch (e) {
      setState(() {
        _messages.add('System: ❌ Gallery error: $e');
      });
    }
  }

  Future<void> _testPotholeDetection() async {
    await _bluetoothService.testPotholeDetection();
  }

  Future<void> _testSpeedBreakerDetection() async {
    await _bluetoothService.testSpeedBreakerDetection();
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🤖 AI Hazard Detection'),
          content: const Text('Choose image source for road hazard analysis:'),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImageFromCamera();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImageFromGallery();
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _testPotholeDetection();
              },
              icon: const Text('🕳️'),
              label: const Text('Test Pothole'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _testSpeedBreakerDetection();
              },
              icon: const Text('🚧'),
              label: const Text('Test Speed Breaker'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _msgSub.cancel();
    _rangeSub.cancel();
    _connectionSub.cancel();
    _vehicleInfoSub.cancel();
    _manualConnectionSub.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_myVehicle - V2V Safety'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Vehicle connection status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _isInRange ? Colors.green.shade100 : Colors.red.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInRange ? Icons.link : Icons.link_off,
                          color: _isInRange ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isInRange ? '🚗 CONNECTED' : '🚗 DISCONNECTED',
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
                const SizedBox(height: 8),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _myVehicle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isManuallyConnected ? Icons.link : Icons.link_off,
                          color: _isManuallyConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isManuallyConnected ? Colors.green.shade600 : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isManuallyConnected ? _connectedVehicle : 'Not Connected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Connect/Disconnect Button
                    SizedBox(
                      width: 200,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: _isManuallyConnected 
                          ? () => _bluetoothService.disconnectFromVehicle()
                          : _bluetoothService.canConnect 
                            ? () => _bluetoothService.connectToVehicle()
                            : null,
                        icon: Icon(
                          _isManuallyConnected ? Icons.link_off : Icons.link,
                          size: 18,
                        ),
                        label: Text(
                          _isManuallyConnected ? 'Disconnect' : 'Connect',
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isManuallyConnected 
                            ? Colors.red.shade600 
                            : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
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
                        onPressed: _isManuallyConnected && _isInRange ? () => _sendSafetyAlert('pothole') : null,
                        icon: const Text('🕳️', style: TextStyle(fontSize: 16)),
                        label: const Text('Pothole\nAhead', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isManuallyConnected && _isInRange) ? Colors.orange : Colors.grey,
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
                        onPressed: _isManuallyConnected && _isInRange ? () => _sendSafetyAlert('speedbreaker') : null,
                        icon: const Text('🚧', style: TextStyle(fontSize: 16)),
                        label: const Text('Speed Breaker\nAhead', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isManuallyConnected && _isInRange) ? Colors.amber : Colors.grey,
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
                        onPressed: _isManuallyConnected && _isInRange ? () => _sendSafetyAlert('accident') : null,
                        icon: const Text('🚨', style: TextStyle(fontSize: 16)),
                        label: const Text('Accident\nReported', textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isManuallyConnected && _isInRange) ? Colors.red : Colors.grey,
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
                const SizedBox(height: 8),
                // AI Detection Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.camera_enhance),
                    label: const Text('🤖 AI Hazard Detection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
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