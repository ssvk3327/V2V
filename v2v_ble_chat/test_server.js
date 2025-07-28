const WebSocket = require('ws');

console.log('Testing WebSocket server connection...');

const ws = new WebSocket('ws://localhost:8080');

ws.on('open', function open() {
  console.log('✅ Connected to server successfully!');
  
  // Send a test message
  ws.send(JSON.stringify({
    message: 'Hello from test client!',
    sender: 'Test_Vehicle_001'
  }));
});

ws.on('message', function message(data) {
  console.log('📨 Received:', JSON.parse(data));
});

ws.on('error', function error(err) {
  console.log('❌ Connection error:', err.message);
});

ws.on('close', function close() {
  console.log('🔌 Connection closed');
  process.exit(0);
});

// Close after 5 seconds
setTimeout(() => {
  ws.close();
}, 5000);