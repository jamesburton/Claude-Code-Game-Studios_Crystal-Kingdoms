# Online Multiplayer

> **Status**: Future Plan (Post-V1)
> **Author**: user + agents
> **Last Updated**: 2026-03-28
> **Target Sprint**: Sprint 7+

## Overview

Online multiplayer allows Crystal Kingdoms players on different devices and locations to compete in real-time matches. Players create or join games via a room code, with low-latency event synchronization ensuring the cursor-racing mechanic feels responsive across the network. The system supports both self-hosted servers (for LAN/private use) and shared cloud services.

## Architecture Options

### Option A: SignalR (Recommended for .NET hosts)

- **Server**: ASP.NET Core with SignalR hub
- **Transport**: WebSockets (primary), Server-Sent Events (fallback)
- **Latency**: ~20-50ms on good connections
- **Self-host**: Single binary, runs on any machine with .NET runtime
- **Cloud**: Azure SignalR Service, or deploy to any VPS
- **Godot client**: WebSocket connection via Godot's WebSocketPeer

### Option B: WebSocket Server (Lightweight)

- **Server**: Node.js or Go WebSocket server
- **Transport**: Raw WebSockets
- **Latency**: ~20-50ms
- **Self-host**: Single binary or Docker container
- **Cloud**: Fly.io, Railway, or any VPS
- **Godot client**: Native WebSocketPeer

### Option C: WebRTC (Peer-to-Peer)

- **Server**: Minimal signaling server only (for connection establishment)
- **Transport**: Direct peer-to-peer UDP
- **Latency**: Lowest possible (~10-30ms)
- **Self-host**: Only need signaling server
- **Cloud**: Free STUN/TURN servers available
- **Godot client**: WebRTCPeerConnection (built-in)
- **Tradeoff**: More complex NAT traversal; no server authority

### Recommendation

**SignalR for cloud/shared hosting, WebSocket for self-host simplicity, WebRTC as stretch goal for lowest latency.** Start with WebSocket (simplest) and add SignalR adapter for Azure hosting.

## Core Features

### Room System

- **Create Room**: Host generates a 6-character room code (e.g., "CK-A3F9")
- **Join Room**: Players enter code to join; room shows player list with ready status
- **Room Settings**: Host configures match settings (grid, players, timing, etc.)
- **Quick Match**: Auto-matchmaking for public games (future)

### Connection Flow

```
1. Player opens Online menu
2. Choose: Create Room / Join Room
3. Create: server generates room code, player becomes host
4. Join: enter code, connect to room
5. Lobby: see player list, host configures match
6. Host presses Start → match begins for all connected players
7. During match: events synced via server
8. Match end: results shown, option to rematch
```

### Network Synchronization Model

**Server-authoritative with client prediction:**

1. **Cursor spawn**: Server decides cursor position and broadcasts to all clients
2. **Player action**: Client sends action immediately (local prediction)
3. **Server validates**: Server runs RulesEngine, broadcasts authoritative EventLog
4. **Client reconciles**: If prediction matches server, smooth; if not, snap to server state
5. **Latency compensation**: Actions timestamped; server uses earliest valid timestamp for claim racing

### Event Protocol

```
// Client → Server
ActionMessage:
    room_id: string
    player_id: string
    direction: int          // -1 tap, 0-3 directions
    timestamp: float        // client-side timestamp for ordering

// Server → All Clients
CursorSpawnMessage:
    cursor_index: int
    expire_time: float

EventLogMessage:
    actor_id: string
    events: Array[Event]    // same format as local EventLog

MatchEndMessage:
    summary: MatchSummary

// Lobby
RoomStateMessage:
    room_code: string
    players: Array[PlayerInfo]
    config: GameConfig (serialized)
    state: "lobby" | "playing" | "finished"
```

### Latency Handling

- **Claim racing**: Server timestamps incoming actions; earliest wins (with configurable grace window for network jitter)
- **Visual cursor**: Clients show cursor immediately on spawn; if another player claims first, cursor disappears with "claimed by X" flash
- **Chain animation**: Plays from EventLog on all clients simultaneously
- **Disconnection**: Player marked inactive; CPU takes over after 10s timeout (configurable)

## Self-Hosting

### Requirements
- Any machine that can run a WebSocket server (Node.js, .NET, Go, Python)
- LAN play: zero configuration, server auto-discovered via mDNS/broadcast
- Internet play: port forwarding or VPN (Tailscale, ZeroTier)

### Docker Image
```dockerfile
FROM node:20-slim
COPY server/ /app
WORKDIR /app
RUN npm install
EXPOSE 8080
CMD ["node", "server.js"]
```

### LAN Discovery
- Server broadcasts presence on UDP port 19736
- Clients listen for broadcasts and show "LAN Games" list
- No room code needed for LAN — just click to join

## Shared/Cloud Hosting

### Options
- **Azure SignalR Service**: Managed, auto-scaling, free tier available
- **Fly.io / Railway**: Deploy Docker container, ~$5/month
- **Cloudflare Workers + Durable Objects**: Edge-based, very low latency
- **Supabase Realtime**: PostgreSQL + WebSocket pub/sub

### Default Public Server
- Host a free-tier instance for the web version
- Players can switch to self-hosted via settings
- Rate-limited to prevent abuse

## Implementation Phases

### Phase 1: Local Network (Sprint 7)
- WebSocket server in GDScript (runs in-process for host)
- LAN discovery via UDP broadcast
- 2-8 players on same network
- No room codes needed — just connect

### Phase 2: Internet Play (Sprint 8)
- Standalone server (Node.js or Go)
- Room codes for joining
- NAT traversal guidance (port forward or VPN)
- Docker image for self-hosting

### Phase 3: Cloud Service (Sprint 9)
- SignalR or managed WebSocket service
- Public matchmaking server
- Account-free play (session tokens)
- Anti-cheat basics (server-authoritative)

### Phase 4: Social Features (Sprint 10+)
- Friend list (via room code history)
- Spectator mode (watch live matches)
- Ranked matchmaking
- Cross-platform (web ↔ desktop)

## Dependencies

| System | Direction | Interface |
|--------|-----------|-----------|
| **GameConfig** | Network serializes | Full config sent to all clients on match start |
| **RulesEngine** | Server runs authoritative copy | Clients may run local prediction |
| **TurnDirector** | Server owns cursor timing | Clients display cursor from server messages |
| **MatchFlow** | Server owns match state | Clients receive score updates via events |
| **Input System** | Clients send actions to server | Server validates and broadcasts |

## Open Questions

| Question | Notes |
|----------|-------|
| Should web version use the same protocol as desktop? | Yes — WebSocket works in browsers natively |
| How to handle >200ms latency gracefully? | Show "waiting for server" indicator; extend claim window |
| Should replays work for online matches? | Yes — server can save EventLog; clients request download |
| Voice chat? | Out of scope — use Discord/external |
