#!/usr/bin/env python3
"""
WebSocket Server for V2V Communication with Distance-Aware Alerts
Handles real-time communication between vehicles with distance information
"""

import asyncio
import websockets
import json
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class V2VServer:
    def __init__(self):
        self.connected_vehicles = {}
        self.message_history = []
        
    async def register_vehicle(self, websocket, vehicle_id):
        """Register a new vehicle connection"""
        self.connected_vehicles[vehicle_id] = {
            'websocket': websocket,
            'connected_at': datetime.now(),
            'last_seen': datetime.now()
        }
        logger.info(f"🚗 Vehicle {vehicle_id} connected. Total vehicles: {len(self.connected_vehicles)}")
        
        # Send welcome message with distance calculation capability
        welcome_msg = {
            'type': 'system',
            'message': f'Vehicle {vehicle_id} connected to V2V network with distance-aware hazard detection',
            'timestamp': datetime.now().isoformat(),
            'vehicle_count': len(self.connected_vehicles)
        }
        await websocket.send(json.dumps(welcome_msg))
        
    async def unregister_vehicle(self, vehicle_id):
        """Unregister a vehicle connection"""
        if vehicle_id in self.connected_vehicles:
            del self.connected_vehicles[vehicle_id]
            logger.info(f"🚗 Vehicle {vehicle_id} disconnected. Remaining vehicles: {len(self.connected_vehicles)}")
    
    async def broadcast_message(self, sender_id, message_data):
        """Broadcast message to all other vehicles"""
        if len(self.connected_vehicles) <= 1:
            logger.warning(f"📡 No other vehicles to receive message from {sender_id}")
            return
            
        # Add timestamp and sender info
        message_data['sender'] = sender_id
        message_data['timestamp'] = datetime.now().isoformat()
        
        # Store in history
        self.message_history.append(message_data)
        
        # Log distance-aware messages
        if 'distance' in message_data.get('message', ''):
            logger.info(f"📏 Distance-aware alert from {sender_id}: {message_data.get('message', '')}")
        else:
            logger.info(f"📡 Broadcasting from {sender_id}: {message_data.get('message', '')}")
        
        # Send to all other vehicles
        disconnected_vehicles = []
        for vehicle_id, vehicle_info in self.connected_vehicles.items():
            if vehicle_id != sender_id:
                try:
                    await vehicle_info['websocket'].send(json.dumps(message_data))
                    logger.info(f"✅ Message delivered to Vehicle {vehicle_id}")
                except websockets.exceptions.ConnectionClosed:
                    logger.warning(f"❌ Vehicle {vehicle_id} connection lost")
                    disconnected_vehicles.append(vehicle_id)
                except Exception as e:
                    logger.error(f"❌ Error sending to Vehicle {vehicle_id}: {e}")
                    disconnected_vehicles.append(vehicle_id)
        
        # Clean up disconnected vehicles
        for vehicle_id in disconnected_vehicles:
            await self.unregister_vehicle(vehicle_id)
    
    async def handle_vehicle_connection(self, websocket, path):
        """Handle individual vehicle WebSocket connections"""
        vehicle_id = None
        try:
            # Wait for vehicle identification
            async for message in websocket:
                try:
                    data = json.loads(message)
                    
                    if data.get('type') == 'register':
                        vehicle_id = data.get('vehicle_id')
                        await self.register_vehicle(websocket, vehicle_id)
                        
                    elif data.get('type') == 'message' and vehicle_id:
                        await self.broadcast_message(vehicle_id, data)
                        
                    elif data.get('type') == 'safety_alert' and vehicle_id:
                        # Special handling for distance-aware safety alerts
                        alert_data = data.copy()
                        alert_data['type'] = 'safety_alert'
                        await self.broadcast_message(vehicle_id, alert_data)
                        
                    else:
                        logger.warning(f"⚠️ Unknown message type from {vehicle_id}: {data}")
                        
                except json.JSONDecodeError:
                    logger.error(f"❌ Invalid JSON from {vehicle_id}: {message}")
                except Exception as e:
                    logger.error(f"❌ Error processing message from {vehicle_id}: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"🔌 Vehicle {vehicle_id} connection closed")
        except Exception as e:
            logger.error(f"❌ Connection error for {vehicle_id}: {e}")
        finally:
            if vehicle_id:
                await self.unregister_vehicle(vehicle_id)

async def main():
    """Start the V2V WebSocket server"""
    server = V2VServer()
    
    print("🚗 V2V Safety Communication Server with Distance Calculation")
    print("=" * 60)
    print("🌐 Starting WebSocket server on localhost:8080")
    print("📏 Distance-aware hazard detection enabled")
    print("🔄 Ready for vehicle connections...")
    print("=" * 60)
    
    # Start WebSocket server
    start_server = websockets.serve(
        server.handle_vehicle_connection,
        "localhost",
        8080,
        ping_interval=20,
        ping_timeout=10
    )
    
    logger.info("🚀 V2V Server started on ws://localhost:8080")
    logger.info("📡 Waiting for vehicle connections...")
    
    await start_server
    
    # Keep server running
    try:
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        logger.info("🛑 Server shutdown requested")
        print("\n🛑 V2V Server shutting down...")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 V2V Server stopped")
    except Exception as e:
        print(f"❌ Server error: {e}")