const std = @import("std");
const c = @cImport({
    @cInclude("uuid/uuid.h");
    @cInclude("enet/enet.h");
    @cInclude("string.h");
});

const REQUEST = enum(u8) {
    get_uuid = 0,
    //[type - 1] [uuid 16][nametag 16][enet contorl flag]
    //[1][16][16][1]
    assign_name = 1,
    create_room = 2,
    join_room = 3,
    game_packet = 4,
    _,
};

pub fn main() !void {
    std.debug.print("starting \n", .{});
    if (c.enet_initialize() != 0) {
        std.debug.print("could not init enet\n", .{});
    }
    defer c.enet_deinitialize();
    var client: ?*c.ENetHost = undefined;

    client = c.enet_host_create(null, 1, 2, 0, 0);
    if (client == null) {
        std.debug.print("could not make a client\n", .{});
    }
    defer c.enet_host_destroy(client);

    var address: c.ENetAddress = undefined;
    var event: c.ENetEvent = undefined;
    const event_ptr: [*c]c.ENetEvent = @ptrCast(&event);
    var peer: [*c]c.ENetPeer = undefined;

    _ = c.enet_address_set_host(&address, "localhost");

    address.port = 6666;

    peer = c.enet_host_connect(client, &address, 2, 0);

    if (peer == null) {
        std.debug.print("no peers bozo \n", .{});
    }

    var uuid: c.uuid_t = undefined;

    var connected: bool = false;
    var got_uuid: bool = false;
    var success: bool = false;
    var name_sent: bool = false;
    while (!success) {
        _ = c.enet_host_service(client, event_ptr, 1000);
        switch (event.type) {
            c.ENET_EVENT_TYPE_CONNECT => {
                connected = true;
            },
            c.ENET_EVENT_TYPE_NONE => {
                if (connected and !got_uuid) {
                    const message: c_char = 0;
                    const packet: *c.ENetPacket = c.enet_packet_create(&message, 2, c.ENET_PACKET_FLAG_RELIABLE);
                    _ = c.enet_peer_send(peer, 0, packet);
                } else if (connected and !name_sent) {
                    var message: [33]u8 = undefined;
                    message[0] = 1;
                    @memcpy(message[1..17], &uuid);
                    @memcpy(message[17..33], "this, is my name");
                    const packet: *c.ENetPacket = c.enet_packet_create(&message, 34, c.ENET_PACKET_FLAG_RELIABLE);
                    _ = c.enet_peer_send(peer, 0, packet);
                    name_sent = true;
                    std.debug.print("sending name request\n", .{});
                }
            },
            c.ENET_EVENT_TYPE_RECEIVE => {
                const packet = event.packet.*;
                const req_type: REQUEST = @enumFromInt(packet.data[0]);
                switch (req_type) {
                    .get_uuid => {
                        @memcpy(&uuid, packet.data[1..17]);
                        std.debug.print("got uuid and its {x}\n", .{packet.data[1..]});
                        got_uuid = true;
                    },
                    .assign_name => {
                        std.debug.print("assign name response: {s}\n", .{packet.data[1..]});
                        success = true;
                    },
                    .create_room => {},
                    .game_packet => {},
                    .join_room => {},
                    _ => {
                        const reply = c.enet_packet_create(
                            "lowkey kill yourself dude",
                            "lowkey kill yourself dude".len,
                            c.ENET_PACKET_FLAG_RELIABLE,
                        );
                        _ = c.enet_peer_send(event.peer, 0, reply);
                    },
                }
                c.enet_packet_destroy(event.packet);
            },
            c.ENET_EVENT_TYPE_DISCONNECT => {
                std.debug.print("disconnected \n", .{});
            },
            else => {
                std.debug.print("else happened  \n", .{});
            },
        }
    }
}
