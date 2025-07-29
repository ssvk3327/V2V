import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../services/image_detection_service.dart';

class DetectionResultScreen extends StatefulWidget {
  final File? imageFile;
  final String? assetPath;
  final List<DetectionResult> detections;
  final String alertMessage;
  final double confidence;

  const DetectionResultScreen({
    Key? key,
    this.imageFile,
    this.assetPath,
    required this.detections,
    required this.alertMessage,
    required this.confidence,
  }) : super(key: key);

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  ui.Image? _image;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      Uint8List bytes;
      
      if (widget.imageFile != null) {
        // Load from file
        bytes = await widget.imageFile!.readAsBytes();
      } else if (widget.assetPath != null) {
        // Load from assets
        final ByteData data = await rootBundle.load(widget.assetPath!);
        bytes = data.buffer.asUint8List();
      } else {
        return;
      }

      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      setState(() {
        _image = frameInfo.image;
        _imageLoaded = true;
      });
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Detection Results'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Detection Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 Detection Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.alertMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(widget.confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Detections: ${widget.detections.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (widget.detections.isNotEmpty && widget.detections.first.distance != null)
                  Text(
                    'Nearest: ${widget.detections.first.distanceString}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          
          // Image with Bounding Boxes
          Expanded(
            child: _imageLoaded && _image != null
                ? Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: DetectionPainter(
                          image: _image!,
                          detections: widget.detections,
                        ),
                        child: AspectRatio(
                          aspectRatio: _image!.width / _image!.height,
                          child: Container(),
                        ),
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.purple,
                    ),
                  ),
          ),
          
          // Detection Details
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Detection Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.detections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final detection = entry.value;
                  final color = _getDetectionColor(index);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${detection.type} (${(detection.confidence * 100).toInt()}%)',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (detection.distance != null)
                                Text(
                                  '📏 Distance: ${detection.distanceString}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDetectionColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }
}

class DetectionPainter extends CustomPainter {
  final ui.Image image;
  final List<DetectionResult> detections;

  DetectionPainter({
    required this.image,
    required this.detections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image
    final paint = Paint();
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    // Calculate scale factors
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    // Draw bounding boxes
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final bbox = detection.boundingBox;
      
      // Get bounding box coordinates
      final x = (bbox['x'] as num).toDouble();
      final y = (bbox['y'] as num).toDouble();
      final width = (bbox['width'] as num).toDouble();
      final height = (bbox['height'] as num).toDouble();
      
      // Convert to screen coordinates (center-based to top-left based)
      final left = (x - width / 2) * scaleX;
      final top = (y - height / 2) * scaleY;
      final right = (x + width / 2) * scaleX;
      final bottom = (y + height / 2) * scaleY;
      
      final rect = Rect.fromLTRB(left, top, right, bottom);
      
      // Choose color based on detection type
      Color boxColor;
      String emoji;
      if (detection.type.toLowerCase().contains('pothole')) {
        boxColor = Colors.red;
        emoji = '🕳️';
      } else if (detection.type.toLowerCase().contains('speed') || 
                 detection.type.toLowerCase().contains('breaker') ||
                 detection.type.toLowerCase().contains('broken')) {
        boxColor = Colors.orange;
        emoji = '🚧';
      } else {
        boxColor = Colors.yellow;
        emoji = '⚠️';
      }
      
      // Draw bounding box
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(rect, boxPaint);
      
      // Draw filled background for label
      final labelBgPaint = Paint()
        ..color = boxColor.withOpacity(0.8);
      final labelRect = Rect.fromLTWH(left, top - 30, 120, 25);
      canvas.drawRect(labelRect, labelBgPaint);
      
      // Draw label text with distance
      String labelText = '$emoji ${detection.type} ${(detection.confidence * 100).toInt()}%';
      if (detection.distance != null) {
        labelText += ' (${detection.distanceString})';
      }
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Adjust label background width based on text
      final labelWidth = textPainter.width + 8;
      final adjustedLabelRect = Rect.fromLTWH(left, top - 30, labelWidth, 25);
      canvas.drawRect(adjustedLabelRect, labelBgPaint);
      
      textPainter.paint(canvas, Offset(left + 4, top - 28));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}