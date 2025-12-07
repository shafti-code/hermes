const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
    @cInclude("uuid/uuid.h");
});

const Request = enum(u8) {
    get_uuid = 0,
    assign_name = 1,

    //room related requests
    create_room = 2,
    join_room = 3,
    list_rooms = 4,
    leave_room = 5,
    begin_race = 6,

    //game related requests

    loaded = 7,
    start_game = 8,
    game_packet = 9,
    _,
};

const Result = enum(u8) {
    ok = 0,
    bad_request = 1,
    server_error = 2,
};

var client: ?*c.ENetHost = undefined;
var address: c.ENetAddress = undefined;
var event: c.ENetEvent = undefined;
const event_ptr: [*c]c.ENetEvent = @ptrCast(&event);
var peer: [*c]c.ENetPeer = undefined;

export fn hermesInit() void {
    if (c.enet_initialize() != 0) {
        std.debug.print("Could not initialize ENet\n", .{});
        return;
    }
    address.host = c.ENET_HOST_ANY;
    address.port = 6666;
    client = c.enet_host_create(
        null,
        1,
        2,
        0,
        0,
    );
    if (client == null) {
        std.debug.print("Could not create ENet server\n", .{});
        return;
    }
    _ = c.enet_address_set_host(&address, "localhost");

    peer = c.enet_host_connect(client, &address, 2, 0);

    if (peer == null) {
        std.debug.print("no peers bozo \n", .{});
    }
    std.debug.print("\nHERMES -> INITIALIZATION SUCESSFULL\n\n", .{});
}
export fn hermesGetUuid() void {
    std.debug.print("\n\nHERMES -> SENDING UUID REQUEST\n", .{});
    const message = @intFromEnum(Request.get_uuid);
    const request = c.enet_packet_create(&message, 1, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesCreateRoom(uuid: *c.uuid_t, room_name: *[16]u8) void {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.create_room);
    @memcpy(message[1..17], uuid[0..]);
    @memcpy(message[17..33], room_name[0..]);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
    std.debug.print("\nHERMES -> CREATE ROOM SENT\n\n", .{});
}

export fn hermesJoinRoom(client_id: *c.uuid_t, host_id: *c.uuid_t) void {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.join_room);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..33], host_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesLeaveRoom(client_id: *c.uuid_t, opponent_id: *c.uuid_t) void {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.leave_room);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..33], opponent_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesListRooms() void {
    var message: u8 = @intFromEnum(Request.list_rooms);
    const message_ptr: *u8 = &message;
    const request = c.enet_packet_create(message_ptr, 1, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
    std.debug.print("\nHERMES -> LIST ROOMS SENT\n\n", .{});
}

export fn hermesStartGame(client_id: *c.uuid_t) void {
    var message: [17]u8 = undefined;
    message[0] = @intFromEnum(Request.start_game);
    @memcpy(message[1..17], client_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesLoaded(client_id: *c.uuid_t) void {
    var message: [17]u8 = undefined;
    message[0] = @intFromEnum(Request.loaded);
    @memcpy(message[1..17], client_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesSendGameData(client_id: *c.uuid_t, x: [*c]f32, y: [*c]f32, angle: [*c]f32) void {
    var message: [29]u8 = undefined;
    message[0] = @intFromEnum(Request.game_packet);

    const ptr_x: [*c]u8 = @ptrCast(x);
    const ptr_y: [*c]u8 = @ptrCast(y);
    const ptr_a: [*c]u8 = @ptrCast(angle);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..21], ptr_x);
    @memcpy(message[21..25], ptr_y);
    @memcpy(message[25..29], ptr_a);
}

export fn hermesPolling(uuid: *c.uuid_t, uuids: *c.uuid_t, got_opponent: *c_int, names: [*c][16]u8, room_ammount: *u8, start_game: *c_int, leave_room: *c_int, begin_race: *c_int, player_x: [*c]f32, player_y: [*c]f32, player_angle: [*c]f32) void {
    _ = c.enet_host_service(client, &event, 0);
    switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {
                    @memcpy(uuid[0..16], packet.data[1..17]);
                    std.debug.print("\nHERMES -> GOT UUID{x}\n\n", .{packet.data[1..]});
                },
                .assign_name => {},
                .create_room => {
                    const result_type: Result = @enumFromInt(packet.data[1]);
                    switch (result_type) {
                        .ok => {
                            std.debug.print("\nHERMES -> CREATE ROOM SUCCESS\n\n", .{});
                        },
                        .server_error => {
                            std.debug.print("\nHERMES -> CREATE ROOM SERVER ERROR\n\n", .{});
                        },
                        .bad_request => {
                            std.debug.print("\nHERMES -> CREATE ROOM BAD REQUEST\n\n", .{});
                        },
                    }
                },
                .join_room => {
                    got_opponent.* = @intFromBool(true);
                    std.debug.print("\nHERMES ->OPPONENT JOINED\n\n", .{});
                },
                .leave_room => {
                    leave_room.* = @intFromBool(true);
                },

                .list_rooms => {
                    const max_rooms: usize = 10; // matches your buffer size
                    const room_entry_size: usize = 32; // 16 UUID + 16 name

                    const actual_data_len = packet.dataLength - 1;
                    const total_rooms = actual_data_len / room_entry_size;
                    var rooms_to_copy: usize = undefined;
                    if (total_rooms > max_rooms) {
                        rooms_to_copy = max_rooms;
                    } else {
                        rooms_to_copy = total_rooms;
                    }

                    const uuid_bytes = rooms_to_copy * 16;
                    const name_bytes = rooms_to_copy * 16;

                    const uuids_ptr: [*c]u8 = @ptrCast(uuids);
                    const names_ptr: [*c]u8 = @ptrCast(names);

                    if (uuid_bytes > 0) {
                        @memcpy(uuids_ptr[0..uuid_bytes], packet.data[1 .. 1 + uuid_bytes]);
                    }

                    if (name_bytes > 0) {
                        const names_start = 1 + rooms_to_copy * 16;
                        @memcpy(names_ptr[0..name_bytes], packet.data[names_start .. names_start + name_bytes]);
                    }

                    room_ammount.* = @truncate(rooms_to_copy);
                },

                .start_game => {
                    start_game.* = @intFromBool(true);
                },
                .game_packet => {
                    const ptr_x: [*c]u8 = @ptrCast(player_x);
                    const ptr_y: [*c]u8 = @ptrCast(player_y);
                    const ptr_a: [*c]u8 = @ptrCast(player_angle);
                    @memcpy(ptr_x, packet.data[1..5]);
                    @memcpy(ptr_y, packet.data[5..10]);
                    @memcpy(ptr_a, packet.data[10..15]);
                },
                .begin_race => {
                    begin_race.* = @intFromBool(true);
                },
                .loaded => {},
                _ => {},
            }
            c.enet_packet_destroy(event.packet);
        },
        c.ENET_EVENT_TYPE_NONE => {},
        c.ENET_EVENT_TYPE_DISCONNECT => {
            std.debug.print("client disconnected\n", .{});
        },
        else => {
            std.debug.print("weird packet\n", .{});
        },
    }
}

export fn hermesDeinit() void {
    c.enet_deinitialize();
    c.enet_host_destroy(client);
}
