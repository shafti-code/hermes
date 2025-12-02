const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
    @cInclude("uuid/uuid.h");
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

const Vector2 = struct {
    x: f32,
    y: f32,
};

const Player = struct {
    id: c.uuid_t,
    nametag: [16]u8,
    opponent_id: c.uuid_t,
    peer: ?c.ENetPeer,
    position: ?Vector2,
};

const Lobby = struct {
    players: [2]c.uuid_t,
};


pub fn create_player() !void {}

pub fn main() !void {
    if (c.enet_initialize() != 0) {
        std.debug.print("Could not initialize ENet\n", .{});
        return;
    }
    defer c.enet_deinitialize();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var players = std.AutoHashMap(c.uuid_t, Player).init(allocator);
    defer players.deinit();

    var address: c.ENetAddress = undefined;
    address.host = c.ENET_HOST_ANY;
    address.port = 6666;

    const server = c.enet_host_create(
        &address,
        1000,
        2,
        0,
        0,
    );
    if (server == null) {
        std.debug.print("Could not create ENet server\n", .{});
        return;
    }
    defer c.enet_host_destroy(server);

    var event: c.ENetEvent = undefined;

    while (true) {
        const result = c.enet_host_service(server, &event, 1000);

        if (result > 0) switch (event.type) {
            c.ENET_EVENT_TYPE_CONNECT => {
                std.debug.print("client connected\n", .{});
            },
            c.ENET_EVENT_TYPE_RECEIVE => {
                const packet = event.packet.*;
                const req_type: REQUEST = @enumFromInt(packet.data[0]);
                switch (req_type) {
                    .get_uuid => {
                        std.debug.print("got a request for an uuid\n", .{});
                        var id: c.uuid_t = undefined;
                        c.uuid_generate_random(&id);
                        try players.put(id, Player{
                            .id = id,
                            .nametag = .{0} ** 16,
                            .opponent_id = .{0} ** 16,
                            .peer = null,
                            .position = null,
                        });

                        var message: [17]u8 = undefined;
                        message[0] = @intFromEnum(REQUEST.get_uuid);
                        @memcpy(message[1..17],&id);
                        const reply = c.enet_packet_create(
                            &message,
                            message.len + 1,
                            c.ENET_PACKET_FLAG_RELIABLE,
                        );
                        _ = c.enet_peer_send(event.peer, 0, reply);
                        std.debug.print("created a player with id: {x}\n",.{id});
                    },
                    .assign_name => {
                        std.debug.print("got a request for a name {s} with length {}\n", .{packet.data[17..33],packet.dataLength});
                        var client_id: c.uuid_t = undefined;
                        client_id  = packet.data[1..17].*;
                        if (players.getPtr(client_id)) |player| {
                            @memcpy(player.nametag[0..],packet.data[17..33]);
                            var message: [3]u8 = undefined;
                            message[0] = @intFromEnum(REQUEST.assign_name);
                            @memcpy(message[1..3],"ok");
                            const reply: *c.ENetPacket = c.enet_packet_create(
                                &message,
                                message.len + 1,
                                c.ENET_PACKET_FLAG_RELIABLE,
                            );
                            _ = c.enet_peer_send(event.peer, 0, reply);
                            std.debug.print("assigned a name, {s}\n",.{player.nametag});
                        }else{
                            std.debug.print("couldnt find the player assosciated with that id: {x}\n",.{packet.data[17..33]});
                        }
                    },
                    .create_room => {},
                    .join_room => {},
                    .game_packet => {},
                    _ => {
                        const reply = c.enet_packet_create(
                            "invalid request",
                            "invalid request".len,
                            c.ENET_PACKET_FLAG_RELIABLE,
                        );
                        _ = c.enet_peer_send(event.peer, 0, reply);
                    },
                }
                c.enet_packet_destroy(event.packet);
            },
            c.ENET_EVENT_TYPE_NONE  => {
                std.debug.print("we chilling nothing is happening \n",.{});
            },
            c.ENET_EVENT_TYPE_DISCONNECT => {
                std.debug.print("client disconnected\n", .{});
            },
            else => { std.debug.print("weird packet\n",.{});},
        } else if (result == 0) {
            std.debug.print("waiting for connections\n", .{});
        } else {
            std.debug.print("enet_host_service error\n", .{});
        }
    }
    return;
}
