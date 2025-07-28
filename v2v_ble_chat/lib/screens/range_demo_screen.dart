import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

class RangeDemoScreen extends StatefulWidget {
  const RangeDemoScreen({Key? key}) : super(key: key);

  @override
  State<RangeDemoScreen> createState() => _RangeDemoScreenState();
}

class _RangeDemoScreenState extends State<RangeDemoScreen> {
  double _distance = 50.0; // meters
  String _selectedTechnology = 'BLE';
  bool _isConnected = true;
  Timer? _simulationTimer;
  
  final Map<String, Map<String, dynamic>> _technologies = {
    'BLE': {
      'maxRange': 100.0,
      'color': Colors.blue,
      'description': 'Bluetooth Low Energy\n10-100m range',
    },
    'WiFi Direct': {
      'maxRange': 200.0,
      'color': Colors.green,
      'description': 'WiFi Peer-to-Peer\n50-200m range',
    },
    'DSRC': {
      'maxRange': 1000.0,
      'color': Colors.orange,
      'description': 'Dedicated Short Range\n300-1000m range',
    },
    'C-V2X': {
      'maxRange': 5000.0,
      'color': Colors.purple,
      'description': 'Cellular V2X\n1-10km+ range',
    },
  };

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        // Simulate vehicle movement
        _distance += Random().nextDouble() * 20 - 10; // ±10m change
        _distance = _distance.clamp(0.0, 6000.0);
        
        // Check if still in range
        final maxRange = _technologies[_selectedTechnology]!['maxRange'] as double;
        _isConnected = _distance <= maxRange;
      });
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  String _getSignalStrength() {
    final maxRange = _technologies[_selectedTechnology]!['maxRange'] as double;
    final strength = (1 - (_distance / maxRange)).clamp(0.0, 1.0);
    
    if (strength > 0.8) return 'Excellent';
    if (strength > 0.6) return 'Good';
    if (strength > 0.4) return 'Fair';
    if (strength > 0.2) return 'Poor';
    return 'No Signal';
  }

  Color _getSignalColor() {
    final maxRange = _technologies[_selectedTechnology]!['maxRange'] as double;
    final strength = (1 - (_distance / maxRange)).clamp(0.0, 1.0);
    
    if (strength > 0.6) return Colors.green;
    if (strength > 0.3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final tech = _technologies[_selectedTechnology]!;
    final maxRange = tech['maxRange'] as double;
    final techColor = tech['color'] as Color;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2V Range Connectivity Demo'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Technology Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select V2V Technology:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _technologies.keys.map((tech) {
                        return ChoiceChip(
                          label: Text(tech),
                          selected: _selectedTechnology == tech,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedTechnology = tech;
                              });
                            }
                          },
                          selectedColor: _technologies[tech]!['color'],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tech['description'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Range Visualization
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Status Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isConnected ? '🟢 CONNECTED' : '🔴 OUT OF RANGE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isConnected ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              'Signal: ${_getSignalStrength()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getSignalColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Distance Display
                      Text(
                        'Distance: ${_distance.toStringAsFixed(0)}m',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Range Slider
                      Column(
                        children: [
                          Text('Max Range: ${maxRange.toStringAsFixed(0)}m'),
                          Slider(
                            value: _distance.clamp(0.0, maxRange),
                            min: 0,
                            max: maxRange,
                            divisions: (maxRange / 10).round(),
                            activeColor: techColor,
                            onChanged: (value) {
                              setState(() {
                                _distance = value;
                                _isConnected = _distance <= maxRange;
                              });
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Visual Range Indicator
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomPaint(
                            painter: RangePainter(
                              distance: _distance,
                              maxRange: maxRange,
                              isConnected: _isConnected,
                              techColor: techColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Information Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Real-World Factors Affecting Range:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Vehicle speed (higher speed = reduced effective range)'),
                    const Text('• Urban environment (buildings block signals)'),
                    const Text('• Weather conditions (rain/snow reduce range)'),
                    const Text('• Interference from other devices'),
                    const Text('• Line of sight obstacles'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RangePainter extends CustomPainter {
  final double distance;
  final double maxRange;
  final bool isConnected;
  final Color techColor;

  RangePainter({
    required this.distance,
    required this.maxRange,
    required this.isConnected,
    required this.techColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 20;
    
    // Draw range circles
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Max range circle
    paint.color = techColor.withOpacity(0.3);
    canvas.drawCircle(center, maxRadius, paint);
    
    // Current distance circle
    final currentRadius = (distance / maxRange) * maxRadius;
    paint.color = isConnected ? Colors.green : Colors.red;
    paint.strokeWidth = 3;
    canvas.drawCircle(center, currentRadius, paint);
    
    // Vehicle A (center)
    final vehiclePaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center, 8, vehiclePaint);
    
    // Vehicle B (at distance)
    final angle = 0.0; // Fixed angle for simplicity
    final vehicleBPos = Offset(
      center.dx + currentRadius * cos(angle),
      center.dy + currentRadius * sin(angle),
    );
    vehiclePaint.color = isConnected ? Colors.green : Colors.red;
    canvas.drawCircle(vehicleBPos, 8, vehiclePaint);
    
    // Connection line
    if (isConnected) {
      final linePaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(center, vehicleBPos, linePaint);
    }
    
    // Labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Vehicle A label
    textPainter.text = const TextSpan(
      text: 'Vehicle A',
      style: TextStyle(color: Colors.black, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - 25, center.dy + 15));
    
    // Vehicle B label
    textPainter.text = TextSpan(
      text: 'Vehicle B',
      style: TextStyle(
        color: isConnected ? Colors.green : Colors.red,
        fontSize: 12,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(vehicleBPos.dx - 25, vehicleBPos.dy + 15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}