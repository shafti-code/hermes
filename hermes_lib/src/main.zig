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
    begin_match = 6,

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
        0,
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
}

export fn hermesGetUuid(id: *c.uuid_t) void {
    const message = @intFromEnum(Request.get_uuid);
    const request = c.enet_packet_create(&message, 1, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
    var success: bool = false;
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {
                    @memcpy(
                        @as([*]u8, &id.*), // pointer to the bytes of the 16-byte array
                        packet.data[1..17], // 16 bytes from the packet
                    );

                    success = true;
                },
                .assign_name => {},
                .create_room => {},
                .join_room => {},
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
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

export fn hermesAssignName(uuid: *[16]u8, name: *[16]u8) c_int {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.assign_name);
    @memcpy(message[1..17], uuid);
    @memcpy(message[17..33], name);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {
                    const result_type: Result = @enumFromInt(packet.data[1]);
                    switch (result_type) {
                        .ok => {
                            return @intFromBool(true);
                        },
                        .server_error => {
                            return @intFromBool(false);
                        },
                        .bad_request => {
                            return @intFromBool(false);
                        },
                    }
                },
                .create_room => {},
                .join_room => {},
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
            }
            c.enet_packet_destroy(event.packet);
        },
        c.ENET_EVENT_TYPE_NONE => {
            std.debug.print("we chilling nothing is happening \n", .{});
            return @intFromBool(false);
        },
        c.ENET_EVENT_TYPE_DISCONNECT => {
            std.debug.print("client disconnected\n", .{});
            return @intFromBool(false);
        },
        else => {
            std.debug.print("weird packet\n", .{});
        },
    } else if (result == 0) {
        std.debug.print("waiting for connections\n", .{});
    } else {
        std.debug.print("enet_host_service error\n", .{});
        return @intFromBool(false);
    }
    return @intFromBool(false);
}

export fn hermesCreateRoom(uuid: *c.uuid_t, room_name: *c.uuid_t) c_int {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.create_room);
    @memcpy(message[1..17], uuid);
    @memcpy(message[17..33], room_name);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {
                    const result_type: Result = @enumFromInt(packet.data[1]);
                    switch (result_type) {
                        .ok => {
                            return @intFromBool(true);
                        },
                        .server_error => {
                            return @intFromBool(false);
                        },
                        .bad_request => {
                            return @intFromBool(false);
                        },
                    }
                },
                .join_room => {},
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
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
        return @intFromBool(false);
    } else {
        std.debug.print("enet_host_service error\n", .{});
    }
    return @intFromBool(false);
}

export fn hermesJoinRoom(client_id: *c.uuid_t, host_id: *c.uuid_t, opponent_name: *c.uuid_t) c_int {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.join_room);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..33], host_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);

    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {},
                .join_room => {
                    const result_type: Result = @enumFromInt(packet.data[1]);
                    if (packet.dataLength == 17) {
                        @memcpy(
                            @as([*]u8, &opponent_name.*), // pointer to the bytes of the 16-byte array
                            packet.data[1..17], // 16 bytes from the packet
                        );
                    } else {
                        switch (result_type) {
                            .ok => {},
                            .server_error => {
                                return @intFromBool(false);
                            },
                            .bad_request => {
                                return @intFromBool(false);
                            },
                        }
                    }
                },
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
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
    return @intFromBool(false);
}

export fn hermesLeaveRoom(client_id: *c.uuid_t, opponent_id: *c.uuid_t) void {
    var message: [33]u8 = undefined;
    message[0] = @intFromEnum(Request.leave_room);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..33], opponent_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn heremesListRoom(uuids: [*c]u8, names: [*c]u8, ammount: c_ulong) c_int {
    var message: u8 = @intFromEnum(Request.list_rooms);
    const message_ptr: *u8 = &message;
    const request = c.enet_packet_create(message_ptr, 1, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);

    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {},
                .join_room => {},
                .leave_room => {},
                .list_rooms => {
                    const expected_bytes = ammount * 16;

                    if (packet.dataLength >= (expected_bytes * 2) + 1) {
                        @memcpy(uuids[0..expected_bytes], packet.data[1 .. 1 + expected_bytes]);
                        @memcpy(names[0..expected_bytes], packet.data[1 + expected_bytes .. 1 + (expected_bytes * 2)]);
                    } else {
                        const actual_bytes = (packet.dataLength - 1) / 2;

                        @memcpy(uuids[0..actual_bytes], packet.data[1 .. 1 + actual_bytes]);
                        @memset(uuids[actual_bytes..expected_bytes], 0);

                        const names_start_idx = 1 + actual_bytes;
                        @memcpy(names[0..actual_bytes], packet.data[names_start_idx .. names_start_idx + actual_bytes]);
                        @memset(names[actual_bytes..expected_bytes], 0);
                    }
                },
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
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
    return @intFromBool(false);
}

export fn hermesStartGame(client_id: *c.uuid_t) void {
    var message: [17]u8 = undefined;
    message[0] = @intFromEnum(Request.start_game);
    @memcpy(message[1..17], client_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesWaitForOpponent(opp_name: [*c]u8) c_int {
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {},
                .join_room => {
                    @memcpy(opp_name[0..16], packet.data[1..]);
                    return @intFromBool(true);
                },
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
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
    return @intFromBool(false);
}

export fn hermesWaitForStart() c_int {
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {},
                .join_room => {},
                .leave_room => {
                    return @intFromEnum(Request.leave_room);
                },
                .list_rooms => {},
                .start_game => {
                    return @intFromEnum(Request.start_game);
                },
                .game_packet => {},
                .begin_match => {},
                .loaded => {},
                _ => {},
            }
            c.enet_packet_destroy(event.packet);
        },
        c.ENET_EVENT_TYPE_NONE => {
            return 0;
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
    return @intFromBool(false);
}

export fn hermesLoaded(client_id: *c.uuid_t) void {
    var message: [17]u8 = undefined;
    message[0] = @intFromEnum(Request.loaded);
    @memcpy(message[1..17], client_id);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesGetGameState(client_id: *c.uuid_t, x: [*c]f32, y: [*c]f32) void {
    const x_ptr: [*c]u8 = @ptrCast(x);
    const y_ptr: [*c]u8 = @ptrCast(y);

    var message: [25]u8 = undefined;
    message[0] = @intFromEnum(Request.game_packet);
    @memcpy(message[1..17], client_id);
    @memcpy(message[17..21], x_ptr);
    @memcpy(message[21..25], y_ptr);
    const request = c.enet_packet_create(&message, message.len, c.ENET_PACKET_FLAG_RELIABLE);
    _ = c.enet_peer_send(peer, 0, request);
}

export fn hermesAwaitBeginMatch() c_int {
    const result = c.enet_host_service(client, &event, 0);
    if (result > 0) switch (event.type) {
        c.ENET_EVENT_TYPE_CONNECT => {
            std.debug.print("client connected\n", .{});
        },
        c.ENET_EVENT_TYPE_RECEIVE => {
            const packet = event.packet.*;
            const req_type: Request = @enumFromInt(packet.data[0]);
            switch (req_type) {
                .get_uuid => {},
                .assign_name => {},
                .create_room => {},
                .join_room => {},
                .leave_room => {},
                .list_rooms => {},
                .start_game => {},
                .game_packet => {},
                .begin_match => {
                    return @intFromBool(true);
                },
                .loaded => {},
                _ => {},
            }
            c.enet_packet_destroy(event.packet);
        },
        c.ENET_EVENT_TYPE_NONE => {
            return 0;
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
    return @intFromBool(false);
}

export fn hermesDeinit() void {
    c.enet_deinitialize();
    c.enet_host_destroy(client);
}
