import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const V2VBluetoothDemoApp());
}

class V2VBluetoothDemoApp extends StatelessWidget {
  const V2VBluetoothDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2V Two-Way BLE Chat Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
} 