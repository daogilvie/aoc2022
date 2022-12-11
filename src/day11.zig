const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;
const print = std.debug.print;
const descending = std.sort.desc(usize);

const OperationMethod = enum { add, multiply, square };

const WorryBooster = struct {
    operation: OperationMethod,
    value: usize,

    pub fn boost(self: WorryBooster, worry: usize) usize {
        return switch (self.operation) {
            .add => worry + self.value,
            .multiply => worry * self.value,
            .square => worry * worry,
        };
    }
};

const WorryTester = struct {
    value: usize,
    pub fn doTest(self: WorryTester, level: usize) bool {
        return @rem(level, self.value) == 0;
    }
};

const Monkey = struct {
    items: ArrayList(usize),
    booster: WorryBooster,
    tester: WorryTester,
    true_index: usize,
    false_index: usize,
    inspection_count: usize,

    pub fn addItem(self: *Monkey, item: usize) void {
        self.items.append(item) catch unreachable;
    }

    pub fn deinit(self: Monkey) void {
        self.items.deinit();
    }
};

fn stripPrefix(haystack: []const u8) []const u8 {
    const semi_index = std.mem.indexOfScalar(u8, haystack, ':').?;
    return haystack[semi_index + 2 ..];
}

fn getEndNumber(haystack: []const u8) usize {
    const val_str = haystack[std.mem.lastIndexOfScalar(u8, haystack, ' ').? + 1 ..];
    return std.fmt.parseInt(usize, val_str, 10) catch unreachable;
}

fn parseMonkey(monkey_def: []const u8, allocator: Allocator) Monkey {
    var monkey_lines = std.mem.tokenize(u8, monkey_def, "\n");
    // skip first line
    _ = monkey_lines.next();
    const item_line = stripPrefix(monkey_lines.next().?);
    var item_list = ArrayList(usize).init(allocator);
    var starting_items = std.mem.tokenize(u8, item_line, " ,");
    while (starting_items.next()) |value| {
        const val = std.fmt.parseInt(usize, value, 10) catch unreachable;
        item_list.append(val) catch unreachable;
    }
    const operation_line = stripPrefix(monkey_lines.next().?);
    // The square case is easy
    var booster: WorryBooster = undefined;
    if (std.mem.eql(u8, operation_line, "new = old * old")) {
        booster = WorryBooster{ .operation = OperationMethod.square, .value = 0 };
    } else {
        const value = getEndNumber(operation_line);
        if (std.mem.indexOfScalar(u8, operation_line, '+') == null) {
            booster = WorryBooster{ .operation = OperationMethod.multiply, .value = value };
        } else {
            booster = WorryBooster{ .operation = OperationMethod.add, .value = value };
        }
    }
    const test_line = stripPrefix(monkey_lines.next().?);
    var tester: WorryTester = WorryTester{ .value = getEndNumber(test_line) };
    const true_line = stripPrefix(monkey_lines.next().?);
    const true_monkey = getEndNumber(true_line);
    const false_line = stripPrefix(monkey_lines.next().?);
    const false_monkey = getEndNumber(false_line);
    return Monkey{ .items = item_list, .booster = booster, .tester = tester, .true_index = true_monkey, .false_index = false_monkey, .inspection_count = 0 };
}

fn clearOutMonkeys(monkehs: *ArrayList(Monkey)) void {
    for (monkehs.*.items) |monkeh| {
        monkeh.deinit();
    }
    monkehs.*.deinit();
}

fn createMonkeyList(content: []const u8, allocator: Allocator) ArrayList(Monkey) {
    var monkey_blocks = std.mem.split(u8, content, "Monkey ");
    var monkehs = ArrayList(Monkey).init(allocator);
    var monkey_index: usize = 0;
    while (monkey_blocks.next()) |monkeh_block| {
        if (monkeh_block.len == 0) continue;
        monkehs.append(parseMonkey(monkeh_block, allocator)) catch unreachable;
        monkey_index += 1;
    }
    return monkehs;
}

fn determineMonkeyBusiness(monkehs: *ArrayList(Monkey), allocator: Allocator) usize {
    var inspection_counts = allocator.alloc(usize, monkehs.items.len) catch unreachable;
    defer allocator.free(inspection_counts);
    for (monkehs.items) |monkeh, index| {
        inspection_counts[index] = monkeh.inspection_count;
    }
    std.sort.sort(usize, inspection_counts, {}, descending);
    return inspection_counts[0] * inspection_counts[1];
}

fn partOne(content: []const u8, allocator: Allocator) usize {
    var monkehs = createMonkeyList(content, allocator);
    defer clearOutMonkeys(&monkehs);
    var round_counter: usize = 0;
    while (round_counter < 20) : (round_counter += 1) {
        for (monkehs.items) |*monkeh| {
            for (monkeh.items.items) |item_value| {
                monkeh.inspection_count += 1;
                var new_level = monkeh.booster.boost(item_value);
                new_level = @divFloor(new_level, 3);
                if (monkeh.tester.doTest(new_level)) {
                    monkehs.items[monkeh.true_index].addItem(new_level);
                } else {
                    monkehs.items[monkeh.false_index].addItem(new_level);
                }
            }
            monkeh.items.clearRetainingCapacity();
        }
    }
    return determineMonkeyBusiness(&monkehs, allocator);
}

fn partTwo(content: []const u8, allocator: Allocator) usize {
    var monkehs = createMonkeyList(content, allocator);
    defer clearOutMonkeys(&monkehs);
    var common_multiplier: usize = 1;
    for (monkehs.items) |monkeh| {
        common_multiplier *= monkeh.tester.value;
    }

    var round_counter: usize = 0;
    while (round_counter < 10000) : (round_counter += 1) {
        for (monkehs.items) |*monkeh| {
            for (monkeh.items.items) |item_value| {
                monkeh.inspection_count += 1;
                var new_level = monkeh.booster.boost(item_value);
                new_level = @mod(new_level, common_multiplier);
                if (monkeh.tester.doTest(new_level)) {
                    monkehs.items[monkeh.true_index].addItem(new_level);
                } else {
                    monkehs.items[monkeh.false_index].addItem(new_level);
                }
            }
            monkeh.items.clearRetainingCapacity();
        }
    }
    return determineMonkeyBusiness(&monkehs, allocator);
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    const part_1 = partOne(content, allocator.*);
    const part_2 = partTwo(content, allocator.*);

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 11");
    var answer = solve("day11.in", allocator) catch unreachable;
    answer.print();
}

test "day 11 worked examples" {
    var answer = try solve("day11.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 10605) catch |err| {
        print("{d} is not 10605\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 2713310158) catch |err| {
        print("{d} is not 2713310158\n", .{answer.part_2});
        return err;
    };
}
