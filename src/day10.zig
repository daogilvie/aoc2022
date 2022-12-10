const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = utils.NumericAnswer(isize);

const print = std.debug.print;

const Operation = enum { noop, addx };

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var instructions = std.mem.tokenize(u8, content, " \n");
    var cycle_count: isize = 0;
    var next_increment: ?isize = 0;
    var x_register: isize = 1;
    var signal_sum: isize = 0;
    var instruction: ?[]const u8 = undefined;
    while (true) : (cycle_count += 1) {
        if (@mod(cycle_count, 40) == 20) {
            signal_sum += cycle_count * x_register;
        }
        if (next_increment) |value| {
            x_register += value;
            next_increment = null;
        } else {
            instruction = instructions.next();
            if (instruction) |instruction_str| {
                const operation = std.meta.stringToEnum(Operation, instruction_str).?;
                switch (operation) {
                    .noop => {},
                    .addx => {
                        next_increment = try std.fmt.parseInt(isize, instructions.next().?, 10);
                    },
                }
            } else break;
        }
    }

    return Answer{ .part_1 = signal_sum, .part_2 = 0 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 10");
    var answer = solve("day10.in", allocator) catch unreachable;
    answer.print();
}

test "day 10 worked examples" {
    var answer = try solve("day10.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 13140) catch |err| {
        print("{d} is not 13140\n", .{answer.part_1});
        return err;
    };
    // std.testing.expect(answer.part_2 == 1) catch |err| {
    //     print("{d} is not 1\n", .{answer.part_2});
    //     return err;
    // };
}
