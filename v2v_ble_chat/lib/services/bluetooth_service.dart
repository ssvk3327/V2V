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
  bool _manuallyConnected = false; // New: tracks manual connection state
  String? _deviceId;
  String? _vehicleName;
  String? _connectedVehicle;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  double _currentRange = 50.0; // meters
  Timer? _rangeTimer;

  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<double> _rangeController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<Map<String, String>> _vehicleInfoController = StreamController.broadcast();
  final StreamController<bool> _manualConnectionController = StreamController.broadcast();
  
  Stream<String> get messages => _messageController.stream;
  Stream<double> get range => _rangeController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  Stream<Map<String, String>> get vehicleInfo => _vehicleInfoController.stream;
  Stream<bool> get manualConnectionStatus => _manualConnectionController.stream;

  // Start advertising - connect to WebSocket server (but don't auto-connect to other vehicles)
  Future<void> startAdvertising() async {
    // Vehicle name will be assigned by server based on connection order
    _messageController.add('System: Initializing vehicle...');
    _updateVehicleInfo(); // Update UI immediately
    
    await _connectToServer();
    _startRangeSimulation();
  }

  // New: Manual connection method
  Future<void> connectToVehicle() async {
    if (!_connected) {
      _messageController.add('System: Not connected to V2V network');
      return;
    }

    if (_currentRange > 100.0) {
      _messageController.add('System: Cannot connect - Other vehicle out of range (${_currentRange.toInt()}m)');
      return;
    }

    if (_manuallyConnected) {
      _messageController.add('System: Already connected to other vehicle');
      return;
    }

    _messageController.add('System: Attempting to connect to other vehicle...');
    
    // Send connection request through WebSocket
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'connect_request',
        'sender': _vehicleName ?? 'Unknown Vehicle',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    }
  }

  // New: Disconnect from other vehicle
  void disconnectFromVehicle() {
    if (!_manuallyConnected) {
      _messageController.add('System: Not connected to any vehicle');
      return;
    }

    _messageController.add('System: Disconnecting from other vehicle...');
    _manuallyConnected = false;
    _manualConnectionController.add(false);
    _updateVehicleInfo();

    // Send disconnect notification
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'disconnect_request',
        'sender': _vehicleName ?? 'Unknown Vehicle',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    }
  }

  void _updateVehicleInfo() {
    String status;
    if (!_connected) {
      status = 'Offline';
    } else if (!_manuallyConnected) {
      status = 'Online - Not Connected';
    } else if (_currentRange > 100.0) {
      status = 'Out of Range';
    } else {
      status = 'Connected';
    }

    _vehicleInfoController.add({
      'myVehicle': _vehicleName ?? 'Initializing...',
      'connectedVehicle': _manuallyConnected ? (_connectedVehicle ?? 'Other Vehicle') : 'None',
      'status': status
    });
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
      _connectionController.add(inRange && _connected && _manuallyConnected);
      
      if (!inRange && _manuallyConnected) {
        _messageController.add('System: ${_connectedVehicle ?? 'Other vehicle'} moved out of range (${_currentRange.toInt()}m) - Connection lost');
        _manuallyConnected = false;
        _manualConnectionController.add(false);
      } else if (inRange && _manuallyConnected) {
        String signal = _getSignalStrength(_currentRange);
        _messageController.add('System: Connected to ${_connectedVehicle ?? 'other vehicle'}: ${_currentRange.toInt()}m - Signal: $signal');
      } else if (_connected && !_manuallyConnected) {
        _messageController.add('System: ${_connectedVehicle ?? 'Other vehicle'} in range (${_currentRange.toInt()}m) - Press Connect to establish connection');
      }
      
      _updateVehicleInfo();
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
      
      // Send emulator identification after connection
      await Future.delayed(const Duration(milliseconds: 500));
      if (_channel != null) {
        // Try to identify emulator by checking device info
        _channel!.sink.add(jsonEncode({
          'type': 'identify',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
      }
      
      // Listen for messages
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            switch (message['type']) {
              case 'system':
                _messageController.add('System: ${message['message']}');
                
                // Extract my vehicle name from welcome message
                if (message['message'].contains('Connected as')) {
                  if (message['message'].contains('Vehicle A')) {
                    _vehicleName = 'Vehicle A';
                    _deviceId = 'Vehicle_A';
                  } else if (message['message'].contains('Vehicle B')) {
                    _vehicleName = 'Vehicle B';
                    _deviceId = 'Vehicle_B';
                  }
                  _connected = true;
                  _scanning = false;
                  _connectionController.add(true);
                  _updateVehicleInfo();
                }
                
                // Extract connected vehicle name from join message
                if (message['message'].contains('joined the V2V network')) {
                  if (message['message'].contains('Vehicle A') && _vehicleName != 'Vehicle A') {
                    _connectedVehicle = 'Vehicle A';
                  } else if (message['message'].contains('Vehicle B') && _vehicleName != 'Vehicle B') {
                    _connectedVehicle = 'Vehicle B';
                  }
                  _updateVehicleInfo();
                }
                break;
              case 'peer':
                String senderName = message['sender'] ?? 'Unknown Vehicle';
                // Clean up sender name display
                if (senderName.contains('Vehicle_A') || senderName == 'Vehicle_A') senderName = 'Vehicle A';
                if (senderName.contains('Vehicle_B') || senderName == 'Vehicle_B') senderName = 'Vehicle B';
                if (senderName.contains('Vehicle A')) senderName = 'Vehicle A';
                if (senderName.contains('Vehicle B')) senderName = 'Vehicle B';
                _messageController.add('🚗 $senderName: ${message['message']}');
                break;
              case 'alert':
                String senderName = message['sender'] ?? 'Unknown Vehicle';
                // Clean up sender name display
                if (senderName.contains('Vehicle_A') || senderName == 'Vehicle_A') senderName = 'Vehicle A';
                if (senderName.contains('Vehicle_B') || senderName == 'Vehicle_B') senderName = 'Vehicle B';
                if (senderName.contains('Vehicle A')) senderName = 'Vehicle A';
                if (senderName.contains('Vehicle B')) senderName = 'Vehicle B';
                _messageController.add('⚠️ ALERT from $senderName: ${message['message']}');
                break;
              case 'connect_request':
                String senderName = message['sender'] ?? 'Unknown Vehicle';
                if (senderName.contains('Vehicle_A') || senderName == 'Vehicle_A') senderName = 'Vehicle A';
                if (senderName.contains('Vehicle_B') || senderName == 'Vehicle_B') senderName = 'Vehicle B';
                if (senderName.contains('Vehicle A')) senderName = 'Vehicle A';
                if (senderName.contains('Vehicle B')) senderName = 'Vehicle B';
                
                if (_currentRange <= 100.0 && !_manuallyConnected) {
                  _manuallyConnected = true;
                  _connectedVehicle = senderName;
                  _manualConnectionController.add(true);
                  _messageController.add('System: Connected to $senderName successfully!');
                  _updateVehicleInfo();
                  
                  // Send connection confirmation
                  if (_channel != null) {
                    _channel!.sink.add(jsonEncode({
                      'type': 'connect_confirm',
                      'sender': _vehicleName ?? 'Unknown Vehicle',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    }));
                  }
                } else if (_currentRange > 100.0) {
                  _messageController.add('System: Connection request from $senderName failed - Out of range');
                } else {
                  _messageController.add('System: Connection request from $senderName failed - Already connected');
                }
                break;
              case 'connect_confirm':
                String senderName = message['sender'] ?? 'Unknown Vehicle';
                if (senderName.contains('Vehicle_A') || senderName == 'Vehicle_A') senderName = 'Vehicle A';
                if (senderName.contains('Vehicle_B') || senderName == 'Vehicle_B') senderName = 'Vehicle B';
                if (senderName.contains('Vehicle A')) senderName = 'Vehicle A';
                if (senderName.contains('Vehicle B')) senderName = 'Vehicle B';
                
                _manuallyConnected = true;
                _connectedVehicle = senderName;
                _manualConnectionController.add(true);
                _messageController.add('System: Connection confirmed by $senderName!');
                _updateVehicleInfo();
                break;
              case 'disconnect_request':
                String senderName = message['sender'] ?? 'Unknown Vehicle';
                if (senderName.contains('Vehicle_A') || senderName == 'Vehicle_A') senderName = 'Vehicle A';
                if (senderName.contains('Vehicle_B') || senderName == 'Vehicle_B') senderName = 'Vehicle B';
                if (senderName.contains('Vehicle A')) senderName = 'Vehicle A';
                if (senderName.contains('Vehicle B')) senderName = 'Vehicle B';
                
                _manuallyConnected = false;
                _manualConnectionController.add(false);
                _messageController.add('System: $senderName disconnected');
                _updateVehicleInfo();
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
        // Ensure vehicle name is set before showing ready message
        if (_vehicleName != null) {
          _messageController.add('System: $_vehicleName connected to V2V network! Ready for safety alerts.');
        } else {
          _messageController.add('System: Connected to V2V network! Ready for safety alerts.');
        }
        _connectionController.add(true);
        _updateVehicleInfo();
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
    
    if (_connected && _manuallyConnected && _channel != null && _currentRange <= 100.0) {
      try {
        // Send alert through WebSocket
        final payload = jsonEncode({
          'type': 'alert',
          'message': '$alertIcon $alertMessage',
          'sender': _vehicleName ?? 'Unknown Vehicle',
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
          'sender': _vehicleName ?? 'Unknown Vehicle',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        _channel!.sink.add(payload);
      } catch (e) {
        _messageController.add('System: Failed to send message: $e');
      }
    } else if (_currentRange > 100.0) {
      _messageController.add('System: Out of range (${_currentRange.toInt()}m) - Message not sent');
    } else if (!_manuallyConnected) {
      _messageController.add('System: Not connected to any vehicle - Alert not sent');
    } else {
      _messageController.add('System: Out of range - Alert not sent');
    }
  }

  double get currentRange => _currentRange;
  bool get isConnected => _connected && _manuallyConnected && _currentRange <= 100.0;
  bool get isOnline => _connected;
  bool get isManuallyConnected => _manuallyConnected;
  bool get canConnect => _connected && !_manuallyConnected && _currentRange <= 100.0;
  String get vehicleName => _vehicleName ?? 'Initializing...';
  String get connectedVehicle => _connectedVehicle ?? 'None';

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
    if (!_vehicleInfoController.isClosed) {
      _vehicleInfoController.close();
    }
    
    _scanning = false;
    _connected = false;
    _deviceId = null;
    _vehicleName = null;
    _connectedVehicle = null;
  }
} 