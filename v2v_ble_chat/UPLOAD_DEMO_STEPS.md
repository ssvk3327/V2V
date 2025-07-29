# 📤 Manual Upload Demo - Step by Step Process

## 🎯 **EXACT WORKFLOW: Upload → Process → Display Output**

### **Step 1: Upload Pothole Image**
```
1. Open Vehicle A (emulator-5554)
2. Tap "🤖 AI Hazard Detection" (purple button)
3. Select "📷 Camera Upload" or "🖼️ Gallery Upload"
4. Choose/capture an image with potholes
5. Watch upload process begin...
```

### **Step 2: Processing Phase**
```
Expected Messages During Processing:
- "System: 📤 Uploading image to backend for processing..."
- "System: 📊 Processing... 20%" (reading file)
- "System: 📊 Processing... 40%" (encoding)
- "System: 📊 Processing... 60%" (uploading)
- "System: 📊 Processing... 80%" (backend AI processing)
- "System: 🤖 Backend AI: X hazard(s) found (nearest: X.Xm)"
- "System: 📡 Source: backend_api"
```

### **Step 3: Output Display**
```
Visual Results Screen Opens:
- Original uploaded image displayed
- Red bounding boxes around detected potholes
- Distance labels: "🕳️ potholes 85% (1.1 m)"
- Summary: "🎯 Detection Summary: Pothole detected 1.1 m ahead - Reduce speed"
- V2V Alert sent to other vehicle
```

### **Step 4: Upload Speed Breaker Image**
```
1. Tap "🤖 AI Hazard Detection" again
2. Select "🖼️ Gallery Upload" 
3. Choose an image with speed breakers
4. Watch processing again...
```

### **Step 5: Speed Breaker Processing**
```
Processing Messages:
- Upload progress tracking
- Backend AI analysis
- "System: 🤖 Backend AI: 1 hazard(s) found (nearest: 2.7m)"
```

### **Step 6: Speed Breaker Output**
```
Visual Results:
- Speed breaker image displayed
- Orange bounding box: "🚧 broken road 57% (2.7 m)"
- V2V Alert: "🚧 Speed breaker detected 2.7 m ahead - Slow down"
```