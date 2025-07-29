#!/usr/bin/env python3
"""
Flask Backend API for V2V Image Processing with Distance Calculation
Handles manual image uploads and processes them using Roboflow API
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import base64
import requests
import os
import tempfile
import json
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web/mobile requests

# Roboflow API configuration
ROBOFLOW_API_KEY = "g1iMaJma6G9wZZ2Fm5PN"
ROBOFLOW_MODEL_ENDPOINT = "https://detect.roboflow.com/pothole-and-speed-breaker-detect/1"

def calculate_distance(object_type, pixel_width, pixel_height):
    """Calculate distance based on object dimensions"""
    # Constants for distance calculation
    FOCAL_LENGTH = 800.0  # in pixels (adjust based on camera)
    
    # Real-world dimensions based on object type
    if object_type.lower() in ['potholes', 'pothole']:
        REAL_WIDTH = 0.3   # approx. pothole width in meters
        REAL_HEIGHT = 0.1  # approx. pothole height in meters
    elif object_type.lower() in ['speed_breaker', 'speedbreaker', 'broken road']:
        REAL_WIDTH = 3.0   # approx. speed breaker width in meters
        REAL_HEIGHT = 0.15 # approx. speed breaker height in meters
    else:
        return None
    
    # Calculate distance using both width and height, then average
    distance_from_width = (REAL_WIDTH * FOCAL_LENGTH) / pixel_width
    distance_from_height = (REAL_HEIGHT * FOCAL_LENGTH) / pixel_height
    
    return (distance_from_width + distance_from_height) / 2

def format_distance(distance):
    """Format distance for display"""
    if distance is None:
        return "Unknown distance"
    if distance < 1.0:
        return f"{int(distance * 100)} cm"
    else:
        return f"{distance:.1f} m"

def process_detections(predictions):
    """Process Roboflow predictions and add distance calculations"""
    detections = []
    
    for pred in predictions:
        obj_type = pred['class']
        confidence = pred['confidence']
        x = pred['x']
        y = pred['y']
        width = pred['width']
        height = pred['height']
        
        # Calculate distance
        distance = calculate_distance(obj_type, width, height)
        
        detection = {
            'type': obj_type,
            'confidence': confidence,
            'boundingBox': {
                'x': x,
                'y': y,
                'width': width,
                'height': height
            },
            'distance': distance,
            'distanceString': format_distance(distance)
        }
        
        detections.append(detection)
    
    return detections

def generate_alert_message(detections):
    """Generate appropriate alert message based on detections"""
    if not detections:
        return {
            'hasHazards': False,
            'alertMessage': 'No hazards detected - Road clear',
            'alertType': 'clear',
            'alertIcon': '✅'
        }
    
    # Sort by distance (nearest first), then by confidence
    detections.sort(key=lambda x: (
        x['distance'] if x['distance'] is not None else float('inf'),
        -x['confidence']
    ))
    
    top_detection = detections[0]
    
    # Generate alert based on nearest/highest confidence detection
    if top_detection['type'].lower() in ['pothole', 'potholes']:
        alert_type = 'pothole'
        alert_icon = '🕳️'
        if top_detection['distance']:
            alert_message = f"{alert_icon} Pothole detected {top_detection['distanceString']} ahead - Reduce speed"
        else:
            alert_message = f"{alert_icon} Pothole detected ahead - Reduce speed"
    elif top_detection['type'].lower() in ['speed_breaker', 'speedbreaker', 'broken road']:
        alert_type = 'speedbreaker'
        alert_icon = '🚧'
        if top_detection['distance']:
            alert_message = f"{alert_icon} Speed breaker detected {top_detection['distanceString']} ahead - Slow down"
        else:
            alert_message = f"{alert_icon} Speed breaker detected ahead - Slow down"
    else:
        alert_type = 'hazard'
        alert_icon = '⚠️'
        if top_detection['distance']:
            alert_message = f"{alert_icon} Road hazard detected {top_detection['distanceString']} ahead - Proceed with caution"
        else:
            alert_message = f"{alert_icon} Road hazard detected ahead - Proceed with caution"
    
    return {
        'hasHazards': True,
        'alertMessage': alert_message,
        'alertType': alert_type,
        'alertIcon': alert_icon,
        'confidence': top_detection['confidence'],
        'nearestDistance': top_detection['distance']
    }

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'V2V Image Processing API',
        'timestamp': datetime.now().isoformat(),
        'features': [
            'Image upload and processing',
            'Roboflow AI detection',
            'Distance calculation',
            'V2V alert generation'
        ]
    })

@app.route('/process-image', methods=['POST'])
def process_image():
    """Process uploaded image for hazard detection"""
    try:
        logger.info("📸 Received image processing request")
        
        # Check if image data is provided
        if 'image' not in request.json:
            return jsonify({
                'success': False,
                'error': 'No image data provided'
            }), 400
        
        # Get base64 image data
        image_data = request.json['image']
        
        # Remove data URL prefix if present
        if image_data.startswith('data:image'):
            image_data = image_data.split(',')[1]
        
        logger.info(f"📊 Processing image data: {len(image_data)} characters")
        
        # Send to Roboflow API
        response = requests.post(
            ROBOFLOW_MODEL_ENDPOINT,
            params={
                'api_key': ROBOFLOW_API_KEY,
                'confidence': 0.4,
                'overlap': 0.3,
            },
            data=image_data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        
        if response.status_code != 200:
            logger.error(f"❌ Roboflow API error: {response.status_code}")
            return jsonify({
                'success': False,
                'error': f'AI detection service error: {response.status_code}'
            }), 500
        
        # Parse API response
        api_data = response.json()
        predictions = api_data.get('predictions', [])
        
        logger.info(f"🎯 Found {len(predictions)} detections")
        
        # Process detections with distance calculation
        detections = process_detections(predictions)
        
        # Generate alert message
        alert_info = generate_alert_message(detections)
        
        # Prepare response
        result = {
            'success': True,
            'timestamp': datetime.now().isoformat(),
            'detectionCount': len(detections),
            'detections': detections,
            **alert_info,
            'allDetections': [
                {
                    'type': d['type'],
                    'confidence': d['confidence'],
                    'boundingBox': d['boundingBox'],
                    'distance': d['distance'],
                    'distanceString': d['distanceString']
                }
                for d in detections
            ]
        }
        
        # Log results
        if detections:
            nearest = min(detections, key=lambda x: x['distance'] if x['distance'] else float('inf'))
            if nearest['distance']:
                logger.info(f"🎯 Nearest hazard: {nearest['type']} at {nearest['distanceString']}")
            else:
                logger.info(f"🎯 Detected: {nearest['type']} (distance unknown)")
        else:
            logger.info("✅ No hazards detected")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Error processing image: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'Processing error: {str(e)}'
        }), 500

@app.route('/test-detection', methods=['POST'])
def test_detection():
    """Test endpoint with predefined images"""
    try:
        test_type = request.json.get('type', 'pothole')
        
        logger.info(f"🧪 Testing {test_type} detection")
        
        if test_type == 'pothole':
            # Simulate pothole detection results
            detections = [
                {
                    'type': 'potholes',
                    'confidence': 0.806,
                    'boundingBox': {'x': 185.0, 'y': 212.5, 'width': 202.0, 'height': 81.0},
                    'distance': 1.1,
                    'distanceString': '1.1 m'
                },
                {
                    'type': 'potholes',
                    'confidence': 0.702,
                    'boundingBox': {'x': 656.5, 'y': 216.5, 'width': 191.0, 'height': 75.0},
                    'distance': 1.2,
                    'distanceString': '1.2 m'
                }
            ]
        else:  # speed breaker
            detections = [
                {
                    'type': 'broken road',
                    'confidence': 0.566,
                    'boundingBox': {'x': 246.0, 'y': 271.0, 'width': 492.0, 'height': 246.0},
                    'distance': 2.7,
                    'distanceString': '2.7 m'
                }
            ]
        
        alert_info = generate_alert_message(detections)
        
        result = {
            'success': True,
            'timestamp': datetime.now().isoformat(),
            'detectionCount': len(detections),
            'detections': detections,
            **alert_info,
            'allDetections': detections
        }
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"❌ Error in test detection: {str(e)}")
        return jsonify({
            'success': False,
            'error': f'Test error: {str(e)}'
        }), 500

if __name__ == '__main__':
    print("🚗 V2V Image Processing Backend API")
    print("=" * 50)
    print("🌐 Starting Flask server on http://localhost:5000")
    print("📸 Image upload endpoint: POST /process-image")
    print("🧪 Test endpoint: POST /test-detection")
    print("❤️ Health check: GET /health")
    print("📏 Distance calculation: Enabled")
    print("🤖 AI Detection: Roboflow API integrated")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=5000, debug=True)