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
const END_MARKER: u8 = 'E';
const MAXI: usize = std.math.maxInt(usize);

const Point = struct {
    row: isize,
    column: isize,
    marker: u8,

    fn printPoint(self: Point) void {
        print("{c}@[{d},{d}]", .{ self.marker, self.row, self.column });
    }

    fn getMarkerDiff(self: Point, other: Point) usize {
        var diff: usize = 10000;
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
        return if (their_marker <= my_marker + 1) 1 else diff;
    }
};

const Map = struct {
    points: []Point,
    allocator: Allocator,
    width: usize,
    height: usize,
    start_index: usize,
    goal_index: usize,

    pub fn deinit(self: Map) void {
        self.allocator.free(self.points);
    }

    pub fn goalHeuristic(self: Map, point: Point) usize {
        const goal_point = self.points[self.goal_index];
        const h_dist = @intCast(usize, std.math.absInt(goal_point.column - point.column) catch unreachable);
        const v_dist = @intCast(usize, std.math.absInt(goal_point.row - point.row) catch unreachable);
        return h_dist + v_dist;
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

    fn init(map: Map, f_scores: *AutoHashMap(Point, usize)) AStarOpenSet {
        return AStarOpenSet{ .q = PriorityQueue(Point, *AutoHashMap(Point, usize), compareFScore).init(map.allocator, f_scores), .q_map = AutoHashMap(Point, void).init(map.allocator), .len = 0 };
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

const NEIGHBOUR_DIRS: [4][]const u8 = .{ "NORTH", "EAST", "SOUTH", "WEST" };

fn doAStar(map: Map) !usize {
    var f_score = AutoHashMap(Point, usize).init(map.allocator);
    defer f_score.deinit();

    var open_set = AStarOpenSet.init(map, &f_score);
    defer open_set.deinit();
    // The set of discovered nodes that may need to be (re-)expanded.
    // Initially, only the start node is known.
    // This is usually implemented as a min-heap or priority queue rather than a hash-set.
    open_set.enqueue(map.points[map.start_index]);

    // For node n, cameFrom[n] is the node immediately preceding it on the cheapest path from start
    // to n currently known.
    //cameFrom := an empty map
    var came_from = AutoHashMap(Point, Point).init(map.allocator);
    defer came_from.deinit();

    // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
    var g_score = AutoHashMap(Point, usize).init(map.allocator);
    defer g_score.deinit();
    try g_score.put(map.points[map.start_index], 0);

    // For node n, fScore[n] := gScore[n] + h(n). fScore[n] represents our current best guess as to
    // how cheap a path could be from start to finish if it goes through n.
    //fScore := map with default value of Infinity
    try f_score.put(map.points[map.start_index], 0);

    var current: Point = undefined;
    var neighbours: [4]?Point = undefined;
    //while openSet is not empty
    while (open_set.len > 0) {
        // This operation can occur in O(Log(N)) time if openSet is a min-heap or a priority queue
        // current := the node in openSet having the lowest fScore[] value
        current = open_set.pop();
        // print("CURRENT ", .{});
        // current.printPoint();
        // print("\n", .{});

        // if current = goal
        //     return reconstruct_path(cameFrom, current)
        if (current.marker == END_MARKER) {
            var path_length: usize = 0;
            var step: Point = current;
            // print("PATH!\n", .{});
            while (came_from.contains(step)) : (path_length += 1) {
                const next = came_from.fetchRemove(step);
                if (next) |kv| {
                    step = kv.value;
                    // print("  ", .{});
                    // step.printPoint();
                    // print("\n", .{});
                }
            }
            return path_length;
        }

        // for each neighbor of current
        neighbours = .{ map.getNorth(current), map.getEast(current), map.getSouth(current), map.getWest(current) };

        for (neighbours) |possible_neighbour| {
            if (possible_neighbour == null) continue;
            const neighbour = possible_neighbour.?;

            // d(current,neighbor) is the weight of the edge from current to neighbor
            // tentative_gScore is the distance from start to the neighbor through current
            // tentative_gScore := gScore[current] + d(current, neighbor)
            var tentative_g = g_score.get(current).?;
            // Start out with a high diff to discourage paths
            const diff: usize = current.getMarkerDiff(neighbour);
            tentative_g += diff;
            var neighbour_g = g_score.get(neighbour);
            // print("    {s} ", .{NEIGHBOUR_DIRS[n_index]});
            // neighbour.printPoint();
            // print(" G: {?} vs {d} ({d})\n", .{ neighbour_g, tentative_g, diff});
            // if tentative_gScore < gScore[neighbor]
            //     // This path to neighbor is better than any previous one. Record it!
            //     cameFrom[neighbor] := current
            //     gScore[neighbor] := tentative_gScore
            //     fScore[neighbor] := tentative_gScore + h(neighbor)
            //     if neighbor not in openSet
            //         openSet.add(neighbor)
            if (neighbour_g == null or neighbour_g.? > tentative_g) {
                // print("        BETTER '{c}': {?} vs {d}, F={d}\n", .{ neighbour.marker, neighbour_g, tentative_g, tentative_g + map.goalHeuristic(neighbour) });
                try came_from.put(neighbour, current);
                try g_score.put(neighbour, tentative_g);
                try f_score.put(neighbour, tentative_g + map.goalHeuristic(neighbour));
                if (!open_set.contains(neighbour)) {
                    // print("          ENQUEUE!\n", .{});
                    open_set.enqueue(neighbour);
                }
            }
        }
    }

    // Open set is empty but goal was never reached
    // return failure
    return error.SolveNoWorkGood;
}

fn parseMap(input: []const u8, allocator: Allocator) Map {
    var point_list = ArrayList(Point).init(allocator);
    var height: isize = 0;
    var column: isize = 0;
    var width: isize = 0;
    var start_index: usize = 0;
    var goal_index: usize = 0;
    for (input) |char| {
        if (char == '\n') {
            if (width == 0) width = column;
            height += 1;
            column = 0;
        } else {
            if (char == START_MARKER) start_index = point_list.items.len else if (char == END_MARKER) goal_index = point_list.items.len;
            point_list.append(Point{ .row = height, .column = column, .marker = char }) catch unreachable;
            column += 1;
        }
    }

    return Map{ .points = point_list.toOwnedSlice() catch unreachable, .allocator = allocator, .width = std.math.cast(usize, width).?, .height = std.math.cast(usize, height).?, .start_index = start_index, .goal_index = goal_index };
}

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var map = parseMap(content, allocator.*);
    defer map.deinit();
    // print("\n\n{s}\n\n", .{content});
    const part_1 = try doAStar(map);
    const part_2 = 0;

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
}
