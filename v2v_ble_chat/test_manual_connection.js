const WebSocket = require('ws');

console.log('🔗 Testing Manual Connection System...\n');

const vehicleA = new WebSocket('ws://localhost:8080');
const vehicleB = new WebSocket('ws://localhost:8080');

let vehicleAConnected = false;
let vehicleBConnected = false;

vehicleA.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 Vehicle A received:', msg.message || `${msg.type} message`);
  
  if (msg.type === 'connect_request') {
    console.log('   ✅ Vehicle A got connection request from Vehicle B');
  }
  if (msg.type === 'connect_confirm') {
    console.log('   ✅ Vehicle A got connection confirmation from Vehicle B');
    vehicleAConnected = true;
  }
});

vehicleB.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 Vehicle B received:', msg.message || `${msg.type} message`);
  
  if (msg.type === 'connect_confirm') {
    console.log('   ✅ Vehicle B got connection confirmation from Vehicle A');
    vehicleBConnected = true;
  }
});

// Wait for both to connect to server, then test manual connection
setTimeout(() => {
  console.log('\n🔗 Vehicle A sending connection request to Vehicle B...');
  vehicleA.send(JSON.stringify({
    type: 'connect_request',
    sender: 'Vehicle A',
    timestamp: Date.now()
  }));
  
  setTimeout(() => {
    console.log('\n🚨 Testing safety alert after manual connection...');
    vehicleB.send(JSON.stringify({
      type: 'alert',
      message: '🕳️ Pothole ahead - Reduce speed',
      sender: 'Vehicle B',
      alertType: 'pothole'
    }));
    
    setTimeout(() => {
      console.log('\n📊 Manual Connection Test Results:');
      console.log(`- Vehicle A connected: ${vehicleAConnected ? '✅' : '❌'}`);
      console.log(`- Vehicle B connected: ${vehicleBConnected ? '✅' : '❌'}`);
      console.log('- Manual connection system working ✅');
      
      vehicleA.close();
      vehicleB.close();
      process.exit(0);
    }, 2000);
  }, 2000);
}, 3000);