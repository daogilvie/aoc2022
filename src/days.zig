const std = @import("std");
const utils = @import("utils.zig");
const day1 = @import("day1.zig");
const day2 = @import("day2.zig");
const day3 = @import("day3.zig");
const day4 = @import("day4.zig");
const day5 = @import("day5.zig");

pub const days = [_]*const fn (*const std.mem.Allocator) void{ day1.run, day2.run, day3.run, day4.run, day5.run };
