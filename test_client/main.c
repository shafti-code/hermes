#include <stdio.h>
#include <unistd.h> // for sleep
#include "game_client.h"

int main() {
    GameClient client;
    ENetEvent event;

    // 1. Initialize
    if (gc_init(&client) != 0) {
        printf("Failed to init ENet\n");
        return 1;
    }

    // 2. Connect
    printf("Connecting...\n");
    if (gc_connect(&client, "127.0.0.1", 6666) != 0) {
        printf("Connection failed.\n");
        return 1;
    }
    printf("Connected!\n");

    // 3. Request UUID
    gc_req_get_uuid(&client);

    // Main Loop
    int running = 1;
    while (running) {
        int status = gc_poll_event(&client, &event);
        
        if (status > 0) {
            if (event.type == ENET_EVENT_TYPE_RECEIVE) {
                uint8_t type = event.packet->data[0];

                switch (type) {
                    case REQ_GET_UUID:
                        printf("Received My UUID: ");
                        print_uuid(client.my_uuid);
                        printf("\n");
                        
                        // Once we have UUID, set name
                        gc_req_assign_name(&client, "CoolPlayer");
                        break;

                    case REQ_ASSIGN_NAME:
                        // Zig sends [1, result]
                        if (event.packet->data[1] == RES_OK) {
                            printf("Name assigned successfully. Creating room...\n");
                            gc_req_create_room(&client, "MyAwesomeRoom");
                        } else {
                            printf("Failed to assign name.\n");
                        }
                        break;

                    case REQ_CREATE_ROOM:
                        if (event.packet->data[1] == RES_OK) {
                            printf("Room created! Waiting for players...\n");
                            // In a real GUI, you'd wait here. 
                            // For test, let's list rooms to verify.
                            gc_req_list_rooms(&client);
                        }
                        break;

                    case REQ_LIST_ROOMS:
                        printf("--- Room List ---\n");
                        // Format: [4, host(16), name(16), host(16), name(16)...]
                        size_t offset = 1;
                        while (offset + 32 <= event.packet->dataLength) {
                            UUID h_id;
                            char r_name[17] = {0}; // +1 for null terminator
                            
                            memcpy(h_id.bytes, &event.packet->data[offset], 16);
                            memcpy(r_name, &event.packet->data[offset + 16], 16);
                            
                            printf("Room: %s | Host: ", r_name);
                            print_uuid(h_id);
                            printf("\n");
                            
                            offset += 32;
                        }
                        printf("-----------------\n");
                        break;
                    
                    case REQ_JOIN_ROOM:
                        // If we are host, server sends us [3, joiner_name(16)]
                        printf("Player joined: %.16s\n", &event.packet->data[1]);
                        
                        // Tell server we are ready
                        gc_req_loaded(&client);
                        break;
                        
                    case REQ_BEGIN_MATCH:
                        printf("Both players loaded! Match starting.\n");
                        // Send some game data
                        uint8_t dummy_input[5] = {1, 0, 1, 0, 1};
                        gc_req_send_game_packet(&client, 100, dummy_input);
                        break;

                    case REQ_GAME_PACKET:
                        // Receive [9, data1(4), data2(5)]
                        // Note: Server strips the ID before sending to opponent
                        // Wait, looking at server: 
                        // It reads client [17..21], [21..26]
                        // It writes to reply [1..5], [5..10]
                        {
                            uint32_t val;
                            memcpy(&val, &event.packet->data[1], 4);
                            printf("Game Packet received: val=%d\n", val);
                        }
                        break;
                }
                
                enet_packet_destroy(event.packet);
            }
        }
        
        // Simulating 60fps
        usleep(16000); 
    }

    gc_shutdown(&client);
    return 0;
}
