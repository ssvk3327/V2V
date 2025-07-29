import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

// Detection result model with distance calculation
class DetectionResult {
  final String type; // 'pothole' or 'speed_breaker'
  final double confidence;
  final Map<String, dynamic> boundingBox;
  final double? distance; // Distance in meters
  
  DetectionResult({
    required this.type,
    required this.confidence,
    required this.boundingBox,
    this.distance,
  });
  
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final boundingBox = {
      'x': (json['x'] ?? 0.0).toDouble(),
      'y': (json['y'] ?? 0.0).toDouble(),
      'width': (json['width'] ?? 0.0).toDouble(),
      'height': (json['height'] ?? 0.0).toDouble(),
    };

    // Calculate distance based on object type and size
    final distance = _calculateDistance(
      json['class'] ?? 'unknown',
      boundingBox['width']!,
      boundingBox['height']!,
    );

    return DetectionResult(
      type: json['class'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: boundingBox,
      distance: distance,
    );
  }

  // Distance calculation based on object dimensions
  static double? _calculateDistance(String objectType, double pixelWidth, double pixelHeight) {
    // Constants for distance calculation
    const double focalLength = 800.0; // in pixels (adjust based on camera)
    
    double? realWidth;
    double? realHeight;
    
    // Real-world dimensions based on object type
    switch (objectType.toLowerCase()) {
      case 'potholes':
      case 'pothole':
        realWidth = 0.3;  // approx. pothole width in meters
        realHeight = 0.1; // approx. pothole height in meters
        break;
      case 'speed_breaker':
      case 'speedbreaker':
      case 'broken road':
        realWidth = 3.0;  // approx. speed breaker width in meters
        realHeight = 0.15; // approx. speed breaker height in meters
        break;
      default:
        return null; // Unknown object type
    }
    
    if (realWidth == null || realHeight == null) return null;
    
    // Calculate distance using both width and height, then average
    final distanceFromWidth = (realWidth * focalLength) / pixelWidth;
    final distanceFromHeight = (realHeight * focalLength) / pixelHeight;
    
    return (distanceFromWidth + distanceFromHeight) / 2;
  }

  // Get formatted distance string
  String get distanceString {
    if (distance == null) return 'Unknown distance';
    if (distance! < 1.0) {
      return '${(distance! * 100).toInt()} cm';
    } else {
      return '${distance!.toStringAsFixed(1)} m';
    }
  }
}

class ImageDetectionService {
  static const String _apiKey = "g1iMaJma6G9wZZ2Fm5PN";
  static const String _modelEndpoint = "https://detect.roboflow.com/pothole-and-speed-breaker-detect/1";
  
  final Dio _dio = Dio();
  
  // Real API detection for uploaded images
  Future<List<DetectionResult>> detectHazards(File imageFile) async {
    try {
      print('🔍 Starting real hazard detection...');
      print('📸 Image path: ${imageFile.path}');
      
      // Read and encode image
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      print('📊 Image size: ${bytes.length} bytes');
      print('🔗 Sending to Roboflow API...');
      
      // Prepare request
      final response = await _dio.post(
        _modelEndpoint,
        queryParameters: {
          'api_key': _apiKey,
          'confidence': 0.4, // Minimum confidence threshold
          'overlap': 0.3,    // Overlap threshold for NMS
        },
        data: base64Image,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final predictions = data['predictions'] as List<dynamic>? ?? [];
        
        print('📊 API Response: Found ${predictions.length} detections');
        
        final detections = predictions
            .map((pred) => DetectionResult.fromJson(pred))
            .where((result) => result.confidence > 0.4) // Filter low confidence
            .toList();
            
        // Log each detection
        for (int i = 0; i < detections.length; i++) {
          final detection = detections[i];
          print('  🎯 Detection ${i+1}: ${detection.type} (${(detection.confidence * 100).toInt()}% confidence)');
        }
        
        return detections;
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Detection error: $e');
      return [];
    }
  }

  // Simulate API detection for demo (fallback)
  Future<List<DetectionResult>> simulateDetection() async {
    try {
      print('🔍 Simulating hazard detection...');
      
      // Simulate the API response for the pothole image
      await Future.delayed(const Duration(seconds: 2)); // Simulate API delay
      
      final mockDetections = [
        DetectionResult(
          type: 'potholes',
          confidence: 0.8061,
          boundingBox: {'x': 656.5, 'y': 216.5, 'width': 191.0, 'height': 75.0},
        ),
        DetectionResult(
          type: 'potholes', 
          confidence: 0.7016,
          boundingBox: {'x': 185.0, 'y': 212.5, 'width': 202.0, 'height': 81.0},
        ),
      ];
      
      print('📊 Found ${mockDetections.length} detections');
      return mockDetections;
    } catch (e) {
      print('❌ Detection error: $e');
      return [];
    }
  }
  
  // Analyze detection results and generate safety alerts
  Map<String, dynamic> analyzeDetections(List<DetectionResult> detections) {
    if (detections.isEmpty) {
      return {
        'hasHazards': false,
        'alertType': null,
        'alertMessage': 'Road clear - No hazards detected',
        'confidence': 0.0,
        'detectionCount': 0,
      };
    }
    
    // Sort by distance (nearest first), then by confidence
    detections.sort((a, b) {
      // If both have distance, sort by distance (nearest first)
      if (a.distance != null && b.distance != null) {
        return a.distance!.compareTo(b.distance!);
      }
      // If only one has distance, prioritize it
      if (a.distance != null) return -1;
      if (b.distance != null) return 1;
      // If neither has distance, sort by confidence
      return b.confidence.compareTo(a.confidence);
    });
    final topDetection = detections.first;
    
    String alertType;
    String alertMessage;
    String alertIcon;
    
    switch (topDetection.type.toLowerCase()) {
      case 'pothole':
      case 'potholes':
        alertType = 'pothole';
        alertIcon = '🕳️';
        alertMessage = topDetection.distance != null 
            ? '$alertIcon Pothole detected ${topDetection.distanceString} ahead - Reduce speed'
            : '$alertIcon Pothole detected ahead - Reduce speed';
        break;
      case 'speed_breaker':
      case 'speedbreaker':
      case 'broken road':
      case 'speed breaker':
        alertType = 'speedbreaker';
        alertIcon = '🚧';
        alertMessage = topDetection.distance != null
            ? '$alertIcon Speed breaker detected ${topDetection.distanceString} ahead - Slow down'
            : '$alertIcon Speed breaker detected ahead - Slow down';
        break;
      default:
        alertType = 'hazard';
        alertIcon = '⚠️';
        alertMessage = topDetection.distance != null
            ? '$alertIcon Road hazard detected ${topDetection.distanceString} ahead - Proceed with caution'
            : '$alertIcon Road hazard detected ahead - Proceed with caution';
    }
    
    return {
      'hasHazards': true,
      'alertType': alertType,
      'alertMessage': alertMessage,
      'alertIcon': alertIcon,
      'confidence': topDetection.confidence,
      'detectionCount': detections.length,
      'detections': detections, // Full detection objects with bounding boxes
      'nearestDistance': topDetection.distance,
      'allDetections': detections.map((d) => {
        'type': d.type,
        'confidence': d.confidence,
        'boundingBox': d.boundingBox,
        'distance': d.distance,
        'distanceString': d.distanceString,
      }).toList(),
    };
  }
  
  // Process real uploaded image and return analysis
  Future<Map<String, dynamic>> processImage(File imageFile) async {
    try {
      print('📸 Processing uploaded image...');
      
      // Detect hazards using real API
      final detections = await detectHazards(imageFile);
      
      // Analyze results
      final analysis = analyzeDetections(detections);
      
      print('✅ Analysis complete: ${analysis['alertMessage']}');
      
      return analysis;
    } catch (e) {
      print('❌ Image processing failed: $e');
      return {
        'hasHazards': false,
        'alertType': 'error',
        'alertMessage': 'Image processing failed - Manual detection required',
        'confidence': 0.0,
        'detectionCount': 0,
        'error': e.toString(),
      };
    }
  }

  // Process simulated detection and return analysis (fallback)
  Future<Map<String, dynamic>> processSimulatedImage() async {
    try {
      print('📸 Processing simulated image...');
      
      // Detect hazards
      final detections = await simulateDetection();
      
      // Analyze results
      final analysis = analyzeDetections(detections);
      
      print('✅ Analysis complete: ${analysis['alertMessage']}');
      
      return analysis;
    } catch (e) {
      print('❌ Image processing failed: $e');
      return {
        'hasHazards': false,
        'alertType': 'error',
        'alertMessage': 'Image processing failed - Manual detection required',
        'confidence': 0.0,
        'detectionCount': 0,
        'error': e.toString(),
      };
    }
  }

  // Test with specific asset images
  Future<Map<String, dynamic>> testWithPotholeImage() async {
    try {
      print('🧪 Testing with pothole image...');
      
      // Load the pothole test image from assets
      final byteData = await rootBundle.load('assets/test_images/pothole_test.jpeg');
      final bytes = byteData.buffer.asUint8List();
      
      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/pothole_test.jpeg');
      await tempFile.writeAsBytes(bytes);
      
      // Process with real API
      final analysis = await processImage(tempFile);
      
      // Clean up
      await tempFile.delete();
      
      return analysis;
    } catch (e) {
      print('❌ Pothole test failed: $e');
      return {
        'hasHazards': false,
        'alertType': 'error',
        'alertMessage': 'Pothole test failed',
        'confidence': 0.0,
      };
    }
  }

  // Test with speed breaker image
  Future<Map<String, dynamic>> testWithSpeedBreakerImage() async {
    try {
      print('🧪 Testing with speed breaker image...');
      
      // Load the speed breaker test image from assets
      final byteData = await rootBundle.load('assets/test_images/speedbreaker_test.jpeg');
      final bytes = byteData.buffer.asUint8List();
      
      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/speedbreaker_test.jpeg');
      await tempFile.writeAsBytes(bytes);
      
      // Process with real API
      final analysis = await processImage(tempFile);
      
      // Clean up
      await tempFile.delete();
      
      return analysis;
    } catch (e) {
      print('❌ Speed breaker test failed: $e');
      return {
        'hasHazards': false,
        'alertType': 'error',
        'alertMessage': 'Speed breaker test failed',
        'confidence': 0.0,
      };
    }
  }
  
  // Test function with the provided image
  Future<Map<String, dynamic>> testWithSampleImage() async {
    try {
      // This would be used for testing with the provided pothole image
      print('🧪 Running test detection...');
      
      // Use the same simulation as the main detection
      final analysis = await processSimulatedImage();
      print('🎯 Test result: ${analysis['alertMessage']}');
      
      return analysis;
    } catch (e) {
      print('❌ Test failed: $e');
      return {
        'hasHazards': false,
        'alertType': 'error',
        'alertMessage': 'Test detection failed',
        'confidence': 0.0,
      };
    }
  }

}