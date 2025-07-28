const WebSocket = require('ws');

console.log('🧪 Testing Sender Name Display...\n');

const vehicleA = new WebSocket('ws://localhost:8080');
const vehicleB = new WebSocket('ws://localhost:8080');

let messagesReceived = [];

vehicleA.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 Vehicle A received:', msg.message);
  if (msg.type === 'alert') {
    console.log(`   ✅ Alert sender: "${msg.sender}"`);
    messagesReceived.push({receiver: 'A', sender: msg.sender, type: 'alert'});
  }
});

vehicleB.on('message', function message(data) {
  const msg = JSON.parse(data);
  console.log('📱 Vehicle B received:', msg.message);
  if (msg.type === 'alert') {
    console.log(`   ✅ Alert sender: "${msg.sender}"`);
    messagesReceived.push({receiver: 'B', sender: msg.sender, type: 'alert'});
  }
});

// Wait for connections then test alerts
setTimeout(() => {
  console.log('\n🚨 Vehicle A sending pothole alert...');
  vehicleA.send(JSON.stringify({
    type: 'alert',
    message: '🕳️ Pothole ahead - Reduce speed',
    sender: 'Vehicle A',
    alertType: 'pothole'
  }));
  
  setTimeout(() => {
    console.log('\n🚨 Vehicle B sending accident alert...');
    vehicleB.send(JSON.stringify({
      type: 'alert',
      message: '🚨 Accident reported - Use alternate route',
      sender: 'Vehicle B',
      alertType: 'accident'
    }));
    
    setTimeout(() => {
      console.log('\n📊 Sender Name Test Results:');
      messagesReceived.forEach(msg => {
        console.log(`- Vehicle ${msg.receiver} received alert from: "${msg.sender}"`);
        if (msg.sender === 'Vehicle A' || msg.sender === 'Vehicle B') {
          console.log('  ✅ Sender name correct!');
        } else {
          console.log('  ❌ Sender name incorrect!');
        }
      });
      
      vehicleA.close();
      vehicleB.close();
      process.exit(0);
    }, 1000);
  }, 1000);
}, 2000);