import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final flutterReactiveBle = FlutterReactiveBle();
  final Uuid serviceUuid = Uuid.parse("12345678-1234-5678-1234-56789abcdef0");
  final Uuid charUuid = Uuid.parse("12345678-1234-5678-1234-56789abcdef1");

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  QualifiedCharacteristic? _characteristic;
  DiscoveredDevice? _connectedDevice;
  final StreamController<String> _messageController = StreamController.broadcast();
  Stream<String> get messages => _messageController.stream;

  void startScan(Function(DiscoveredDevice) onDeviceFound) {
    _scanSub?.cancel();
    _scanSub = flutterReactiveBle
        .scanForDevices(withServices: [serviceUuid], scanMode: ScanMode.lowLatency)
        .listen((device) {
      onDeviceFound(device);
    });
  }

  void stopScan() {
    _scanSub?.cancel();
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    _connSub?.cancel();
    _connSub = flutterReactiveBle
        .connectToDevice(
          id: device.id,
          servicesWithCharacteristicsToDiscover: {serviceUuid: [charUuid]},
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        _connectedDevice = device;
        _characteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: charUuid,
          deviceId: device.id,
        );
        // Optionally subscribe to notifications if supported
        flutterReactiveBle.subscribeToCharacteristic(_characteristic!).listen((data) {
          _messageController.add('Peer: ${String.fromCharCodes(data)}');
        });
      }
    });
  }

  Future<void> sendMessage(String message) async {
    if (_characteristic == null) return;
    await flutterReactiveBle.writeCharacteristicWithResponse(
      _characteristic!,
      value: message.codeUnits,
    );
    _messageController.add('Me: $message');
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _messageController.close();
    _connectedDevice = null;
    _characteristic = null;
  }
} 