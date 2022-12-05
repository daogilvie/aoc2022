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

pub const Answer = struct {
    part_1: usize,
    part_2: usize,

    pub fn print(self: Answer) void {
        std.debug.print("Part 1: {d}\n", .{self.part_1});
        std.debug.print("Part 2: {d}\n", .{self.part_2});
    }
};

pub const AnswerStr = struct {
    part_1: []const u8,
    part_2: []const u8,
    allocator: std.mem.Allocator,

    pub fn print(self: AnswerStr) void {
        std.debug.print("Part 1: {s}\n", .{self.part_1});
        std.debug.print("Part 2: {s}\n", .{self.part_2});
    }

    pub fn deinit(self: *AnswerStr) void {
        self.allocator.free(self.part_1);
        self.allocator.free(self.part_2);
    }
};
