const std = @import("std");
const Allocator = std.mem.Allocator;
const parse = @import("parse.zig");
const Stmt = parse.Stmt;
const Parser = parse.Parser;

var memory = [_]i32{0} ** (1 << 16);

pub fn interpret(stmts: []Stmt) void {
    var current: u16 = 0;
    for (stmts) |stmt| {
        switch (stmt) {
            .add => |add| {
                memory[current] += add.num;
            },
            .minus => |minus| {
                memory[current] -= minus.num;
            },
            .move => |move| {
                current = move.idx;
            },
            .print_num => {
                std.debug.print("{d}", .{memory[current]});
            },
            else => unreachable,
        }
    }
}

test "interpret" {
    const code =
        \\@2
        \\+5
        \\-4
        \\p_num
    ;

    var parser = parse.Parser.init(std.testing.allocator);

    const stmts = try parser.parse(code);
    defer parser.deinit();

    interpret(stmts);

    try std.testing.expectEqual(0, memory[0]);
    try std.testing.expectEqual(0, memory[1]);
    try std.testing.expectEqual(1, memory[2]);
}
