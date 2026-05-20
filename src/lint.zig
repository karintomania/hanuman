const std = @import("std");
const Allocator = std.mem.Allocator;
const parse = @import("parse.zig");

pub const Linter = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) Linter {
        return Linter{
            .arena = .init(allocator),
        };
    }

    pub fn lint(self: *Linter, code: []const u8) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        const allocator = self.arena.allocator();

        var itr = std.mem.splitSequence(u8, code, "\n");

        while (itr.next()) |line| {
            const linted_line = try self.lint_line(line);
            try result.appendSlice(allocator, linted_line);
            try result.appendSlice(allocator, "\n");
        }

        return try result.toOwnedSlice(allocator);
    }

    fn lint_line(self: *Linter, line: []const u8) ![]const u8 {
        const first_non_whitespace_idx = std.mem.indexOfNone(u8, line, " \t") orelse line.len;

        const line_trimed = std.mem.trim(u8, line, " \t\r\n");
        const allocator = self.arena.allocator();

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

        for (ascii_keywords, 0..) |ascii_keyword, i| {
            if (std.mem.eql(u8, ascii_keyword, line_trimed)) {
                return std.mem.concat(allocator, u8, &[_][]const u8{
                    line[0..first_non_whitespace_idx],
                    keywords[i],
                });
            }
        }

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

    pub fn deinit(self: *Linter) void {
        self.arena.deinit();
    }
};

test "lint works" {
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

    const res = try linter.lint(input);

    try std.testing.expectEqualStrings(expected, res);
}
