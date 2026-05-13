const std = @import("std");
const Allocator = std.mem.Allocator;
const parse = @import("parse.zig");
const Stmt = parse.Stmt;
const Parser = parse.Parser;

const memory_capacity = 1 << 16;

var memory: [memory_capacity]i32 = undefined;

pub const Interpreter = struct {
    arena: std.heap.ArenaAllocator,
    defs: std.StringHashMapUnmanaged([]Stmt),

    pub fn init(allocator: Allocator) Interpreter {
        // init memory
        memory = [_]i32{0} ** (memory_capacity);

        return Interpreter{
            .arena = .init(allocator),
            .defs = .empty,
        };
    }

    pub fn interpret(self: *Interpreter, stmts: []Stmt) !void {
        var current: u16 = 0;
        const allocator = self.arena.allocator();
        for (stmts) |stmt| {
            switch (stmt) {
                .add => |add| {
                    switch (add.num) {
                        .idx => |idx| {
                            const n = memory[idx];
                            memory[current] +%= n;
                        },
                        .n => |n| {
                            memory[current] +%= n;
                        },
                    }
                },
                .minus => |minus| {
                    switch (minus.num) {
                        .idx => |idx| {
                            const n = memory[idx];
                            memory[current] -%= n;
                        },
                        .n => |n| {
                            memory[current] -%= n;
                        },
                    }
                },
                .multi => |multi| {
                    switch (multi.num) {
                        .idx => |idx| {
                            const n = memory[idx];
                            memory[current] *%= n;
                        },
                        .n => |n| {
                            memory[current] *%= n;
                        },
                    }
                },
                .div => |div| {
                    switch (div.num) {
                        .idx => |idx| {
                            const n = memory[idx];
                            memory[current] = @divTrunc(memory[current], n);
                        },
                        .n => |n| {
                            memory[current] = @divTrunc(memory[current], n);
                        },
                    }
                },
                .mod => |mod| {
                    switch (mod.num) {
                        .idx => |idx| {
                            const n = memory[idx];
                            memory[current] = @mod(memory[current], n);
                        },
                        .n => |n| {
                            memory[current] = @mod(memory[current], n);
                        },
                    }
                },
                .move => |move| {
                    current = move.idx;
                },
                .reset => {
                    memory[current] = 0;
                },
                .rand => {
                    memory[current] = std.crypto.random.intRangeAtMost(
                        i32,
                        std.math.minInt(i32),
                        std.math.maxInt(i32),
                    );
                },
                .print_digit => {
                    std.debug.print("{d}", .{memory[current]});
                },
                .print_unicode => {
                    const str = try self.get_unicode_str(memory[current]);
                    std.debug.print("{s}", .{str});
                },
                .echo => |echo| {
                    std.debug.print("{s}", .{echo.str});
                },
                .cr => {
                    std.debug.print("\n", .{});
                },
                .func_def => |func_def| {
                    try self.defs.put(allocator, func_def.name, func_def.body);
                },
                .func_call => |func_call| {
                    const body = self.defs.get(func_call.name).?;
                    try self.interpret(body);
                },
                .loop => |loop| {
                    while (memory[current] != 0) {
                        try self.interpret(loop.body);
                    }
                },
                .cond => |cond| {
                    if (memory[current] != 0) {
                        try self.interpret(cond.body_then);
                    } else {
                        try self.interpret(cond.body_else);
                    }
                },
                // else => {},
            }
        }
    }

    fn get_unicode_str(self: *Interpreter, u: i32) ![]u8 {
        // discard extra bits
        const c: u21 = @truncate(@as(u32, @bitCast(u)));
        const len = try std.unicode.utf8CodepointSequenceLength(c);

        const out = try self.arena.allocator().alloc(u8, len);
        _ = try std.unicode.utf8Encode(c, out);

        return out;
    }

    pub fn deinit(self: *Interpreter) void {
        self.arena.deinit();
    }
};

test "interpret num operations" {
    const code =
        \\@1
        \\+5
        \\-4
        \\@2
        \\+2
        \\*3
        \\/2
        \\@3
        \\+10
        \\%3
        \\@4
        \\+20
        \\_
    ;

    var parser = parse.Parser.init(std.testing.allocator);

    const stmts = try parser.parse(code);
    defer parser.deinit();

    var interpreter = Interpreter.init(std.testing.allocator);
    try interpreter.interpret(stmts);
    defer interpreter.deinit();

    try std.testing.expectEqual(0, memory[0]);
    try std.testing.expectEqual(1, memory[1]);
    try std.testing.expectEqual(3, memory[2]);
    try std.testing.expectEqual(1, memory[3]);
    try std.testing.expectEqual(0, memory[4]);
}

test "interpret function" {
    const code =
        \\+1
        \\fn_x
        \\@1
        \\+10
        \\end_fn
        \\call_x
    ;

    var parser = parse.Parser.init(std.testing.allocator);

    const stmts = try parser.parse(code);
    defer parser.deinit();

    var interpreter = Interpreter.init(std.testing.allocator);
    try interpreter.interpret(stmts);
    defer interpreter.deinit();

    try std.testing.expectEqual(1, memory[0]);
    try std.testing.expectEqual(10, memory[1]);
    try std.testing.expectEqual(0, memory[2]);
}

test "interpret loop" {
    const code =
        \\+10
        \\[
        \\-1
        \\@1
        \\+1
        \\@0
        \\]
    ;

    var parser = parse.Parser.init(std.testing.allocator);

    const stmts = try parser.parse(code);
    defer parser.deinit();

    var interpreter = Interpreter.init(std.testing.allocator);
    try interpreter.interpret(stmts);
    defer interpreter.deinit();

    try std.testing.expectEqual(0, memory[0]);
    try std.testing.expectEqual(10, memory[1]);
    try std.testing.expectEqual(0, memory[2]);
}

test "interpret cond" {
    const code =
        \\fn_test
        \\?
        \\@1
        \\+10
        \\:
        \\@2
        \\-10
        \\;
        \\end_fn
        \\@0
        \\call_test
        \\@0
        \\+1
        \\call_test
    ;

    var parser = parse.Parser.init(std.testing.allocator);

    const stmts = try parser.parse(code);
    defer parser.deinit();

    var interpreter = Interpreter.init(std.testing.allocator);
    try interpreter.interpret(stmts);
    defer interpreter.deinit();

    try std.testing.expectEqual(1, memory[0]);
    try std.testing.expectEqual(10, memory[1]);
    try std.testing.expectEqual(-10, memory[2]);
}
