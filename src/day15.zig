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

const Segment = struct {
    min: isize,
    max: isize,
    len: usize,

    fn init(min: isize, max: isize) Segment {
        return Segment{ .min = min, .max = max, .len = std.math.absCast(max - min) + 1 };
    }

    fn contains(self: Segment, num: isize) bool {
        return num >= self.min and num <= self.max;
    }

    fn overlaps(self: Segment, other: Segment) bool {
        return (self.min >= other.min and self.min <= other.max) or (other.min >= self.min and other.min <= self.max);
    }

    fn combineWith(self: Segment, other: Segment) ?Segment {
        if (!self.overlaps(other)) return null;
        return Segment.init(std.math.min(self.min, other.min), std.math.max(self.max, other.max));
    }
};

fn sortSegments(_: void, a: Segment, b: Segment) bool {
    return a.min < b.min;
}

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

fn generateSegmentsForLine(target_y: isize, sensors: ArrayList(Point), beacons: ArrayList(Point), allocator: Allocator) ArrayList(Segment) {
    var segments = ArrayList(Segment).init(allocator);
    for (sensors.items) |sensor, index| {
        const beacon = beacons.items[index];
        const beacon_distance = sensor.getOffset(beacon).manhattanDistance();
        const target_distance = std.math.absInt(target_y - sensor.y) catch unreachable;

        const wiggle_room = beacon_distance - target_distance;
        if (wiggle_room >= 0) {

            segments.append(Segment.init(sensor.x - wiggle_room, sensor.x + wiggle_room)) catch unreachable;
        }
    }
    var maximally_combined = false;
    while (!maximally_combined) {
        maximally_combined = true;
        var sorted_slice = segments.toOwnedSlice() catch unreachable;
        segments = ArrayList(Segment).init(allocator);
        std.sort.sort(Segment, sorted_slice, {}, sortSegments);
        var current_segment = sorted_slice[0];
        for (sorted_slice[1..]) |test_segment| {
            if (current_segment.combineWith(test_segment)) |combined| {
                maximally_combined = false;
                current_segment = combined;
            } else {
                segments.append(current_segment) catch unreachable;
                current_segment = test_segment;
            }
        }
        segments.append(current_segment) catch unreachable;

        allocator.free(sorted_slice);
    }


    return segments;
}

pub fn solve(filename: str, allocator: Allocator, target_y: isize, search_bound: isize) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var lines = std.mem.tokenize(u8, content, "\n");

    var sensors = ArrayList(Point).init(allocator);
    defer sensors.deinit();
    var beacons = ArrayList(Point).init(allocator);
    defer beacons.deinit();

    var beacon_set = std.AutoHashMap(Point, void).init(allocator);
    defer beacon_set.deinit();

    var unique_beacons = ArrayList(Point).init(allocator);
    defer unique_beacons.deinit();

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
        if (!beacon_set.contains(beacon)) unique_beacons.append(beacon) catch unreachable;
        beacon_set.put(beacon, {}) catch unreachable;
        min_x = std.math.min(std.math.min(sensor.x, beacon.x), min_x);
        max_x = std.math.max(std.math.max(sensor.x, beacon.x), max_x);
        min_y = std.math.min(std.math.min(sensor.y, beacon.y), min_y);
        max_y = std.math.max(std.math.max(sensor.y, beacon.y), max_y);
    }

    // Part 1 single line
    var segments = generateSegmentsForLine(target_y, sensors, beacons, allocator);
    var running_len: usize = 0;
    for (segments.items) | segment | {
        running_len += segment.len;
        // Any beacons that are in the segment need to be discounted.
        for (unique_beacons.items) |beacon| {
            if (beacon.y == target_y and segment.contains(beacon.x)) running_len -= 1;
        }
    }
    segments.deinit();

    // Part 2 search
    var search_y: isize = 0;
    const part_2: usize = while (search_y < search_bound) : (search_y += 1) {
        segments = generateSegmentsForLine(search_y, sensors, beacons, allocator);
        defer segments.deinit();
        if (segments.items.len > 1) {
            break std.math.absCast(segments.items[0].max + 1) * 4000000 + std.math.absCast(search_y);
        }
    } else 0;

    return Answer{ .part_1 = running_len, .part_2 = part_2 };
}

pub fn run(allocator: Allocator) void {
    utils.printHeader("Day 15");
    var answer = solve("day15.in", allocator, 2000000, 4000000) catch unreachable;
    answer.print();
}

test "day 15 worked examples" {
    var answer = try solve("day15.test", std.testing.allocator, 10, 20);
    std.testing.expect(answer.part_1 == 26) catch |err| {
        print("{d} is not 26\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 56000011) catch |err| {
        print("{d} is not 56000011\n", .{answer.part_2});
        return err;
    };
}
