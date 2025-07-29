import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'image_detection_service.dart';

class BackendApiService {
  static const String _baseUrl = 'http://localhost:5000';
  
  /// Process uploaded image through backend API
  Future<Map<String, dynamic>> processImageUpload(File imageFile) async {
    try {
      // Read image file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Convert to base64
      final String base64Image = base64Encode(imageBytes);
      
      // Prepare request
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Send to backend API
      final response = await http.post(
        Uri.parse('$_baseUrl/process-image'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        // Convert backend response to Flutter format
        return _convertBackendResponse(result);
      } else {
        throw Exception('Backend API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend API error: $e');
      }
      
      // Fallback to direct Roboflow API if backend is unavailable
      return await _fallbackToDirectAPI(imageFile);
    }
  }
  
  /// Test backend with predefined detection results
  Future<Map<String, dynamic>> testBackendDetection(String testType) async {
    try {
      final Map<String, dynamic> requestBody = {
        'type': testType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl/test-detection'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return _convertBackendResponse(result);
      } else {
        throw Exception('Backend test error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Backend test error: $e');
      }
      
      // Fallback to local test data
      return _getFallbackTestData(testType);
    }
  }
  
  /// Check if backend API is available
  Future<bool> isBackendAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Backend not available: $e');
      }
      return false;
    }
  }
  
  /// Convert backend response to Flutter-compatible format
  Map<String, dynamic> _convertBackendResponse(Map<String, dynamic> backendResult) {
    if (!backendResult['success']) {
      throw Exception(backendResult['error'] ?? 'Unknown backend error');
    }
    
    // Extract detections and convert to DetectionResult objects
    final List<dynamic> backendDetections = backendResult['detections'] ?? [];
    final List<DetectionResult> detections = backendDetections.map((detection) {
      return DetectionResult(
        type: detection['type'] ?? 'unknown',
        confidence: (detection['confidence'] ?? 0.0).toDouble(),
        boundingBox: Map<String, dynamic>.from(detection['boundingBox'] ?? {}),
        distance: detection['distance']?.toDouble(),
      );
    }).toList();
    
    return {
      'hasHazards': backendResult['hasHazards'] ?? false,
      'alertType': backendResult['alertType'] ?? 'unknown',
      'alertMessage': backendResult['alertMessage'] ?? 'No message',
      'alertIcon': backendResult['alertIcon'] ?? '⚠️',
      'confidence': (backendResult['confidence'] ?? 0.0).toDouble(),
      'detectionCount': backendResult['detectionCount'] ?? 0,
      'detections': detections,
      'nearestDistance': backendResult['nearestDistance']?.toDouble(),
      'allDetections': backendResult['allDetections'] ?? [],
      'source': 'backend_api',
      'timestamp': backendResult['timestamp'] ?? DateTime.now().toIso8601String(),
    };
  }
  
  /// Fallback to direct Roboflow API if backend is unavailable
  Future<Map<String, dynamic>> _fallbackToDirectAPI(File imageFile) async {
    if (kDebugMode) {
      print('🔄 Falling back to direct Roboflow API');
    }
    
    final ImageDetectionService directService = ImageDetectionService();
    final result = await directService.processImage(imageFile);
    
    // Add source indicator
    result['source'] = 'direct_api_fallback';
    
    return result;
  }
  
  /// Get fallback test data when backend is unavailable
  Map<String, dynamic> _getFallbackTestData(String testType) {
    if (kDebugMode) {
      print('🔄 Using fallback test data for $testType');
    }
    
    if (testType == 'pothole') {
      return {
        'hasHazards': true,
        'alertType': 'pothole',
        'alertMessage': '🕳️ Pothole detected 1.1 m ahead - Reduce speed',
        'alertIcon': '🕳️',
        'confidence': 0.806,
        'detectionCount': 2,
        'detections': [
          DetectionResult(
            type: 'potholes',
            confidence: 0.806,
            boundingBox: {'x': 185.0, 'y': 212.5, 'width': 202.0, 'height': 81.0},
            distance: 1.1,
          ),
          DetectionResult(
            type: 'potholes',
            confidence: 0.702,
            boundingBox: {'x': 656.5, 'y': 216.5, 'width': 191.0, 'height': 75.0},
            distance: 1.2,
          ),
        ],
        'nearestDistance': 1.1,
        'source': 'fallback_test_data',
      };
    } else {
      return {
        'hasHazards': true,
        'alertType': 'speedbreaker',
        'alertMessage': '🚧 Speed breaker detected 2.7 m ahead - Slow down',
        'alertIcon': '🚧',
        'confidence': 0.566,
        'detectionCount': 1,
        'detections': [
          DetectionResult(
            type: 'broken road',
            confidence: 0.566,
            boundingBox: {'x': 246.0, 'y': 271.0, 'width': 492.0, 'height': 246.0},
            distance: 2.7,
          ),
        ],
        'nearestDistance': 2.7,
        'source': 'fallback_test_data',
      };
    }
  }
  
  /// Upload image with progress tracking
  Future<Map<String, dynamic>> uploadImageWithProgress(
    File imageFile,
    Function(double progress)? onProgress,
  ) async {
    try {
      // Simulate upload progress
      if (onProgress != null) {
        onProgress(0.1); // Reading file
      }
      
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      if (onProgress != null) {
        onProgress(0.3); // File read complete
      }
      
      final String base64Image = base64Encode(imageBytes);
      
      if (onProgress != null) {
        onProgress(0.5); // Encoding complete
      }
      
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'filename': imageFile.path.split('/').last,
        'fileSize': imageBytes.length,
      };
      
      if (onProgress != null) {
        onProgress(0.7); // Sending to backend
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/process-image'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (onProgress != null) {
        onProgress(0.9); // Processing response
      }
      
      if (response.statusCode == 200) {
        final result = _convertBackendResponse(jsonDecode(response.body));
        
        if (onProgress != null) {
          onProgress(1.0); // Complete
        }
        
        return result;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Upload error: $e');
      }
      rethrow;
    }
  }
}