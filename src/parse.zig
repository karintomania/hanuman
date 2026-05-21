const std = @import("std");
const Allocator = std.mem.Allocator;

pub const affixes_plus = [_]Affix{
    .{ .prefix = "+", .suffix = "" },
    .{ .prefix = "たった", .suffix = "秒でも長く眠りたい" },
};
pub const affixes_minus = [_]Affix{
    .{ .prefix = "-", .suffix = "" },
    .{ .prefix = "見張り番の俺の落ち度を糾弾", .suffix = "円奪って先輩消える" },
};
pub const affixes_multi = [_]Affix{
    .{ .prefix = "*", .suffix = "" },
    .{ .prefix = "ヘッドホンをして", .suffix = "秒ごとに変わる表情" },
};
pub const affixes_div = [_]Affix{
    .{ .prefix = "/", .suffix = "" },
    .{ .prefix = "零コンマ", .suffix = "秒で片付く命" },
};
pub const affixes_mod = [_]Affix{
    .{ .prefix = "%", .suffix = "" },
    .{ .prefix = "何しろ僕らは", .suffix = "歳だった" },
};
pub const affixes_move = [_]Affix{
    .{ .prefix = "@", .suffix = "" },
    .{ .prefix = "演奏ハヌマーンでアナーキー・イン・ザ・", .suffix = "K" },
};
pub const affixes_func_def = [_]Affix{
    .{ .prefix = "fn_", .suffix = "" },
    .{ .prefix = "そういちいち怒鳴るなって誰だって", .suffix = "したい" },
};
pub const affixes_func_call = [_]Affix{
    .{ .prefix = "call_", .suffix = "" },
    .{ .prefix = "もういちいち言わんだけで俺だって", .suffix = "したい" },
};
pub const affixes_echo = [_]Affix{
    .{ .prefix = "echo \"", .suffix = "\"" },
    .{ .prefix = "捨て看板の女がぼやく「", .suffix = "」" },
};

pub const keyword_print_digit = "換気口の下でギニアピッグが云う";
pub const keyword_ascii_print_digit = "pd";
pub const keyword_print_unicode = "こめかみを指して痩せた鴉が云う";
pub const keyword_ascii_print_unicode = "pu";
pub const keyword_loop_start = "気に喰わんね輪廻の概念";
pub const keyword_ascii_loop_start = "[";
pub const keyword_loop_end = "全くを以って気に入らないね";
pub const keyword_ascii_loop_end = "]";

pub const keyword_func_end = "言う？武闘派に遭遇して同じように言う？";
pub const keyword_ascii_func_end = "end_fn";

pub const keyword_reset_cell = "およそ空っぽの頭の中やけに響く英語のアナウンス";
pub const keyword_ascii_reset_cell = "_";
pub const keyword_cond_start = "どうして?の問いに";
pub const keyword_ascii_cond_start = "?";
pub const keyword_cond_else = "愛してるって";
pub const keyword_ascii_cond_else = ":";
pub const keyword_cond_end = "答えになってないぜ兄さん";
pub const keyword_ascii_cond_end = ";";
pub const keyword_rand = "名前を聞かれ思わずデタラメな名前を名乗ってしまった";
pub const keyword_ascii_rand = "rand";
pub const keyword_cr = "CR人間模様気付けばそれの虜になってる";
pub const keyword_ascii_cr = "cr";

const StmtType = enum {
    add,
    minus,
    multi,
    div,
    mod,
    reset,
    rand,
    move,
    func_def,
    func_call,
    loop,
    cond,
    print_digit,
    print_unicode,
    echo,
    cr,
};

const UnmatchingStatement = error{
    UnmatchingFunctionDefinition,
    UnmatchingLoop,
    UnmatchingCondition,
};

pub const Affix = struct {
    prefix: []const u8,
    suffix: []const u8,
};

pub const Parser = struct {
    arena: std.heap.ArenaAllocator,
    line_num: usize,
    line_processing: []const u8,

    pub fn init(allocator: Allocator) Parser {
        return Parser{
            .arena = .init(allocator),
            .line_num = 0,
            .line_processing = "",
        };
    }

    pub fn parse(self: *Parser, code: []const u8) ![]Stmt {
        var itr = std.mem.splitSequence(u8, code, "\n");
        const stmt = try self.parse_level(&itr, .not_nested);
        return stmt;
    }

    // parse statement. Use recursion for loop/condition/function
    fn parse_level(self: *Parser, itr: *std.mem.SplitIterator(u8, .sequence), nest: NestableStmtType) ![]Stmt {
        var stmts: std.ArrayList(Stmt) = .empty;
        const allocator = self.arena.allocator();

        while (itr.next()) |line_raw| {
            self.line_num += 1;
            self.line_processing = line_raw;

            const line = std.mem.trim(u8, line_raw, " \t\r\n");

            // skip empty lines
            if (std.mem.eql(u8, line, "")) continue;

            // skip comment
            if (std.mem.eql(u8, line[0..1], "#")) continue;

            if (has_affix(&affixes_plus, line)) {
                const num_str = strip_line(&affixes_plus, line);
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .add = StmtAdd{ .num = n } });
                continue;
            }

            if (has_affix(&affixes_minus, line)) {
                const num_str = strip_line(&affixes_minus, line);
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .minus = StmtMinus{ .num = n } });
                continue;
            }

            if (has_affix(&affixes_multi, line)) {
                const num_str = strip_line(&affixes_multi, line);
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .multi = StmtMulti{ .num = n } });
                continue;
            }

            if (has_affix(&affixes_div, line)) {
                const num_str = strip_line(&affixes_div, line);
                // TODO: zero check
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .div = StmtDiv{ .num = n } });
                continue;
            }

            if (has_affix(&affixes_mod, line)) {
                const num_str = strip_line(&affixes_mod, line);
                // TODO: zero check
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .mod = StmtMod{ .num = n } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_reset_cell) or std.mem.eql(u8, line, keyword_reset_cell)) {
                try stmts.append(allocator, Stmt{ .reset = StmtReset{} });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_rand) or std.mem.eql(u8, line, keyword_rand)) {
                try stmts.append(allocator, Stmt{ .rand = StmtRand{} });
                continue;
            }

            if (has_affix(&affixes_move, line)) {
                const num_str = strip_line(&affixes_move, line);
                const n = try parse_number_expression(num_str);
                try stmts.append(allocator, Stmt{ .move = StmtMove{ .num = n } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_print_digit) or std.mem.eql(u8, line, keyword_print_digit)) {
                try stmts.append(allocator, Stmt{ .print_digit = StmtPrintDigit{} });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_print_unicode) or std.mem.eql(u8, line, keyword_print_unicode)) {
                try stmts.append(allocator, Stmt{ .print_unicode = StmtPrintUnicode{} });
                continue;
            }

            if (has_affix(&affixes_echo, line)) {
                const text = strip_line(&affixes_echo, line);
                try stmts.append(allocator, Stmt{ .echo = StmtEcho{ .str = text } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_cr) or std.mem.eql(u8, line, keyword_cr)) {
                try stmts.append(allocator, Stmt{ .cr = StmtCR{} });
                continue;
            }

            // func definition
            if (has_affix(&affixes_func_def, line)) {
                const name = strip_line(&affixes_func_def, line);
                const body = try self.parse_level(itr, .func);

                try stmts.append(allocator, Stmt{ .func_def = StmtFuncDef{
                    .name = name,
                    .body = body,
                } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_func_end) or std.mem.eql(u8, line, keyword_func_end)) {
                if (nest != .func) return UnmatchingStatement.UnmatchingFunctionDefinition;

                // error handling for other kind of end_xx
                return stmts.toOwnedSlice(allocator);
            }

            if (has_affix(&affixes_func_call, line)) {
                const name = strip_line(&affixes_func_call, line);
                try stmts.append(allocator, Stmt{ .func_call = StmtFuncCall{ .name = name } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_loop_start) or std.mem.eql(u8, line, keyword_loop_start)) {
                const body = try self.parse_level(itr, .loop);

                try stmts.append(allocator, Stmt{ .loop = StmtLoop{
                    .body = body,
                } });
                continue;
            }

            if (std.mem.eql(u8, line, keyword_ascii_loop_end) or std.mem.eql(u8, line, keyword_loop_end)) {
                if (nest != .loop) return UnmatchingStatement.UnmatchingLoop;

                return stmts.toOwnedSlice(allocator);
            }

            if (std.mem.eql(u8, line, keyword_ascii_cond_start) or std.mem.eql(u8, line, keyword_cond_start)) {
                const body_then = try self.parse_level(itr, .cond_then);
                const body_else = try self.parse_level(itr, .cond_else);

                try stmts.append(allocator, Stmt{ .cond = StmtCond{
                    .body_then = body_then,
                    .body_else = body_else,
                } });
                continue;
            }

            if ((std.mem.eql(u8, line, keyword_ascii_cond_else) or std.mem.eql(u8, line, keyword_cond_else))) {
                if (nest != .cond_then) return UnmatchingStatement.UnmatchingCondition;
                return stmts.toOwnedSlice(allocator);
            }
            if ((std.mem.eql(u8, line, keyword_ascii_cond_end) or std.mem.eql(u8, line, keyword_cond_end))) {
                if (nest != .cond_else) return UnmatchingStatement.UnmatchingCondition;
                return stmts.toOwnedSlice(allocator);
            }

            return error.ParseError;
        }

        return stmts.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }
};

fn parse_number_expression(str: []const u8) !Num {
    if (std.mem.startsWith(u8, str, "&")) {
        const idx = std.fmt.parseInt(u16, str[1..], 10) catch return error.ParseError;
        return Num{ .idx = idx };
    }

    const num = std.fmt.parseInt(i32, str, 10) catch return error.ParseError;
    return Num{ .n = num };
}

// use this to flag if current position is inside nested structure
const NestableStmtType = enum {
    not_nested,
    func,
    loop,
    cond_then,
    cond_else,
};

const NumType = enum {
    n,
    idx,
};

const Num = union(NumType) {
    n: i32,
    idx: u16,
};

const StmtAdd = struct {
    num: Num,
};

const StmtMinus = struct {
    num: Num,
};

const StmtMulti = struct {
    num: Num,
};

const StmtDiv = struct {
    num: Num,
};

const StmtMod = struct {
    num: Num,
};

const StmtReset = struct {};

const StmtRand = struct {};

const StmtMove = struct {
    num: Num,
};

const StmtPrintDigit = struct {};

const StmtPrintUnicode = struct {};

const StmtEcho = struct {
    str: []const u8,
};

const StmtCR = struct {};

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
    multi: StmtMulti,
    div: StmtDiv,
    mod: StmtMod,
    reset: StmtReset,
    rand: StmtRand,
    move: StmtMove,
    func_def: StmtFuncDef,
    func_call: StmtFuncCall,
    loop: StmtLoop,
    cond: StmtCond,
    print_digit: StmtPrintDigit,
    print_unicode: StmtPrintUnicode,
    echo: StmtEcho,
    cr: StmtCR,
};

pub fn has_affix(affixes: []const Affix, line: []const u8) bool {
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
pub fn strip_line(affixes: []const Affix, line: []const u8) []const u8 {
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

    const res = strip_line(&affixes_plus, input);

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
        const res = has_affix(&affixes_plus, in);
        try std.testing.expectEqual(expected[i], res);
    }
}

test "parse cell operations" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\@2
        \\+5
        \\-4
        \\*3
        \\/2
        \\%6
        \\_
        \\rand
        \\+&5
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(2, result[0].move.num.n);
    try std.testing.expectEqual(5, result[1].add.num.n);
    try std.testing.expectEqual(4, result[2].minus.num.n);
    try std.testing.expectEqual(3, result[3].multi.num.n);
    try std.testing.expectEqual(2, result[4].div.num.n);
    try std.testing.expectEqual(6, result[5].mod.num.n);
    try std.testing.expectEqual(StmtType.reset, std.meta.activeTag(result[6]));
    try std.testing.expectEqual(StmtType.rand, std.meta.activeTag(result[7]));
    try std.testing.expectEqual(5, result[8].add.num.idx);
}

test "parse print operations" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const code =
        \\pd
        \\pu
        \\echo "test"
    ;
    const result = try parser.parse(code);

    try std.testing.expectEqual(StmtType.print_digit, std.meta.activeTag(result[0]));
    try std.testing.expectEqual(StmtType.print_unicode, std.meta.activeTag(result[1]));
    try std.testing.expectEqual(StmtType.echo, std.meta.activeTag(result[2]));
    try std.testing.expectEqualStrings("test", result[2].echo.str);
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
    try std.testing.expectEqual(5, body[0].add.num.n);

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
    try std.testing.expectEqual(3, body[0].add.num.n);
    try std.testing.expectEqual(1, body[1].minus.num.n);
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
    try std.testing.expectEqual(3, loop_body[0].add.num.n);
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
    try std.testing.expectEqual(5, cond.body_then[0].add.num.n);
    try std.testing.expectEqual(1, cond.body_else.len);
    try std.testing.expectEqual(2, cond.body_else[0].minus.num.n);
}

test "unmatching errors" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    _ = parser.parse("end_fn") catch |err| {
        try std.testing.expectEqual(UnmatchingStatement.UnmatchingFunctionDefinition, err);
    };

    _ = parser.parse("]") catch |err| {
        try std.testing.expectEqual(UnmatchingStatement.UnmatchingLoop, err);
    };

    _ = parser.parse("?") catch |err| {
        try std.testing.expectEqual(UnmatchingStatement.UnmatchingCondition, err);
    };

    _ = parser.parse(";") catch |err| {
        try std.testing.expectEqual(UnmatchingStatement.UnmatchingCondition, err);
    };
}
