const std = @import("std");
const utils = @import("utils.zig");

const OpposingMove = enum(u8) {
    A = 1,
    B = 2,
    C = 3,

    pub fn winningElement(self: OpposingMove) OpposingMove {
        return switch (self) {
            OpposingMove.A => OpposingMove.B,
            OpposingMove.B => OpposingMove.C,
            OpposingMove.C => OpposingMove.A,
        };
    }

    pub fn losingElement(self: OpposingMove) OpposingMove {
        return switch (self) {
            OpposingMove.A => OpposingMove.C,
            OpposingMove.B => OpposingMove.A,
            OpposingMove.C => OpposingMove.B,
        };
    }
};

const MyMove = enum(u8) { X = 1, Y = 2, Z = 3 };

const winning_score: u8 = 6;
const drawing_score: u8 = 3;
const losing_score: u8 = 0;

fn calculateScoreOne(opponent: OpposingMove, me: MyMove) usize {
    const their_ord = @enumToInt(opponent);
    const my_ord = @enumToInt(me);
    const from_draw: u8 = if (their_ord == my_ord) drawing_score else 0;
    const from_win: u8 = switch (me) {
        MyMove.X => if (opponent == OpposingMove.C) winning_score else 0,
        MyMove.Y => if (opponent == OpposingMove.A) winning_score else 0,
        MyMove.Z => if (opponent == OpposingMove.B) winning_score else 0,
    };
    return from_draw + from_win + my_ord;
}

fn calculateScoreTwo(opponent: OpposingMove, me: MyMove) usize {
    return switch (me) {
        MyMove.X => losing_score + @enumToInt(opponent.losingElement()),
        MyMove.Y => drawing_score + @enumToInt(opponent),
        MyMove.Z => winning_score + @enumToInt(opponent.winningElement()),
    };
}

pub fn run(allocator: *const std.mem.Allocator) !void {
    utils.printHeader("Day 2");
    const contents = try utils.readInputFileToBuffer("day2.in", allocator);
    defer allocator.free(contents);

    var score_one: usize = 0;
    var score_two: usize = 0;
    var entries = std.mem.tokenize(u8, contents, "\n ");

    while (entries.next()) |opponent| {
        const op_move = std.meta.stringToEnum(OpposingMove, opponent).?;
        const me = entries.next().?;
        const my_move = std.meta.stringToEnum(MyMove, me).?;
        score_one += calculateScoreOne(op_move, my_move);
        score_two += calculateScoreTwo(op_move, my_move);
    }

    std.debug.print("Part 1: My score would be {d}\n", .{score_one});
    std.debug.print("Part 2: My score would be {d}\n", .{score_two});
}
