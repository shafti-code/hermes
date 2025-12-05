#include "game_client.h"
#include <stdio.h>
#include <string.h>

// Helper to pad strings to 16 bytes as expected by Zig: [16]u8
void copy_padded_string(uint8_t* dest, const char* src) {
    memset(dest, 0, 16);
    if (src) {
        strncpy((char*)dest, src, 16);
    }
}

int gc_init(GameClient* client) {
    if (enet_initialize() != 0) return -1;
    
    client->host = enet_host_create(NULL, 1, 2, 0, 0);
    if (client->host == NULL) return -2;

    memset(&client->my_uuid, 0, 16);
    memset(&client->opponent_uuid, 0, 16);
    client->connected = false;
    return 0;
}

void gc_shutdown(GameClient* client) {
    if (client->host) enet_host_destroy(client->host);
    enet_deinitialize();
}

int gc_connect(GameClient* client, const char* ip, int port) {
    ENetAddress address;
    enet_address_set_host(&address, ip);
    address.port = port;

    client->server_peer = enet_host_connect(client->host, &address, 2, 0);
    if (client->server_peer == NULL) return -1;
    
    // Wait up to 5 seconds for the connection to succeed
    ENetEvent event;
    if (enet_host_service(client->host, &event, 5000) > 0 &&
        event.type == ENET_EVENT_TYPE_CONNECT) {
        client->connected = true;
        return 0;
    }
    
    enet_peer_reset(client->server_peer);
    return -1;
}

void gc_disconnect(GameClient* client) {
    if(client->connected) {
        enet_peer_disconnect(client->server_peer, 0);
        enet_host_flush(client->host);
        client->connected = false;
    }
}

// --- Request Wrappers ---

void gc_req_get_uuid(GameClient* client) {
    uint8_t data[1] = { REQ_GET_UUID };
    ENetPacket* packet = enet_packet_create(data, 1, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_assign_name(GameClient* client, const char* name) {
    // Structure: [Type(1)][UUID(16)][Name(16)] = 33 bytes
    uint8_t data[33];
    data[0] = REQ_ASSIGN_NAME;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    copy_padded_string(&data[17], name);
    
    // Cache name locally
    copy_padded_string((uint8_t*)client->my_name, name);

    ENetPacket* packet = enet_packet_create(data, 33, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_create_room(GameClient* client, const char* room_name) {
    // Structure: [Type(1)][UUID(16)][RoomName(16)] = 33 bytes
    uint8_t data[33];
    data[0] = REQ_CREATE_ROOM;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    copy_padded_string(&data[17], room_name);

    ENetPacket* packet = enet_packet_create(data, 33, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_list_rooms(GameClient* client) {
    uint8_t data[1] = { REQ_LIST_ROOMS };
    ENetPacket* packet = enet_packet_create(data, 1, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_join_room(GameClient* client, UUID host_id) {
    // Structure: [Type(1)][MyID(16)][HostID(16)] = 33 bytes
    uint8_t data[33];
    data[0] = REQ_JOIN_ROOM;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    memcpy(&data[17], host_id.bytes, 16);
    
    // Optimistically set opponent ID (Verification should happen via server response)
    client->opponent_uuid = host_id;

    ENetPacket* packet = enet_packet_create(data, 33, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_leave_room(GameClient* client) {
    // Structure: [Type(1)][MyID(16)][OppID(16)]
    uint8_t data[33];
    data[0] = REQ_LEAVE_ROOM;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    memcpy(&data[17], client->opponent_uuid.bytes, 16);

    ENetPacket* packet = enet_packet_create(data, 33, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_loaded(GameClient* client) {
    // Structure: [Type(1)][MyID(16)]
    uint8_t data[17];
    data[0] = REQ_LOADED;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    ENetPacket* packet = enet_packet_create(data, 17, ENET_PACKET_FLAG_RELIABLE);
    enet_peer_send(client->server_peer, 0, packet);
}

void gc_req_send_game_packet(GameClient* client, uint32_t data1, uint8_t data2[5]) {
    // Structure: [Type(1)][MyID(16)][Data1(4)][Data2(5)] = 26 bytes
    // Note: Zig server reads: packet.data[17..21] and packet.data[21..26]
    uint8_t data[26];
    data[0] = REQ_GAME_PACKET;
    memcpy(&data[1], client->my_uuid.bytes, 16);
    memcpy(&data[17], &data1, 4);
    if (data2) memcpy(&data[21], data2, 5);
    else memset(&data[21], 0, 5);

    ENetPacket* packet = enet_packet_create(data, 26, ENET_PACKET_FLAG_UNSEQUENCED);
    enet_peer_send(client->server_peer, 0, packet);
}

int gc_poll_event(GameClient* client, ENetEvent* event) {
    int result = enet_host_service(client->host, event, 0);
    
    if (result > 0 && event->type == ENET_EVENT_TYPE_RECEIVE) {
        uint8_t type = event->packet->data[0];

        // Automatic internal state handling based on responses
        switch (type) {
            case REQ_GET_UUID:
                // Server reply: [0, uuid(16)]
                if (event->packet->dataLength >= 17) {
                    memcpy(client->my_uuid.bytes, &event->packet->data[1], 16);
                }
                break;
            
            // Add other auto-handlers if needed (e.g., updating opponent ID on join)
        }
    }
    
    return result;
}

void print_uuid(UUID uuid) {
    for(int i=0; i<16; i++) printf("%02x", uuid.bytes[i]);
}
