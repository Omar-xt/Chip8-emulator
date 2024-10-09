const std = @import("std");
const cpu = @import("cpu.zig");
const sdl = @cImport(@cInclude("SDL.h"));

fn prints(args: []const u8) void {
    std.debug.print("{s}\n", .{args});
}

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;

const cols = 32;
const rows = 64;
const pixel_size = 16;
const SCREEN_WIDTH = rows * pixel_size;
const SCREEN_HEIGHT = cols * pixel_size;

fn init() void {
    if (sdl.SDL_Init(sdl.SDL_INIT_EVERYTHING) < 0) {
        @panic("SDL Initialization Failed!");
    }

    window = sdl.SDL_CreateWindow("Omar", sdl.SDL_WINDOWPOS_CENTERED, sdl.SDL_WINDOWPOS_CENTERED, SCREEN_WIDTH, SCREEN_HEIGHT, 0);

    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_WINDOW_OPENGL);
}

pub fn deinit() void {
    sdl.SDL_DestroyWindow(window);
    window = null;

    sdl.SDL_Quit();
}

fn event_loop(keep_running: *bool) void {
    var e: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&e) > 0) {
        switch (e.type) {
            sdl.SDL_QUIT => keep_running.* = false,
            sdl.SDL_KEYDOWN => {
                if (e.key.keysym.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                    keep_running.* = false;
                }

                if (e.key.keysym.scancode == sdl.SDL_SCANCODE_W) {
                    cpu.set_key(@intCast(2));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_A) {
                    cpu.set_key(@intCast(4));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_D) {
                    cpu.set_key(@intCast(6));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_S) {
                    cpu.set_key(@intCast(8));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_0) {
                    cpu.set_key(@intCast(0));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_1) {
                    cpu.set_key(@intCast(1));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_2) {
                    cpu.set_key(@intCast(3));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_3) {
                    cpu.set_key(@intCast(5));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_4) {
                    cpu.set_key(@intCast(7));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_5) {
                    cpu.set_key(@intCast(9));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_6) {
                    cpu.set_key(@intCast(10));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_T) {
                    cpu.set_key(@intCast(11));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_Y) {
                    cpu.set_key(@intCast(12));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_U) {
                    cpu.set_key(@intCast(13));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_I) {
                    cpu.set_key(@intCast(14));
                } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_O) {
                    cpu.set_key(@intCast(15));
                }

                // std.debug.print("{any}\n", .{e.key});
            },
            sdl.SDL_KEYUP => {
                cpu.set_key(16);
            },
            else => {},
        }
    }
}

fn set_rect_pos(x: usize, y: usize, rect: *sdl.SDL_Rect) void {
    rect.*.x = @intCast(x);
    rect.*.y = @intCast(y);
}

pub fn main() !void {

    // try cpu.execute();
    // cpu.draw();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var arg_it = try std.process.argsWithAllocator(allocator);
    _ = arg_it.skip();

    const filename = arg_it.next() orelse blk: {
        prints("No ROM file given!\n");
        break :blk "test1.ch8";
    };

    try cpu.loadRom(filename);
    defer cpu.deinit();

    init();
    defer deinit();

    _ = sdl.SDL_RenderPresent(renderer);

    var rect = sdl.SDL_Rect{ .x = 0, .y = 0, .w = pixel_size, .h = pixel_size };

    var keep_running = true;
    while (keep_running) {
        event_loop(&keep_running);

        _ = sdl.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 255);

        _ = sdl.SDL_RenderClear(renderer);

        _ = sdl.SDL_SetRenderDrawColor(renderer, 250, 250, 250, 255);

        try cpu.one_step();

        for (0..cols) |j| {
            for (0..rows) |i| {
                const ind = i + j * rows;
                set_rect_pos(i * pixel_size, j * pixel_size, &rect);

                if (cpu.graphic[ind] == 1) {
                    //-- outline
                    // _ = sdl.SDL_RenderDrawRect(renderer, &rect);
                    //-- fill
                    _ = sdl.SDL_RenderFillRect(renderer, &rect);
                }
            }
        }

        _ = sdl.SDL_RenderPresent(renderer);

        std.time.sleep(@divFloor(1e9, 180));
        // cpu.draw();

        // cpu.set_key(0);
    }

    std.debug.print("--->{any}\n", .{cpu.registers});
}
