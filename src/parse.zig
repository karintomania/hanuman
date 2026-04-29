const std = @import("std");
const Allocator = std.mem.Allocator;

const plus_affixes = [_]Affix{
    .{ .prefix = "+", .suffix = "" },
    .{ .prefix = "たった", .suffix = "秒でも長く眠りたい" },
};
const minus_affixes = [_]Affix{.{ .prefix = "-", .suffix = "" }};
const move_affixes = [_]Affix{.{ .prefix = "@", .suffix = "" }};
const func_def_affixes = [_]Affix{.{ .prefix = "fn_", .suffix = "" }};
const func_call_affixes = [_]Affix{.{ .prefix = "call_", .suffix = "" }};

const StmtType = enum {
    add,
    minus,
    move,
    print_num,
    func_def,
    func_call,
    loop,
    cond,
};

const Affix = struct {
    prefix: []const u8,
    suffix: []const u8,
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

        while (itr.next()) |line_raw| {
            const line = std.mem.trim(u8, line_raw, " \t\r\n");

            if (has_affix(&plus_affixes, line)) {
                const num_str = strip_line(&plus_affixes, line);
                const n = try std.fmt.parseInt(i32, num_str, 10);
                try stmts.append(allocator, Stmt{ .add = StmtAdd{ .num = n } });
            }

            if (has_affix(&minus_affixes, line)) {
                const num_str = strip_line(&minus_affixes, line);
                const n = try std.fmt.parseInt(i32, num_str, 10);
                try stmts.append(allocator, Stmt{ .minus = StmtMinus{ .num = n } });
            }

            if (has_affix(&move_affixes, line)) {
                const num_str = strip_line(&move_affixes, line);
                const n = try std.fmt.parseInt(u16, num_str, 10);
                try stmts.append(allocator, Stmt{ .move = StmtMove{ .idx = n } });
            }

            if (std.mem.eql(u8, line, "pd")) {
                try stmts.append(allocator, Stmt{ .print_num = StmtPrintNum{} });
            }

            // func definition
            if (has_affix(&func_def_affixes, line)) {
                const name = strip_line(&func_def_affixes, line);
                const body = try self.parse_level(itr, .func);

                try stmts.append(allocator, Stmt{ .func_def = StmtFuncDef{
                    .name = name,
                    .body = body,
                } });
            }

            if (nest == .func and std.mem.eql(u8, line, "end_fn")) {
                // error handling for other kind of end_xx
                return stmts.toOwnedSlice(allocator);
            }

            if (has_affix(&func_call_affixes, line)) {
                const name = strip_line(&func_call_affixes, line);
                try stmts.append(allocator, Stmt{ .func_call = StmtFuncCall{ .name = name } });
            }

            // func definition
            if (std.mem.eql(u8, "[", line)) {
                const body = try self.parse_level(itr, .loop);

                try stmts.append(allocator, Stmt{ .loop = StmtLoop{
                    .body = body,
                } });
            }

            if (nest == .loop and std.mem.eql(u8, line, "]")) {
                return stmts.toOwnedSlice(allocator);
            }

            // func definition
            if (std.mem.eql(u8, "?", line)) {
                const body_then = try self.parse_level(itr, .cond_then);
                const body_else = try self.parse_level(itr, .cond_else);

                try stmts.append(allocator, Stmt{ .cond = StmtCond{
                    .body_then = body_then,
                    .body_else = body_else,
                } });
            }

            if (nest == .cond_then and std.mem.eql(u8, line, ":")) {
                return stmts.toOwnedSlice(allocator);
            }
            if (nest == .cond_else and std.mem.eql(u8, line, ";")) {
                return stmts.toOwnedSlice(allocator);
            }
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
    func,
    loop,
    cond_then,
    cond_else,
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
    name: []const u8,
    body: []Stmt,
};

const StmtLoop = struct {
    body: []Stmt,
};

const StmtCond = struct {
    body_then: []Stmt,
    body_else: []Stmt,
};

const StmtFuncCall = struct {
    name: []const u8,
};

pub const Stmt = union(StmtType) {
    add: StmtAdd,
    minus: StmtMinus,
    move: StmtMove,
    print_num: StmtPrintNum,
    func_def: StmtFuncDef,
    func_call: StmtFuncCall,
    loop: StmtLoop,
    cond: StmtCond,
};

fn has_affix(affixes: []const Affix, line: []const u8) bool {
    for (affixes) |affix| {
        var matched = true;
        if (affix.prefix.len > 0 and !std.mem.startsWith(u8, line, affix.prefix)) {
            matched = false;
        }
        if (affix.suffix.len > 0 and !std.mem.endsWith(u8, line, affix.suffix)) {
            matched = false;
        }

        if (matched) return true;
    }

    return false;
}

// remove prefix and suffix
fn strip_line(affixes: []const Affix, line: []const u8) []const u8 {
    var tmp = line;

    for (affixes) |affix| {
        if (affix.prefix.len > 0 and std.mem.startsWith(u8, tmp, affix.prefix)) {
            tmp = tmp[affix.prefix.len..];
        }
        if (affix.suffix.len > 0 and std.mem.endsWith(u8, tmp, affix.suffix)) {
            tmp = tmp[0 .. tmp.len - affix.suffix.len];
        }
    }

    return tmp;
}

test "strip line" {
    const input = "たった1秒でも長く眠りたい";

    const res = strip_line(&plus_affixes, input);

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
        const res = has_affix(&plus_affixes, in);
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
        \\pd
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(2, result[0].move.idx);
    try std.testing.expectEqual(5, result[1].add.num);
    try std.testing.expectEqual(4, result[2].minus.num);
    try std.testing.expectEqual(StmtType.print_num, std.meta.activeTag(result[3]));
}

test "parse function" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\fn_テスト
        \\+5
        \\end_fn
        \\call_テスト
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(StmtType.func_def, std.meta.activeTag(result[0]));
    const func_def = result[0].func_def;
    try std.testing.expectEqualStrings("テスト", func_def.name);

    const body = func_def.body;
    try std.testing.expectEqual(1, body.len);
    try std.testing.expectEqual(5, body[0].add.num);

    try std.testing.expectEqual(StmtType.func_call, std.meta.activeTag(result[1]));
    try std.testing.expectEqualStrings(result[1].func_call.name, "テスト");
}

test "parse loop" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\[
        \\+3
        \\-1
        \\]
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(1, result.len);
    try std.testing.expectEqual(StmtType.loop, std.meta.activeTag(result[0]));
    const body = result[0].loop.body;
    try std.testing.expectEqual(2, body.len);
    try std.testing.expectEqual(3, body[0].add.num);
    try std.testing.expectEqual(1, body[1].minus.num);
}

test "parse loop inside function" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\fn_テスト
        \\[
        \\+3
        \\]
        \\end_fn
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(1, result.len);
    try std.testing.expectEqual(StmtType.func_def, std.meta.activeTag(result[0]));

    const func_body = result[0].func_def.body;
    try std.testing.expectEqual(1, func_body.len);
    try std.testing.expectEqual(StmtType.loop, std.meta.activeTag(func_body[0]));

    const loop_body = func_body[0].loop.body;
    try std.testing.expectEqual(1, loop_body.len);
    try std.testing.expectEqual(3, loop_body[0].add.num);
}

test "parse condition" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\?
        \\+5
        \\:
        \\-2
        \\;
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(1, result.len);
    try std.testing.expectEqual(StmtType.cond, std.meta.activeTag(result[0]));
    const cond = result[0].cond;
    try std.testing.expectEqual(1, cond.body_then.len);
    try std.testing.expectEqual(5, cond.body_then[0].add.num);
    try std.testing.expectEqual(1, cond.body_else.len);
    try std.testing.expectEqual(2, cond.body_else[0].minus.num);
}
