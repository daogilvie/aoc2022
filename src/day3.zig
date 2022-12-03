const std = @import("std");
const utils = @import("utils.zig");

const Solution = utils.Solution;

const ItemMap = std.AutoHashMap(u8, u8);

const descending = std.sort.desc(u8);

/// Classic anglophone-centric character-set maths.
fn getPriority(item: u8) u8 {
    return if (item > 90)
        item - 96
    else
        item - 38;
}

const DUPLICATE_PLACEHOLDER = ' ';

/// This function is a bit messy — the elf_trio_item_map is for part 2, but all
/// the part 1 de-duping logic is contained in here. It returns out the duplicated
/// item in the rucksack, and modifies the entries in the trio map to mark all
/// the items in this particular rucksack with the impact. The impact is a power
/// of 2, which means I can uniquely identify which combinations of bags an item
/// is in. There's probably a bit-flipping whizzbang option here, but this seemed
/// simpler to write.
fn itemiseRucksackAndFindDuplicate(rucksack_contents: []const u8, elf_trio_item_map: *ItemMap, item_impact: u8, allocator: *const std.mem.Allocator) u8 {
    var duplicate: u8 = DUPLICATE_PLACEHOLDER;
    // This internal map is for part 1: it is a bit wasteful in terms of memory,
    // as I don't need the usize count at all, but I've already got the type
    // so ¯\_(ツ)_/¯
    var internal_map = ItemMap.init(allocator.*);
    defer internal_map.deinit();

    var halfway_point = rucksack_contents.len / 2;

    for (rucksack_contents) |item, index| {
        const in_compartment_2 = index >= halfway_point;
        // For compartment 1, we just lazily put things we find in the internal
        // map, so that we can check for them again in compartment 2
        if (!in_compartment_2) {
            internal_map.put(item, 0) catch unreachable;
        }

        // We look in the trio map, to see if this item has come up before in
        // the trio, and we add our impact to it if we've not seen it in this
        // particular bag before.
        const entry = elf_trio_item_map.getOrPut(item) catch unreachable;
        const found_in_previous_bag: bool = entry.found_existing and entry.value_ptr.* < item_impact;
        if (!entry.found_existing) {
            entry.value_ptr.* = item_impact;
        } else if (found_in_previous_bag) {
            entry.value_ptr.* += item_impact;
        }

        // If we haven't set a duplicate, we're in compartment 2, and we've found
        // a dupe... then it's the dupe!
        if (duplicate == DUPLICATE_PLACEHOLDER and in_compartment_2 and internal_map.contains(item)) {
            duplicate = item;
        }
    }

    return duplicate;
}

fn solve(filename: []const u8, allocator: *const std.mem.Allocator) !Solution {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var elf_trio_items = ItemMap.init(allocator.*);
    defer elf_trio_items.deinit();

    var part_1_priority_sum: usize = 0;
    var part_2_badge_sum: usize = 0;
    var duplicate: u8 = DUPLICATE_PLACEHOLDER;

    var rucksacks = std.mem.tokenize(u8, contents, "\n");
    while (rucksacks.next()) |first_rucksack| {
        // Fetch the next 2 rucksacks straight away, I think it's more readable?
        const second_rucksack = rucksacks.next().?;
        const third_rucksack = rucksacks.next().?;

        // Start of a new trio, so clear the trio map
        elf_trio_items.clearRetainingCapacity();

        duplicate = itemiseRucksackAndFindDuplicate(first_rucksack, &elf_trio_items, 1, allocator);
        part_1_priority_sum += getPriority(duplicate);

        duplicate = itemiseRucksackAndFindDuplicate(second_rucksack, &elf_trio_items, 2, allocator);
        part_1_priority_sum += getPriority(duplicate);

        duplicate = itemiseRucksackAndFindDuplicate(third_rucksack, &elf_trio_items, 4, allocator);
        part_1_priority_sum += getPriority(duplicate);

        // There will be only one key in the map with a value of 7, and this
        // is the one present in all three rucksacks. The else branch is unreachable
        // here (assuming no bugs or bad data), so I mark it as such to prevent the
        // compiler fretting about mismatched types on the arm.
        var badge_candidates = elf_trio_items.iterator();
        const badge_item = while (badge_candidates.next()) |entry| {
            if (entry.value_ptr.* == 7) break entry.key_ptr.*;
        } else unreachable;
        part_2_badge_sum += getPriority(badge_item);
    }

    return Solution{ .part_1 = part_1_priority_sum, .part_2 = part_2_badge_sum };
}

pub fn run(allocator: *const std.mem.Allocator) !void {
    utils.printHeader("Day 3");
    const solution = try solve("day3.in", allocator);
    std.debug.print("Part 1: {d}\n", .{solution.part_1});
    std.debug.print("Part 2: {d}\n", .{solution.part_2});
}

test "day 3 priority cast" {
    try std.testing.expectEqual(getPriority('a'), 1);
    try std.testing.expectEqual(getPriority('n'), 14);
    try std.testing.expectEqual(getPriority('z'), 26);
    try std.testing.expectEqual(getPriority('A'), 27);
    try std.testing.expectEqual(getPriority('N'), 40);
    try std.testing.expectEqual(getPriority('Z'), 52);
}

test "day 3 rucksack duplicate checker" {
    const contents = try utils.readInputFileToBuffer("day3.test", &std.testing.allocator);
    defer std.testing.allocator.free(contents);
    var map = ItemMap.init(std.testing.allocator);
    defer map.deinit();

    const dupes = [6]u8{ 'p', 'L', 'P', 'v', 't', 's' };
    var index: u8 = 0;

    var rucksacks = std.mem.tokenize(u8, contents, "\n");

    while (rucksacks.next()) |rucksack| {
        const dupe = itemiseRucksackAndFindDuplicate(rucksack, &map, 1, &std.testing.allocator);
        const desired = dupes[index];
        std.testing.expectEqual(dupe, desired) catch |err| {
            std.debug.print("{c} is not {c}\n", .{ dupe, desired });
            return err;
        };
        index += 1;
    }
}

test "day 3 worked example" {
    const solution = try solve("day3.test", &std.testing.allocator);
    std.testing.expect(solution.part_1 == 157) catch |err| {
        std.debug.print("{d} is not 157\n", .{solution.part_1});
        return err;
    };
    try std.testing.expect(solution.part_2 == 70);
}