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

const PuzzleContext = struct {
    distances: [][]usize,
    allocator: Allocator,
    valves: []Valve,
    uv: []Valve,
    max_ticks: usize = 30,

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

        // // We now downselect the distance matrix to be only the useful valves
        // var dist_u: [][]usize = allocator.alloc([]usize, uv.len) catch unreachable;
        //
        // for (dist_u) |*du_slice, uv_ind| {
        //     du_slice.* = allocator.alloc(usize, uv.len) catch unreachable;
        //     const source_valve = uv[uv_ind];
        //     const source_slice = dist[source_valve.ind];
        //     for (du_slice.*) |*entry, index| {
        //         const dest_valve = uv[index];
        //         entry.* = source_slice[dest_valve.ind];
        //     }
        // }
        //
        // for (dist) |d_slice| {
        //     allocator.free(d_slice);
        // }
        // allocator.free(dist);
        return PuzzleContext{ .valves = valves, .distances = dist, .allocator = allocator, .uv = uv };
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
    }

    fn getDistance(self: PuzzleContext, from: Valve, to: Valve) usize {
        return self.distances[from.ind][to.ind];
    }
};

// const PuzzleMatrixState = struct {
//     time_tick: usize,
//     values: [][]usize,
//     allocator: Allocator,
//
//     pub fn init(ctx: *PuzzleContext) PuzzleMatrixState {
//         const arr_size = ctx.*.uv.len;
//         var my_values: [][]usize = ctx.*.allocator.alloc([]usize, arr_size);
//         for (my_values) |*v_slice| {
//             v_slice.* = allocator.alloc(usize, arr_size) catch unreachable;
//         }
//         var time: usize = 1;
//     }
//
//     fn deinit(self: *PuzzleMatrixState) void {
//         for (self.values) |v_slice| {
//             self.allocator.free(v_slice);
//         }
//     }
//
// }

const PuzzleState = struct {
    ctx: *const PuzzleContext,
    location: Valve,
    total_flow_benefit: usize = 0,
    time_spent: usize = 0,
    pub fn format(
        self: PuzzleState,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("(time={d},flow_accum={d}", .{ self.time_spent, self.total_flow_benefit });
        try writer.writeAll(")");
    }

    fn getExpectedBenefit(self: PuzzleState, valve: Valve) usize {
        const distance = self.ctx.getDistance(self.location, valve);
        const time_consumed = 1 + self.time_spent + distance;
        return if (self.ctx.max_ticks < time_consumed) 0 else (self.ctx.max_ticks - time_consumed) * valve.flow_rate;
    }

    fn getDistance(self: PuzzleState, valve: Valve) usize {
        return self.ctx.getDistance(self.location, valve);
    }

    fn advanceToValve(self: PuzzleState, valve: Valve) PuzzleState {
        const new_time = self.time_spent + 1 + self.ctx.getDistance(self.location, valve);
        const new_flow = if (new_time < self.ctx.max_ticks) self.total_flow_benefit + (self.ctx.max_ticks - new_time) * valve.flow_rate else self.total_flow_benefit;
        return PuzzleState{ .ctx = self.ctx, .location = valve, .total_flow_benefit = new_flow, .time_spent = new_time };
    }

    fn getCutoffBenefit(self: PuzzleState) usize {
        return if (self.time_spent > self.ctx.max_ticks) 0 else self.total_flow_benefit;
    }
};

fn explore(current_state: PuzzleState, remaining: []Valve, ctx: *PuzzleContext) usize {
    // Degenerate cases:
    if (remaining.len == 1) {
        // Advance
        const new = current_state.advanceToValve(remaining[0]);
        return new.total_flow_benefit;
    }
    var local_valves = ctx.*.allocator.alloc(Valve, remaining.len) catch unreachable;
    std.mem.copy(Valve, local_valves, remaining);
    defer ctx.*.allocator.free(local_valves);
    var onward_valves = ctx.*.allocator.alloc(Valve, remaining.len - 1) catch unreachable;
    defer ctx.*.allocator.free(onward_valves);
    var local_max: usize = current_state.total_flow_benefit;
    outer: for (local_valves) |next_valve, skip_ind| {
        var onward_ind: usize = 0;
        inner: for (local_valves) |v, ind| {
            if (ind == skip_ind) continue :inner;
            onward_valves[onward_ind] = v;
            onward_ind += 1;
        }
        if (current_state.getExpectedBenefit(next_valve) == 0) continue :outer;
        const onward_state = current_state.advanceToValve(next_valve);
        local_max = std.math.max(local_max, explore(onward_state, onward_valves, ctx));
    }
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

    const root_valve = for (ctx.valves) |v| {
        if (std.mem.eql(u8, v.id, "AA")) break v;
    } else unreachable;

    const root_state = PuzzleState{ .ctx = &ctx, .location = root_valve, .total_flow_benefit = 0, .time_spent = 0 };

    var path = ArrayList(PuzzleState).init(allocator);
    defer path.deinit();

    var part_1 = explore(root_state, ctx.uv, &ctx);

    ctx.max_ticks = 26;
    var part_2: usize = 0;
    var partitions = PartitionIter.init(ctx.uv, allocator);
    var size_cutoff: usize = @divTrunc(ctx.uv.len, 3);
    var p_count: usize = 0;
    print("\n", .{});
    while (partitions.next()) |valve_sets| {
        p_count += 1;
        print("\r{d: >2} / {d}", .{ p_count, partitions.limit });
        // Heuristics for a quick skip? I'm assuming the partitions where only < 1/3rd  of
        // valves are in one side just won't cut it.
        if (valve_sets[0].len < size_cutoff or valve_sets[0].len > ctx.uv.len - size_cutoff) continue;
        const local_max = explore(root_state, valve_sets[0], &ctx) + explore(root_state, valve_sets[1], &ctx);
        part_2 = std.math.max(part_2, local_max);
    }
    print("\n", .{});

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
