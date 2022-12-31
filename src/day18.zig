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
    facing: u8,

    pub fn fromStr(string: str) Cube {
        var coords = std.mem.tokenize(u8, string, ",");
        const x = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        const y = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        const z = std.fmt.parseInt(u8, coords.next().?, 10) catch unreachable;
        return Cube{ .x = x, .y = y, .z = z, .facing = 0 };
    }

    fn eql(self: *Cube, other: *Cube) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z and self.facing == other.facing;
    }

    fn eqlNoFace(self: *const Cube, other: *const Cube) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    fn cloneNoFace(self: *const Cube) Cube {
        return Cube{ .x = self.x, .y = self.y, .z = self.z, .facing = 0 };
    }

    pub fn format(
        self: Cube,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d},{d},{d}|({d})", .{ self.x, self.y, self.z, self.facing });
    }
};

const CubeSet = std.AutoHashMap(Cube, void);
const CubeFlagMap = std.AutoHashMap(Cube, bool);

const TEST_CUBE = Cube{ .x = 2, .y = 2, .z = 5, .facing = 0 };

const FaceNeighbourhoodIterator = struct {
    source: *const Cube,
    index: u8 = 0,

    fn next(self: *FaceNeighbourhoodIterator) ?Cube {
        if (self.index == 6) return null;

        var to_ret = Cube{ .x = self.source.x, .y = self.source.y, .z = self.source.z, .facing = self.source.facing };

        while (to_ret.eqlNoFace(self.source)) {
            switch (self.index) {
                0 => to_ret.x += 1,
                1 => to_ret.y += 1,
                2 => to_ret.z += 1,
                3 => {
                    if (to_ret.x >= 1) to_ret.x -= 1;
                },
                4 => {
                    if (to_ret.y >= 1) to_ret.y -= 1;
                },
                5 => {
                    if (to_ret.z >= 1) to_ret.z -= 1;
                },
                else => return null,
            }
            self.index += 1;
        }
        to_ret.facing = self.index;
        return to_ret;
    }
};

fn canEscape(cube: *const Cube, extents: Cube, solid_cubes: *const CubeSet, current: *CubeSet, memo: *CubeFlagMap) bool {
    // First: Check this cube in the memo
    if (memo.get(cube.*)) |result| {
        return result;
    }
    // Is this cube solid? In which case the answer is no.
    if (solid_cubes.contains(cube.*)) return false;

    // Does this cube have any extreme dimension? If so, it must be external
    // by default.
    if (cube.x == 0 or cube.x >= extents.x or cube.y == 0 or cube.y >= extents.y or cube.z == 0 or cube.z >= extents.z) return true;

    // This cube is not solid, and has no known result, so we need to check
    // each neighbour.
    // Add ourselves to the current set
    const c_nf = cube.cloneNoFace();
    current.put(c_nf, {}) catch unreachable;
    var f_it = FaceNeighbourhoodIterator{ .source = cube };
    const is_external = while (f_it.next()) |*f| {
        // Don't hop back and forth forever
        if (current.contains(f.cloneNoFace())) continue;
        const t = f.cloneNoFace();
        if (canEscape(&t, extents, solid_cubes, current, memo)) break true;
    } else false;

    _ = current.remove(c_nf);
    memo.put(cube.*, is_external) catch unreachable;

    return is_external;
}

fn floodFillOutside(cube: *const Cube, extents: Cube, solid_cubes: *const CubeSet, current: *CubeSet) usize {
    var impact_counter: usize = 0;
    var local_impacts: usize = 0;
    current.put(cube.*, {}) catch unreachable;
    var f_it = FaceNeighbourhoodIterator{ .source = cube };
    while (f_it.next()) |*f| {
        const t = f.cloneNoFace();
        if (current.contains(t)) {
            continue;
        }
        if (solid_cubes.contains(t)) {
            local_impacts += 1;
        } else if (f.x <= extents.x + 1 and f.y <= extents.y + 1 and f.z <= extents.z + 1) {
            impact_counter += floodFillOutside(&t, extents, solid_cubes, current);
        } else {
            continue;
        }
    }
    return impact_counter + local_impacts;
}

// Constants for logic
pub fn solve(filename: str, allocator: Allocator) !Answer {
    var content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);

    var open_cube_set = std.AutoHashMap(Cube, void).init(allocator);
    defer open_cube_set.deinit();

    var border_cube_set = std.AutoHashMap(Cube, void).init(allocator);
    defer border_cube_set.deinit();

    var extents = Cube{ .x = 0, .y = 0, .z = 0, .facing = 0 };

    var lines = std.mem.tokenize(u8, content, "\n");
    while (lines.next()) |l| {
        const c = Cube.fromStr(l);
        extents.x = std.math.max(extents.x, c.x);
        extents.y = std.math.max(extents.y, c.y);
        extents.z = std.math.max(extents.z, c.z);
        open_cube_set.put(c, {}) catch unreachable;
    }

    var cube_it = open_cube_set.keyIterator();

    var part_1: usize = 0;
    while (cube_it.next()) |c| {
        part_1 += 6;
        var f_it = FaceNeighbourhoodIterator{ .source = c };
        while (f_it.next()) |*f| {
            // We don't care about facing for part 1
            const facing_less_cube = Cube{ .x = f.x, .y = f.y, .z = f.z, .facing = 0 };
            if (open_cube_set.contains(facing_less_cube)) {
                part_1 -= 1;
            } else {
                border_cube_set.put(f.*, {}) catch unreachable;
            }
        }
    }

    // The exposed cube set is a set of every empty cube adjacent to a face of
    // an actual cube. For each of these, we walk every direction, and if any
    // walk direction has no real cube, count the face as external
    var part_2: usize = 0;
    cube_it = border_cube_set.keyIterator();

    var escape_memo = CubeFlagMap.init(allocator);
    defer escape_memo.deinit();

    var under_consideration = CubeSet.init(allocator);
    defer under_consideration.deinit();

    // var candidate_cube = while (cube_it.next()) |c| {
    //     const t = c.cloneNoFace();
    //     const can_escape = canEscape(&t, extents, &open_cube_set, &under_consideration, &escape_memo);
    //     if (can_escape) break t;
    // } else unreachable;
    const candidate_cube = Cube{ .x = 0, .y = 0, .z = 0, .facing = 0 };

    print("\n", .{});
    part_2 += floodFillOutside(&candidate_cube, extents, &open_cube_set, &under_consideration);

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
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
    std.testing.expect(answer.part_2 == 58) catch {
        print("{d} is not 58\n", .{answer.part_2});
        failed = true;
    };
    try std.testing.expect(!failed);
}
