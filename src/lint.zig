const std = @import("std");
const Allocator = std.mem.Allocator;
const parse = @import("parse.zig");

const ascii_keywords = [_][]const u8{
    parse.keyword_ascii_print_digit,
    parse.keyword_ascii_print_unicode,
    parse.keyword_ascii_loop_start,
    parse.keyword_ascii_loop_end,
    parse.keyword_ascii_func_end,
    parse.keyword_ascii_reset_cell,
    parse.keyword_ascii_cond_start,
    parse.keyword_ascii_cond_else,
    parse.keyword_ascii_cond_end,
    parse.keyword_ascii_rand,
    parse.keyword_ascii_cr,
};
const keywords = [_][]const u8{
    parse.keyword_print_digit,
    parse.keyword_print_unicode,
    parse.keyword_loop_start,
    parse.keyword_loop_end,
    parse.keyword_func_end,
    parse.keyword_reset_cell,
    parse.keyword_cond_start,
    parse.keyword_cond_else,
    parse.keyword_cond_end,
    parse.keyword_rand,
    parse.keyword_cr,
};

const affixes_list = [_][]const parse.Affix{
    &parse.affixes_plus,
    &parse.affixes_minus,
    &parse.affixes_multi,
    &parse.affixes_div,
    &parse.affixes_mod,
    &parse.affixes_move,
    &parse.affixes_func_def,
    &parse.affixes_func_call,
    &parse.affixes_echo,
};

pub const Linter = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) Linter {
        return Linter{
            .arena = .init(allocator),
        };
    }

    pub fn to_lyrics(self: *Linter, code: []const u8) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        const allocator = self.arena.allocator();

        var itr = std.mem.splitSequence(u8, code, "\n");

        while (itr.next()) |line| {
            const linted_line = try self.to_lyrics_line(line);
            try result.appendSlice(allocator, linted_line);
            try result.appendSlice(allocator, "\n");
        }

        return try result.toOwnedSlice(allocator);
    }

    fn to_lyrics_line(self: *Linter, line: []const u8) ![]const u8 {
        const first_non_whitespace_idx = std.mem.indexOfNone(u8, line, " \t") orelse line.len;

        const line_trimed = std.mem.trim(u8, line, " \t\r\n");
        const allocator = self.arena.allocator();

        for (ascii_keywords, 0..) |ascii_keyword, i| {
            if (std.mem.eql(u8, ascii_keyword, line_trimed)) {
                return std.mem.concat(allocator, u8, &[_][]const u8{
                    line[0..first_non_whitespace_idx],
                    keywords[i],
                });
            }
        }

        for (affixes_list) |affixes| {
            if (parse.has_affix(affixes, line_trimed)) {
                const num_str = parse.strip_line(affixes, line_trimed);

                return std.mem.concat(allocator, u8, &[_][]const u8{
                    line[0..first_non_whitespace_idx],
                    affixes[1].prefix,
                    num_str,
                    affixes[1].suffix,
                });
            }
        }

        return line;
    }

    pub fn to_ascii(self: *Linter, code: []const u8) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        const allocator = self.arena.allocator();

        var itr = std.mem.splitSequence(u8, code, "\n");

        while (itr.next()) |line| {
            const linted_line = try self.to_ascii_line(line);
            try result.appendSlice(allocator, linted_line);
            try result.appendSlice(allocator, "\n");
        }

        return try result.toOwnedSlice(allocator);
    }

    fn to_ascii_line(self: *Linter, line: []const u8) ![]const u8 {
        const first_non_whitespace_idx = std.mem.indexOfNone(u8, line, " \t") orelse line.len;

        const line_trimed = std.mem.trim(u8, line, " \t\r\n");
        const allocator = self.arena.allocator();

        for (keywords, 0..) |keyword, i| {
            if (std.mem.eql(u8, keyword, line_trimed)) {
                return std.mem.concat(allocator, u8, &[_][]const u8{
                    line[0..first_non_whitespace_idx],
                    ascii_keywords[i],
                });
            }
        }

        for (affixes_list) |affixes| {
            if (parse.has_affix(affixes, line_trimed)) {
                const num_str = parse.strip_line(affixes, line_trimed);

                return std.mem.concat(allocator, u8, &[_][]const u8{
                    line[0..first_non_whitespace_idx],
                    affixes[0].prefix,
                    num_str,
                    affixes[0].suffix,
                });
            }
        }

        return line;
    }

    pub fn deinit(self: *Linter) void {
        self.arena.deinit();
    }
};

test "to_lyrics works" {
    const input =
        \\# test
        \\@0
        \\+1
        \\  @0
        \\  +1
        \\ _
    ;

    const expected =
        \\# test
        \\演奏ハヌマーンでアナーキー・イン・ザ・0K
        \\たった1秒でも長く眠りたい
        \\  演奏ハヌマーンでアナーキー・イン・ザ・0K
        \\  たった1秒でも長く眠りたい
        \\ およそ空っぽの頭の中やけに響く英語のアナウンス
        \\
    ;

    var linter = Linter.init(std.testing.allocator);
    defer linter.deinit();

    const res = try linter.to_lyrics(input);

    try std.testing.expectEqualStrings(expected, res);
}
test "to_ascii works" {
    const input =
        \\# test
        \\演奏ハヌマーンでアナーキー・イン・ザ・0K
        \\たった1秒でも長く眠りたい
        \\  演奏ハヌマーンでアナーキー・イン・ザ・0K
        \\  たった1秒でも長く眠りたい
        \\ およそ空っぽの頭の中やけに響く英語のアナウンス
    ;

    const expected =
        \\# test
        \\@0
        \\+1
        \\  @0
        \\  +1
        \\ _
        \\
    ;

    var linter = Linter.init(std.testing.allocator);
    defer linter.deinit();

    const res = try linter.to_ascii(input);

    try std.testing.expectEqualStrings(expected, res);
}
