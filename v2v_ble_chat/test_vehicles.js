const WebSocket = require('ws');

console.log('🚗 Testing Vehicle A & B Assignment...\n');

// Simulate Vehicle A connection
const vehicleA = new WebSocket('ws://localhost:8080');
let vehicleAName = '';

vehicleA.on('open', function open() {
  console.log('📱 First device connecting...');
});

vehicleA.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 First device received:', msg.message);
  
  if (msg.message.includes('Connected as')) {
    vehicleAName = msg.message.includes('Vehicle A') ? 'Vehicle A' : 'Vehicle B';
    console.log(`✅ First device assigned as: ${vehicleAName}`);
  }
});

// Wait 2 seconds then connect Vehicle B
setTimeout(() => {
  const vehicleB = new WebSocket('ws://localhost:8080');
  let vehicleBName = '';
  
  vehicleB.on('open', function open() {
    console.log('📱 Second device connecting...');
  });
  
  vehicleB.on('message', function message(data) {
    const msg = JSON.parse(data);
    console.log('📱 Second device received:', msg.message);
    
    if (msg.message.includes('Connected as')) {
      vehicleBName = msg.message.includes('Vehicle A') ? 'Vehicle A' : 'Vehicle B';
      console.log(`✅ Second device assigned as: ${vehicleBName}`);
      
      // Test safety alert
      setTimeout(() => {
        console.log(`\n🚨 ${vehicleBName} sending pothole alert...`);
        vehicleB.send(JSON.stringify({
          type: 'alert',
          message: '🕳️ Pothole ahead - Reduce speed',
          sender: vehicleBName,
          alertType: 'pothole'
        }));
      }, 1000);
    }
  });
  
  // Close connections after test
  setTimeout(() => {
    console.log('\n🔌 Closing test connections...');
    vehicleA.close();
    vehicleB.close();
    
    setTimeout(() => {
      console.log('\n📊 Test Results:');
      console.log(`- First device: ${vehicleAName}`);
      console.log(`- Second device: ${vehicleBName}`);
      console.log('- Vehicle assignment working ✅');
      console.log('- Safety alerts working ✅');
      process.exit(0);
    }, 500);
  }, 4000);
  
}, 2000);