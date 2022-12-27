const std = @import("std");
const utils = @import("utils.zig");

const str = []const u8;
const Allocator = std.mem.Allocator;
const Answer = utils.Answer;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const print = std.debug.print;

const Valve = struct {
    id: str,
    ind: usize = 0,
    ind_u: usize = 0,
    flow_rate: usize,
    neighbours: [][]const u8,
    allocator: Allocator,

    fn deinit(self: *Valve) void {
        self.allocator.free(self.neighbours);
    }

    pub fn format(
        self: Valve,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}({d}", .{ self.id, self.flow_rate });
        try writer.writeAll(")");
    }
};

const SHIFT_1: usize = 1;

fn parseValve(line: str, allocator: Allocator) Valve {
    var words = std.mem.tokenize(u8, line, " ");
    // "Valve"
    _ = words.next();

    const id = words.next().?;

    // "has flow"
    _ = words.next();
    _ = words.next();

    const rate_def = words.next().?;
    const eq_index = std.mem.indexOfScalar(u8, rate_def, '=').?;
    const flow_rate: usize = std.fmt.parseInt(usize, rate_def[eq_index + 1 .. rate_def.len - 1], 10) catch unreachable;

    // "tunnels lead to valves"
    _ = words.next();
    _ = words.next();
    _ = words.next();
    _ = words.next();

    var neighbour_al = ArrayList(str).init(allocator);
    while (words.next()) |neighbour| {
        neighbour_al.append(neighbour[0..2]) catch unreachable;
    }

    return Valve{ .id = id, .flow_rate = flow_rate, .neighbours = neighbour_al.toOwnedSlice() catch unreachable, .allocator = allocator };
}

const VBits = std.bit_set.IntegerBitSet(16);
const MemoKey = struct {
    tick: usize,
    ind: usize,
    vstates: u16,
};

const PuzzleContext = struct {
    distances: [][]usize,
    allocator: Allocator,
    valves: []Valve,
    uv: []Valve,
    start_valve: Valve,
    max_ticks: usize = 30,
    ticks_spent: usize = 0,
    current_benefit: usize = 0,
    valve_states: VBits,
    current_location: usize,
    memos: std.AutoHashMap(MemoKey, usize),

    fn init(valves: []Valve, allocator: Allocator) PuzzleContext {
        // Floyd Warshall approach
        var useful_valves = ArrayList(Valve).init(allocator);
        var index_map = StringHashMap(usize).init(allocator);
        defer index_map.deinit();
        var dist: [][]usize = allocator.alloc([]usize, valves.len) catch unreachable;
        for (dist) |*d_slice| {
            d_slice.* = allocator.alloc(usize, valves.len) catch unreachable;
            std.mem.set(usize, d_slice.*, valves.len);
        }

        var useful_ind: usize = 0;
        for (valves) |*valve, index| {
            valve.ind = index;
            if (valve.flow_rate > 0) {
                valve.ind_u = useful_ind;
                useful_valves.append(valve.*) catch unreachable;
                useful_ind += 1;
            }
            index_map.put(valve.id, index) catch unreachable;
        }
        const start_ind = index_map.get("AA").?;
        valves[start_ind].ind_u = useful_ind;

        // Edges
        for (valves) |valve, index| {
            dist[index][index] = 0;
            for (valve.neighbours) |neighbour_id| {
                const neighbour_ind = index_map.get(neighbour_id).?;
                dist[index][neighbour_ind] = 1;
                dist[neighbour_ind][index] = 1;
            }
        }
        for (valves) |_, K| {
            for (valves) |_, I| {
                for (valves) |_, J| {
                    if (dist[I][J] > dist[I][K] + dist[K][J]) {
                        dist[I][J] = dist[I][K] + dist[K][J];
                    }
                }
            }
        }

        const uv = useful_valves.toOwnedSlice() catch unreachable;

        // We now downselect the distance matrix to be only the useful valves
        // Plus the starting valve for the initial exploration.
        var dist_u: [][]usize = allocator.alloc([]usize, uv.len + 1) catch unreachable;

        for (dist_u) |*du_slice, uv_ind| {
            du_slice.* = allocator.alloc(usize, uv.len + 1) catch unreachable;
            const source_valve = if (uv_ind == uv.len) valves[start_ind] else uv[uv_ind];
            const source_slice = dist[source_valve.ind];
            for (du_slice.*) |*entry, index| {
                const dest_valve = if (index == uv.len) valves[start_ind] else uv[index];
                entry.* = source_slice[dest_valve.ind];
            }
        }

        for (dist) |d_slice| {
            allocator.free(d_slice);
        }
        allocator.free(dist);
        var memos = std.AutoHashMap(MemoKey, usize).init(allocator);
        return PuzzleContext{ .valves = valves, .distances = dist_u, .start_valve = valves[start_ind], .allocator = allocator, .uv = uv, .valve_states = VBits.initEmpty(), .current_location = uv.len, .memos = memos };
    }

    fn deinit(self: *PuzzleContext) void {
        for (self.distances) |d_slice| {
            self.allocator.free(d_slice);
        }
        self.allocator.free(self.distances);
        for (self.valves) |*v| {
            v.deinit();
        }
        self.allocator.free(self.valves);
        self.allocator.free(self.uv);
        self.memos.deinit();
    }

    fn getDistance(self: PuzzleContext, from: Valve, to: Valve) usize {
        return self.getDistanceInd(from.ind_u, to.ind_u);
    }

    fn getDistanceInd(self: PuzzleContext, from_i: usize, to_i: usize) usize {
        return self.distances[from_i][to_i];
    }

    fn getExpectedBenefit(self: PuzzleContext, valve_index: usize) usize {
        const distance = self.getDistanceInd(self.current_location, valve_index);
        const time_consumed = 1 + self.ticks_spent + distance;
        return if (self.max_ticks < time_consumed) 0 else (self.max_ticks - time_consumed) * self.uv[valve_index].flow_rate;
    }

    fn getRemainingValves(self: PuzzleContext) []usize {
        const len = self.uv.len - self.valve_states.count();
        var valves = self.allocator.alloc(usize, len) catch unreachable;
        var i: usize = 0;
        for (self.uv) |_, ind| {
            if (!self.valve_states.isSet(ind)) {
                valves[i] = ind;
                i += 1;
            }
        }
        return valves;
    }

    fn advanceToValve(self: *PuzzleContext, valve_index: usize) void {
        self.ticks_spent += 1 + self.getDistanceInd(self.current_location, valve_index);
        self.current_benefit += if (self.ticks_spent < self.max_ticks) (self.max_ticks - self.ticks_spent) * self.uv[valve_index].flow_rate else 0;
        self.toggleValveState(valve_index);
        self.current_location = valve_index;
    }

    fn toggleValveState(self: *PuzzleContext, valve_index: usize) void {
        self.valve_states.toggle(valve_index);
    }

    fn toggleAllValveStates(self: *PuzzleContext) void {
        self.valve_states.toggleAll();
        // Now we want to unset the Most Significant N bits, where
        // N is whatever the difference between uv.len and 16 is.
        self.valve_states.setRangeValue(.{ .start = self.uv.len, .end = 16 }, false);
    }

    fn resetValveStates(self: *PuzzleContext) void {
        self.valve_states = VBits.initEmpty();
    }

    fn lookup(self: PuzzleContext) ?usize {
        // print("LOOKING UP {[0]d}@{[1]d}:{[2]b:0>[3]}\n", .{ self.current_location, self.ticks_spent, self.valve_states.mask, self.uv.len });
        return self.memos.get(MemoKey{ .tick = self.ticks_spent, .ind = self.current_location, .vstates = self.valve_states.mask });
    }

    fn memoize(self: *PuzzleContext, benefit: usize) void {
        // print("MEMO-IZING {[0]d}@{[1]d}:{[2]b:0>[3]} as {[4]d}\n", .{ self.current_location, self.ticks_spent, self.valve_states.mask, self.uv.len, benefit });
        self.memos.put(MemoKey{ .tick = self.ticks_spent, .ind = self.current_location, .vstates = self.valve_states.mask }, benefit) catch unreachable;
    }
};

fn memoisedExplore(ctx: *PuzzleContext) usize {
    // identify remaining valves from context bitset
    var local_valves = ctx.getRemainingValves();
    defer ctx.allocator.free(local_valves);
    if (local_valves.len == 0 or ctx.ticks_spent >= ctx.max_ticks) {
        return ctx.current_benefit;
    }
    if (ctx.lookup()) |v| {
        // print("FOUND IT INNIT\n", .{});
        return ctx.current_benefit + v;
    }

    const c_time = ctx.ticks_spent;
    const c_loc = ctx.current_location;
    const c_ben = ctx.current_benefit;
    // print("{[1]s: >[0]} ARRIVED AT {[2]d}\n", .{ ctx.ticks_spent, " ", c_loc });

    var local_max: usize = ctx.current_benefit;
    for (local_valves) |next_valve| {
        // Prune any that would be pointless
        if (ctx.getExpectedBenefit(next_valve) == 0) continue;
        ctx.advanceToValve(next_valve);
        const exp = memoisedExplore(ctx);
        local_max = std.math.max(local_max, exp);
        // Reset back to current state
        ctx.toggleValveState(next_valve);
        ctx.ticks_spent = c_time;
        ctx.current_location = c_loc;
        ctx.current_benefit = c_ben;
    }
    ctx.memoize(local_max - c_ben);
    return local_max;
}

const PartitionIter = struct {
    source: []Valve,
    bucket_parts: [][]Valve,
    bucket_0: []Valve,
    bucket_1: []Valve,
    current_partition: usize = 0,
    limit: usize,
    allocator: Allocator,

    pub fn init(valves: []Valve, allocator: Allocator) PartitionIter {
        const limit = SHIFT_1 << @truncate(u6, valves.len - 1);
        var buckets = allocator.alloc([]Valve, 2) catch unreachable;
        var bucket_0 = allocator.alloc(Valve, valves.len - 1) catch unreachable;
        var bucket_1 = allocator.alloc(Valve, valves.len - 1) catch unreachable;
        return PartitionIter{ .source = valves, .limit = limit, .bucket_0 = bucket_0, .bucket_parts = buckets, .bucket_1 = bucket_1, .allocator = allocator };
    }

    pub fn next(self: *PartitionIter) ?[][]Valve {
        self.current_partition += 1;
        if (self.current_partition > self.limit) {
            self.allocator.free(self.bucket_parts);
            self.allocator.free(self.bucket_0);
            self.allocator.free(self.bucket_1);
            return null;
        }
        var ind: usize = 0;
        var where_1_ind: usize = 0;
        var where_0_ind: usize = 0;
        var part = self.current_partition;
        while (ind < self.source.len) : (ind += 1) {
            const bit = (part >> @truncate(u6, ind)) & 1;
            const v = self.source[ind];
            if (bit == 1) {
                self.bucket_1[where_1_ind] = v;
                where_1_ind += 1;
            } else {
                self.bucket_0[where_0_ind] = v;
                where_0_ind += 1;
            }
        }
        self.bucket_parts[0] = self.bucket_0[0..where_0_ind];
        self.bucket_parts[1] = self.bucket_1[0..where_1_ind];
        return self.bucket_parts;
    }
};

pub fn solve(filename: str, allocator: Allocator) !Answer {
    const content = try utils.readInputFileToBuffer(filename, allocator);
    defer allocator.free(content);
    var valves_al = ArrayList(Valve).init(allocator);
    var lines = std.mem.tokenize(u8, content, "\n");
    while (lines.next()) |line| {
        var valve = parseValve(line, allocator);
        valves_al.append(valve) catch unreachable;
    }

    var valves = valves_al.toOwnedSlice() catch unreachable;
    var ctx = PuzzleContext.init(valves, allocator);
    defer ctx.deinit();

    print("\n", .{});
    const p1_start = std.time.milliTimestamp();
    var part_1 = memoisedExplore(&ctx);
    print("P1 took: ~{d}ms\n", .{std.time.milliTimestamp() - p1_start});

    const p2_start = @intCast(usize, std.time.timestamp());
    ctx.max_ticks = 26;
    ctx.memos.clearRetainingCapacity();
    // Fill the dict
    _ = memoisedExplore(&ctx);
    var part_2: usize = 0;
    var partitions = PartitionIter.init(ctx.uv, allocator);
    var size_cutoff: usize = @divTrunc(ctx.uv.len, 3);
    var p_count: f64 = 0;
    print("\n", .{});
    while (partitions.next()) |valve_sets| {
        ctx.resetValveStates();
        p_count += 1;
        // Heuristics for a quick skip? I'm assuming the partitions where only <= 1/3rd  of
        // valves are in one side just won't cut it.
        if (valve_sets[0].len <= size_cutoff or valve_sets[1].len <= size_cutoff) continue;
        for (valve_sets[0]) |v| {
            ctx.toggleValveState(v.ind_u);
        }
        // print("BEFORE R1 {b:0>16} | {d} {d} {d}\n", .{ ctx.valve_states.mask, ctx.current_benefit, ctx.ticks_spent, ctx.current_location });
        const route_1 = memoisedExplore(&ctx);
        // print("AFTER R1 {b:0>16} | {d} {d} {d} = {d}\n", .{ ctx.valve_states.mask, ctx.current_benefit, ctx.ticks_spent, ctx.current_location, route_1 });
        ctx.toggleAllValveStates();
        // print("BEFORE R2 {b:0>16} | {d} {d} {d}\n", .{ ctx.valve_states.mask, ctx.current_benefit, ctx.ticks_spent, ctx.current_location });
        const route_2 = memoisedExplore(&ctx);
        // print("AFTER R2 {b:0>16} | {d} {d} {d} = {d} \n", .{ ctx.valve_states.mask, ctx.current_benefit, ctx.ticks_spent, ctx.current_location, route_2 });
        part_2 = std.math.max(part_2, route_1 + route_2);
    }
    print("\nP2 took ~{d}s\n", .{@intCast(usize, std.time.timestamp()) - p2_start});

    return Answer{ .part_1 = part_1, .part_2 = part_2 };
}

pub fn run(allocator: Allocator) void {
    utils.printHeader("Day 16");
    var answer = solve("day16.in", allocator) catch unreachable;
    answer.print();
}

test "day 16 worked examples" {
    var answer = try solve("day16.test", std.testing.allocator);
    std.testing.expect(answer.part_1 == 1651) catch |err| {
        print("{d} is not 1651\n", .{answer.part_1});
        return err;
    };
    std.testing.expect(answer.part_2 == 1707) catch |err| {
        print("{d} is not 1707\n", .{answer.part_2});
        return err;
    };
}
