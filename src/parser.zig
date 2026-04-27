const std = @import("std");
const Allocator = std.mem.Allocator;

const StmtType = enum {
    add,
    minus,
    move,
    print_num,
};

const StmtAdd = struct {
    num: i32,
};

const StmtMinus = struct {
    num: i32,
};
const StmtMove = struct {
    idx: u16,
};

const StmtPrintNum = struct {};

pub const Stmt = union(StmtType) {
    add: StmtAdd,
    minus: StmtMinus,
    move: StmtMove,
    print_num: StmtPrintNum,
};

pub fn parse(allocator: Allocator, code: []const u8) ![]Stmt {
    var itr = std.mem.splitSequence(u8, code, "\n");
    var stmts: std.ArrayList(Stmt) = .empty;

    while (itr.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        const stmtOrNull = try term0(trimmed);

        if (stmtOrNull) |stmt| {
            try stmts.append(allocator, stmt);
        }
    }

    return try stmts.toOwnedSlice(allocator);
}

fn term0(line: []const u8) !?Stmt {
    if (has_prefix_and_suffix("+", "", line)) {
        const num_str = strip_line("+", "", line);
        const n = try std.fmt.parseInt(i32, num_str, 10);
        return Stmt{ .add = StmtAdd{ .num = n } };
    }

    if (has_prefix_and_suffix("-", "", line)) {
        const num_str = strip_line("-", "", line);
        const n = try std.fmt.parseInt(i32, num_str, 10);
        return Stmt{ .minus = StmtMinus{ .num = n } };
    }

    if (has_prefix_and_suffix("@", "", line)) {
        const num_str = strip_line("@", "", line);
        const n = try std.fmt.parseInt(u16, num_str, 10);
        return Stmt{ .move = StmtMove{ .idx = n } };
    }

    if (std.mem.eql(u8, line, "p_num")) {
        return Stmt{ .print_num = StmtPrintNum{} };
    }

    return null;
}

fn has_prefix_and_suffix(prefix: []const u8, suffix: []const u8, line: []const u8) bool {
    if (prefix.len > 0 and !std.mem.startsWith(u8, line, prefix)) {
        return false;
    }
    if (suffix.len > 0 and !std.mem.endsWith(u8, line, suffix)) {
        return false;
    }

    return true;
}

// remove prefix and suffix
fn strip_line(prefix: []const u8, suffix: []const u8, line: []const u8) []const u8 {
    var tmp = line;
    if (prefix.len > 0) {
        tmp = tmp[prefix.len..];
    }
    if (suffix.len > 0) {
        tmp = tmp[0 .. tmp.len - suffix.len];
    }

    return tmp;
}

test "strip line" {
    const input = "たった1秒でも長く眠りたい";

    const res = strip_line("たった", "秒でも長く眠りたい", input);

    try std.testing.expectEqualStrings("1", res);
}

test "has prefix and suffix" {
    const inputs = [_][]const u8{
        "たった1秒でも長く眠りたい",
        "たった1秒だけ",
        "1秒だけ",
    };

    const expected = [_]bool{ true, false, false };

    for (inputs, 0..) |in, i| {
        const res = has_prefix_and_suffix("たった", "秒でも長く眠りたい", in);
        try std.testing.expectEqual(expected[i], res);
    }
}

test "parse" {
    const code =
        \\@2
        \\+5
        \\-4
        \\p_num
    ;
    const result = try parse(std.testing.allocator, code);

    try std.testing.expectEqual(2, result[0].move.idx);
    try std.testing.expectEqual(5, result[1].add.num);
    try std.testing.expectEqual(4, result[2].minus.num);
    try std.testing.expectEqual(StmtType.print_num, std.meta.activeTag(result[3]));

    std.testing.allocator.free(result);
}
