import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final List<DiscoveredDevice> _devices = [];
  bool _scanning = false;

  void _startScan() {
    setState(() {
      _devices.clear();
      _scanning = true;
    });
    _bluetoothService.startScan((device) {
      if (!_devices.any((d) => d.id == device.id)) {
        setState(() {
          _devices.add(device);
        });
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _scanning = false;
      });
      _bluetoothService.stopScan();
    });
  }

  void _connectAndNavigate(DiscoveredDevice device) async {
    await _bluetoothService.connectToDevice(device);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bluetoothService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Central Chat')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _scanning ? null : _startScan,
            child: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : device.id),
                  subtitle: Text(device.id),
                  trailing: ElevatedButton(
                    onPressed: () => _connectAndNavigate(device),
                    child: const Text('Connect'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 