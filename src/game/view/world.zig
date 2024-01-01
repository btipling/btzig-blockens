const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const plane = @import("../shape/plane.zig");
const cursor = @import("../shape/cursor.zig");
const cube = @import("../shape/cube.zig");
const shape = @import("../shape/shape.zig");

const chunkSize: comptime_int = 64 * 64 * 64;

pub const World = struct {
    worldPlane: plane.Plane,
    cursor: cursor.Cursor,
    appState: *state.State,

    pub fn init(worldPlane: plane.Plane, c: cursor.Cursor, appState: *state.State) !World {
        return World{
            .worldPlane = worldPlane,
            .appState = appState,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World) !void {
        // const chunk: [chunkSize]u32 = [_]u32{1} ** chunkSize;
        const chunk: [1]u32 = [_]u32{1};
        const m = self.appState.game.lookAt;
        try self.worldPlane.draw(m);
        for (chunk, 0..) |blockId, i| {
            const x = @as(gl.Float, @floatFromInt(@mod(i, 64)));
            const y = @as(gl.Float, @floatFromInt(@mod(i / 64, 64)));
            const z = @as(gl.Float, @floatFromInt(i / (64 * 64)));
            if (self.appState.game.cubesMap.get(blockId)) |is| {
                try cube.Cube.drawInstanced(x, y, z, m, is);
            } else {
                std.debug.print("blockId {d} not found in cubesMap\n", .{blockId});
            }
        }
        try self.cursor.draw(m);
    }
};
