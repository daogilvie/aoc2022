const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;

const print = std.debug.print;

const ascending = std.sort.asc(usize);

const CUTOFF_SIZE: usize = 100000;
const CAPACITY: usize = 70000000;
const TARGET_USAGE: usize = CAPACITY - 30000000;

fn makePrefixedName(dir_stack: ArrayList([]u8), dirname: []const u8, allocator: Allocator) []u8 {
    // Base case
    if (dir_stack.items.len == 0) {
        var bytes: []u8 = allocator.alloc(u8, dirname.len) catch unreachable;
        std.mem.copy(u8, bytes, dirname);
        return bytes;
    } else {
        var running_len: usize = 0;
        for (dir_stack.items) |dir| {
            running_len += dir.len + 1;
        }
        var bytes: []u8 = allocator.alloc(u8, running_len + dirname.len) catch unreachable;
        running_len = 0;
        for (dir_stack.items) |item| {
            std.mem.copy(u8, bytes[running_len .. running_len + item.len], item);
            running_len += item.len;
            bytes[running_len] = '/';
        }
        std.mem.copy(u8, bytes[bytes.len - dirname.len ..], dirname);
        return bytes;
    }
}

fn clearDirStack(dir_stack: ArrayList([]u8), allocator: Allocator) void {
    for (dir_stack.items) |item| {
        allocator.free(item);
    }
    dir_stack.deinit();
}

pub fn solve(filename: []const u8, allocator: Allocator) !Answer {
    const contents = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(contents);

    var lines = std.mem.tokenize(u8, contents, "\n");

    // Make a map to store directory sizes as fully qualified paths —
    // just in case there are any sub dirs with the same name knocking about.
    var dir_size_map = std.StringArrayHashMap(usize).init(allocator);
    defer dir_size_map.deinit();
    var dir_stack = ArrayList([]u8).init(allocator);
    defer clearDirStack(dir_stack, allocator);
    var full_sum: usize = 0;
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "$ ls")) {
            // ls lines are meaningless to us!
            continue;
        }
        if (std.mem.startsWith(u8, line, "$ cd")) {
            if (std.mem.endsWith(u8, line, "/")) {
                // We should clear the dir stack
                dir_stack.clearRetainingCapacity();
            } else if (std.mem.endsWith(u8, line, "..")) {
                // Pop back up a dir and deallocate the name buffer for
                // the dir like a good citizen.
                var item = dir_stack.pop();
                allocator.free(item);
            } else {
                // ASSUMPTION: A cd line like this is descending into a new dir
                try dir_stack.append(makePrefixedName(dir_stack, line[5..], allocator));
            }
        } else if (!std.mem.startsWith(u8, line, "dir")) {
            var parts = std.mem.tokenize(u8, line, " ");
            var filesize = try std.fmt.parseInt(usize, parts.next().?, 10);
            // This filesize counts for every directory in the stack,
            // so lets update them all, plus add it to the full sum for the
            // root directory.
            for (dir_stack.items) |nested_dirname| {
                var entry = try dir_size_map.getOrPut(nested_dirname);
                if (!entry.found_existing) {
                    entry.value_ptr.* = filesize;
                } else {
                    entry.value_ptr.* += filesize;
                }
            }
            full_sum += filesize;
        }
    }

    var values: []usize = dir_size_map.values();
    std.sort.sort(usize, values, {}, ascending);

    var part_1_answer: usize = 0;
    {
        var index: usize = 1;
        var size = values[0];
        while (size < CUTOFF_SIZE) : (index += 1) {
            part_1_answer += size;
            size = values[index];
        }
    }

    std.mem.reverse(usize, values);
    var part_2_answer = for (values) |filesize, index| {
        const test_total = full_sum - filesize;
        if (test_total > TARGET_USAGE) break values[index - 1];
    } else unreachable;

    return Answer{ .part_1 = part_1_answer, .part_2 = part_2_answer };
}

pub fn run(allocator: Allocator) void {
    utils.printHeader("Day 7");
    var answer = solve("day7.in", allocator) catch unreachable;
    answer.print();
}

test "day 7 worked example" {
    var answer = try solve("day7.test", std.testing.allocator);
    std.testing.expect(answer.part_1 == 95437) catch |err| {
        print("{d} is not 95437\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 24933642) catch |err| {
        print("{d} is not 24933642\n", .{answer.part_2});
        return err;
    };
}
