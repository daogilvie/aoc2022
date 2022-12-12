const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = struct {
    part_1: isize,
    part_2: []const u8,
    allocator: Allocator,

    fn print(self: Answer) void {
        std.debug.print("Part 1:{d}\nPart 2:\n{s}\n", .{ self.part_1, self.part_2 });
    }

    fn deinit(self: Answer) void {
        self.allocator.free(self.part_2);
    }
};

const print = std.debug.print;

const CRT_BUF_LEN = 40 * 6;

const Operation = enum { noop, addx };

pub fn closeEnough(target: isize, value: isize) bool {
    return std.math.absInt(target - value) catch unreachable < 2;
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var instructions = std.mem.tokenize(u8, content, " \n");
    var cycle_count: usize = 0;
    var next_increment: ?isize = 0;
    var x_register: isize = 1;
    var signal_sum: isize = 0;
    var instruction: ?[]const u8 = undefined;

    var crt_pixels: [CRT_BUF_LEN]u8 = .{'.'} ** CRT_BUF_LEN;
    std.mem.set(u8, &crt_pixels, '`');
    while (true) : (cycle_count += 1) {
        const cycle_signed = @intCast(isize, cycle_count);
        if (@mod(cycle_count, 40) == 20) {
            signal_sum += cycle_signed * x_register;
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
        if (closeEnough(@rem(cycle_signed, 40), x_register)) {
            crt_pixels[cycle_count] = '#';
        }
    }

    // Convert pixels to rows for easy display/comparison
    // First real use of comptime to unroll a loop. A toy use, but interesting.
    var crt_screen: []u8 = try allocator.*.alloc(u8, CRT_BUF_LEN + 5);
    comptime var index: usize = 0;
    comptime var start = index * 40;
    comptime var end = start + 40;
    inline while (index < 5) : (index += 1) {
        start = index * 40;
        end = start + 40;
        std.mem.copy(u8, crt_screen[start + index .. end + index], crt_pixels[start..end]);
        crt_screen[40 * (index + 1) + index] = '\n';
    }
    start = index * 40;
    end = start + 40;
    std.mem.copy(u8, crt_screen[start + index .. end + index], crt_pixels[start..end]);

    return Answer{ .part_1 = signal_sum, .part_2 = crt_screen, .allocator = allocator.* };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 10");
    var answer = solve("day10.in", allocator) catch unreachable;
    defer answer.deinit();
    answer.print();
}

test "day 10 worked examples" {
    var answer = try solve("day10.test", &std.testing.allocator);
    defer answer.deinit();
    std.testing.expect(answer.part_1 == 13140) catch |err| {
        print("{d} is not 13140\n", .{answer.part_1});
        return err;
    };
    const p2_output =
        \\##``##``##``##``##``##``##``##``##``##``
        \\###```###```###```###```###```###```###`
        \\####````####````####````####````####````
        \\#####`````#####`````#####`````#####`````
        \\######``````######``````######``````####
        \\#######```````#######```````#######`````
    ;
    std.testing.expect(std.mem.eql(u8, answer.part_2, p2_output)) catch |err| {
        print("\n{s}\nis not\n{s}\n", .{ answer.part_2, p2_output });
        return err;
    };
}
