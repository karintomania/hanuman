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

    if (args.len < 2 or 3 < args.len) {
        usage();
        return 1;
    }

    if (args.len == 3) {
        const file_path = args[2];
        const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_write });
        defer file.close();
        const code = try file.readToEndAlloc(allocator, MAX_BYTES);
        defer allocator.free(code);

        var linter = lint.Linter.init(allocator);
        defer linter.deinit();

        var linted: []const u8 = undefined;

        if (std.mem.eql(u8, args[1], "--to-ascii")) {
            linted = try linter.to_ascii(code);
        } else if (std.mem.eql(u8, args[1], "--to-lyrics")) {
            linted = try linter.to_lyrics(code);
        } else {
            usage();
            return 1;
        }

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

fn usage() void {
    std.debug.print(
        \\Usage: hanuman [FILE]
        \\Options:
        \\  --to-lyrics [FILE]: replace ascii syntax of the specified file to lyrics
        \\  --to-ascii [FILE]: replace lyrics of the specified file to ascii syntax
    ,
        .{},
    );
}

test {
    // This ensures their tests are included.
    std.testing.refAllDecls(@This());
}
