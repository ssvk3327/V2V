@echo off
echo Starting V2V Safety Communication Demo...
echo.

echo Step 1: Starting WebSocket Server...
start "V2V Server" cmd /k "cd /d e:\projects\v2v_ble_chat && node server.js"
timeout /t 3 /nobreak >nul

echo Step 2: Starting Vehicle A (First Emulator)...
start "Vehicle A" cmd /k "cd /d e:\projects\v2v_ble_chat && flutter run -d emulator-5554"
timeout /t 10 /nobreak >nul

echo Step 3: Starting Vehicle B (Second Emulator)...
start "Vehicle B" cmd /k "cd /d e:\projects\v2v_ble_chat && flutter run -d emulator-5556"

echo.
echo Demo started! 
echo - First emulator (emulator-5554) = Vehicle A
echo - Second emulator (emulator-5556) = Vehicle B
echo.
echo Press any key to exit...
pause >nul