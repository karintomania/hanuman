const std = @import("std");
const Allocator = std.mem.Allocator;

const StmtType = enum {
    add,
    minus,
    move,
    print_num,
    func_def,
    func_call,
};

pub const Parser = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) Parser {
        return Parser{ .arena = .init(allocator) };
    }

    pub fn parse(self: *Parser, code: []const u8) ![]Stmt {
        var itr = std.mem.splitSequence(u8, code, "\n");
        const stmt = try self.parse_level(&itr, .not_nested);
        return stmt;
    }

    fn parse_level(self: *Parser, itr: *std.mem.SplitIterator(u8, .sequence), nest: NestableStmtType) ![]Stmt {
        var stmts: std.ArrayList(Stmt) = .empty;
        const allocator = self.arena.allocator();

        _ = nest;

        while (itr.next()) |line_raw| {
            const line = std.mem.trim(u8, line_raw, " \t\r\n");

            if (has_prefix_and_suffix("+", "", line)) {
                const num_str = strip_line("+", "", line);
                const n = try std.fmt.parseInt(i32, num_str, 10);
                try stmts.append(allocator, Stmt{ .add = StmtAdd{ .num = n } });
            }

            if (has_prefix_and_suffix("-", "", line)) {
                const num_str = strip_line("-", "", line);
                const n = try std.fmt.parseInt(i32, num_str, 10);
                try stmts.append(allocator, Stmt{ .minus = StmtMinus{ .num = n } });
            }

            if (has_prefix_and_suffix("@", "", line)) {
                const num_str = strip_line("@", "", line);
                const n = try std.fmt.parseInt(u16, num_str, 10);
                try stmts.append(allocator, Stmt{ .move = StmtMove{ .idx = n } });
            }

            if (std.mem.eql(u8, line, "p_num")) {
                try stmts.append(allocator, Stmt{ .print_num = StmtPrintNum{} });
            }

            // if (nest == .func_def and std.mem.eql(u8, line, "endfn")) {
            //     const num_str = strip_line("@", "", line);
            //     const n = try std.fmt.parseInt(u16, num_str, 10);
            //     return Stmt{ .move = StmtMove{ .idx = n } };
            // }
        }

        return stmts.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }
};

// use this to flag if current position is inside nested structure
const NestableStmtType = enum {
    not_nested,
    func_def,
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

const StmtFuncDef = struct {
    body: []Stmt,
};

const StmtFuncCall = struct {
    body: []Stmt,
};

pub const Stmt = union(StmtType) {
    add: StmtAdd,
    minus: StmtMinus,
    move: StmtMove,
    print_num: StmtPrintNum,
    func_def: StmtFuncDef,
    func_call: StmtFuncCall,
};

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
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\@2
        \\+5
        \\-4
        \\p_num
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(2, result[0].move.idx);
    try std.testing.expectEqual(5, result[1].add.num);
    try std.testing.expectEqual(4, result[2].minus.num);
    try std.testing.expectEqual(StmtType.print_num, std.meta.activeTag(result[3]));
}
