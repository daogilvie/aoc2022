const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;
const print = std.debug.print;
const Order = std.math.Order;

const Ordering = enum { correct, wrong, unknown };

const ListEntry = union(enum) {
    number: usize,
    list: []ListEntry,

    fn deinit(self: ListEntry, recurse: bool, allocator: Allocator) void {
        switch (self) {
            ListEntry.number => return,
            ListEntry.list => {
                if (recurse) {
                    for (self.list) |entry| {
                        entry.deinit(true, allocator);
                    }
                }
                allocator.free(self.list);
            },
        }
    }

    fn getAsList(self: ListEntry, allocator: Allocator) ListEntry {
        var new_entry = self;
        switch (self) {
            .number => {
                var slice: []ListEntry = allocator.alloc(ListEntry, 1) catch unreachable;
                slice[0] = ListEntry{ .number = self.number };
                new_entry = ListEntry{ .list = slice };
            },
            .list => {},
        }
        return new_entry;
    }
};

const ParserContext = struct { pair_index: usize = 0, depth: usize = 0, remaining: []const u8, allocator: Allocator };

fn isNumberEntry(entry: ListEntry) bool {
    return switch (entry) {
        .number => true,
        else => false,
    };
}

fn compareListEntries(left: ListEntry, right: ListEntry, allocator: Allocator) Ordering {
    // Case 1: Both Numbers
    if (isNumberEntry(left) and isNumberEntry(right)) {
        return if (left.number < right.number)
            Ordering.correct
        else if (left.number > right.number) Ordering.wrong else Ordering.unknown;
    } else if (isNumberEntry(left)) {
        // Make fake list for left
        var fake_left = left.getAsList(allocator);
        defer fake_left.deinit(false, allocator);
        return compareListEntries(fake_left, right, allocator);
    } else if (isNumberEntry(right)) {
        // Make fake list for right
        var fake_right = right.getAsList(allocator);
        defer fake_right.deinit(false, allocator);
        return compareListEntries(left, fake_right, allocator);
    } else {
        // Both are list types
        var current_comparison = Ordering.unknown;
        var index: usize = 0;
        const left_len: usize = left.list.len;
        const right_len: usize = right.list.len;
        while (current_comparison == Ordering.unknown) : (index += 1) {
            // Are both lists done?
            if (index >= right_len and index >= left_len) {
                break;
            }
            if (index >= right_len) {
                current_comparison = Ordering.wrong;
            } else if (index >= left_len) {
                current_comparison = Ordering.correct;
            } else {
                current_comparison = compareListEntries(left.list[index], right.list[index], allocator);
            }
        }
        return current_comparison;
    }
}

fn orderPackets(allocator: Allocator, a: ListEntry, b: ListEntry) bool {
    return switch (compareListEntries(a, b, allocator)) {
        .correct => true,
        else => false,
    };
}

// Parse a number up to the next , or ]
fn parseNextNumber(context: *ParserContext) ?ListEntry {
    const slice_len = for (context.remaining) |char, index| {
        if (!std.ascii.isDigit(char)) {
            break index;
        }
    } else context.remaining.len;
    if (slice_len == 0) return null;
    const num = std.fmt.parseInt(usize, context.remaining[0..slice_len], 10) catch unreachable;
    context.remaining = context.remaining[slice_len..];
    return ListEntry{ .number = num };
}

fn parseList(context: *ParserContext) ?ListEntry {
    var entries = ArrayList(ListEntry).init(context.allocator);
    if (context.remaining[0] != '[') return null;
    context.remaining = context.remaining[1..];
    context.depth += 1;
    while (true) {
        if (parseNextNumber(context)) |number_entry| {
            entries.append(number_entry) catch unreachable;
        } else if (parseList(context)) |list_entry| {
            entries.append(list_entry) catch unreachable;
        }
        const char = context.remaining[0];
        context.remaining = context.remaining[1..];
        if (char == ']') {
            break;
        }
    }
    context.depth -= 1;
    return ListEntry{ .list = entries.toOwnedSlice() catch unreachable };
}

fn deinitPackets(packets: []ListEntry, allocator: Allocator) void {
    for (packets) |packet| {
        packet.deinit(true, allocator);
    }
    allocator.free(packets);
}

fn parseStrComplete(input: []const u8, allocator: Allocator) ListEntry {
    var context = ParserContext{ .allocator = allocator, .remaining = input };
    return parseList(&context).?;
}

pub fn solve(filename: str, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var pair_index: usize = 1;
    var part_1: usize = 0;

    var lines = std.mem.tokenize(u8, content, "\n");

    var packets = ArrayList(ListEntry).init(allocator.*);

    while (lines.next()) |line| {
        var left = parseStrComplete(line, allocator.*);
        packets.append(left) catch unreachable;
        const right_line = lines.next().?;
        var right = parseStrComplete(right_line, allocator.*);
        packets.append(right) catch unreachable;

        // Are these correct?
        if (compareListEntries(left, right, allocator.*) == Ordering.correct) {
            part_1 += pair_index;
        }

        pair_index += 1;
    }

    // Inject divider packet
    packets.append(parseStrComplete("[[2]]", allocator.*)) catch unreachable;
    packets.append(parseStrComplete("[[6]]", allocator.*)) catch unreachable;
    var sortable = packets.toOwnedSlice() catch unreachable;
    defer deinitPackets(sortable, allocator.*);
    std.sort.sort(ListEntry, sortable, allocator.*, orderPackets);
    var part_2: usize = 1;
    for (sortable) |entry, index| {
        if (entry.list.len == 1) {
            switch (entry.list[0]) {
                .list => |inner_list| {
                    if (inner_list.len != 1) continue;
                    switch (inner_list[0]) {
                        .list => continue,
                        .number => |value| {
                            if (value == 2 or value == 6) part_2 *= index + 1;
                        },
                    }
                },
                else => continue,
            }
        }
    }

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 13");
    var answer = solve("day13.in", allocator) catch unreachable;
    answer.print();
}

test "day 13 worked examples" {
    var answer = try solve("day13.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 13) catch |err| {
        print("{d} is not 13\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 140) catch |err| {
        print("{d} is not 140\n", .{answer.part_2});
        return err;
    };
}
