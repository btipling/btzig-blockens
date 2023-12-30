const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const texture_gen = @import("texture_gen.zig");
const game = @import("game.zig");
const state = @import("../state.zig");

const pressStart2PFont = @embedFile("../assets/fonts/PressStart2P/PressStart2P-Regular.ttf");

pub const UI = struct {
    window: *glfw.Window,
    Game: game.Game,
    TextureGen: texture_gen.TextureGen,

    pub fn init(appState: *state.State, window: *glfw.Window, alloc: std.mem.Allocator) !UI {
        const font_size: f32 = 24.0;
        const gameFont = zgui.io.addFontFromMemory(pressStart2PFont, std.math.floor(font_size * 1.1));
        zgui.io.setDefaultFont(gameFont);
        return UI{
            .window = window,
            .Game = game.Game{},
            .TextureGen = try texture_gen.TextureGen.init(appState, alloc),
        };
    }

    pub fn deinit(self: UI) void {
        self.TextureGen.deinit();
    }

    pub fn drawGame(self: *UI) !void {
        try self.Game.draw(self.window);
    }

    pub fn drawTextureGen(self: *UI) !void {
        try self.TextureGen.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }
};
