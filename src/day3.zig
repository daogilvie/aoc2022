const std = @import("std");
const utils = @import("utils.zig");

const Solution = utils.Solution;

const descending = std.sort.desc(u8);

fn getPriority(item: u8) u8 {
    return if (item > 90)
        item - 96
    else
        item - 38;
}

const Rucksack = struct {
    compartment_one: []const u8,
    compartment_two: []const u8,
    duplicate: u8,

    pub fn init(contents: []const u8, allocator: *const std.mem.Allocator) !Rucksack {
        const compartment_one = contents[0 .. contents.len / 2];
        const compartment_two = contents[contents.len / 2 ..];

        var map = std.AutoHashMap(u8, usize).init(allocator.*);
        defer map.deinit();
        for (compartment_one) |item| {
            const count = try map.getOrPutValue(item, 0);
            try map.put(item, count.value_ptr.* + 1);
        }

        const duplicate = for (compartment_two) |item| {
            if (map.contains(item)) break item;
        } else ' ';

        return Rucksack{ .compartment_one = compartment_one, .compartment_two = compartment_two, .duplicate = duplicate };
    }
};

fn solve(filename: []const u8, allocator: *const std.mem.Allocator) !Solution {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);
    var rucksacks = std.mem.tokenize(u8, contents, "\n");
    var part_1_priority_sum: usize = 0;
    while (rucksacks.next()) |rucksack_contents| {
        const sack = try Rucksack.init(rucksack_contents, allocator);
        part_1_priority_sum += getPriority(sack.duplicate);
    }
    return Solution{ .part_1 = part_1_priority_sum, .part_2 = 0 };
}

pub fn run(allocator: *const std.mem.Allocator) !void {
    utils.printHeader("Day 3");
    const solution = try solve("day3.in", allocator);
    std.debug.print("Part 1: {d}\n", .{solution.part_1});
    std.debug.print("Part 2: {d}\n", .{solution.part_2});
}

test "day 3 rucksack example" {
    const sack = try Rucksack.init("vJrwpWtwJgWrhcsFMMfFFhFp", &std.testing.allocator);
    try std.testing.expect(std.mem.eql(u8, sack.compartment_one, "vJrwpWtwJgWr"));
    try std.testing.expect(std.mem.eql(u8, sack.compartment_two, "hcsFMMfFFhFp"));
    try std.testing.expectEqual(sack.duplicate, 'p');
}

test "day 3 priority cast" {
    try std.testing.expectEqual(getPriority('a'), 1);
    try std.testing.expectEqual(getPriority('n'), 14);
    try std.testing.expectEqual(getPriority('z'), 26);
    try std.testing.expectEqual(getPriority('A'), 27);
    try std.testing.expectEqual(getPriority('N'), 40);
    try std.testing.expectEqual(getPriority('Z'), 52);
}

test "day 3 worked example" {
    const solution = try solve("day3.test", &std.testing.allocator);
    try std.testing.expect(solution.part_1 == 157);
    // try std.testing.expect(solution.part_2 == 12);
}
