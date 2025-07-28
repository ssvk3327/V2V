import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  bool _scanning = false;
  bool _connected = false;
  String? _deviceId;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  double _currentRange = 50.0; // meters
  Timer? _rangeTimer;

  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<double> _rangeController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  
  Stream<String> get messages => _messageController.stream;
  Stream<double> get range => _rangeController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;

  // Start advertising - connect to WebSocket server
  Future<void> startAdvertising() async {
    _deviceId = 'Vehicle_${Random().nextInt(1000)}';
    _messageController.add('System: $_deviceId initializing...');
    
    await _connectToServer();
    _startRangeSimulation();
  }

  void startScanning() async {
    if (_scanning) return;
    _scanning = true;
    
    _messageController.add('System: Scanning for nearby vehicles...');
    
    // If not connected, try to connect
    if (!_connected) {
      await _connectToServer();
    }
  }

  void _startRangeSimulation() {
    _rangeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Simulate vehicle movement - range changes between 20-150 meters
      _currentRange += (Random().nextDouble() - 0.5) * 20; // ±10m change
      _currentRange = _currentRange.clamp(20.0, 150.0);
      
      _rangeController.add(_currentRange);
      
      // Check if still in BLE range (100m max)
      bool inRange = _currentRange <= 100.0;
      _connectionController.add(inRange && _connected);
      
      if (!inRange && _connected) {
        _messageController.add('System: Vehicle moved out of range (${_currentRange.toInt()}m)');
      } else if (inRange && _connected) {
        String signal = _getSignalStrength(_currentRange);
        _messageController.add('System: Range: ${_currentRange.toInt()}m - Signal: $signal');
      }
    });
  }

  String _getSignalStrength(double range) {
    if (range <= 30) return 'Excellent';
    if (range <= 50) return 'Good';
    if (range <= 70) return 'Fair';
    if (range <= 90) return 'Poor';
    return 'Weak';
  }

  Future<void> _connectToServer() async {
    try {
      _messageController.add('System: Connecting to V2V network...');
      
      // Connect to local WebSocket server
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://10.0.2.2:8080'), // Android emulator host IP
      );
      
      // Listen for messages
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            switch (message['type']) {
              case 'system':
                _messageController.add('System: ${message['message']}');
                if (message['message'].contains('online') || message['message'].contains('joined')) {
                  _connected = true;
                  _scanning = false;
                  _connectionController.add(true);
                }
                break;
              case 'peer':
                _messageController.add('🚗 ${message['sender']}: ${message['message']}');
                break;
              case 'alert':
                _messageController.add('⚠️ ALERT: ${message['message']}');
                break;
            }
          } catch (e) {
            _messageController.add('System: Error parsing message: $e');
          }
        },
        onError: (error) {
          _messageController.add('System: Connection error - using local mode');
          _connected = false;
          _connectionController.add(false);
        },
        onDone: () {
          _messageController.add('System: Disconnected from V2V network');
          _connected = false;
          _connectionController.add(false);
        },
      );
      
      // Wait a moment for connection to establish
      await Future.delayed(const Duration(seconds: 2));
      
      if (_channel != null) {
        _connected = true;
        _scanning = false;
        _messageController.add('System: Connected to V2V network! Ready for safety alerts.');
        _connectionController.add(true);
      }
      
    } catch (e) {
      _messageController.add('System: Failed to connect to V2V network: $e');
      _messageController.add('System: Running in local demo mode');
      _connected = false;
      _connectionController.add(false);
    }
  }

  Future<void> sendSafetyAlert(String alertType) async {
    String alertMessage = '';
    String alertIcon = '';
    
    switch (alertType) {
      case 'pothole':
        alertMessage = 'Pothole ahead - Reduce speed';
        alertIcon = '🕳️';
        break;
      case 'speedbreaker':
        alertMessage = 'Speed breaker ahead - Slow down';
        alertIcon = '🚧';
        break;
      case 'accident':
        alertMessage = 'Accident reported - Use alternate route';
        alertIcon = '🚨';
        break;
    }
    
    // Show locally
    _messageController.add('Me: $alertIcon $alertMessage');
    
    if (_connected && _channel != null && _currentRange <= 100.0) {
      try {
        // Send alert through WebSocket
        final payload = jsonEncode({
          'type': 'alert',
          'message': '$alertIcon $alertMessage',
          'sender': _deviceId ?? 'Unknown Vehicle',
          'alertType': alertType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        _channel!.sink.add(payload);
      } catch (e) {
        _messageController.add('System: Failed to send alert: $e');
      }
    } else if (_currentRange > 100.0) {
      _messageController.add('System: Out of range - Alert not transmitted');
    } else {
      _messageController.add('System: Not connected - Alert not sent');
    }
  }

  Future<void> sendMessage(String message) async {
    // Always show the sent message locally
    _messageController.add('Me: $message');
    
    if (_connected && _channel != null && _currentRange <= 100.0) {
      try {
        // Send message through WebSocket
        final payload = jsonEncode({
          'type': 'peer',
          'message': message,
          'sender': _deviceId ?? 'Unknown Vehicle',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        _channel!.sink.add(payload);
      } catch (e) {
        _messageController.add('System: Failed to send message: $e');
      }
    } else if (_currentRange > 100.0) {
      _messageController.add('System: Out of range (${_currentRange.toInt()}m) - Message not sent');
    } else {
      _messageController.add('System: Not connected - Message not sent');
    }
  }

  double get currentRange => _currentRange;
  bool get isConnected => _connected && _currentRange <= 100.0;

  void dispose() {
    _rangeTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_rangeController.isClosed) {
      _rangeController.close();
    }
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
    
    _scanning = false;
    _connected = false;
    _deviceId = null;
  }
} 