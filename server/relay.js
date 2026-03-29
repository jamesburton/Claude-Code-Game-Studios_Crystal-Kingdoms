// Crystal Kingdoms — WebSocket Relay Server
// Forwards messages between host and clients using room codes.
// Deploy: node relay.js [port]

const { WebSocketServer } = require('ws');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || process.argv[2] || '8080');
const rooms = new Map(); // roomCode -> { host, clients: Map<ws, name>, spectators: Set<ws> }

const wss = new WebSocketServer({ port: PORT });
console.log(`Crystal Kingdoms Relay Server running on port ${PORT}`);

wss.on('connection', (ws) => {
  ws._room = null;
  ws._isHost = false;
  ws._isSpectator = false;

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());
      handleMessage(ws, msg);
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', msg: 'Invalid message' }));
    }
  });

  ws.on('close', () => {
    handleDisconnect(ws);
  });
});

function handleMessage(ws, msg) {
  switch (msg.type) {
    case 'create_room':
      createRoom(ws, msg.name || 'Host');
      break;
    case 'join_room':
      joinRoom(ws, msg.code, msg.name || 'Player', false);
      break;
    case 'spectate_room':
      joinRoom(ws, msg.code, msg.name || 'Spectator', true);
      break;
    default:
      // Forward all other messages within the room
      forwardMessage(ws, msg);
  }
}

function createRoom(ws, hostName) {
  const code = generateCode();
  rooms.set(code, {
    host: ws,
    hostName,
    clients: new Map(),
    spectators: new Set(),
    created: Date.now(),
  });
  ws._room = code;
  ws._isHost = true;
  ws.send(JSON.stringify({ type: 'room_created', code }));
  console.log(`Room ${code} created by ${hostName}`);
}

function joinRoom(ws, code, name, asSpectator) {
  const room = rooms.get(code);
  if (!room) {
    ws.send(JSON.stringify({ type: 'error', msg: 'Room not found' }));
    return;
  }

  ws._room = code;
  ws._isSpectator = asSpectator;

  if (asSpectator) {
    room.spectators.add(ws);
    ws.send(JSON.stringify({ type: 'joined', code, spectator: true }));
  } else {
    room.clients.set(ws, name);
    ws.send(JSON.stringify({ type: 'joined', code, spectator: false }));
    // Forward join to host
    if (room.host && room.host.readyState === 1) {
      room.host.send(JSON.stringify({ type: 'join', name }));
    }
  }
  console.log(`${name} ${asSpectator ? 'spectating' : 'joined'} room ${code}`);
}

function forwardMessage(ws, msg) {
  const code = ws._room;
  if (!code) return;
  const room = rooms.get(code);
  if (!room) return;

  const raw = JSON.stringify(msg);

  if (ws._isHost) {
    // Host → all clients + spectators
    for (const client of room.clients.keys()) {
      if (client.readyState === 1) client.send(raw);
    }
    for (const spec of room.spectators) {
      if (spec.readyState === 1) spec.send(raw);
    }
  } else if (!ws._isSpectator) {
    // Client → host only
    if (room.host && room.host.readyState === 1) {
      room.host.send(raw);
    }
  }
  // Spectators cannot send game messages
}

function handleDisconnect(ws) {
  const code = ws._room;
  if (!code) return;
  const room = rooms.get(code);
  if (!room) return;

  if (ws._isHost) {
    // Host left — close room
    for (const client of room.clients.keys()) {
      client.send(JSON.stringify({ type: 'error', msg: 'Host disconnected' }));
      client.close();
    }
    for (const spec of room.spectators) {
      spec.close();
    }
    rooms.delete(code);
    console.log(`Room ${code} closed (host left)`);
  } else if (ws._isSpectator) {
    room.spectators.delete(ws);
  } else {
    const name = room.clients.get(ws) || 'Unknown';
    room.clients.delete(ws);
    if (room.host && room.host.readyState === 1) {
      room.host.send(JSON.stringify({ type: 'left', name }));
    }
    console.log(`${name} left room ${code}`);
  }
}

function generateCode() {
  let code;
  do {
    code = 'CK-' + crypto.randomBytes(2).toString('hex').toUpperCase();
  } while (rooms.has(code));
  return code;
}

// Cleanup stale rooms every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.created > 3600000) { // 1 hour max
      console.log(`Cleaning stale room ${code}`);
      rooms.delete(code);
    }
  }
}, 300000);
