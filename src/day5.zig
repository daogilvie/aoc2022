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
        for (stacks.items) | *stack, index | {
            const crate_id: u8 = layer[(index * 4) + 1];
            if (crate_id != ' ') {
                try stack.append(crate_id);
            }
        }
    }
    return BunchOfStacks { .stacks = stacks };
}

fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
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
            try stacks.stacks.items[dest-1].append(stacks.stacks.items[source-1].popOrNull().?);
        }
    }

    // Crate Tops!
    var crate_tops: []u8 = try allocator.*.alloc(u8, stacks.stacks.items.len);
    for (stacks.stacks.items) |stack, index| {
        crate_tops[index] = stack.items[stack.items.len - 1];
    }

    var part_2: []u8 = try allocator.*.alloc(u8, stacks.stacks.items.len);

    return Answer{ .part_1 = crate_tops, .part_2 = part_2, .allocator = allocator.* };
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
    // try std.testing.expect(solution.part_2 == 5);
}


// test "day 5 arraylist" {
//     var list_of_lists = ArrayList(ArrayList(u8)).init(std.testing.allocator);
//     var i: u8 = 0;
//     while (i < 2) : (i+=1){
//         try list_of_lists.append(ArrayList(u8).init(std.testing.allocator));
//     }
//     defer list_of_lists.deinit();
//     const values = [2]u8 {'a', 'b'};
//     for (list_of_lists.items) |*list, index| {
//         try list.append(values[index]);
//         std.testing.expect(list.items.len == 1) catch |err| {
//             print("{d} is not 1\n", .{list.items.len});
//             return err;
//         };
//     }
//     for (list_of_lists.items) | list, index | {
//         try std.testing.expect(list.items.len == 1);
//         try std.testing.expectEqual(list.items[0], values[index]);
//         list.deinit();
//     }
// }
