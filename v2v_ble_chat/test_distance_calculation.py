#!/usr/bin/env python3
"""
Distance Calculation Test for V2V Safety System
Tests the distance calculation functionality using the provided code logic
"""

import requests
import base64
import json

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

def test_roboflow_with_distance(image_path):
    """Test Roboflow API and calculate distances"""
    API_KEY = "g1iMaJma6G9wZZ2Fm5PN"
    MODEL_ENDPOINT = "https://detect.roboflow.com/pothole-and-speed-breaker-detect/1"
    
    try:
        print(f"🧪 Testing distance calculation for: {image_path}")
        print("-" * 50)
        
        # Read and encode image
        with open(image_path, 'rb') as f:
            image_data = f.read()
        
        base64_image = base64.b64encode(image_data).decode('utf-8')
        print(f"📸 Image loaded: {len(image_data)} bytes")
        
        # Send to API
        response = requests.post(
            MODEL_ENDPOINT,
            params={
                'api_key': API_KEY,
                'confidence': 0.4,
                'overlap': 0.3,
            },
            data=base64_image,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        
        if response.status_code == 200:
            data = response.json()
            predictions = data.get('predictions', [])
            
            print(f"✅ API Response successful!")
            print(f"📊 Found {len(predictions)} detections")
            
            distances = []
            
            for i, pred in enumerate(predictions):
                obj_type = pred['class']
                confidence = pred['confidence']
                x = pred['x']
                y = pred['y']
                width = pred['width']
                height = pred['height']
                
                # Calculate distance
                distance = calculate_distance(obj_type, width, height)
                distance_str = format_distance(distance)
                
                print(f"\n  🎯 Detection {i+1}:")
                print(f"     Type: {obj_type}")
                print(f"     Confidence: {confidence:.1%}")
                print(f"     Location: ({x}, {y})")
                print(f"     Size: {width}x{height} pixels")
                print(f"     📏 Estimated Distance: {distance_str}")
                
                if distance is not None:
                    distances.append({
                        'type': obj_type,
                        'confidence': confidence,
                        'x': x, 'y': y,
                        'width': width, 'height': height,
                        'distance': distance
                    })
            
            # Find nearest detection
            if distances:
                nearest = min(distances, key=lambda x: x['distance'])
                print(f"\n🎯 NEAREST DETECTION:")
                print(f"   Type: {nearest['type']}")
                print(f"   Location: ({nearest['x']}, {nearest['y']})")
                print(f"   Size: {nearest['width']}x{nearest['height']} pixels")
                print(f"   📏 Distance: {format_distance(nearest['distance'])}")
                print(f"   Confidence: {nearest['confidence']:.1%}")
                
                # Generate alert message
                if nearest['type'].lower() in ['potholes', 'pothole']:
                    alert = f"🕳️ Pothole detected {format_distance(nearest['distance'])} ahead - Reduce speed"
                elif nearest['type'].lower() in ['broken road', 'speed_breaker']:
                    alert = f"🚧 Speed breaker detected {format_distance(nearest['distance'])} ahead - Slow down"
                else:
                    alert = f"⚠️ Road hazard detected {format_distance(nearest['distance'])} ahead - Proceed with caution"
                
                print(f"\n📱 V2V Alert Message:")
                print(f"   {alert}")
                
                return {
                    'success': True,
                    'detections': len(predictions),
                    'nearest_distance': nearest['distance'],
                    'alert_message': alert
                }
            else:
                print("\n⚠️ No distance calculations possible (unknown object types)")
                return {'success': True, 'detections': len(predictions), 'nearest_distance': None}
                
        else:
            print(f"❌ API Error: {response.status_code}")
            return {'success': False, 'error': f"API Error: {response.status_code}"}
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return {'success': False, 'error': str(e)}

def main():
    """Test distance calculation with both images"""
    print("🚗 V2V Safety - Distance Calculation Test")
    print("=" * 60)
    
    test_images = [
        {
            'path': r"e:\projects\v2v_ble_chat\assets\test_images\pothole_test.jpeg",
            'name': 'Pothole Image (abc.jpeg)',
            'expected_type': 'pothole'
        },
        {
            'path': r"e:\projects\v2v_ble_chat\assets\test_images\speedbreaker_test.jpeg",
            'name': 'Speed Breaker Image',
            'expected_type': 'speed breaker'
        }
    ]
    
    results = []
    
    for test_image in test_images:
        print(f"\n🧪 Testing {test_image['name']}...")
        print("=" * 60)
        
        try:
            result = test_roboflow_with_distance(test_image['path'])
            results.append({
                'name': test_image['name'],
                'result': result
            })
        except FileNotFoundError:
            print(f"❌ Image not found: {test_image['path']}")
            results.append({
                'name': test_image['name'],
                'result': {'success': False, 'error': 'File not found'}
            })
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 DISTANCE CALCULATION TEST SUMMARY")
    print("=" * 60)
    
    for result in results:
        print(f"\n📸 {result['name']}:")
        if result['result']['success']:
            if result['result'].get('nearest_distance'):
                print(f"   ✅ Distance calculated: {format_distance(result['result']['nearest_distance'])}")
                print(f"   📱 Alert: {result['result'].get('alert_message', 'N/A')}")
            else:
                print(f"   ⚠️ Detection successful but no distance calculated")
            print(f"   🎯 Detections: {result['result'].get('detections', 0)}")
        else:
            print(f"   ❌ Failed: {result['result'].get('error', 'Unknown error')}")
    
    print(f"\n🎉 Distance calculation test completed!")
    print("This functionality is now integrated into the Flutter V2V app!")

if __name__ == "__main__":
    main()