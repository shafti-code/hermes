#ifndef GAME_CLIENT_H
#define GAME_CLIENT_H

#include <enet/enet.h>
#include <stdint.h>
#include <stdbool.h>

// Matches Zig: const Request = enum(u8)
typedef enum {
    REQ_GET_UUID    = 0,
    REQ_ASSIGN_NAME = 1,
    REQ_CREATE_ROOM = 2,
    REQ_JOIN_ROOM   = 3,
    REQ_LIST_ROOMS  = 4,
    REQ_LEAVE_ROOM  = 5,
    REQ_BEGIN_MATCH = 6,
    REQ_LOADED      = 7,
    REQ_START_GAME  = 8,
    REQ_GAME_PACKET = 9
} RequestType;

// Matches Zig: const Result = enum(u8)
typedef enum {
    RES_OK          = 0,
    RES_BAD_REQUEST = 1,
    RES_SERVER_ERROR= 2
} ResultCode;

// Generic byte array for UUIDs (16 bytes)
typedef struct {
    uint8_t bytes[16];
} UUID;

// Structure to hold room info returned by list_rooms
typedef struct {
    UUID host_id;
    char name[16];
} RoomInfo;

typedef struct {
    ENetHost* host;
    ENetPeer* server_peer;
    UUID my_uuid;
    UUID opponent_uuid;
    char my_name[16];
    bool connected;
} GameClient;

// --- Lifecycle ---
int gc_init(GameClient* client);
void gc_shutdown(GameClient* client);
int gc_connect(GameClient* client, const char* ip, int port);
void gc_disconnect(GameClient* client);

// --- Requests (Client -> Server) ---
void gc_req_get_uuid(GameClient* client);
void gc_req_assign_name(GameClient* client, const char* name);
void gc_req_create_room(GameClient* client, const char* room_name);
void gc_req_list_rooms(GameClient* client);
void gc_req_join_room(GameClient* client, UUID host_id);
void gc_req_leave_room(GameClient* client);
void gc_req_loaded(GameClient* client);
// Matches: message[1..5] (4 bytes) and message[5..10] (5 bytes)
void gc_req_send_game_packet(GameClient* client, uint32_t data1, uint8_t data2[5]);

// --- Event Handling ---
// Returns 1 if a packet was processed, 0 if no events, -1 on error
// Populates internal client state (like my_uuid) automatically on receipt.
int gc_poll_event(GameClient* client, ENetEvent* event);

// Helpers
void print_uuid(UUID uuid);

#endif
