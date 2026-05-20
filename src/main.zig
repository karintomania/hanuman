const std = @import("std");
const parse = @import("parse.zig");
const lint = @import("lint.zig");
const interpret = @import("interpret.zig");

// 4MB
const MAX_BYTES: usize = 4096 * 1000;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("Memory leak detected!");
    }

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            \\Usage: hanuman [FILE]
            \\Options:
            \\  --lint [FILE]: replace ascii syntax of the specified file to full syntax
        ,
            .{},
        );
        return 1;
    }

    if (std.mem.eql(u8, args[1], "--lint")) {
        const file_path = args[2];
        const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_write });
        defer file.close();
        const code = try file.readToEndAlloc(allocator, MAX_BYTES);
        defer allocator.free(code);

        var linter = lint.Linter.init(allocator);
        defer linter.deinit();

        const linted = try linter.lint(code);

        try file.seekTo(0);
        try file.setEndPos(linted.len);
        try file.writeAll(linted);

        return 0;
    }

    const file_path = args[1];
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const code = try file.readToEndAlloc(allocator, MAX_BYTES);
    defer allocator.free(code);

    var parser = parse.Parser.init(allocator);
    defer parser.deinit();
    const stmts = parser.parse(code) catch {
        std.debug.print("俺の知らない遊びを知ってそうでああなんか急に虚しくなる (Parse Error) at line {d}:\n\"{s}\"\n", .{ parser.line_num, parser.line_processing });
        return 1;
    };

    var interpreter = interpret.Interpreter.init(allocator);
    defer interpreter.deinit();
    try interpreter.interpret(stmts);

    return 0;
}

test {
    // This ensures their tests are included.
    std.testing.refAllDecls(@This());
}
