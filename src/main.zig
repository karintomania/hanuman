const std = @import("std");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("Memory leak detected!");
    }
    const allocator = gpa.allocator();

    const code =
        \\-1
        \\p_num
        \\@2
        \\-2
        \\p_num
    ;

    const stmts = try parser.parse(allocator, code);
    defer allocator.free(stmts);

    interpreter.interpret(stmts);
}
