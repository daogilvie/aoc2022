const std = @import("std");

pub fn readInputFileToBuffer(name: []const u8, allocator: *const std.mem.Allocator) ![]u8 {
    const fullpath = try std.fs.path.join(allocator.*, &.{ "inputs", name });
    defer allocator.free(fullpath);
    return try std.fs.cwd().readFileAlloc(allocator.*, fullpath, 1000000);
}

// Surely this is longer than will ever be needed for headers.
// It is only hear to print edges around headers
const header_slice = "###################################";

pub fn printHeader(header: []const u8) void {
    const line = header_slice[0 .. header.len + 4];
    std.debug.print("\n{s}\n# {s} #\n{s}\n\n", .{ line, header, line });
}
