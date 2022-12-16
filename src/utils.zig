const std = @import("std");

pub fn readInputFileToBuffer(name: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const fullpath = try std.fs.path.join(allocator, &.{ "inputs", name });
    defer allocator.free(fullpath);
    return try std.fs.cwd().readFileAlloc(allocator, fullpath, 1000000);
}

// Surely this is longer than will ever be needed for headers.
// It is only hear to print edges around headers
const header_slice = "###################################";

pub fn printHeader(header: []const u8) void {
    const line = header_slice[0 .. header.len + 4];
    std.debug.print("\n{s}\n# {s} #\n{s}\n\n", .{ line, header, line });
}

pub fn NumericAnswer(comptime T: type) type {
    return struct {
        const This = @This();
        part_1: T,
        part_2: T,

        pub fn print(self: This) void {
            std.debug.print("Part 1: {d}\n", .{self.part_1});
            std.debug.print("Part 2: {d}\n", .{self.part_2});
        }
    };
}

pub const Answer = NumericAnswer(usize);

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

fn factorial(n: usize) usize {
    var f: usize = 1;
    var count: usize = n;
    while (count > 0) : (count -= 1) {
        f *= count;
    }
    return f;
}

fn PermutationsIterator() type {
    return struct {
        size: usize,
        c: []usize,
        A: []u8,
        i: usize = 0,
        len: usize,
        allocator: std.mem.Allocator,
        const Self = @This();

        pub fn init(size: usize, allocator: std.mem.Allocator) Self {
            var inds = allocator.alloc(usize, size) catch unreachable;
            var output = allocator.alloc(u8, size) catch unreachable;
            std.mem.set(usize, inds, 0);
            for (output) |_, ind| {
                output[ind] = @truncate(u8, ind);
            }
            return .{ .size = size, .c = inds, .A = output, .len = factorial(size), .allocator = allocator };
        }

        fn deinit(self: Self) void {
            self.allocator.free(self.c);
            self.allocator.free(self.A);
        }

        fn next(self: *Self) ?[]u8 {
            if (self.i >= self.size) {
                self.deinit();
                return null;
            }
            if (self.i == 0) {
                self.i = 1;
            } else if (self.c[self.i] < self.i) {
                if (@rem(self.i, 2) == 0) {
                    std.mem.swap(u8, &self.A[0], &self.A[self.i]);
                } else {
                    std.mem.swap(u8, &self.A[self.c[self.i]], &self.A[self.i]);
                }
                self.c[self.i] += 1;
                self.i = 1;
            } else {
                self.c[self.i] = 0;
                self.i += 1;
                return self.next();
            }
            return self.A;
        }
    };
}
