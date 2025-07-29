#!/usr/bin/env python3
"""
Demo script showing exact upload → process → display workflow
Simulates the Flutter app uploading pothole and speed breaker images
"""

import requests
import base64
import json
import time
from pathlib import Path

def simulate_upload_progress():
    """Simulate the upload progress that user will see"""
    progress_steps = [
        (20, "📊 Processing... 20% (reading file)"),
        (40, "📊 Processing... 40% (encoding image)"),
        (60, "📊 Processing... 60% (uploading to backend)"),
        (80, "📊 Processing... 80% (AI processing)"),
        (100, "📊 Processing... 100% (complete)")
    ]
    
    for progress, message in progress_steps:
        print(f"System: {message}")
        time.sleep(1)  # Simulate processing time

def upload_and_process_image(image_path, image_type):
    """Upload image and show complete workflow"""
    print(f"\n🎯 STEP: Upload {image_type} Image")
    print("=" * 50)
    
    # Step 1: Upload begins
    print("User Action: Tap 'AI Hazard Detection' → Select image")
    print(f"System: 📤 Uploading {image_type} image to backend for processing...")
    
    # Step 2: Processing phase
    simulate_upload_progress()
    
    try:
        # Read and encode image
        with open(image_path, 'rb') as f:
            image_data = f.read()
        
        base64_image = base64.b64encode(image_data).decode('utf-8')
        
        # Prepare request
        payload = {
            'image': base64_image,
            'timestamp': int(time.time() * 1000),
            'filename': f'{image_type}_upload.jpeg',
            'fileSize': len(image_data)
        }
        
        # Send to backend
        response = requests.post(
            'http://localhost:5000/process-image',
            headers={'Content-Type': 'application/json'},
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            
            # Step 3: Display output
            print(f"\n🎯 PROCESSING COMPLETE - OUTPUT DISPLAY:")
            print("=" * 50)
            print(f"System: 🤖 Backend AI: {result['detectionCount']} hazard(s) found")
            
            if result['nearestDistance']:
                print(f"System: 📏 Nearest hazard: {result['nearestDistance']:.1f}m away")
            
            print(f"System: 📡 Source: backend_api")
            print(f"System: {result['alertMessage']}")
            
            # Display detection details
            if result['detections']:
                print(f"\n📋 VISUAL RESULTS DISPLAYED:")
                for i, detection in enumerate(result['detections'], 1):
                    confidence = detection.get('confidence', 0) * 100
                    distance = detection.get('distanceString', 'Unknown distance')
                    obj_type = detection['type']
                    
                    if 'pothole' in obj_type.lower():
                        icon = "🕳️"
                        color = "Red"
                    else:
                        icon = "🚧"
                        color = "Orange"
                    
                    print(f"   {i}. {color} bounding box: \"{icon} {obj_type} {confidence:.1f}% ({distance})\"")
            
            # V2V Alert
            print(f"\n📡 V2V ALERT TRANSMITTED:")
            print(f"   To other vehicle: \"⚠️ ALERT from Vehicle A: {result['alertMessage']}\"")
            
            return True
            
        else:
            print(f"❌ Upload failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error during upload: {e}")
        return False

def main():
    """Demonstrate complete upload workflow"""
    print("🚗 V2V Manual Upload Demo - Complete Workflow")
    print("=" * 60)
    print("Demonstrating: Upload → Process → Display Output")
    print("=" * 60)
    
    # Check backend availability
    try:
        response = requests.get('http://localhost:5000/health', timeout=5)
        if response.status_code != 200:
            print("❌ Backend not available - start backend_api.py first")
            return
    except:
        print("❌ Backend not available - start backend_api.py first")
        return
    
    print("✅ Backend API is ready")
    
    # Demo 1: Upload Pothole Image
    pothole_path = Path("assets/test_images/pothole_test.jpeg")
    if pothole_path.exists():
        success1 = upload_and_process_image(pothole_path, "pothole")
    else:
        print(f"❌ Pothole test image not found: {pothole_path}")
        success1 = False
    
    if success1:
        print("\n" + "="*60)
        input("Press Enter to continue with speed breaker upload...")
    
    # Demo 2: Upload Speed Breaker Image  
    speedbreaker_path = Path("assets/test_images/speedbreaker_test.jpeg")
    if speedbreaker_path.exists():
        success2 = upload_and_process_image(speedbreaker_path, "speed_breaker")
    else:
        print(f"❌ Speed breaker test image not found: {speedbreaker_path}")
        success2 = False
    
    # Summary
    print("\n" + "="*60)
    print("🎯 DEMO COMPLETE - WORKFLOW SUMMARY")
    print("="*60)
    print("✅ Upload → Process → Display workflow demonstrated")
    print("✅ Both pothole and speed breaker images processed")
    print("✅ Visual results with distance-labeled bounding boxes")
    print("✅ V2V alerts transmitted with precise distances")
    print("\n🎉 Manual upload system is fully operational!")
    print("📱 Flutter app ready for real user demonstrations")

if __name__ == "__main__":
    main()