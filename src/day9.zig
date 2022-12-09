const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = utils.Answer;

const print = std.debug.print;

const Direction = enum(u8) {
    U,
    UR,
    R,
    DR,
    D,
    DL,
    L,
    UL,
};

const Position = struct {
    x: isize = 0,
    y: isize = 0,

    fn steps_away(self: Position, other: Position) usize {
        const steps_x = std.math.absInt(self.x - other.x) catch unreachable;
        const steps_y = std.math.absInt(self.y - other.y) catch unreachable;
        return @intCast(usize, std.math.max(steps_x, steps_y));
    }

    fn step(self: *Position, direction: Direction) void {
        switch (direction) {
            .U => self.y += 1,
            .UR => {
                self.x += 1;
                self.y += 1;
            },
            .R => self.x += 1,
            .DR => {
                self.x += 1;
                self.y -= 1;
            },
            .D => self.y -= 1,
            .DL => {
                self.x -= 1;
                self.y -= 1;
            },
            .L => self.x -= 1,
            .UL => {
                self.x -= 1;
                self.y += 1;
            },
        }
    }

    fn snap_step_direction(self: Position, other: *Position) Direction {
        if (self.x > other.x) {
            if (self.y > other.y) return .UR else if (self.y < other.y) return .DR else return .R;
        } else if (self.x < other.x) {
            if (self.y > other.y) return .UL else if (self.y < other.y) return .DL else return .L;
        } else if (self.y > other.y) return .U else return .D;
    }
};

const PositionSet = std.AutoHashMap(Position, void);

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var knot_positions: [10]Position = .{Position{}} ** 10;

    var tail_positions = PositionSet.init(allocator.*);
    var second_positions = PositionSet.init(allocator.*);
    defer tail_positions.deinit();
    defer second_positions.deinit();

    try tail_positions.put(knot_positions[9], {});
    try second_positions.put(knot_positions[1], {});

    // Loop 1: calculate
    var step: usize = 0;
    var instructions = std.mem.tokenize(u8, content, " \n");
    while (instructions.next()) |dir_letter| {
        const dir = std.meta.stringToEnum(Direction, dir_letter).?;
        const amount_str = instructions.next().?;
        const amount = try std.fmt.parseInt(usize, amount_str, 10);
        var steps: usize = 0;
        while (steps < amount) : (steps += 1) {
            for (knot_positions) |*knot, index| {
                if (index == 0) {
                    knot.step(dir);
                    continue;
                }
                if (knot.steps_away(knot_positions[index - 1]) >= 2) {
                    knot.step(knot_positions[index - 1].snap_step_direction(knot));
                }
            }
            try tail_positions.put(knot_positions[9], {});
            try second_positions.put(knot_positions[1], {});
        }
        step += 1;
    }

    return Answer{ .part_1 = second_positions.count(), .part_2 = tail_positions.count() };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 9");
    var answer = solve("day9.in", allocator) catch unreachable;
    answer.print();
}

test "day 9 worked examples" {
    var answer = try solve("day9.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 13) catch |err| {
        print("{d} is not 13\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 1) catch |err| {
        print("{d} is not 1\n", .{answer.part_2});
        return err;
    };
    answer = try solve("day9_part2.test", &std.testing.allocator);
    std.testing.expect(answer.part_2 == 36) catch |err| {
        print("{d} is not 36\n", .{answer.part_2});
        return err;
    };
}
