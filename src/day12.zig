const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PriorityQueue = std.PriorityQueue;
const AutoHashMap = std.AutoHashMap;
const Answer = utils.Answer;
const print = std.debug.print;

const START_MARKER: u8 = 'S';
const SUMMIT_MARKER: u8 = 'E';
const MAXI: usize = std.math.maxInt(usize);

const Point = struct {
    row: isize,
    column: isize,
    marker: u8,

    fn canStepFrom(self: Point, other: Point) bool {
        var my_marker = switch(self.marker) {
            'S' => 'a',
            'E' => 'z',
            else => self.marker
        };
        var their_marker = switch(other.marker) {
            'S' => 'a',
            'E' => 'z',
            else => other.marker
        };
        return my_marker <= their_marker + 1;
    }
};

const Map = struct {
    points: []Point,
    allocator: Allocator,
    width: usize,
    height: usize,
    summit_index: usize,
    lowland_indices: []usize,
    start_index: usize,

    pub fn deinit(self: Map) void {
        self.allocator.free(self.points);
        self.allocator.free(self.lowland_indices);
    }

    pub fn getAtCoords(self: Map, row: isize, col: isize) Point {
        const a_row = @intCast(usize, std.math.absInt(row) catch unreachable);
        const a_col = @intCast(usize, std.math.absInt(col) catch unreachable);
        const index = a_row * self.width + a_col;
        return self.points[index];
    }

    pub fn getNorth(self: Map, point: Point) ?Point {
        return if (point.row == 0) null else self.getAtCoords(point.row - 1, point.column);
    }

    pub fn getEast(self: Map, point: Point) ?Point {
        return if (point.column == self.width - 1) null else self.getAtCoords(point.row, point.column + 1);
    }

    pub fn getSouth(self: Map, point: Point) ?Point {
        return if (point.row == self.height - 1) null else self.getAtCoords(point.row + 1, point.column);
    }

    pub fn getWest(self: Map, point: Point) ?Point {
        return if (point.column == 0) null else self.getAtCoords(point.row, point.column - 1);
    }
};

fn compareFScore(context: *AutoHashMap(Point, usize), a: Point, b: Point) std.math.Order {
    var a_f = if (context.*.get(a)) |score| score else MAXI;
    var b_f = if (context.*.get(b)) |score| score else MAXI;
    return std.math.order(a_f, b_f);
}

const AStarOpenSet = struct {
    q: PriorityQueue(Point, *AutoHashMap(Point, usize), compareFScore),
    q_map: AutoHashMap(Point, void),
    len: usize,

    fn init(map: Map, estimated_node_journey_costss: *AutoHashMap(Point, usize)) AStarOpenSet {
        return AStarOpenSet{ .q = PriorityQueue(Point, *AutoHashMap(Point, usize), compareFScore).init(map.allocator, estimated_node_journey_costss), .q_map = AutoHashMap(Point, void).init(map.allocator), .len = 0 };
    }
    fn deinit(self: *AStarOpenSet) void {
        self.q.deinit();
        self.q_map.deinit();
    }

    fn enqueue(self: *AStarOpenSet, point: Point) void {
        self.q_map.put(point, {}) catch unreachable;
        self.q.add(point) catch unreachable;
        self.len += 1;
    }
    fn pop(self: *AStarOpenSet) Point {
        var p = self.q.remove();
        _ = self.q_map.remove(p);
        self.len -= 1;
        return p;
    }
    fn contains(self: AStarOpenSet, point: Point) bool {
        return self.q_map.contains(point);
    }
};

fn doAStarIsh(map: Map, target_marker: u8) !usize {
    // Referred to as the "F score" because maths ¯\_(ツ)_/¯
    var estimated_node_journey_costs = AutoHashMap(Point, usize).init(map.allocator);
    defer estimated_node_journey_costs.deinit();
    try estimated_node_journey_costs.put(map.points[map.summit_index], 0);

    // Referred to as the "open set" normally
    var border_points_to_explore = AStarOpenSet.init(map, &estimated_node_journey_costs);
    defer border_points_to_explore.deinit();
    border_points_to_explore.enqueue(map.points[map.summit_index]);

    // Referred to as the "came_from" map
    var cheapest_path_lookback = AutoHashMap(Point, Point).init(map.allocator);
    defer cheapest_path_lookback.deinit();

    // Referred to as the "G score" because maths ¯\_(ツ)_/¯
    var confirmed_node_journey_costs = AutoHashMap(Point, usize).init(map.allocator);
    defer confirmed_node_journey_costs.deinit();
    try confirmed_node_journey_costs.put(map.points[map.summit_index], 0);

    var current_point: Point = undefined;
    var neighbours: [4]?Point = undefined;
    while (border_points_to_explore.len > 0) {
        current_point = border_points_to_explore.pop();

        if (current_point.marker == target_marker) {
            var path_length: usize = 0;
            var step: Point = current_point;
            while (cheapest_path_lookback.contains(step)) : (path_length += 1) {
                const next = cheapest_path_lookback.fetchRemove(step);
                if (next) |kv| {
                    step = kv.value;
                }
            }
            return path_length;
        }

        neighbours = .{ map.getNorth(current_point), map.getEast(current_point), map.getSouth(current_point), map.getWest(current_point) };

        for (neighbours) |possible_neighbour| {
            if (possible_neighbour == null) continue;
            const neighbour = possible_neighbour.?;

            var tentative_new_cost_to_reach_neighbour = confirmed_node_journey_costs.get(current_point).? + 1;

            // Prune impassable nodes right away
            if (!current_point.canStepFrom(neighbour)) continue;

            var existing_cost_to_reach_neighbour = confirmed_node_journey_costs.get(neighbour);
            if (existing_cost_to_reach_neighbour == null or existing_cost_to_reach_neighbour.? > tentative_new_cost_to_reach_neighbour) {
                try cheapest_path_lookback.put(neighbour, current_point);
                try confirmed_node_journey_costs.put(neighbour, tentative_new_cost_to_reach_neighbour);
                try estimated_node_journey_costs.put(neighbour, tentative_new_cost_to_reach_neighbour );
                if (!border_points_to_explore.contains(neighbour)) {
                    border_points_to_explore.enqueue(neighbour);
                }
            }
        }
    }

    // Should never get here, so just return an error.
    return error.SolveNoWorkGood;
}

fn parseMap(input: []const u8, allocator: Allocator) Map {
    var point_list = ArrayList(Point).init(allocator);
    var lowland_list = ArrayList(usize).init(allocator);
    var start_index: usize = 0;
    var height: isize = 0;
    var column: isize = 0;
    var width: isize = 0;
    var summit_index: usize = 0;
    for (input) |char| {
        if (char == '\n') {
            if (width == 0) width = column;
            height += 1;
            column = 0;
        } else {
            if (char == SUMMIT_MARKER) summit_index = point_list.items.len;
            if (char == SUMMIT_MARKER) start_index = point_list.items.len;
            if (char == START_MARKER or char == 'a') lowland_list.append(point_list.items.len) catch unreachable;
            point_list.append(Point{ .row = height, .column = column, .marker = char }) catch unreachable;
            column += 1;
        }
    }

    return Map{ .points = point_list.toOwnedSlice() catch unreachable, .allocator = allocator, .width = std.math.cast(usize, width).?, .height = std.math.cast(usize, height).?, .summit_index = summit_index, .lowland_indices = lowland_list.toOwnedSlice() catch unreachable, .start_index = start_index };
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var map = parseMap(content, allocator.*);
    defer map.deinit();
    const part_1 = try doAStarIsh(map, 'S');
    const part_2 = try doAStarIsh(map, 'a');

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 12");
    var answer = solve("day12.in", allocator) catch unreachable;
    answer.print();
}

test "day 12 worked examples" {
    var answer = try solve("day12.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 31) catch |err| {
        print("{d} is not 31\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 29) catch |err| {
        print("{d} is not 29\n", .{answer.part_2});
        return err;
    };
}

test "day 12 puzzle results" {
    // I wanted to tidy up my code and not break the puzzle
    // results so I put the right answers in a test
    var answer = try solve("day12.in", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 440) catch |err| {
        print("{d} is not 440\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 439) catch |err| {
        print("{d} is not 439\n", .{answer.part_2});
        return err;
    };
}
