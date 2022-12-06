const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const Answer = utils.Answer;
const ArrayList = std.ArrayList;

const Stack = ArrayList(u8);

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
    var stack_lines = std.mem.tokenize(u8, input, "\n");
    var stack_lines_reordered = ArrayList([]const u8).init(allocator.*);
    defer stack_lines_reordered.deinit();
    while (stack_lines.next()) |line| {
        try stack_lines_reordered.append(line);
    }
    var stack_defs = std.mem.tokenize(u8, stack_lines_reordered.pop(), " ");
    var bunch_of_stacks = BunchOfStacks.init(allocator.*);
    while (stack_defs.next()) |_| {
        try bunch_of_stacks.addStack();
    }

    while (stack_lines_reordered.popOrNull()) |layer| {
        for (bunch_of_stacks.stacks.items) |*stack, index| {
            const crate_id: u8 = layer[(index * 4) + 1];
            if (crate_id != ' ') {
                try stack.append(crate_id);
            }
        }
    }
    return bunch_of_stacks;
}

const WINDOW_LENGTH: usize = 4;

/// Return the number of u8s to advance to check the next window,
/// or 0 if this window is all different
fn checkWindowIsAllDifferent(window: []const u8) usize {
    var advance: usize = 0;
    if (window[0] == window[1] or window[0] == window[2] or window[0] == window[3]) {
        advance = 1;
    }
    if (window[1] == window[2] or window[1] == window[3]) {
        advance = 2;
    }
    if (window[2] == window[3]) {
        advance = 3;
    }
    return advance;
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var window_start: usize = 0;
    const part_1: usize = while (window_start < contents.len - WINDOW_LENGTH) {
        const window = contents[window_start .. window_start + WINDOW_LENGTH];

        var diff: usize = checkWindowIsAllDifferent(window);
        if (diff > 0) {
            window_start += diff;
        } else break window_start + WINDOW_LENGTH;
    } else 0;

    return Answer{ .part_1 = part_1, .part_2 = 0 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 6");
    var answer = solve("day6.in", allocator) catch unreachable;
    answer.print();
}

test "day 6 worked example" {
    var answer = try solve("day6.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 7) catch |err| {
        print("{d} is not 7\n", .{answer.part_1});
        return err;
    };
    // std.testing.expect(std.mem.eql(u8, answer.part_2, "MCD")) catch |err| {
    //     print("\"{s}\" is not \"MCD\"\n", .{answer.part_1});
    //     return err;
    // };
}
