const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Answer = utils.Answer;

const print = std.debug.print;

const SIGHTLINE_STARTER = 0;

const SightlineTracker = struct {
    up: usize = SIGHTLINE_STARTER,
    right: usize = SIGHTLINE_STARTER,
    down: usize = SIGHTLINE_STARTER,
    left: usize = SIGHTLINE_STARTER,

    fn scenicScore(self: SightlineTracker) usize {
        return self.up * self.right * self.down * self.left;
    }
};

const Grove = struct {
    trees: []u8,
    sightlines: []SightlineTracker,
    width: usize,
    height: usize,
    allocator: Allocator,

    pub fn init(content: []u8, allocator: Allocator) !Grove {
        const height: usize = std.mem.count(u8, content, "\n");
        const width: usize = std.mem.indexOfScalar(u8, content, '\n').?;

        var trees = try allocator.alloc(u8, height * width);

        var lines = std.mem.tokenize(u8, content, "\n");
        var running_len: usize = 0;
        while (lines.next()) |line| {
            std.mem.copy(u8, trees[running_len .. running_len + line.len], line);
            running_len += line.len;
        }

        var sightlines: []SightlineTracker = try allocator.alloc(SightlineTracker, height * width);
        for (sightlines) |_, index| {
            sightlines[index] = SightlineTracker{};
        }

        return Grove{ .trees = trees, .sightlines = sightlines, .width = width, .height = height, .allocator = allocator };
    }

    fn deinit(self: *Grove) void {
        self.allocator.free(self.trees);
        self.allocator.free(self.sightlines);
    }

    fn coordsToIndex(self: Grove, row: usize, col: usize) usize {
        return row * self.width + col;
    }

    fn updateSightlineDistances(distances: *[10]usize, my_height: u8) void {
        for (distances) |_, d_index| {
            // Any tree my height or lower can't see past me, any tree
            // taller can see over me
            if (d_index <= my_height) {
                distances[d_index] = 1;
            } else distances[d_index] += 1;
        }
    }

    fn calculateSightlines(self: *Grove) void {
        var row: usize = 0;
        var col: usize = 0;

        var sightline_distances: [10]usize = .{SIGHTLINE_STARTER} ** 10;

        // From left
        while (row < self.width) : (row += 1) {
            sightline_distances = .{SIGHTLINE_STARTER} ** 10;
            col = 0;
            while (col < self.height) : (col += 1) {
                const index = self.coordsToIndex(row, col);
                const my_height: u8 = self.trees[index] - 48;
                self.sightlines[index].left = sightline_distances[my_height];
                updateSightlineDistances(&sightline_distances, my_height);
            }
        }

        // From Right
        row = 0;
        while (row < self.width) : (row += 1) {
            sightline_distances = .{SIGHTLINE_STARTER} ** 10;
            col = self.width;

            while (col > 0) : (col -= 1) {
                const index = self.coordsToIndex(row, col - 1);
                const my_height: u8 = self.trees[index] - 48;
                self.sightlines[index].right = sightline_distances[my_height];
                updateSightlineDistances(&sightline_distances, my_height);
            }
        }

        // From Top
        col = 0;
        while (col < self.width) : (col += 1) {
            sightline_distances = .{SIGHTLINE_STARTER} ** 10;
            row = 0;
            while (row < self.height) : (row += 1) {
                const index = self.coordsToIndex(row, col);
                const my_height: u8 = self.trees[index] - 48;
                self.sightlines[index].up = sightline_distances[my_height];
                updateSightlineDistances(&sightline_distances, my_height);
            }
        }

        // From Bottom
        col = 0;
        while (col < self.width) : (col += 1) {
            sightline_distances = .{SIGHTLINE_STARTER} ** 10;
            row = self.height;
            while (row > 0) : (row -= 1) {
                const index = self.coordsToIndex(row - 1, col);
                const my_height: u8 = self.trees[index] - 48;
                self.sightlines[index].down = sightline_distances[my_height];
                updateSightlineDistances(&sightline_distances, my_height);
            }
        }
    }
};

pub fn solve(filename: []const u8, allocator: *const Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var grove = try Grove.init(content, allocator.*);
    defer grove.deinit();

    grove.calculateSightlines();

    var part_1: usize = 0;
    for (grove.sightlines) |heightlines, index| {
        const row: usize = @divFloor(index,grove.width);
        const col: usize = @rem(index,grove.width);
        const visible_up = heightlines.up >= row;
        const visible_left = heightlines.left >= col;
        const visible_down = heightlines.down >= (grove.height - row);
        const visible_right = heightlines.right >= (grove.width - col);
        if (visible_up or visible_down or visible_left or visible_right) part_1 += 1;
    }

    var part_2: usize = 0;
    for (grove.sightlines) |heightlines, index| {
        const row: usize = @divFloor(index,grove.width);
        const col: usize = @rem(index,grove.width);
        if (row == 0 or col == 0 or row == grove.height - 1 or col == grove.width - 1) continue;
        part_2 = std.math.max(heightlines.scenicScore(), part_2);
    }

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: *const Allocator) void {
    utils.printHeader("Day 8");
    var answer = solve("day8.in", allocator) catch unreachable;
    answer.print();
}

test "day 8 worked example" {
    var answer = try solve("day8.test", &std.testing.allocator);
    std.testing.expect(answer.part_1 == 21) catch |err| {
        print("{d} is not 21\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 8) catch |err| {
        print("{d} is not 8\n", .{answer.part_2});
        return err;
    };
}
