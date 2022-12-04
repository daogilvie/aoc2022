const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Answer = utils.Answer;

const Assignment = struct {
    lower: usize,
    upper: usize,

    pub fn fullyContains(self: Assignment, other: Assignment) bool {
        return self.lower <= other.lower and self.upper >= other.upper;
    }

    pub fn init(input: str) Assignment {
        var parts = std.mem.tokenize(u8, input, "-");
        const lower: usize = std.fmt.parseInt(usize, parts.next().?, 10) catch unreachable;
        const upper: usize = std.fmt.parseInt(usize, parts.next().?, 10) catch unreachable;
        return Assignment{ .lower = lower, .upper = upper };
    }
};

fn solve(filename: []const u8, allocator: *const std.mem.Allocator) !Answer {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var assignments = std.mem.tokenize(u8, contents, ",\n");
    var containments: usize = 0;

    while (assignments.next()) |left_assignment| {
        const right_assignment = assignments.next().?;
        const left = Assignment.init(left_assignment);
        const right = Assignment.init(right_assignment);
        if (left.fullyContains(right) or right.fullyContains(left)) {
            containments += 1;
        }
    }

    return Answer{ .part_1 = containments, .part_2 = 0 };
}

pub fn run(allocator: *const std.mem.Allocator) void {
    utils.printHeader("Day 4");
    const solution = solve("day4.in", allocator) catch unreachable;
    std.debug.print("Part 1: {d}\n", .{solution.part_1});
    std.debug.print("Part 2: {d}\n", .{solution.part_2});
}

test "day 4 assignment parse" {
    const input = "18-793";
    const output = Assignment.init(input);
    try std.testing.expectEqual(output.lower, 18);
    try std.testing.expectEqual(output.upper, 793);
}

test "day 4 assignment contains" {
    const inner = Assignment{ .lower = 1, .upper = 10 };
    const outer = Assignment{ .lower = 1, .upper = 15 };
    try std.testing.expect(inner.fullyContains(inner));
    try std.testing.expect(!inner.fullyContains(outer));
    try std.testing.expect(outer.fullyContains(inner));
}

test "day 4 worked example" {
    const solution = try solve("day4.test", &std.testing.allocator);
    std.testing.expect(solution.part_1 == 2) catch |err| {
        std.debug.print("{d} is not 2\n", .{solution.part_1});
        return err;
    };
    // try std.testing.expect(solution.part_2 == 70);
}
