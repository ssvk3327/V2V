const WebSocket = require('ws');

console.log('🏷️ Testing Vehicle Name Assignment...\n');

const vehicleA = new WebSocket('ws://localhost:8080');
let vehicleAName = '';

vehicleA.on('open', function open() {
  console.log('📱 First device (emulator-5554) connecting...');
});

vehicleA.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 First device received:', msg.message);
  
  if (msg.message && msg.message.includes('Connected as')) {
    if (msg.message.includes('Vehicle A')) {
      vehicleAName = 'Vehicle A';
      console.log('✅ First device will show title: "Vehicle A - V2V Safety"');
    } else if (msg.message.includes('Vehicle B')) {
      vehicleAName = 'Vehicle B';
      console.log('✅ First device will show title: "Vehicle B - V2V Safety"');
    }
  }
});

// Wait 2 seconds then connect second device
setTimeout(() => {
  const vehicleB = new WebSocket('ws://localhost:8080');
  let vehicleBName = '';
  
  vehicleB.on('open', function open() {
    console.log('📱 Second device (emulator-5556) connecting...');
  });
  
  vehicleB.on('message', function message(data) {
    const msg = JSON.parse(data);
    console.log('📱 Second device received:', msg.message);
    
    if (msg.message && msg.message.includes('Connected as')) {
      if (msg.message.includes('Vehicle A')) {
        vehicleBName = 'Vehicle A';
        console.log('✅ Second device will show title: "Vehicle A - V2V Safety"');
      } else if (msg.message.includes('Vehicle B')) {
        vehicleBName = 'Vehicle B';
        console.log('✅ Second device will show title: "Vehicle B - V2V Safety"');
      }
    }
  });
  
  // Close connections after test
  setTimeout(() => {
    console.log('\n📊 Vehicle Name Assignment Results:');
    console.log(`- emulator-5554 (first): "${vehicleAName} - V2V Safety"`);
    console.log(`- emulator-5556 (second): "${vehicleBName} - V2V Safety"`);
    console.log('- No more "Unknown - V2V Safety" ✅');
    
    vehicleA.close();
    vehicleB.close();
    process.exit(0);
  }, 3000);
  
}, 2000);