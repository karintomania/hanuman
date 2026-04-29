const std = @import("std");
const parse = @import("parse.zig");
const interpret = @import("interpret.zig");

// 4MB
const MAX_BYTES: usize = 4096 * 1000;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("Memory leak detected!");
    }

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        std.debug.print("Usage: hanuman [FILE]", .{});
        return;
    }

    const file_path = args[1];
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const code = try file.readToEndAlloc(allocator, MAX_BYTES);
    defer allocator.free(code);

    var parser = parse.Parser.init(allocator);
    defer parser.deinit();
    const stmts = try parser.parse(code);

    var interpreter = interpret.Interpreter.init(allocator);
    defer interpreter.deinit();
    try interpreter.interpret(stmts);
}
