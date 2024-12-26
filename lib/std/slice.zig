const std = @import("std.zig");

pub fn slice(comptime T: type) type {
    _ = T;
    return struct {};
}
