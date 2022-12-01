const std = @import("std");

pub fn readInputFileToBuffer(name: []const u8, allocator: *const std.mem.Allocator) ![]u8 {
    const fullpath = try std.fs.path.join(allocator.*, &.{"inputs", name});
    defer allocator.free(fullpath);
    return try std.fs.cwd().readFileAlloc(allocator.*, fullpath , 1000000);
}
