const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const position = @import("position.zig");
const config = @import("config.zig");
const cube = @import("./shape/cube.zig");
const shape = @import("./shape/shape.zig");
const data = @import("./data/data.zig");

pub const State = struct {
    app: App,
    game: Game,
    db: data.Data,

    pub fn init(alloc: std.mem.Allocator) !State {
        var db = try data.Data.init(alloc);
        db.ensureSchema() catch |err| {
            std.log.err("Failed to ensure schema: {}\n", .{err});
            return err;
        };
        db.ensureDefaultWorld() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
        var s = State{
            .app = try App.init(),
            .game = try Game.init(alloc),
            .db = db,
        };
        try s.game.initBlocks(&s, alloc);
        return s;
    }

    pub fn deinit(self: *State) void {
        self.game.deinit();
    }
};

pub const View = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
};

pub const App = struct {
    view: View = View.game,
    demoCubeVersion: u32 = 0,
    demoTextureColors: ?[data.RGBAColorTextureSize]gl.Uint,

    pub fn init() !App {
        return App{
            .view = View.game,
            .demoCubeVersion = 0,
            .demoTextureColors = null,
        };
    }

    fn clearViewState(self: *App) void {
        self.demoCubeVersion += 1;
        self.demoTextureColors = null;
    }

    pub fn setGameView(self: *App) !void {
        self.clearViewState();
        self.view = View.game;
    }

    pub fn setTextureGeneratorView(self: *App) !void {
        self.clearViewState();
        self.view = View.textureGenerator;
    }

    pub fn setWorldEditorView(self: *App) !void {
        self.clearViewState();
        self.view = View.worldEditor;
    }

    pub fn setBlockEditorView(self: *App) !void {
        self.clearViewState();
        self.view = View.blockEditor;
    }

    pub fn setTextureColor(self: *App, demoTextureColors: [data.RGBAColorTextureSize]gl.Uint) void {
        self.demoTextureColors = demoTextureColors;
        self.demoCubeVersion += 1;
    }
};

pub const Game = struct {
    blockOptions: std.ArrayList(data.blockOption),
    cameraPos: @Vector(4, gl.Float),
    cameraFront: @Vector(4, gl.Float),
    cameraUp: @Vector(4, gl.Float),
    lookAt: zm.Mat,
    lastFrame: gl.Float,
    deltaTime: gl.Float,
    firstMouse: bool,
    lastX: gl.Float,
    lastY: gl.Float,
    yaw: gl.Float,
    pitch: gl.Float,
    blocks: std.ArrayList(cube.Cube),
    highlightedIndex: ?usize = 0,

    pub fn init(alloc: std.mem.Allocator) !Game {
        var g = Game{
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
            .cameraPos = @Vector(4, gl.Float){ 0.0, 1.0, 3.0, 1.0 },
            .cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 },
            .cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 },
            .lookAt = zm.identity(),
            .lastFrame = 0.0,
            .deltaTime = 0.0,
            .firstMouse = true,
            .lastX = 0.0,
            .lastY = 0.0,
            .yaw = -90.0,
            .pitch = 0.0,
            .blocks = std.ArrayList(cube.Cube).init(alloc),
        };

        try Game.updateLookAt(&g);
        return g;
    }

    pub fn deinit(self: *Game) void {
        for (self.blocks.items) |block| {
            block.deinit();
        }
    }

    pub fn initBlocks(self: *Game, appState: *State, alloc: std.mem.Allocator) !void {
        try appState.db.listBlocks(&self.blockOptions);
        var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        if (self.blockOptions.items.len == 0) {
            return;
        }
        for (0..config.num_blocks) |_| {
            const b = try self.getRandomBlock(appState, self.blocks, alloc, random);
            try self.blocks.append(b);
        }
    }

    pub fn updateCameraPosition(self: *Game, updatedCameraPosition: @Vector(4, gl.Float)) !void {
        self.cameraPos = updatedCameraPosition;
        try self.updateLookAt();
        try self.pickObject();
    }

    pub fn updateCameraFront(self: *Game, updatedCameraFront: @Vector(4, gl.Float)) !void {
        self.cameraFront = updatedCameraFront;
        try self.updateLookAt();
        try self.pickObject();
    }

    fn updateLookAt(self: *Game) !void {
        self.lookAt = zm.lookAtRh(
            self.cameraPos,
            self.cameraPos + self.cameraFront,
            self.cameraUp,
        );
    }

    fn pickObject(self: *Game) !void {
        var currentPos = self.cameraPos;
        const maxRayLength = 100;
        var found = false;
        for (0..maxRayLength) |i| {
            if (i == maxRayLength) {
                return;
            }
            const checkDistance = @as(gl.Float, @floatFromInt(i));
            const cdV: @Vector(4, gl.Float) = @splat(checkDistance);
            const distance = @as(@Vector(4, gl.Float), cdV);
            currentPos = @floor(self.cameraPos + (distance * self.cameraFront));
            for (self.blocks.items, 0..) |block, j| {
                if (block.position.x == currentPos[0] and block.position.y == currentPos[1] and block.position.z == currentPos[2]) {
                    if (self.highlightedIndex) |hi| {
                        if (hi == j) {
                            return;
                        }
                        self.blocks.items[hi].shape.highlight = 0;
                    }
                    self.highlightedIndex = j;
                    self.blocks.items[j].shape.highlight = 1;
                    found = true;
                }
            }
        }
        if (!found) {
            if (self.highlightedIndex) |hi| {
                if (self.blocks.items.len > hi) {
                    self.blocks.items[hi].shape.highlight = 0;
                }
            }
            self.highlightedIndex = null;
        }
    }

    pub fn getRandomBlock(self: *Game, appState: *State, blocks: std.ArrayList(cube.Cube), alloc: std.mem.Allocator, random: std.rand.Random) !cube.Cube {
        var pos: position.Position = undefined;
        var available = false;
        const maxTries = 100;
        var tries: u32 = 0;
        while (!available and tries < maxTries) {
            pos = randomBlockPosition(random);
            var found = false;
            for (blocks.items) |block| {
                if (block.position.x == pos.x and block.position.y == pos.y and block.position.z == pos.z) {
                    found = true;
                    break;
                }
            }
            available = !found;
            tries += 1;
        }
        return try cube.Cube.init(appState, self.randomCubeType(random), pos, alloc);
    }

    pub fn randomCubeType(self: *Game, random: std.rand.Random) u32 {
        const i = random.uintAtMost(usize, self.blockOptions.items.len - 1);
        return self.blockOptions.items[i].id;
    }

    pub fn randomXZP(random: std.rand.Random) gl.Float {
        return @as(gl.Float, @floatFromInt(random.uintAtMost(u32, 15)));
    }

    pub fn randomYP(random: std.rand.Random) gl.Float {
        switch (random.uintAtMost(u32, 100)) {
            0...75 => return 0.0,
            76...85 => return 1.0,
            86...95 => return 2.0,
            else => return 3.0,
        }
    }

    pub fn randomBlockPosition(
        random: std.rand.Random,
    ) position.Position {
        return position.Position{ .x = randomXZP(random) - 15 / 2, .y = randomYP(random), .z = (randomXZP(random) * -1.0) };
    }
};
