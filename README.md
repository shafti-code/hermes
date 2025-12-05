# Messager of the gods, or just a barebones server implementation for video games
i dont know what to tell you its just a zig udp server made to power a very specific video game, a template almost but not really
mainly develped for a gamejam as part of our game dev ecosystem
powered by enet

run with
```
zig build run
```


# Hermes Protocol - Packet Documentation
```
[0] = 3
[1..16] = client uuid (the joiner)
[17..32] = host uuid (the room owner's uuid)
```
Server forwards a packet to the host (owner) with the following format:

`[3][16-byte-joiner-nametag]` (the host receives the joiner's nametag).

---

### list_rooms (4)
Request size: 1 byte

```
[0] = 4
```
Server replies with a variable-length packet: first byte is 4, followed by zero or more entries: each entry is `[16-byte-host-uuid][16-byte-room-name]`.

Parsing: iterate every 32 bytes after the first to get host id + name.

---

### leave_room (5)
Request size: 1 + 16 + 16 = 33 bytes

```
[0] = 5
[1..16] = client uuid
[17..32] = opponent uuid
```
Server will update room state and send to the opponent a 2-byte packet: `[5][should_leave_flag (0/1)]`.

---

### begin_match (6)
Client may receive `[6]` from server to indicate match start. Typically server sends `[6]` to both players when ready.

---

### loaded (7)
Request size: 1 + 16 = 17 bytes

```
[0] = 7
[1..16] = client uuid
```
Server marks player as loaded and, when both players have sent loaded, sends `[6]` (begin_match) to both.

---

### start_game (8)
Request size: 1 + 16 = 17 bytes

```
[0] = 8
[1..16] = client uuid
```
Server notifies both players with status responses `[8][Result]`.

---

### game_packet (9)
Client -> server: used to send short in-game messages between players. Expected client packet size (server code expects): 1 + 16 + 9 = 26 bytes

```
[0] = 9
[1..16] = client uuid
[17..25] = payload (9 bytes)
```
Server will forward a 10-byte packet to the opponent: `[9][payload (9 bytes)]` on channel 1 unsequenced.


---

## Notes
- Strings (nametag, room name) are fixed 16 bytes on the wire; pad or truncate as needed. They are not guaranteed NUL-terminated.
- All packets sent by the client should be reliable unless stated otherwise. `game_packet` is forwarded unsequenced on channel 1 by the server; use that for real-time small updates.
- For list parsing, be cautious if the server returns zero rooms (packet length will be 1).

