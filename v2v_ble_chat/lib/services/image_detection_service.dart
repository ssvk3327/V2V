import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

// Detection result model
class DetectionResult {
  final String type; // 'pothole' or 'speed_breaker'
  final double confidence;
  final Map<String, dynamic> boundingBox;
  
  DetectionResult({
    required this.type,
    required this.confidence,
    required this.boundingBox,
  });
  
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      type: json['class'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: json,
    );
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
    
    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final topDetection = detections.first;
    
    String alertType;
    String alertMessage;
    String alertIcon;
    
    switch (topDetection.type.toLowerCase()) {
      case 'pothole':
      case 'potholes':
        alertType = 'pothole';
        alertIcon = '🕳️';
        alertMessage = '$alertIcon Pothole detected ahead - Reduce speed';
        break;
      case 'speed_breaker':
      case 'speedbreaker':
      case 'broken road':
      case 'speed breaker':
        alertType = 'speedbreaker';
        alertIcon = '🚧';
        alertMessage = '$alertIcon Speed breaker detected ahead - Slow down';
        break;
      default:
        alertType = 'hazard';
        alertIcon = '⚠️';
        alertMessage = '$alertIcon Road hazard detected ahead - Proceed with caution';
    }
    
    return {
      'hasHazards': true,
      'alertType': alertType,
      'alertMessage': alertMessage,
      'alertIcon': alertIcon,
      'confidence': topDetection.confidence,
      'detectionCount': detections.length,
      'allDetections': detections.map((d) => {
        'type': d.type,
        'confidence': d.confidence,
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