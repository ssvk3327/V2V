@echo off
echo 🚗 Starting V2V Safety Communication with AI Hazard Detection
echo ================================================================

echo.
echo 🔧 Step 1: Starting WebSocket server...
start "V2V Server" cmd /k "cd /d %~dp0 && node server.js"

echo.
echo ⏳ Waiting for server to initialize...
timeout /t 3 /nobreak >nul

echo.
echo 📱 Step 2: Starting Vehicle A (emulator-5554)...
start "Vehicle A" cmd /k "cd /d %~dp0 && flutter run -d emulator-5554"

echo.
echo ⏳ Waiting for Vehicle A to initialize...
timeout /t 10 /nobreak >nul

echo.
echo 📱 Step 3: Starting Vehicle B (emulator-5556)...
start "Vehicle B" cmd /k "cd /d %~dp0 && flutter run -d emulator-5556"

echo.
echo ✅ All components started!
echo.
echo 🎯 Demo Features:
echo   • Manual vehicle connection (100m range limit)
echo   • Real-time range simulation
echo   • Quick safety alerts (manual)
echo   • 🤖 AI Hazard Detection (NEW!)
echo     - Camera capture
echo     - Gallery selection  
echo     - Test AI with sample pothole image
echo.
echo 📋 Demo Script:
echo   1. Wait for both vehicles to show proper names
echo   2. Press Connect button when in range
echo   3. Test manual safety alerts
echo   4. Try AI Detection button:
echo      - "Test AI" = Analyze sample pothole image
echo      - "Camera" = Take photo for analysis
echo      - "Gallery" = Select image for analysis
echo   5. Watch automatic alerts when hazards detected
echo.
echo Press any key to close this window...
pause >nul