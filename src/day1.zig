const std = @import("std");
const utils = @import("utils.zig");

fn cmpDescending(context: void, a: usize, b: usize) bool {
    return std.sort.desc(usize)(context, a, b);
}

pub fn run(allocator: *const std.mem.Allocator) !void {
    utils.printHeader("Day 1");

    const contents = try utils.readInputFileToBuffer("day1.in", allocator);
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

    std.sort.sort(usize, sorted, {}, cmpDescending);

    std.debug.print("Part 1: Most well-equipped elf has {d} calories\n", .{sorted[0]});
    std.debug.print("Part 2: Most well-equipped 3 elves have {d} calories\n", .{sorted[0] + sorted[1] + sorted[2]});
}
