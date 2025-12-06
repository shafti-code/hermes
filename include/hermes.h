#ifndef HERMES_H
#define HERMES_H

#include <stddef.h> // For size_t
#include <stdint.h> // For fixed-width types like uint8_t
#include <enet/enet.h> // Required for ENet types like ENetPeer, ENetHost, etc.
#include <uuid/uuid.h> // Required for uuid_t

// --- Exported Types ---

// The C equivalent of your Request enum (u8)
typedef enum {
    Request_get_uuid = 0,
    Request_assign_name = 1,
    Request_create_room = 2,
    Request_join_room = 3,
    Request_list_rooms = 4,
    Request_leave_room = 5,
    Request_begin_match = 6,
    Request_loaded = 7,
    Request_start_game = 8,
    Request_game_packet = 9,
} hermes_Request;

// The C equivalent of your Result enum (u8)
typedef enum {
    Result_ok = 0,
    Result_bad_request = 1,
    Result_server_error = 2,
} hermes_Result;


// --- Exported Functions ---

/**
 * Initializes ENet, sets up the address, creates the client host, 
 * and attempts to connect to localhost:6666.
 */
void hermesInit(void);

/**
 * Sends a request to get the client's UUID and polls for the response.
 * @param id Pointer to a 16-byte buffer (uuid_t) where the received UUID will be copied.
 */
void hermesGetUuid(uuid_t *id);

/**
 * Sends a request to assign a name (16 bytes) to the client UUID (16 bytes).
 * @param uuid Pointer to the client's 16-byte UUID.
 * @param name Pointer to the 16-byte name buffer.
 * @return 1 on success (Result_ok received), 0 otherwise.
 */
int hermesAssignName(uint8_t *uuid, uint8_t *name);

/**
 * Sends a request to create a new room with the given name/ID.
 * @param uuid Pointer to the client's 16-byte UUID.
 * @param room_name Pointer to the 16-byte room name/ID.
 * @return 1 on success (Result_ok received), 0 otherwise.
 */
int hermesCreateRoom(uuid_t *uuid, uuid_t *room_name);

/**
 * Sends a request to join a room hosted by host_id and polls for a response.
 * @param client_id Pointer to the client's UUID.
 * @param host_id Pointer to the host's UUID.
 * @param opponent_name Pointer to a 16-byte buffer to receive the opponent's name/ID if joined.
 * @return 1 if opponent name received (successful join), 0 otherwise.
 */
int hermesJoinRoom(uuid_t *client_id, uuid_t *host_id, uuid_t *opponent_name);

/**
 * Sends a notification that the client is leaving the room.
 * @param client_id Pointer to the client's UUID.
 * @param opponent_id Pointer to the opponent's UUID (or 0s if leaving alone/host).
 */
void hermesLeaveRoom(uuid_t *client_id, uuid_t *opponent_id);

/**
 * Sends a request to list available rooms and polls for the response containing the list.
 * @param uuids Pointer to a buffer to receive UUIDs (total ammount * 16 bytes).
 * @param names Pointer to a buffer to receive Names (total ammount * 16 bytes).
 * @param ammount The maximum number of rooms to expect (used for buffer size).
 * @return The number of rooms received, or 0 on error/timeout.
 */
int heremesListRoom(uint8_t *uuids, uint8_t *names, size_t ammount);

/**
 * Sends a signal to the server that the host is starting the game.
 * @param client_id Pointer to the client's UUID.
 */
void hermesStartGame(uuid_t *client_id);

/**
 * Polls for a packet signaling an opponent joined the room.
 * @param opp_name Pointer to a 16-byte buffer to store the opponent's name/ID.
 * @return 1 if opponent joined, 0 otherwise.
 */
int hermesWaitForOpponent(uint8_t *opp_name);

/**
 * Polls for a packet signaling either a game start or an opponent leaving.
 * @return The Request enum value (e.g., Request_start_game or Request_leave_room), or 0 if nothing happened.
 */
int hermesWaitForStart(void);

/**
 * Sends a notification to the server that the client has finished loading assets.
 * @param client_id Pointer to the client's UUID.
 */
void hermesLoaded(uuid_t *client_id);

/**
 * Sends the client's current position to the server.
 * @param client_id Pointer to the client's UUID.
 * @param x Pointer to the client's x-coordinate (float).
 * @param y Pointer to the client's y-coordinate (float).
 */
void hermesGetGameState(uuid_t *client_id, float *x, float *y);

/**
 * Polls for the final server signal to begin the match (game clock start).
 * @return 1 if Request_begin_match received, 0 otherwise.
 */
int hermesAwaitBeginMatch(void);

/**
 * Cleans up the ENet host and deinitializes the library.
 */
void hermesDeinit(void);

#endif // HERMES_H
