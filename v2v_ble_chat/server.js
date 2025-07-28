const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

let vehicles = [];
let vehicleCounter = 0;

console.log('🚗 V2V Safety Communication Server started on port 8080');

wss.on('connection', function connection(ws) {
  // Clean up any closed connections first
  vehicles = vehicles.filter(vehicle => vehicle.ws.readyState === WebSocket.OPEN);
  
  vehicleCounter++;
  const vehicleInfo = {
    ws: ws,
    id: `Vehicle_${vehicleCounter}`,
    connectedAt: new Date().toLocaleTimeString()
  };
  
  vehicles.push(vehicleInfo);
  
  console.log(`🚗 ${vehicleInfo.id} connected at ${vehicleInfo.connectedAt}. Active vehicles: ${vehicles.length}`);
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'system',
    message: `Connected as ${vehicleInfo.id}. ${vehicles.length} vehicle(s) in network.`
  }));
  
  // Broadcast to other vehicles that a new vehicle joined
  vehicles.forEach(vehicle => {
    if (vehicle.ws !== ws && vehicle.ws.readyState === WebSocket.OPEN) {
      vehicle.ws.send(JSON.stringify({
        type: 'system',
        message: `${vehicleInfo.id} joined the V2V network`
      }));
    }
  });

  ws.on('message', function incoming(data) {
    try {
      const message = JSON.parse(data);
      console.log('Received:', message);
      
      // Determine message type
      const messageType = message.type || 'peer';
      
      // Broadcast message to all other vehicles
      vehicles.forEach(vehicle => {
        if (vehicle.ws !== ws && vehicle.ws.readyState === WebSocket.OPEN) {
          if (messageType === 'alert') {
            vehicle.ws.send(JSON.stringify({
              type: 'alert',
              message: message.message,
              sender: message.sender || 'Unknown Vehicle',
              alertType: message.alertType
            }));
          } else {
            vehicle.ws.send(JSON.stringify({
              type: 'peer',
              message: message.message,
              sender: message.sender || 'Unknown Vehicle'
            }));
          }
        }
      });
    } catch (e) {
      console.error('Error parsing message:', e);
    }
  });

  ws.on('close', function() {
    const disconnectedVehicle = vehicles.find(vehicle => vehicle.ws === ws);
    vehicles = vehicles.filter(vehicle => vehicle.ws !== ws);
    
    if (disconnectedVehicle) {
      console.log(`🚗 ${disconnectedVehicle.id} disconnected. Active vehicles: ${vehicles.length}`);
      
      // Notify remaining vehicles
      vehicles.forEach(vehicle => {
        if (vehicle.ws.readyState === WebSocket.OPEN) {
          vehicle.ws.send(JSON.stringify({
            type: 'system',
            message: `${disconnectedVehicle.id} left the V2V network`
          }));
        }
      });
    }
  });
});