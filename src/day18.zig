const std = @import("std");
const utils = @import("utils.zig");

const print = std.debug.print;

// Type shorthands
const str = []const u8;
const Allocator = std.mem.Allocator;
const Answer = utils.NumericAnswer(usize);

const Cube = struct {
    x: u8,
    y: u8,
    z: u8,
    size: u8,

    pub fn fromStr(string: str) Cube {
        var coords = std.mem.tokenize(u8, string, ",");
        const x = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        const y = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        const z = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        return Cube{ .x = x, .y = y, .z = z, .size = 1 };
    }

    fn eql(self: *Cube, other: *Cube) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z and self.size == other.size;
    }
};

const FaceNeighbourhoodIterator = struct {
    source: *Cube,
    index: u8 = 0,

    fn next(self: *FaceNeighbourhoodIterator) ?Cube {
        if (self.index == 6) return null;

        var to_ret = Cube{ .x = self.source.x, .y = self.source.y, .z = self.source.z, .size = self.source.size };

        while (to_ret.eql(self.source)) {
            switch (self.index) {
                0 => to_ret.x += self.source.size,
                1 => to_ret.y += self.source.size,
                2 => to_ret.z += self.source.size,
                3 => {
                    if (to_ret.x >= self.source.size) to_ret.x -= self.source.size;
                },
                4 => {
                    if (to_ret.y >= self.source.size) to_ret.y -= self.source.size;
                },
                5 => {
                    if (to_ret.z >= self.source.size) to_ret.z -= self.source.size;
                },
                else => return null,
            }
            self.index += 1;
        }
        return to_ret;
    }
};

// Constants for logic
pub fn solve(filename: str, allocator: Allocator) !Answer {
    var content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var open_cube_set = std.AutoHashMap(Cube, void).init(allocator);
    defer open_cube_set.deinit();

    var lines = std.mem.tokenize(u8, content, "\n");
    while (lines.next()) |l| {
        open_cube_set.put(Cube.fromStr(l), {}) catch unreachable;
    }

    var cube_it = open_cube_set.keyIterator();

    var part_1: usize = 0;
    while (cube_it.next()) |c| {
        part_1 += 6;
        var f_it = FaceNeighbourhoodIterator{ .source = c };
        while (f_it.next()) |f| {
            if (open_cube_set.contains(f)) part_1 -= 1;
        }
    }

    return Answer{ .part_1 = part_1, .part_2 = 0 };
}

pub fn run(allocator: Allocator) void {
    utils.printHeader("Day 18");
    var answer = solve("day18.in", allocator) catch unreachable;
    answer.print();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }
    run(allocator);
}

test "day 18 worked examples" {
    var answer = try solve("day18.test", std.testing.allocator);
    var failed = false;
    std.testing.expect(answer.part_1 == 64) catch {
        print("{d} is not 64\n", .{answer.part_1});
        failed = true;
    };
    try std.testing.expect(!failed);
}
