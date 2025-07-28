const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

let vehicles = [];
let vehicleCounter = 0;
let emulatorAssignments = {}; // Track which emulator gets which vehicle name

console.log('🚗 V2V Safety Communication Server started on port 8080');

wss.on('connection', function connection(ws) {
  // Clean up any closed connections first
  vehicles = vehicles.filter(vehicle => vehicle.ws.readyState === WebSocket.OPEN);
  
  // Assign Vehicle A or Vehicle B based on connection order
  let vehicleName;
  const connectionTime = Date.now();
  
  if (vehicles.length === 0) {
    vehicleName = 'Vehicle A';
    console.log('🚗 First emulator connected - assigning as Vehicle A');
  } else if (vehicles.length === 1) {
    vehicleName = 'Vehicle B';
    console.log('🚗 Second emulator connected - assigning as Vehicle B');
  } else {
    vehicleName = `Vehicle ${String.fromCharCode(65 + vehicles.length)}`; // C, D, etc.
  }
  
  const vehicleInfo = {
    ws: ws,
    id: vehicleName,
    connectedAt: new Date().toLocaleTimeString(),
    connectionTime: connectionTime
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
      
      // Find the sending vehicle to get correct name
      const sendingVehicle = vehicles.find(v => v.ws === ws);
      const senderName = sendingVehicle ? sendingVehicle.id : (message.sender || 'Unknown Vehicle');
      
      // Determine message type
      const messageType = message.type || 'peer';
      
      // Handle connection management messages
      if (messageType === 'connect_request' || messageType === 'connect_confirm' || messageType === 'disconnect_request') {
        console.log(`📡 ${messageType} from ${senderName}`);
      }
      
      // Broadcast message to all other vehicles
      vehicles.forEach(vehicle => {
        if (vehicle.ws !== ws && vehicle.ws.readyState === WebSocket.OPEN) {
          if (messageType === 'alert') {
            vehicle.ws.send(JSON.stringify({
              type: 'alert',
              message: message.message,
              sender: senderName,
              alertType: message.alertType
            }));
          } else if (messageType === 'connect_request') {
            vehicle.ws.send(JSON.stringify({
              type: 'connect_request',
              sender: senderName,
              timestamp: message.timestamp
            }));
          } else if (messageType === 'connect_confirm') {
            vehicle.ws.send(JSON.stringify({
              type: 'connect_confirm',
              sender: senderName,
              timestamp: message.timestamp
            }));
          } else if (messageType === 'disconnect_request') {
            vehicle.ws.send(JSON.stringify({
              type: 'disconnect_request',
              sender: senderName,
              timestamp: message.timestamp
            }));
          } else {
            vehicle.ws.send(JSON.stringify({
              type: 'peer',
              message: message.message,
              sender: senderName
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