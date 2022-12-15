const std = @import("std");
const utils = @import("utils.zig");

const day_structs = .{
    @import("day1.zig"),
    @import("day2.zig"),
    @import("day3.zig"),
    @import("day4.zig"),
    @import("day5.zig"),
    @import("day6.zig"),
    @import("day7.zig"),
    @import("day8.zig"),
    @import("day9.zig"),
    @import("day10.zig"),
    @import("day11.zig"),
    @import("day12.zig"),
    @import("day13.zig"),
    @import("day14.zig"),
    @import("day15.zig"),
};

pub const days = daygen: {
    const num_days = day_structs.len;
    var day_dyn: [num_days]*const (fn (std.mem.Allocator) void) = .{undefined} ** num_days;
    for (day_structs) |day, ind| {
        day_dyn[ind] = day.run;
    }
    break :daygen day_dyn;
};
