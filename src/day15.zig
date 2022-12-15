const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;
const print = std.debug.print;

const Offset = struct {
    x: isize,
    y: isize,

    fn manhattanDistance(self: Offset) isize {
        return (std.math.absInt(self.x) catch unreachable) + (std.math.absInt(self.y) catch unreachable);
    }
};

const Point = struct {
    x: isize,
    y: isize,

    fn getOffset(self: Point, other: Point) Offset {
        return Offset{
            .x = other.x - self.x,
            .y = other.y - self.y,
        };
    }

    fn equals(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    fn fromStr(input: str) Point {
        // input is "x=?, y=?"
        var parts = std.mem.split(u8, input, ", ");
        const x_part = parts.next().?;
        const y_part = parts.next().?;
        const x = std.fmt.parseInt(isize, x_part[2..], 10) catch unreachable;
        const y = std.fmt.parseInt(isize, y_part[2..], 10) catch unreachable;
        return Point{ .x = x, .y = y };
    }
};


pub fn solve(filename: str, allocator: Allocator, target_y: isize) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var lines = std.mem.tokenize(u8, content, "\n");

    var sensors = ArrayList(Point).init(allocator);
    defer sensors.deinit();
    var beacons = ArrayList(Point).init(allocator);
    defer beacons.deinit();

    var beacon_set = std.AutoHashMap(Point, void).init(allocator);
    defer beacon_set.deinit();

    var min_x: isize = std.math.maxInt(isize);
    var max_x: isize = std.math.minInt(isize);
    var min_y: isize = std.math.maxInt(isize);
    var max_y: isize = std.math.minInt(isize);
    while (lines.next()) |line| {
        const col_pos = std.mem.indexOfScalar(u8, line, ':').?;
        const sensor = Point.fromStr(line[10..col_pos]);
        sensors.append(sensor) catch unreachable;
        const beacon = Point.fromStr(line[col_pos + 23 ..]);
        beacons.append(beacon) catch unreachable;
        beacon_set.put(beacon, {}) catch unreachable;
        min_x = std.math.min(std.math.min(sensor.x, beacon.x), min_x);
        max_x = std.math.max(std.math.max(sensor.x, beacon.x), max_x);
        min_y = std.math.min(std.math.min(sensor.y, beacon.y), min_y);
        max_y = std.math.max(std.math.max(sensor.y, beacon.y), max_y);
    }
    var reached_spots = std.AutoHashMap(Point, void).init(allocator);
    defer reached_spots.deinit();
    for (sensors.items) |sensor, index| {
        const beacon = beacons.items[index];
        const beacon_distance = sensor.getOffset(beacon).manhattanDistance();
        const target_distance = std.math.absInt(target_y - sensor.y) catch unreachable;

        const wiggle_room = beacon_distance - target_distance;

        if (wiggle_room >= 0) {
            var target_x = sensor.x - wiggle_room;
            var limit_x = sensor.x + wiggle_room;
            while (target_x <= limit_x) : (target_x += 1) {
                const t_point = Point{ .x = target_x, .y = target_y };
                if (!beacon_set.contains(t_point)) {
                    reached_spots.put(t_point, {}) catch unreachable;
                }
            }
        }
    }

    return Answer{ .part_1 = reached_spots.count(), .part_2 = 0 };
}

pub fn run(allocator: Allocator) void {
    utils.printHeader("Day 15");
    var answer = solve("day15.in", allocator, 2000000) catch unreachable;
    answer.print();
}

test "day 15 worked examples" {
    var answer = try solve("day15.test", std.testing.allocator, 10);
    std.testing.expect(answer.part_1 == 26) catch |err| {
        print("{d} is not 26\n", .{answer.part_1});
        return err;
    };
}
