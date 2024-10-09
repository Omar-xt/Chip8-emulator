const std = @import("std");

const cols = 32;
const rows = 64;

pub var registers = [_]u8{0} ** 16;

var regI: u12 = 0;
const pc: u8 = 0;

pub var graphic = [_]u1{0} ** (rows * cols);

var current_key: u8 = 16;
var delay_timer: u8 = 0;

//-- allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

//-- subroutine stack
var s_stack = std.ArrayList(u64).init(allocator);

var memory = [_]u8{0} ** 4096;
var mem_reader: FileReader = undefined;

// pub fn init(cols: comptime_int, ) void {
//     cols = cols;
//     rows = rows;
// }

pub fn set_key(key: u8) void {
    current_key = key;
}

const FileReader = struct {
    file: std.fs.File,
    reader: std.fs.File.Reader,

    pub fn init(file: std.fs.File) !FileReader {
        return FileReader{
            .file = file,
            .reader = file.reader(),
        };
    }

    pub fn deinit(self: @This()) void {
        self.file.close();
    }
};

pub fn loadRom(file_path: []const u8) !void {
    const fs = std.fs.cwd();
    const temprom = try fs.createFile("temp.ch8", .{ .read = true });
    const interpreater = try fs.openFile("interpreter_rom.rom", .{});
    const file = try fs.openFile(file_path, .{});
    defer file.close();
    defer interpreater.close();

    try temprom.writeFileAll(interpreater, .{});
    try temprom.writeFileAll(file, .{});

    try temprom.seekTo(512);

    mem_reader = try FileReader.init(temprom);
}

fn dcr(opcode: u16) void {
    _ = opcode;
    for (&graphic) |*p| {
        p.* = 0;
    }
}

//-- Render
pub fn draw() void {
    for (0..cols) |j| {
        for (0..rows) |i| {
            const ind = i + j * rows;
            // std.debug.print("{d} ", .{ind});
            if (graphic[ind] == 1) {
                std.debug.print("11", .{});
            } else std.debug.print(" ", .{});
        }
        std.debug.print("\n", .{});
    }
}

//-- Display a sprite
fn dat(opcode: u16) void {
    const vx = (opcode >> 8) & 0xf;
    const vy = (opcode >> 4) & 0xf;
    const height = opcode & 0xf;
    const x = registers[vx];
    const y = registers[vy];

    const current_pos = mem_reader.reader.context.getPos() catch unreachable;
    defer mem_reader.reader.context.seekTo(current_pos) catch unreachable;

    mem_reader.reader.context.seekTo(regI) catch unreachable;

    registers[15] = 0;

    for (0..height) |j| {
        const width = mem_reader.reader.readInt(u8, .big) catch unreachable;
        for (0..8) |i| {
            const ind = ((x + i) % rows) + ((j + y) % cols) * rows;
            const mask = ((width >> 7 - @as(u3, @truncate(i))) ^ graphic[ind]) & 1;
            if (mask > 0) {
                graphic[ind] = 1;
            } else {
                if (graphic[ind] == 1) registers[15] = 1;
                graphic[ind] = 0;
            }
        }
    }
}

//--set reg
fn str(opcode: u16) void {
    const nn: u8 = @truncate(opcode);
    const x = (opcode >> 8) & 0xf;
    registers[x] = nn;
}

//-- set i
fn sei(opcode: u16) void {
    const mem: u12 = @truncate(opcode);
    regI = mem;
}

//-- Returns from a subroutine
fn rfs(opcode: u16) void {
    _ = opcode;
    const adress = s_stack.pop();
    mem_reader.reader.context.seekTo(adress) catch unreachable;
}

//-- Jumps to address
fn jta(opcode: u16) void {
    const adress: u12 = @truncate(opcode);
    mem_reader.reader.context.seekTo(adress) catch unreachable;
}

//-- Calls subroutine at NNN
fn csa(opcode: u16) void {
    const adress: u12 = @truncate(opcode);
    const offset = mem_reader.reader.context.getPos() catch unreachable;
    s_stack.append(offset) catch unreachable;

    mem_reader.reader.context.seekTo(adress) catch unreachable;
}

//-- Skips the next instruction on equal
fn seq(opcode: u16) void {
    const nn: u8 = @truncate(opcode);
    const x: usize = (opcode >> 8) & 0xf;

    if (registers[x] == nn) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
    }
}

//-- Skips the next instruction on not equal
fn snq(opcode: u16) void {
    const nn: u8 = @truncate(opcode);
    const x: usize = (opcode >> 8) & 0xf;

    if (registers[x] != nn) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
    }
}

//-- Skips the next instruction if VX equals VY
fn sbe(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    if (registers[x] == registers[y]) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
    }
}

//-- Increment
fn inc(opcode: u16) void {
    @setRuntimeSafety(false);
    const nn: u8 = @truncate(opcode);
    const x: usize = (opcode >> 8) & 0xf;

    registers[x] += nn;
}

//-- Assign
fn ass(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    registers[x] = registers[y];
}

//-- Bitwise OR
fn bor(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    registers[x] |= registers[y];
}

//-- Bitwise AND
fn bnd(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    registers[x] &= registers[y];
}

//-- Bitwise XOR
fn xor(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    registers[x] ^= registers[y];
}

//-- Add
fn add(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    const overflow = (255 - registers[x]) < registers[y];

    if (overflow) {
        // @setRuntimeSafety(false);
        registers[x] = registers[y] - (255 - registers[x]) - 1;
    } else registers[x] += registers[y];

    registers[15] = @intFromBool(overflow);
}

//-- Subtrac
fn sub(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    const overflow = registers[x] < registers[y];

    if (overflow) {
        registers[x] = 255 - (registers[y] - registers[x]) + 1;
    } else registers[x] -= registers[y];

    registers[15] = @intFromBool(overflow);
}

//-- Shift right
fn shr(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    registers[x] >>= 1;

    registers[15] = registers[x] & 1;
}

//-- Subtrac 2
fn su2(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    const overflow = registers[x] > registers[y];
    if (overflow) {
        registers[x] = 255 - (registers[x] - registers[y]) + 1;
    } else registers[x] = registers[y] - registers[x];

    registers[15] = @intFromBool(overflow);
}

//-- Shift left
fn shl(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    registers[x] <<= 1;

    registers[15] = (registers[x] >> 7) & 1;
}

//-- Skips the next instruction if VX does not equal VY
fn se2(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const y: usize = (opcode >> 4) & 0xf;

    if (registers[x] != registers[y]) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
    }
}

//-- Jumps to the address NNN plus V0
fn jtn(opcode: u16) void {
    const adress: u12 = @truncate(opcode);
    const offset = mem_reader.reader.context.getPos() catch unreachable;
    s_stack.append(offset) catch unreachable;

    mem_reader.reader.context.seekTo(adress + registers[0]) catch unreachable;
}

//---------------
const random = std.crypto.random;
//-- Set random number
fn ran(opcode: u16) void {
    const nn: u8 = @truncate(opcode);
    const x: usize = (opcode >> 8) & 0xf;
    const r = random.int(u8);

    registers[x] = r & nn;
}
//--------------

//-- Skip on key match
fn ske(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    if (registers[x] == current_key) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
        // current_key = 0;
    }
}

//-- Skip on key unmatch
fn snu(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    if (registers[x] != current_key) {
        mem_reader.reader.context.seekBy(2) catch unreachable;
    }
    // else current_key = 0;
}

//-- Set delay Timer
fn sdt(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    registers[x] = delay_timer;
}

//-- Await key press
fn akp(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    while (current_key < 16) {
        registers[x] = current_key;
        // current_key = 0;
    }
}

//-- Sets the delay timer to VX
fn sdr(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    delay_timer = registers[x];
}

//-- Adds VX to I
fn avi(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    regI += registers[x];
}

//-- Charecter font memory set
fn scm(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;

    regI = registers[x] * 5;
    // regI = @as(u12, @truncate(x)) * 5;
}

//-- Binary codded decimal
fn bcd(opcode: u16) void {
    const x: u4 = @truncate(opcode >> 8);
    const current_pos = mem_reader.reader.context.getPos() catch unreachable;
    defer mem_reader.reader.context.seekTo(current_pos) catch unreachable;

    mem_reader.reader.context.seekTo(regI) catch unreachable;

    var val = registers[x];

    const c = val % 10;
    val /= 10;
    const b = val % 10;
    const a = val / 10;

    std.debug.print("val -> {x} a {d} - b {b} - c {d} \n", .{ val, a, b, c });

    const dcm: [3]u8 = .{ a, b, c };

    const d = allocator.dupe(u8, &dcm) catch unreachable;

    _ = mem_reader.file.write(d) catch unreachable;
    // _ = mem_reader.file.write(d[1..2]) catch unreachable;
    // _ = mem_reader.file.write(d[2..3]) catch unreachable;
}

//-- Stores from V0 to VX (including VX) in memory
fn rdm(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const current_pos = mem_reader.reader.context.getPos() catch unreachable;
    defer mem_reader.reader.context.seekTo(current_pos) catch unreachable;

    mem_reader.reader.context.seekTo(regI) catch unreachable;

    _ = mem_reader.file.write(registers[0 .. x + 1]) catch unreachable;
}

//-- Fills from V0 to VX (including VX) with values from memory
fn rlm(opcode: u16) void {
    const x: usize = (opcode >> 8) & 0xf;
    const current_pos = mem_reader.reader.context.getPos() catch unreachable;
    defer mem_reader.reader.context.seekTo(current_pos) catch unreachable;

    mem_reader.reader.context.seekTo(regI) catch unreachable;

    for (0..x + 1) |ind| {
        const val = mem_reader.reader.readInt(u8, .big) catch unreachable;
        registers[ind] = val;
    }
}

const op_matcher = struct {
    opcode: u16,
    mask: u16,
    func: fn (u16) void,
};

const analyzer = [_]op_matcher{
    .{ .opcode = 0x00e0, .mask = 0xffff, .func = dcr },
    .{ .opcode = 0x00ee, .mask = 0xffff, .func = rfs },
    .{ .opcode = 0x1000, .mask = 0xf000, .func = jta },
    .{ .opcode = 0x2000, .mask = 0xf000, .func = csa },
    .{ .opcode = 0x3000, .mask = 0xf000, .func = seq },
    .{ .opcode = 0x4000, .mask = 0xf000, .func = snq },
    .{ .opcode = 0x5000, .mask = 0xf00f, .func = sbe },
    .{ .opcode = 0x6000, .mask = 0xf000, .func = str },
    .{ .opcode = 0x7000, .mask = 0xf000, .func = inc },
    .{ .opcode = 0x8000, .mask = 0xf00f, .func = ass },
    .{ .opcode = 0x8001, .mask = 0xf00f, .func = bor },
    .{ .opcode = 0x8002, .mask = 0xf00f, .func = bnd },
    .{ .opcode = 0x8003, .mask = 0xf00f, .func = xor },
    .{ .opcode = 0x8004, .mask = 0xf00f, .func = add },
    .{ .opcode = 0x8005, .mask = 0xf00f, .func = sub },
    .{ .opcode = 0x8006, .mask = 0xf00f, .func = shr },
    .{ .opcode = 0x8007, .mask = 0xf00f, .func = su2 },
    .{ .opcode = 0x800e, .mask = 0xf00f, .func = shl },
    .{ .opcode = 0x9000, .mask = 0xf00f, .func = se2 },
    .{ .opcode = 0xa000, .mask = 0xf000, .func = sei },
    .{ .opcode = 0xb000, .mask = 0xf000, .func = jtn },
    .{ .opcode = 0xc000, .mask = 0xf000, .func = ran },
    .{ .opcode = 0xd000, .mask = 0xf000, .func = dat },
    .{ .opcode = 0xe09e, .mask = 0xf0ff, .func = ske },
    .{ .opcode = 0xe0a1, .mask = 0xf0ff, .func = snu },
    .{ .opcode = 0xf007, .mask = 0xf0ff, .func = sdt },
    .{ .opcode = 0xf00a, .mask = 0xf0ff, .func = sdt },
    .{ .opcode = 0xf015, .mask = 0xf0ff, .func = sdr },
    .{ .opcode = 0xf01e, .mask = 0xf0ff, .func = avi },
    .{ .opcode = 0xf029, .mask = 0xf0ff, .func = scm },
    .{ .opcode = 0xf033, .mask = 0xf0ff, .func = bcd },
    .{ .opcode = 0xf055, .mask = 0xf0ff, .func = rdm },
    .{ .opcode = 0xf065, .mask = 0xf0ff, .func = rlm },
};

pub fn get_opcode() !u16 {
    const opcode = try mem_reader.reader.readInt(u16, .big);
    return opcode;
}

pub fn execute() !void {
    while (true) {
        const opcode = try get_opcode();
        if (opcode == 0) break;

        inline for (analyzer) |an| {
            const p = opcode & an.mask;
            // std.debug.print("{x:0>4}\n", .{p});

            if (p == an.opcode) {
                // std.debug.print("{x:0>4}\n", .{opcode});

                an.func(opcode);
                break;
            }
        }

        // draw();
    }
}

var tarminate = false;

pub fn one_step() !void {
    if (tarminate)
        return;

    const opcode = try get_opcode();
    std.debug.print("{x}\n", .{opcode});
    if (opcode == 0) {
        std.debug.print("end of opcode\n", .{});
        tarminate = true;
        return;
    }

    inline for (analyzer, 0..) |an, ind| {
        const p = opcode & an.mask;
        // std.debug.print("{x:0>4}\n", .{p});

        if (p == an.opcode) {
            _ = ind;
            // std.debug.print("{x:0>4} -> ", .{opcode});
            // std.debug.print("{d} -> {d} \n", .{ ind, delay_timer });

            an.func(opcode);

            break;
        }
    }

    // current_key = 0;

    if (delay_timer > 0)
        delay_timer -= 1;
}

pub fn deinit() void {
    mem_reader.deinit();
}
