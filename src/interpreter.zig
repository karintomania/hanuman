const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const Stmt = parser.Stmt;

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

    const stmts = try parser.parse(std.testing.allocator, code);
    defer std.testing.allocator.free(stmts);

    interpret(stmts);

    try std.testing.expectEqual(0, memory[0]);
    try std.testing.expectEqual(0, memory[1]);
    try std.testing.expectEqual(1, memory[2]);
}
