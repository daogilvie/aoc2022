const std = @import("std");
const days = @import("days.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }
    for (days.days) |day_fn| {
        day_fn(allocator);
    }
}

test {
    std.testing.refAllDecls(@This());
}
