const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = utils.AnswerStr;
const ArrayList = std.ArrayList;

const print = std.debug.print;

const BunchOfStacks = struct {
    stacks: ArrayList(ArrayList(u8)),
    allocator: Allocator,

    fn init(allocator: Allocator) BunchOfStacks {
        return BunchOfStacks{ .stacks = ArrayList(ArrayList(u8)).init(allocator), .allocator = allocator };
    }

    fn addStack(self: *BunchOfStacks) !void {
        try self.stacks.append(ArrayList(u8).init(self.allocator));
    }

    pub fn deinit(self: *BunchOfStacks) void {
        var stacks = self.stacks;
        var stacks_cleared: usize = 0;
        while (stacks_cleared < stacks.items.len) : (stacks_cleared += 1) {
            var stack = stacks.items[stacks_cleared];
            stack.deinit();
        }
        stacks.deinit();
    }

    fn moveCrates(self: *BunchOfStacks, amount: usize, source: usize, dest: usize) !void {
        const source_height = self.stacks.items[source - 1].items.len;
        const crate_slice = self.stacks.items[source - 1].items[(source_height - amount)..];
        try self.stacks.items[dest - 1].appendSlice(crate_slice);
        self.stacks.items[source - 1].shrinkRetainingCapacity(source_height - amount);
    }

    fn getTopRow(self: BunchOfStacks) []u8 {
        var crate_tops: []u8 = self.allocator.alloc(u8, self.stacks.items.len) catch unreachable;
        for (self.stacks.items) |stack, index| {
            crate_tops[index] = stack.items[stack.items.len - 1];
        }
        return crate_tops;
    }
};

fn parseStartingStacks(input: []const u8, allocator: *const Allocator) !BunchOfStacks {
    var stack_lines_reordered = std.mem.splitBackwards(u8, input, "\n");
    var stack_defs = std.mem.tokenize(u8, stack_lines_reordered.next().?, " ");
    var bunch_of_stacks = BunchOfStacks.init(allocator.*);
    while (stack_defs.next()) |_| {
        try bunch_of_stacks.addStack();
    }

    while (stack_lines_reordered.next()) |layer| {
        for (bunch_of_stacks.stacks.items) |*stack, index| {
            const crate_id: u8 = layer[(index * 4) + 1];
            if (crate_id != ' ') {
                try stack.append(crate_id);
            }
        }
    }
    return bunch_of_stacks;
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var puzzle_segments = std.mem.split(u8, contents, "\n\n");

    const starting_stacks = puzzle_segments.next().?;

    // As the stacks have different intermediate states, we just operate
    // two different data structures.
    var stacks_part1 = try parseStartingStacks(starting_stacks, allocator);
    var stacks_part2 = try parseStartingStacks(starting_stacks, allocator);
    defer stacks_part1.deinit();
    defer stacks_part2.deinit();

    const instruction_lines = puzzle_segments.next().?;
    var instructions = std.mem.tokenize(u8, instruction_lines, " \n");
    while (instructions.next()) |_| {
        // First part is the verb, this is always "move" so skip it
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
            try stacks_part1.moveCrates(1, source, dest);
        }
        try stacks_part2.moveCrates(amount, source, dest);
    }

    return Answer{ .part_1 = stacks_part1.getTopRow(), .part_2 = stacks_part2.getTopRow(), .allocator = allocator.* };
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
    std.testing.expect(std.mem.eql(u8, answer.part_2, "MCD")) catch |err| {
        print("\"{s}\" is not \"MCD\"\n", .{answer.part_1});
        return err;
    };
}
