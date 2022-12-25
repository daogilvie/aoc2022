const std = @import("std");
const utils = @import("utils.zig");

const print = std.debug.print;

// Type shorthands
const str = []const u8;
const Allocator = std.mem.Allocator;
const Answer = utils.NumericAnswer(usize);

// Constants for logic
const CAVERN_WIDTH: usize = 7;
const MAX_CAVERN_IND: usize = CAVERN_WIDTH - 1;
const APPEARANCE_OFFSET_LEFT = 2;
const APPEARANCE_OFFSET_HEIGHT = 3;
const ROCK_LIMIT = 2022;
const ROCK_LIMIT_2 = 1000000000000;

const MinoType = enum { Wide, Plus, Glider, Tall, Square };

const GasDirection = enum { Left, Right };

const GasState = struct {
    direction: GasDirection,
    content: str,
    index: usize = 0,

    fn init(content: str) GasState {
        var s = GasState{ .direction = GasDirection.Left, .content = content, .index = content.len - 1 };
        return s;
    }

    fn tick(self: *GasState) GasDirection {
        self.index += 1;
        if (self.index == self.content.len) self.index = 0;
        self.direction = switch (self.content[self.index]) {
            '>' => GasDirection.Right,
            '<' => GasDirection.Left,
            else => {
                print("OH NO {d}/{d} = {c}\n", .{ self.index, self.content.len, self.content[self.index] });
                @panic("OH NO");
            },
        };
        return self.direction;
    }
};

const Rock = struct {
    t: MinoType,
    bottom: usize = 0,
    left: usize = APPEARANCE_OFFSET_LEFT,
    right: usize = 0,
    fn shiftSimple(self: *Rock, dir: GasDirection) void {
        if (dir == GasDirection.Right and self.right < MAX_CAVERN_IND) {
            self.left += 1;
            self.right += 1;
        } else if (dir == GasDirection.Left and self.left > 0) {
            self.left -= 1;
            self.right -= 1;
        }
    }
    pub fn format(
        self: Rock,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        if (std.mem.eql(u8, "space", fmt)) {
            try writer.print("    {d}|", .{@enumToInt(self.t)});
            var i: usize = 0;
            while (i <= MAX_CAVERN_IND) : (i += 1) {
                if (i >= self.left and i <= self.right)
                    try writer.print("@", .{})
                else
                    try writer.print(".", .{});
            }

            try writer.print("|", .{});
        } else {
            try writer.print("R({s},l={d},r={d},b={d})", .{ @tagName(self.t), self.left, self.right, self.bottom });
        }
    }
};

const RockSpawner = struct {
    order: [5]MinoType = .{ MinoType.Wide, MinoType.Plus, MinoType.Glider, MinoType.Tall, MinoType.Square },
    index: usize = 0,

    fn spawnRock(self: *RockSpawner, bottom_offset: usize) Rock {
        const t = self.order[self.index];
        self.index += 1;
        if (self.index == 5) self.index = 0;
        var bottom: usize = bottom_offset;
        var right: usize = APPEARANCE_OFFSET_LEFT;
        switch (t) {
            .Wide => {
                right += 3;
            },
            .Plus, .Glider => {
                right += 2;
            },
            .Square => {
                right += 1;
            },
            else => {},
        }
        return Rock{ .t = t, .bottom = bottom, .right = right };
    }
};

const FloorBits = std.bit_set.IntegerBitSet(CAVERN_WIDTH);

const Cavern = struct {
    floors: std.ArrayList(FloorBits),
    spawner: RockSpawner,

    pub fn format(
        self: Cavern,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        var i: usize = 1;
        while (i < self.floors.items.len) : (i += 1) {
            const t_i = self.floors.items.len - i;
            const f = self.getFloorAt(t_i);
            var f_i: usize = 0;
            try writer.print("\n{d: >5}|", .{t_i});
            while (f_i <= MAX_CAVERN_IND) : (f_i += 1) {
                var char: u8 = '.';
                if (f.isSet(f_i)) {
                    char = '#';
                }
                try writer.print("{c}", .{char});
            }
            try writer.print("|", .{});
        }
        try writer.print("\n     |-------|\n", .{});
    }

    fn init(allocator: Allocator) Cavern {
        var floors = std.ArrayList(FloorBits).init(allocator);
        floors.append(FloorBits.initFull()) catch unreachable;
        return Cavern{ .floors = floors, .spawner = RockSpawner{} };
    }

    fn deinit(self: *Cavern) void {
        self.floors.deinit();
    }

    fn spawnRock(self: *Cavern) Rock {
        return self.spawner.spawnRock(self.floors.items.len + APPEARANCE_OFFSET_HEIGHT);
    }

    fn getFloorAt(self: Cavern, floor_height: usize) FloorBits {
        if (floor_height < self.floors.items.len)
            return self.floors.items[floor_height];
        return FloorBits.initEmpty();
    }

    fn setFloorAt(self: *Cavern, floor_height: usize, floor: FloorBits) void {
        if (floor_height < self.floors.items.len) {
            self.floors.items[floor_height] = floor;
        } else if (floor_height == self.floors.items.len) {
            self.floors.append(floor) catch unreachable;
        } else {
            @panic("Don't think we should be skipping floors?!?");
        }
    }

    fn canFall(self: Cavern, rock: Rock) bool {
        if (rock.bottom == 1) return false;
        const immediate_floor = self.getFloorAt(rock.bottom - 1);
        return switch (rock.t) {
            .Wide, .Glider, .Square, .Tall => checkfloor: {
                var i = rock.left;
                while (i <= rock.right) : (i += 1) {
                    if (immediate_floor.isSet(i)) break :checkfloor false;
                } else break :checkfloor true;
            },
            .Plus => checkfloor: {
                var level_floor = self.getFloorAt(rock.bottom);
                break :checkfloor !(immediate_floor.isSet(rock.left + 1) or level_floor.isSet(rock.left) or level_floor.isSet(rock.right));
            },
        };
    }

    fn shiftRockLeft(self: Cavern, rock: *Rock) void {
        if (rock.left == 0) return;
        const f = self.getFloorAt(rock.bottom);
        switch (rock.t) {
            .Wide, .Glider => {
                if (f.isSet(rock.left - 1)) return;
            },
            .Plus => {
                if (f.isSet(rock.left)) return;
                const f_m = self.getFloorAt(rock.bottom + 1);
                if (f_m.isSet(rock.left - 1)) return;
                const f_t = self.getFloorAt(rock.bottom + 2);
                if (f_t.isSet(rock.left)) return;
            },
            .Tall => {
                const t = rock.left - 1;
                if (f.isSet(t)) return;
                var f_num: usize = rock.bottom + 3;
                while (f_num > rock.bottom) : (f_num -= 1) {
                    var f_l = self.getFloorAt(f_num);
                    if (f_l.isSet(t)) return;
                }
            },
            .Square => {
                if (f.isSet(rock.left - 1)) return;
                const f_t = self.getFloorAt(rock.bottom + 1);
                if (f_t.isSet(rock.left - 1)) return;
            },
        }
        rock.left -= 1;
        rock.right -= 1;
    }

    fn shiftRockRight(self: Cavern, rock: *Rock) void {
        if (rock.right == MAX_CAVERN_IND) return;
        const f = self.getFloorAt(rock.bottom);
        switch (rock.t) {
            .Wide => {
                if (f.isSet(rock.right + 1)) return;
            },
            .Glider => {
                const t = rock.right + 1;
                if (f.isSet(t)) return;
                var f_num: usize = rock.bottom + 2;
                while (f_num > rock.bottom) : (f_num -= 1) {
                    var f_l = self.getFloorAt(f_num);
                    if (f_l.isSet(t)) return;
                }
            },
            .Plus => {
                if (f.isSet(rock.right)) return;
                const f_m = self.getFloorAt(rock.bottom + 1);
                if (f_m.isSet(rock.right + 1)) return;
                const f_t = self.getFloorAt(rock.bottom + 2);
                if (f_t.isSet(rock.right)) return;
            },
            .Tall => {
                const t = rock.right + 1;
                if (f.isSet(t)) return;
                var f_num: usize = rock.bottom + 3;
                while (f_num > rock.bottom) : (f_num -= 1) {
                    var f_l = self.getFloorAt(f_num);
                    if (f_l.isSet(t)) return;
                }
            },
            .Square => {
                if (f.isSet(rock.right + 1)) return;
                const f_t = self.getFloorAt(rock.bottom + 1);
                if (f_t.isSet(rock.right + 1)) return;
            },
        }
        rock.left += 1;
        rock.right += 1;
    }
    fn solidifyIntoFloor(self: *Cavern, rock: Rock) void {
        // Settle rock into position
        switch (rock.t) {
            .Wide => {
                var f = self.getFloorAt(rock.bottom);
                f.setRangeValue(.{ .start = rock.left, .end = rock.right + 1 }, true);
                self.setFloorAt(rock.bottom, f);
            },
            .Plus => {
                var f_b = self.getFloorAt(rock.bottom);
                f_b.set(rock.left + 1);
                self.setFloorAt(rock.bottom, f_b);
                var f = self.getFloorAt(rock.bottom + 1);
                f.setRangeValue(.{ .start = rock.left, .end = rock.right + 1 }, true);
                self.setFloorAt(rock.bottom + 1, f);
                var f_t = self.getFloorAt(rock.bottom + 2);
                f_t.set(rock.left + 1);
                self.setFloorAt(rock.bottom + 2, f_t);
            },
            .Glider => {
                var f_b = self.getFloorAt(rock.bottom);
                f_b.setRangeValue(.{ .start = rock.left, .end = rock.right + 1 }, true);
                self.setFloorAt(rock.bottom, f_b);
                var f = self.getFloorAt(rock.bottom + 1);
                f.set(rock.right);
                self.setFloorAt(rock.bottom + 1, f);
                var f_t = self.getFloorAt(rock.bottom + 2);
                f_t.set(rock.right);
                self.setFloorAt(rock.bottom + 2, f_t);
            },
            .Tall => {
                var i: usize = rock.bottom;
                while (i <= rock.bottom + 3) : (i += 1) {
                    var f = self.getFloorAt(i);
                    f.set(rock.left);
                    self.setFloorAt(i, f);
                }
            },
            .Square => {
                var f_b = self.getFloorAt(rock.bottom);
                f_b.setRangeValue(.{ .start = rock.left, .end = rock.right + 1 }, true);
                self.setFloorAt(rock.bottom, f_b);
                var f_t = self.getFloorAt(rock.bottom + 1);
                f_t.setRangeValue(.{ .start = rock.left, .end = rock.right + 1 }, true);
                self.setFloorAt(rock.bottom + 1, f_t);
            },
        }
    }

    fn simulateSmart(self: *Cavern, rock_limit: usize, gas_pattern: str, node: *std.Progress.Node) usize {
        var gas = GasState.init(gas_pattern);

        var rock: Rock = self.spawnRock();

        var rock_count: usize = 0;
        var tick_count: usize = 0;

        var lcm_period = 5 * gas.content.len;
        var last_period_height: usize = 0;
        var last_period_height_delta: usize = 0;
        var last_period_rocks: usize = 0;
        var last_period_rocks_delta: usize = 0;
        var offset: usize = 0;
        var discount: usize = 0;

        print("SIM {d} ROCKS!\n", .{rock_limit});

        while (rock_count <= rock_limit) : (tick_count += 1) {
            if (tick_count > 0 and @rem(tick_count, lcm_period) == 0) {
                discount += 1;
                const current_delta = self.floors.items.len - last_period_height;
                const current_rocks_delta = rock_count - last_period_rocks;
                print("\nLCM :>\nDelta {d} vs {d}\nRocks  {d} vs {d}\n", .{ current_delta, last_period_height_delta, current_rocks_delta, last_period_rocks_delta });
                // Are they the same?
                if (current_delta == last_period_height_delta and current_rocks_delta == last_period_rocks_delta) {
                    // Use rocks per period to figure out how many more periods would be needed
                    const rocks_remainining: usize = rock_limit - rock_count;
                    print("     Rock Count:{d}, remaining {d}\n", .{ rock_count, rocks_remainining });
                    const periods_floor: usize = rocks_remainining / current_rocks_delta;
                    print("     Periods to go:{d}, current_height = {d}\n", .{ periods_floor, self.floors.items.len });
                    // Fast-forward to the last few rocks
                    rock_count += current_rocks_delta * periods_floor;
                    offset = current_delta * periods_floor;
                    print("     Rocks now:{d}, offset= {d}\n", .{ rock_count, offset });
                }
                last_period_height_delta = current_delta;
                last_period_rocks_delta = current_rocks_delta;
                last_period_height = self.floors.items.len;
                last_period_rocks = rock_count;
            }
            switch (gas.tick()) {
                .Left => self.shiftRockLeft(&rock),
                .Right => self.shiftRockRight(&rock),
            }
            if (self.canFall(rock)) {
                rock.bottom -= 1;
            } else {
                self.solidifyIntoFloor(rock);
                rock_count += 1;
                rock = self.spawnRock();
                node.completeOne();
            }
        }

        return self.floors.items.len - discount + offset;
    }
};

pub fn solve(filename: str, allocator: Allocator) !Answer {
    var content = try utils.readInputFileToBuffer(filename, allocator);
    var trimmed = std.mem.trimRight(u8, content, &std.ascii.whitespace);
    defer allocator.free(content);

    var cavern = Cavern.init(allocator);
    defer cavern.deinit();

    var cavern_2 = Cavern.init(allocator);
    defer cavern_2.deinit();

    var root_progress = std.Progress{};
    var p1_node = root_progress.start("Part 1 rocks", ROCK_LIMIT);
    var part_1 = cavern.simulateSmart(ROCK_LIMIT, trimmed, p1_node);
    p1_node.end();

    var p2_node = root_progress.start("Part 2 rocks", ROCK_LIMIT_2);
    var part_2: usize = cavern_2.simulateSmart(ROCK_LIMIT_2, trimmed, p2_node);
    p2_node.end();

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }
    utils.printHeader("Day 17");
    var answer = solve("day17.in", allocator) catch unreachable;
    answer.print();
}

test "day 17 worked examples" {
    var answer = try solve("day17.test", std.testing.allocator);
    var failed = false;
    std.testing.expect(answer.part_1 == 3068) catch {
        print("{d} is not 3068\n", .{answer.part_1});
        failed = true;
    };
    std.testing.expect(answer.part_2 == 1514285714288) catch {
        print("{d} is not 1514285714288\n", .{answer.part_2});
        failed = true;
    };
    try std.testing.expect(!failed);
}

test "plus shifter bottom left" {
    var cav = Cavern.init(std.testing.allocator);
    defer cav.deinit();
    var ledge = FloorBits.initEmpty();
    ledge.set(0);
    ledge.set(1);
    cav.setFloorAt(1, ledge);
    var r = Rock{ .t = MinoType.Plus, .left = 1, .bottom = 1, .right = 3 };
    cav.shiftRockLeft(&r);
    try std.testing.expect(r.left == 1);
}

test "plus shifter bottom right" {
    var cav = Cavern.init(std.testing.allocator);
    defer cav.deinit();
    var ledge = FloorBits.initEmpty();
    ledge.set(3);
    cav.setFloorAt(1, ledge);
    var r = Rock{ .t = MinoType.Plus, .left = 1, .bottom = 1, .right = 3 };
    cav.shiftRockRight(&r);
    try std.testing.expect(r.left == 1);
}

test "plus shifter top left" {
    var cav = Cavern.init(std.testing.allocator);
    defer cav.deinit();
    var ledge = FloorBits.initEmpty();
    ledge.set(0);
    ledge.set(1);
    cav.setFloorAt(1, cav.getFloorAt(1));
    cav.setFloorAt(2, cav.getFloorAt(2));
    cav.setFloorAt(3, ledge);
    var r = Rock{ .t = MinoType.Plus, .left = 1, .bottom = 1, .right = 3 };
    cav.shiftRockLeft(&r);
    try std.testing.expect(r.left == 1);
}

test "plus shifter top right" {
    var cav = Cavern.init(std.testing.allocator);
    defer cav.deinit();
    var ledge = FloorBits.initEmpty();
    ledge.set(3);
    cav.setFloorAt(1, cav.getFloorAt(1));
    cav.setFloorAt(2, cav.getFloorAt(2));
    cav.setFloorAt(3, ledge);
    var r = Rock{ .t = MinoType.Plus, .left = 1, .bottom = 1, .right = 3 };
    cav.shiftRockRight(&r);
    try std.testing.expect(r.left == 1);
}

test "plus can fall" {
    var cav = Cavern.init(std.testing.allocator);
    defer cav.deinit();
    var ledge = FloorBits.initEmpty();
    ledge.set(3);
    cav.setFloorAt(1, ledge);
    cav.setFloorAt(2, ledge);
    var r = Rock{ .t = MinoType.Plus, .left = 3, .bottom = 2, .right = 5 };
    try std.testing.expect(cav.canFall(r) == false);
    r.left -= 2;
    r.right -= 2;
    try std.testing.expect(cav.canFall(r) == false);
    r.left += 1;
    r.right += 1;
    r.bottom += 1;
    try std.testing.expect(cav.canFall(r) == false);
}
