const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = utils.AnswerStr;
const ArrayList = std.ArrayList;

const Stack = ArrayList(u8);

const print = std.debug.print;

const BunchOfStacks = struct {
    stacks: ArrayList(ArrayList(u8)),

    pub fn deinit(self: *BunchOfStacks) void {
        var stacks = self.stacks;
        var stacks_cleared: usize = 0;
        while (stacks_cleared < stacks.items.len) : (stacks_cleared += 1) {
            var stack = stacks.items[stacks_cleared];
            stack.deinit();
        }
        stacks.deinit();
    }
};

fn parseStartingStacks(input: []const u8, allocator: *const Allocator) !BunchOfStacks {
    var stack_lines = std.mem.tokenize(u8, input, "\n");
    var stack_lines_reordered = ArrayList([]const u8).init(allocator.*);
    defer stack_lines_reordered.deinit();
    while (stack_lines.next()) |line| {
        try stack_lines_reordered.append(line);
    }
    var stack_defs = std.mem.tokenize(u8, stack_lines_reordered.pop(), " ");
    var stacks = ArrayList(ArrayList(u8)).init(allocator.*);
    while (stack_defs.next()) |_| {
        try stacks.append(ArrayList(u8).init(allocator.*));
    }

    while (stack_lines_reordered.popOrNull()) |layer| {
        for (stacks.items) |*stack, index| {
            const crate_id: u8 = layer[(index * 4) + 1];
            if (crate_id != ' ') {
                try stack.append(crate_id);
            }
        }
    }
    return BunchOfStacks{ .stacks = stacks };
}

// Part 1 and part 2 have divergent states, so we solve them both independently
// from scratch
fn part1(filename: []const u8, allocator: *const Allocator) ![]u8 {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var puzzle_segments = std.mem.split(u8, contents, "\n\n");

    const starting_stacks = puzzle_segments.next().?;
    var stacks = try parseStartingStacks(starting_stacks, allocator);
    defer stacks.deinit();

    const instruction_lines = puzzle_segments.next().?;
    var instructions = std.mem.tokenize(u8, instruction_lines, " \n");
    while (instructions.next()) |_| {
        // First part is the verb, we skip for now
        // Get the amount next
        const amount: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);
        // now skip _from_
        _ = instructions.next();
        // Now get source
        const source: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);
        // Now skip _to_
        _ = instructions.next();
        // Now get dest
        const dest: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);

        var crates_moved: usize = 0;
        while (crates_moved < amount) : (crates_moved += 1) {
            try stacks.stacks.items[dest - 1].append(stacks.stacks.items[source - 1].popOrNull().?);
        }
    }

    // Crate Tops!
    var crate_tops: []u8 = try allocator.*.alloc(u8, stacks.stacks.items.len);
    for (stacks.stacks.items) |stack, index| {
        crate_tops[index] = stack.items[stack.items.len - 1];
    }
    return crate_tops;
}

fn moveCrates9001(stacks: *BunchOfStacks, amount: usize, source: usize, dest: usize) !void {
    const source_height = stacks.stacks.items[source - 1].items.len;
    const crate_slice = stacks.stacks.items[source - 1].items[(source_height - amount)..];
    try stacks.stacks.items[dest - 1].appendSlice(crate_slice);
    stacks.stacks.items[source - 1].shrinkRetainingCapacity(source_height - amount);
}

fn part2(filename: []const u8, allocator: *const Allocator) ![]u8 {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var puzzle_segments = std.mem.split(u8, contents, "\n\n");

    const starting_stacks = puzzle_segments.next().?;
    var stacks = try parseStartingStacks(starting_stacks, allocator);
    defer stacks.deinit();

    const instruction_lines = puzzle_segments.next().?;
    var instructions = std.mem.tokenize(u8, instruction_lines, " \n");
    while (instructions.next()) |_| {
        // First part is the verb, we skip for now
        // Get the amount next
        const amount: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);
        // now skip _from_
        _ = instructions.next();
        // Now get source
        const source: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);
        // Now skip _to_
        _ = instructions.next();
        // Now get dest
        const dest: usize = try std.fmt.parseInt(usize, instructions.next().?, 10);

        // Part 2
        try moveCrates9001(&stacks, amount, source, dest);
    }

    // Crate Tops!
    var crate_tops: []u8 = try allocator.*.alloc(u8, stacks.stacks.items.len);
    for (stacks.stacks.items) |stack, index| {
        crate_tops[index] = stack.items[stack.items.len - 1];
    }

    return crate_tops;
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    var part_1 = try part1(filename, allocator);
    var part_2 = try part2(filename, allocator);
    return Answer{ .part_1 = part_1, .part_2 = part_2, .allocator = allocator.* };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 5");
    var answer = solve("day5.in", allocator) catch unreachable;
    defer answer.deinit();
    answer.print();
}

test "day 5 worked example" {
    var answer = try solve("day5.test", &std.testing.allocator);
    defer answer.deinit();
    std.testing.expect(std.mem.eql(u8, answer.part_1, "CMZ")) catch |err| {
        print("\"{s}\" is not \"CMZ\"\n", .{answer.part_1});
        return err;
    };
    try std.testing.expect(std.mem.eql(u8, answer.part_2, "MCD"));
}
