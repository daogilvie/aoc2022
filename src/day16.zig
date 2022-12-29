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
const MemoKey = packed struct(u32) {
    tick: u8,
    ind: u8,
    vstates: u16,
};

const PuzzleContext = struct {
    distances: [][]u8,
    allocator: Allocator,
    valves: []Valve,
    uv: []usize,
    start_valve: Valve,
    max_ticks: u8 = 30,
    ticks_spent: u8 = 0,
    current_benefit: usize = 0,
    valve_states: VBits,
    current_location: u8,
    memos: std.AutoHashMap(MemoKey, usize),

    fn init(valves: []Valve, allocator: Allocator) PuzzleContext {
        // Floyd Warshall approach
        var useful_valves = ArrayList(Valve).init(allocator);
        var index_map = StringHashMap(usize).init(allocator);
        defer index_map.deinit();
        var dist: [][]u8 = allocator.alloc([]u8, valves.len) catch unreachable;
        for (dist) |*d_slice| {
            d_slice.* = allocator.alloc(u8, valves.len) catch unreachable;
            std.mem.set(u8, d_slice.*, @truncate(u8, valves.len));
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

        // We now downselect the distance matrix to be only the useful valves
        // Plus the starting valve for the initial exploration.
        var dist_u: [][]u8 = allocator.alloc([]u8, useful_valves.items.len + 1) catch unreachable;

        for (dist_u) |*du_slice, uv_ind| {
            du_slice.* = allocator.alloc(u8, useful_valves.items.len + 1) catch unreachable;
            const source_valve = if (uv_ind == useful_valves.items.len) valves[start_ind] else useful_valves.items[uv_ind];
            const source_slice = dist[source_valve.ind];
            for (du_slice.*) |*entry, index| {
                const dest_valve = if (index == useful_valves.items.len) valves[start_ind] else useful_valves.items[index];
                entry.* = source_slice[dest_valve.ind];
            }
        }
        const uv = allocator.alloc(usize, useful_valves.items.len) catch unreachable;
        for (useful_valves.items) |v, i| {
            uv[i] = v.flow_rate;
        }
        useful_valves.deinit();

        for (dist) |d_slice| {
            allocator.free(d_slice);
        }
        allocator.free(dist);
        var memos = std.AutoHashMap(MemoKey, usize).init(allocator);
        return PuzzleContext{ .valves = valves, .distances = dist_u, .start_valve = valves[start_ind], .allocator = allocator, .uv = uv, .valve_states = VBits.initEmpty(), .current_location = @truncate(u8, uv.len), .memos = memos };
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

    fn getDistance(self: PuzzleContext, from: Valve, to: Valve) u8 {
        return self.getDistanceInd(from.ind_u, to.ind_u);
    }

    fn getDistanceInd(self: PuzzleContext, from_i: usize, to_i: usize) u8 {
        return self.distances[from_i][to_i];
    }

    fn getExpectedBenefit(self: PuzzleContext, valve_index: usize) usize {
        const distance = self.getDistanceInd(self.current_location, valve_index);
        const time_consumed = 1 + self.ticks_spent + distance;
        return if (self.max_ticks < time_consumed) 0 else (self.max_ticks - time_consumed) * self.uv[valve_index];
    }

    fn getRemainingValves(self: PuzzleContext) []u8 {
        const len = self.uv.len - self.valve_states.count();
        var valves = self.allocator.alloc(u8, len) catch unreachable;
        var i: usize = 0;
        for (self.uv) |_, ind| {
            if (!self.valve_states.isSet(ind)) {
                valves[i] = @truncate(u8, ind);
                i += 1;
            }
        }
        return valves;
    }

    fn advanceToValve(self: *PuzzleContext, valve_index: u8) void {
        self.ticks_spent += 1 + self.getDistanceInd(self.current_location, valve_index);
        self.current_benefit += if (self.ticks_spent < self.max_ticks) (self.max_ticks - self.ticks_spent) * self.uv[valve_index] else 0;
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

    fn lookup(self: PuzzleContext) ?usize {
        return self.memos.get(MemoKey{ .tick = self.ticks_spent, .ind = self.current_location, .vstates = self.valve_states.mask });
    }

    fn memoize(self: *PuzzleContext, benefit: usize) void {
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
        return ctx.current_benefit + v;
    }

    const c_time = ctx.ticks_spent;
    const c_loc = ctx.current_location;
    const c_ben = ctx.current_benefit;

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
    current_partition: usize = 0,
    limit: usize,

    pub fn init(count: usize) PartitionIter {
        const limit = SHIFT_1 << @truncate(u6, count - 1);
        return PartitionIter{
            .limit = limit,
        };
    }

    pub fn next(self: *PartitionIter) ?VBits {
        self.current_partition += 1;
        if (self.current_partition > self.limit) {
            return null;
        }
        var bits = VBits.initEmpty();
        bits.mask = @truncate(u16, self.current_partition);
        return bits;
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

    var part_1 = memoisedExplore(&ctx);

    ctx.max_ticks = 26;
    ctx.memos.clearRetainingCapacity();
    var part_2: usize = 0;
    var partitions = PartitionIter.init(ctx.uv.len);
    var size_cutoff: usize = @divTrunc(ctx.uv.len, 3);
    var size_cutoff_upper: usize = ctx.uv.len - size_cutoff;
    while (partitions.next()) |valve_sets| {
        ctx.valve_states = valve_sets;
        // Heuristics for a quick skip? I'm assuming the partitions where
        // only <= 1/3rd of valves are in one side just won't cut it.
        if (valve_sets.count() <= size_cutoff or valve_sets.count() >= size_cutoff_upper) continue;
        const route_1 = memoisedExplore(&ctx);
        ctx.toggleAllValveStates();
        const route_2 = memoisedExplore(&ctx);
        part_2 = std.math.max(part_2, route_1 + route_2);
    }

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
