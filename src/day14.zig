const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;
const print = std.debug.print;

const SAND_SOURCE_COLUMN: usize = 500;

const Offset = struct {
    x: usize,
    y: usize,
};

const Point = struct {
    x: usize,
    y: usize,

    fn fromStr(input: str) Point {
        var parts = std.mem.split(u8, input, ",");
        const x = std.fmt.parseInt(usize, parts.next().?, 10) catch unreachable;
        const y = std.fmt.parseInt(usize, parts.next().?, 10) catch unreachable;
        return Point{ .x = x, .y = y };
    }

    fn getOffset(self: Point, other: Point) Offset {
        return Offset{
            .x = std.math.cast(usize, other.x).? - std.math.cast(usize, self.x).?,
            .y = std.math.cast(usize, other.y).? - std.math.cast(usize, self.y).?,
        };
    }

    fn stepTowards(self: *Point, other: Point) void {
        if (self.x < other.x) self.x += 1 else if (self.x > other.x) self.x -= 1;
        if (self.y < other.y) self.y += 1 else if (self.y > other.y) self.y -= 1;
    }

    fn equals(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Kind = enum(u8) { Air = '.', Rock = '#', Sand = 'O', Void = ' ', Spawn = '+', PreviousSand = 'S', SandPath = '~' };

const Grid = struct {
    cells: []Kind,
    allocator: Allocator,
    top_left: Point,
    width: usize,
    height: usize,
    grain_counter: usize = 0,

    fn init(top_left: Point, bottom_right: Point, allocator: Allocator) Grid {
        const width = bottom_right.x - top_left.x + 1;
        const height = bottom_right.y + 3;
        var cells = allocator.alloc(Kind, width * height) catch unreachable;
        std.mem.set(Kind, cells, Kind.Air);
        cells[500 - top_left.x] = Kind.Spawn;


        return Grid{ .cells = cells, .allocator = allocator, .top_left = top_left, .width = width, .height = height};
    }

    fn deinit(self: *Grid) void {
        self.allocator.free(self.cells);
    }

    fn setKind(self: *Grid, point: Point, kind: Kind) void {
        const offset = self.top_left.getOffset(point);
        const index: usize = (offset.y) * self.width + offset.x;
        self.cells[index] = kind;
    }

    fn addFloor(self: *Grid) void {
        std.mem.set(Kind, self.cells[self.cells.len-self.width..], Kind.Rock);
    }

    fn getKind(self: Grid, point: Point) Kind {
        if (point.x < self.top_left.x or point.x >= self.top_left.x + self.width) return Kind.Void;
        const offset = self.top_left.getOffset(point);
        const index: usize = (offset.y) * self.width + offset.x;
        return self.cells[index];
    }

    fn addRocks(self: *Grid, rock_lines: ArrayList([]Point)) void {
        for (rock_lines.items) |*rock_line| {
            var previous_rock: Point = rock_line.*[0];
            self.setKind(previous_rock, Kind.Rock);
            for (rock_line.*[1..]) |rock_point| {
                // Loop between previous and current
                var tmp_point: Point = previous_rock;
                while (!tmp_point.equals(rock_point)) {
                    tmp_point.stepTowards(rock_point);
                    self.setKind(tmp_point, Kind.Rock);
                }
                previous_rock = rock_point;
            }
        }
    }

    fn printGrid(self: Grid, highlight: ?Point) void {
        print("\n", .{});
        var running_index: usize = 0;
        var local_bytes: []u8 = self.allocator.alloc(u8, self.width) catch unreachable;
        var highlight_index: ?usize = null;
        if (highlight) |point| {
            const offset = self.top_left.getOffset(point);
            highlight_index = (offset.y) * self.width + offset.x;
        }
        defer self.allocator.free(local_bytes);
        var row: usize = 0;
        while (running_index < self.cells.len) : (running_index += self.width) {
            for (self.cells[running_index .. running_index + self.width]) |cell, index| {
                local_bytes[index] = @enumToInt(cell);
            }
            if (highlight_index) |ind| {
                if (ind > running_index and ind < running_index + self.width) {
                    local_bytes[ind - running_index] = 'X';
                }
            }
            print("{d: >4} {s}\n", .{row, local_bytes});
            row += 1;
        }
    }

    fn injectSand(self: *Grid, part_2_mode: bool) ?Point {
        // Part 2 mode assumes infinite floor.
        // Rather than doing that, or just having a huge grid,
        // I think any time a sand would fall into void, we simply place
        // the sand where it _currently_ is, and add to the grid a number
        // of grains that _would_ have fallen in to this place before
        // blocking it.
        // Would require enough grains to fill a diagonal that starts at this
        // cell. Assuming this has already happened for any below diagonal,
        // this just means incrementing the grain counter by however many
        // grains long this diagonal would be, which we can figure out from
        // the height.
        var sand_point = Point{ .x = 500, .y = 0 };
        var tmp_point = Point{ .x = 500, .y = 0 };
        while (tmp_point.equals(sand_point)) {
            self.setKind(sand_point, Kind.SandPath);
            tmp_point.y += 1;
            switch (self.getKind(tmp_point)) {
                .Air => {
                    sand_point.stepTowards(tmp_point);
                    continue;
                },
                .Void => {
                    return null;
                    },
                else => {},
            }
            tmp_point.x -= 1;
            switch (self.getKind(tmp_point)) {
                .Air => {
                    sand_point.stepTowards(tmp_point);
                    continue;
                },
                .Void => {
                    if (!part_2_mode) return null;
                    self.grain_counter += self.height - 2 - sand_point.y;
                    continue;
                    },
                else => {},
            }
            tmp_point.x += 2;
            switch (self.getKind(tmp_point)) {
                .Air => {
                    sand_point.stepTowards(tmp_point);
                    continue;
                },
                .Void => {
                    if (!part_2_mode) return null;
                    // Would require enough grains to fill bottom left
                    // cell. Assuming this has already happened for below
                    // diagonal, this means adding a diagonal line of grains.
                    self.grain_counter += self.height - 2 - sand_point.y;
                    continue;
                    },
                else => {},
            }
            if (sand_point.y == 0) {
              // We're stuck at root, this is the base case!
              self.grain_counter += 1;
              return null;
            }
        }
        self.setKind(sand_point, Kind.PreviousSand);
        self.grain_counter += 1;
        return sand_point;
    }
};

pub fn solve(filename: str, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var lines = std.mem.tokenize(u8, content, "\n");

    var lines_list = ArrayList([]Point).init(allocator.*);
    defer {
        for (lines_list.items) |point_slice| {
            allocator.*.free(point_slice);
        }
        lines_list.deinit();
    }

    var min_x: usize = std.math.maxInt(usize);
    var min_y: usize = std.math.maxInt(usize);
    var max_x: usize = 0;
    var max_y: usize = 0;

    while (lines.next()) |rock_path_definition| {
        var point_list = ArrayList(Point).init(allocator.*);
        var point_defs = std.mem.split(u8, rock_path_definition, " -> ");
        while (point_defs.next()) |point_def| {
            const point = Point.fromStr(point_def);
            min_x = std.math.min(min_x, point.x);
            min_y = std.math.min(min_y, point.y);
            max_x = std.math.max(max_x, point.x);
            max_y = std.math.max(max_y, point.y);
            point_list.append(point) catch unreachable;
        }
        lines_list.append(point_list.toOwnedSlice() catch unreachable) catch unreachable;
    }

    var grid = Grid.init(Point{ .x = min_x, .y = 0 }, Point{ .x = max_x, .y = max_y }, allocator.*);
    grid.addRocks(lines_list);

    var sand_destination: ?Point = Point{ .x = SAND_SOURCE_COLUMN, .y = 0 };
    var previous_sand: ?Point = null;
    while (sand_destination != null) {
        sand_destination = grid.injectSand(false);
        if (sand_destination) |point| {
            if (previous_sand) | prev | {
                grid.setKind(prev, Kind.Sand);
            }
            previous_sand = point;
        }
        // Unset sand path for next print run
        for (grid.cells) |kind, index| {
            if (kind == Kind.SandPath) {
                grid.cells[index] = Kind.Air;
            }
        }
    }
    var part_1 = grid.grain_counter;

    // Reset the grid for part 2:
    // In this part, the 'inifinite' floor is a little lower than our lowest
    // rocks, but to save on any complicated maths I actually just made the grid
    // a little bigger; the idea is that adding a 2 cell gap either side is enough
    // to capture the fiddly little "inside-facing" diagonals at the bottom corners,
    // where it would be a pain to have a heuristic for them.
    // Once we're clear of those fiddly bits though, we can easily estimate sand grains
    // required when hitting the "edge" of the grid, so there is no need to expand
    // the simulation any further even though the space is now unbounded.
    grid.deinit();
    grid = Grid.init(Point{ .x = min_x-2, .y = 0 }, Point{ .x = max_x+2, .y = max_y }, allocator.*);
    grid.addFloor();
    defer grid.deinit();
    grid.addRocks(lines_list);
    grid.grain_counter = 0;
    sand_destination = Point{ .x = SAND_SOURCE_COLUMN, .y = 0 };
    previous_sand = null;
    while (sand_destination != null) {
        sand_destination = grid.injectSand(true);
        if (sand_destination) |point| {
            if (previous_sand) | prev | {
                grid.setKind(prev, Kind.Sand);
            }
            previous_sand = point;
        }
        // Unset sand path for next print run
        for (grid.cells) |kind, index| {
            if (kind == Kind.SandPath) {
                grid.cells[index] = Kind.Air;
            }
        }
    }

    return Answer{ .part_1 = part_1, .part_2 = grid.grain_counter };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 14");
    var answer = solve("day14.in", allocator) catch unreachable;
    answer.print();
}

test "day 14 worked examples" {
    var answer = try solve("day14.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 24) catch |err| {
        print("{d} is not 24\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 93) catch |err| {
        print("{d} is not 93\n", .{answer.part_2});
        return err;
    };
}
