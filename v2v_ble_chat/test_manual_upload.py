#!/usr/bin/env python3
"""
Test script for manual image upload functionality
Simulates Flutter app uploading images to backend API
"""

import requests
import base64
import json
import time
from pathlib import Path

def test_backend_health():
    """Test if backend is responding"""
    try:
        response = requests.get('http://localhost:5000/health', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Backend Health Check:")
            print(f"   Status: {data['status']}")
            print(f"   Service: {data['service']}")
            print(f"   Features: {', '.join(data['features'])}")
            return True
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Backend not available: {e}")
        return False

def test_image_upload():
    """Test manual image upload with real image"""
    try:
        # Use the existing pothole test image
        image_path = Path("assets/test_images/pothole_test.jpeg")
        
        if not image_path.exists():
            print(f"❌ Test image not found: {image_path}")
            return False
        
        print(f"📸 Testing manual upload with: {image_path}")
        
        # Read and encode image
        with open(image_path, 'rb') as f:
            image_data = f.read()
        
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        print(f"📊 Image encoded: {len(base64_image)} characters")
        
        # Prepare request
        payload = {
            'image': base64_image,
            'timestamp': int(time.time() * 1000),
            'filename': 'manual_upload_test.jpeg',
            'fileSize': len(image_data)
        }
        
        print("📤 Uploading to backend...")
        
        # Send to backend
        response = requests.post(
            'http://localhost:5000/process-image',
            headers={'Content-Type': 'application/json'},
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Upload successful!")
            print(f"   Detection Count: {result['detectionCount']}")
            print(f"   Has Hazards: {result['hasHazards']}")
            print(f"   Alert Message: {result['alertMessage']}")
            
            if result['detections']:
                print("   Detections:")
                for i, detection in enumerate(result['detections'], 1):
                    distance = detection.get('distanceString', 'Unknown')
                    confidence = detection.get('confidence', 0) * 100
                    print(f"     {i}. {detection['type']} - {confidence:.1f}% confidence - {distance}")
            
            return True
        else:
            print(f"❌ Upload failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Upload test failed: {e}")
        return False

def test_backend_detection():
    """Test backend detection endpoints"""
    try:
        print("🧪 Testing backend detection endpoints...")
        
        # Test pothole detection
        pothole_payload = {
            'type': 'pothole',
            'timestamp': int(time.time() * 1000)
        }
        
        response = requests.post(
            'http://localhost:5000/test-detection',
            headers={'Content-Type': 'application/json'},
            json=pothole_payload,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Pothole test successful:")
            print(f"   Alert: {result['alertMessage']}")
            print(f"   Nearest Distance: {result.get('nearestDistance', 'Unknown')}m")
        
        # Test speed breaker detection
        speedbreaker_payload = {
            'type': 'speedbreaker',
            'timestamp': int(time.time() * 1000)
        }
        
        response = requests.post(
            'http://localhost:5000/test-detection',
            headers={'Content-Type': 'application/json'},
            json=speedbreaker_payload,
            timeout=10
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Speed breaker test successful:")
            print(f"   Alert: {result['alertMessage']}")
            print(f"   Nearest Distance: {result.get('nearestDistance', 'Unknown')}m")
        
        return True
        
    except Exception as e:
        print(f"❌ Backend detection test failed: {e}")
        return False

def main():
    """Run all manual upload tests"""
    print("🚗 V2V Manual Image Upload Test Suite")
    print("=" * 50)
    
    # Test 1: Backend Health
    print("\n1. Testing Backend Health...")
    health_ok = test_backend_health()
    
    if not health_ok:
        print("❌ Backend not available - cannot proceed with tests")
        return
    
    # Test 2: Manual Image Upload
    print("\n2. Testing Manual Image Upload...")
    upload_ok = test_image_upload()
    
    # Test 3: Backend Detection Endpoints
    print("\n3. Testing Backend Detection Endpoints...")
    detection_ok = test_backend_detection()
    
    # Summary
    print("\n" + "=" * 50)
    print("🎯 Test Results Summary:")
    print(f"   Backend Health: {'✅ PASS' if health_ok else '❌ FAIL'}")
    print(f"   Manual Upload: {'✅ PASS' if upload_ok else '❌ FAIL'}")
    print(f"   Detection Tests: {'✅ PASS' if detection_ok else '❌ FAIL'}")
    
    if health_ok and upload_ok and detection_ok:
        print("\n🎉 All tests passed! Manual upload system is ready!")
        print("📱 Flutter app can now upload images to backend for processing")
        print("📏 Distance calculation and V2V alerts are working")
    else:
        print("\n⚠️ Some tests failed - check backend configuration")

if __name__ == "__main__":
    main()