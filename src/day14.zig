const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;
const print = std.debug.print;

pub fn solve(filename: str, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var part_1: usize = 0;
    var part_2: usize = 0;

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 14");
    var answer = solve("day14.in", allocator) catch unreachable;
    answer.print();
}

test "day 14 worked examples" {
    var answer = try solve("day14.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 24) catch |err| {
        print("{d} is not 24\n", .{answer.part_1});
        return err;
    };
}
