const std = @import("std");
const utils = @import("utils.zig");
const Solution = utils.Solution;

const descending = std.sort.desc(usize);

fn solve(filename: []const u8, allocator: *const std.mem.Allocator) !Solution {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var calorie_list = std.ArrayList(usize).init(allocator.*);
    defer calorie_list.deinit();

    var elf_chunks = std.mem.split(u8, contents, "\n\n");

    while (elf_chunks.next()) |elf_chunk| {
        var elf_items = std.mem.split(u8, elf_chunk, "\n");
        var total_calories: usize = 0;
        while (elf_items.next()) |calorie_bytes| {
            if (calorie_bytes.len == 0) continue; // Skip empty line at the end of the file
            var calorie_count = try std.fmt.parseInt(usize, calorie_bytes, 10);
            total_calories += calorie_count;
        }
        try calorie_list.append(total_calories);
    }

    var sorted = try calorie_list.toOwnedSlice();
    defer allocator.free(sorted);

    std.sort.sort(usize, sorted, {}, descending);

    return Solution{ .part_1 = sorted[0], .part_2 = sorted[0] + sorted[1] + sorted[2] };
}

pub fn run(allocator: *const std.mem.Allocator) !void {
    utils.printHeader("Day 1");
    const solution = try solve("day1.in", allocator);
    std.debug.print("Part 1: {d}\n", .{solution.part_1});
    std.debug.print("Part 2: {d}\n", .{solution.part_2});
}

test "day 1 worked example" {
    const solution = try solve("day1.test", &std.testing.allocator);
    try std.testing.expect(solution.part_1 == 24000);
    try std.testing.expect(solution.part_2 == 45000);
}
