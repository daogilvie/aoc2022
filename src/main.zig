const std = @import("std");
const day1 = @import("day1.zig");
const day2 = @import("day2.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }
    try day1.run(&allocator);
    try day2.run(&allocator);
}

test {
 std.testing.refAllDecls(@This());
}
