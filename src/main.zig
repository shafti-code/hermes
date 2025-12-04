const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
    @cInclude("uuid/uuid.h");
});

const Request = enum(u8) {
    //initial request
    //req:[1 req type][1 enet flag]
    //res:[1 req type][16 uuid][1 enet flag]
    get_uuid = 0,
    //req:[1 req type][uuid 16][16 name(all names are fixed size)]
    //res:[1 req type][1 result enum]
    assign_name = 1,

    //room related requests
    create_room = 2,
    join_room = 3,
    list_rooms = 4,
    leave_room = 5,
    begin_match = 6,

    //game related requests

    loaded = 7,
    start_game = 8,
    game_packet = 9,
    _,
};

const Vector2 = struct {
    x: f32,
    y: f32,
};

const Result = enum(u8) {
    ok = 0,
    bad_request = 1,
    server_error = 2,
};

const Player = struct {
    id: c.uuid_t,
    nametag: [16]u8,

    opponent_id: c.uuid_t,
    peer: c.ENetPeer,

    position: ?Vector2,
};

const Room = struct {
    started: bool,
    full: bool,
    host_id: c.uuid_t,
    opp_id: c.uuid_t,
};
pub fn status_response(event: c.ENetEvent, res_type: Request, result: Result) void {
    var content: [2]u8 = undefined;
    content[0] = @intFromEnum(res_type);
    content[1] = @intFromEnum(result);

    const reply: *c.ENetPacket = c.enet_packet_create(
        &content,
        content.len + 1,
        c.ENET_PACKET_FLAG_RELIABLE,
    );
    _ = c.enet_peer_send(event.peer, 0, reply);
}

pub fn main() !void {
    if (c.enet_initialize() != 0) {
        std.debug.print("Could not initialize ENet\n", .{});
        return;
    }
    defer c.enet_deinitialize();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var players = std.AutoHashMap(c.uuid_t,Player).init(allocator);
    defer players.deinit();

    var rooms = std.array_list.Managed(Room).init(allocator);
    defer rooms.deinit();

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
                const req_type: Request = @enumFromInt(packet.data[0]);
                switch (req_type) {
                    .get_uuid => {
                        std.debug.print("got a request for an uuid\n", .{});
                        var id: c.uuid_t = undefined;
                        c.uuid_generate_random(&id);
                        try players.put(id, Player{
                            .id = id,
                            .nametag = .{0} ** 16,
                            .opponent_id = .{0} ** 16,
                            .peer = event.peer.*,
                            .position = null,
                        });
                        var message: [17]u8 = undefined;
                        message[0] = @intFromEnum(Request.get_uuid);
                        @memcpy(message[1..17], &id);
                        const reply: *c.ENetPacket = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
                        _ = c.enet_peer_send(event.peer, 0, reply);

                        std.debug.print("created a player with id: {x}\n", .{id});
                    },
                    .assign_name => {
                        std.debug.print("got a request for a name {s} with length {}\n", .{ packet.data[17..33], packet.dataLength });

                        //create a placeholder for player id and then copy the bytes over
                        //compiler optimizes this actually so we cna do that practically for free
                        var client_id: c.uuid_t = undefined;
                        client_id = packet.data[1..17].*;

                        if (players.getPtr(client_id)) |player| {
                            //copy the name bytes to the player instance
                            @memcpy(player.nametag[0..], packet.data[17..33]);

                            status_response(event, Request.assign_name, Result.ok);

                            std.debug.print("assigned a name, {s}\n", .{player.nametag});
                        } else {
                            std.debug.print("couldnt find the player assosciated with that id: {x}\n", .{packet.data[17..33]});
                            status_response(event, Request.create_room, Result.bad_request);
                        }
                    },
                    .create_room => {
                        std.debug.print("create room from: {x}\n", .{packet.data[1..17]});

                        var client_id: c.uuid_t = undefined;
                        client_id = packet.data[1..17].*;

                        if (players.getPtr(client_id)) |player| {
                            if (rooms.append(Room{
                                .full = false,
                                .started = false,
                                .host_id = player.id,
                                .opp_id = .{0} ** 16,
                            })) |_| {
                                status_response(event, Request.create_room, Result.ok);
                                std.debug.print("assigned a name, {s}\n", .{player.nametag});
                            } else |err| {
                                status_response(event, Request.create_room, Result.server_error);
                                std.debug.print("got an error : {}\n", .{err});
                            }
                        } else {
                            std.debug.print("couldnt find the player assosciated with that id: {x}\n", .{packet.data[17..33]});
                            status_response(event, Request.create_room, Result.bad_request);
                        }
                    },
                    .join_room => {
                        std.debug.print("join room from: {x}", .{packet.data[1..17]});

                        const client_id: c.uuid_t = packet.data[1..17].*;
                        const hoster_id: c.uuid_t = packet.data[17..33].*;

                        if (players.getPtr(hoster_id)) |host| {
                            if (players.getPtr(client_id)) |client| {
                                host.opponent_id = client_id;
                                client.opponent_id = hoster_id;

                                for (rooms.items) |*room| {
                                    if (std.mem.eql(u8,room.host_id[0..],hoster_id[0..])) {
                                        if (room.full == false) {
                                            @memcpy(room.opp_id[0..],client_id[0..]);
                                            room.full = true;
                                        }
                                    }
                                }

                                var message: [17]u8 = undefined;
                                message[0] = @intFromEnum(Request.join_room);

                                @memcpy(message[1..17], client.nametag[0..]);

                                const reply: *c.ENetPacket = c.enet_packet_create(&message, message.len + 1, c.ENET_PACKET_FLAG_RELIABLE);
                                _ = c.enet_peer_send(&host.peer, 0, reply);
                            } else {
                                std.debug.print("couldnt find the client assosciated with that id: {x} (join room)\n", .{packet.data[17..33]});
                            }
                        } else {
                            std.debug.print("couldnt find the host assosciated with that id: {x}\n (join room)", .{packet.data[17..33]});
                        }
                    },
                    .leave_room => {
                        std.debug.print("leave room from: {x}", .{packet.data[1..17]});

                        const client_id: c.uuid_t = packet.data[1..17].*;
                        const opponent_id: c.uuid_t = packet.data[17..33].*;

                        if (players.getPtr(opponent_id)) |client| {
                            if (players.getPtr(client_id)) |opponent| {
                                opponent.opponent_id = .{0} ** 16;
                                client.opponent_id = .{0} ** 16;

                                var should_leave = false;
                                for (rooms.items,0..) |*room,i| {
                                    if (std.mem.eql(u8,room.host_id[0..],client.id[0..])) {
                                        _ = rooms.swapRemove(i);
                                        should_leave = true;
                                    } else if (std.mem.eql(u8,room.opp_id[0..],client.id[0..])) {
                                        room.opp_id = .{0} ** 16;
                                        room.full = false;
                                    }
                                } 


                                var message: [2]u8 = undefined;
                                message[0] = @intFromEnum(Request.leave_room);
                                message[1] = @intFromBool(should_leave);
                                const reply: *c.ENetPacket = c.enet_packet_create(
                                    &message,
                                    message.len + 1,
                                    c.ENET_PACKET_FLAG_RELIABLE,
                                );
                                _ = c.enet_peer_send(&opponent.peer, 0, reply);
                            } else {
                                std.debug.print("couldnt find the opponent assosciated with that id: {x} (leave room)\n", .{packet.data[17..33]});
                            }
                        } else {
                            std.debug.print("couldnt find the client assosciated with that id: {x} (leave room)\n", .{packet.data[17..33]});
                        }
                    },
                    .list_rooms => {
                    },
                    .start_game => {},
                    .game_packet => {},
                    .begin_match => {},
                    .loaded => {},
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
            c.ENET_EVENT_TYPE_NONE => {
                std.debug.print("we chilling nothing is happening \n", .{});
            },
            c.ENET_EVENT_TYPE_DISCONNECT => {
                std.debug.print("client disconnected\n", .{});
            },
            else => {
                std.debug.print("weird packet\n", .{});
            },
        } else if (result == 0) {
            std.debug.print("waiting for connections\n", .{});
        } else {
            std.debug.print("enet_host_service error\n", .{});
        }
    }
    return;
}
