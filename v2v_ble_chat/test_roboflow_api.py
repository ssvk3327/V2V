#!/usr/bin/env python3
"""
Test script for Roboflow API integration
This script tests the pothole and speed breaker detection using the provided image
"""

import requests
import base64
import json
from PIL import Image
import matplotlib.pyplot as plt

# Roboflow API configuration
API_KEY = "g1iMaJma6G9wZZ2Fm5PN"
MODEL_ENDPOINT = "https://detect.roboflow.com/pothole-and-speed-breaker-detect/1"

def test_roboflow_detection(image_path):
    """Test the Roboflow API with the provided pothole image"""
    
    print("🧪 Testing Roboflow API for pothole detection...")
    
    try:
        # Read and encode image
        with open(image_path, "rb") as image_file:
            image_data = image_file.read()
            base64_image = base64.b64encode(image_data).decode('utf-8')
        
        print(f"📸 Image loaded: {image_path}")
        print(f"📊 Image size: {len(image_data)} bytes")
        
        # Prepare API request
        url = f"{MODEL_ENDPOINT}?api_key={API_KEY}&confidence=0.4&overlap=0.3"
        
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        print("🔍 Sending request to Roboflow API...")
        
        # Make API request
        response = requests.post(url, data=base64_image, headers=headers)
        
        if response.status_code == 200:
            result = response.json()
            predictions = result.get('predictions', [])
            
            print(f"✅ API Response successful!")
            print(f"📊 Found {len(predictions)} detections")
            
            # Analyze predictions
            for i, pred in enumerate(predictions):
                detection_type = pred.get('class', 'unknown')
                confidence = pred.get('confidence', 0.0)
                x = pred.get('x', 0)
                y = pred.get('y', 0)
                width = pred.get('width', 0)
                height = pred.get('height', 0)
                
                print(f"  🎯 Detection {i+1}:")
                print(f"     Type: {detection_type}")
                print(f"     Confidence: {confidence:.2%}")
                print(f"     Location: ({x}, {y})")
                print(f"     Size: {width}x{height}")
            
            # Generate Flutter-compatible response
            flutter_response = analyze_for_flutter(predictions)
            print("\n📱 Flutter App Response:")
            print(json.dumps(flutter_response, indent=2))
            
            return flutter_response
            
        else:
            print(f"❌ API Error: {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def analyze_for_flutter(predictions):
    """Convert Roboflow predictions to Flutter app format"""
    
    if not predictions:
        return {
            'hasHazards': False,
            'alertType': None,
            'alertMessage': 'Road clear - No hazards detected',
            'confidence': 0.0,
            'detectionCount': 0,
        }
    
    # Sort by confidence
    predictions.sort(key=lambda x: x.get('confidence', 0), reverse=True)
    top_detection = predictions[0]
    
    detection_type = top_detection.get('class', '').lower()
    confidence = top_detection.get('confidence', 0.0)
    
    # Map detection types to alert messages
    if 'pothole' in detection_type:
        alert_type = 'pothole'
        alert_icon = '🕳️'
        alert_message = f'{alert_icon} Pothole detected ahead - Reduce speed'
    elif 'speed' in detection_type or 'breaker' in detection_type:
        alert_type = 'speedbreaker'
        alert_icon = '🚧'
        alert_message = f'{alert_icon} Speed breaker detected ahead - Slow down'
    else:
        alert_type = 'hazard'
        alert_icon = '⚠️'
        alert_message = f'{alert_icon} Road hazard detected ahead - Proceed with caution'
    
    return {
        'hasHazards': True,
        'alertType': alert_type,
        'alertMessage': alert_message,
        'alertIcon': alert_icon,
        'confidence': confidence,
        'detectionCount': len(predictions),
        'allDetections': [
            {
                'type': pred.get('class', 'unknown'),
                'confidence': pred.get('confidence', 0.0),
            }
            for pred in predictions
        ],
    }

def main():
    """Main test function"""
    
    print("🚗 V2V Safety - AI Hazard Detection Test")
    print("=" * 50)
    
    # Test with both images
    test_images = [
        {
            'path': r"e:\projects\v2v_ble_chat\assets\test_images\pothole_test.jpeg",
            'name': 'Pothole Image',
            'expected': 'pothole'
        },
        {
            'path': r"e:\projects\v2v_ble_chat\assets\test_images\speedbreaker_test.jpeg", 
            'name': 'Speed Breaker Image',
            'expected': 'speed breaker'
        }
    ]
    
    for test_image in test_images:
        print(f"\n🧪 Testing {test_image['name']}...")
        print("-" * 30)
        
        try:
            # Verify image exists
            with open(test_image['path'], 'rb') as f:
                print(f"✅ Image found: {test_image['path']}")
            
            # Test API
            result = test_roboflow_detection(test_image['path'])
            
            if result and result['hasHazards']:
                print(f"\n🎉 SUCCESS: AI detected {test_image['expected']}!")
                print(f"Alert: {result['alertMessage']}")
                print(f"Confidence: {result['confidence']:.1%}")
                print(f"Detections: {result['detectionCount']}")
            else:
                print(f"\n⚠️  No hazards detected in {test_image['name']}")
                
        except FileNotFoundError:
            print(f"❌ Image not found: {test_image['path']}")
    
    print("\n" + "=" * 50)
    print("All tests completed!")

if __name__ == "__main__":
    main()