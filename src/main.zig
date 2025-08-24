const std = @import("std");

const gitnews = @import("gitnews.zig");

const MAX_BUF_SIZE = 1 << 12;

pub fn main() !void {
    var gpa_state: std.heap.DebugAllocator(.{}) = .init;
    const gpa = gpa_state.allocator();
    defer if (gpa_state.deinit() == .leak) @panic("Memory leaked!");

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    const arena = arena_state.allocator();
    defer arena_state.deinit();

    var ts_arena_state: std.heap.ThreadSafeAllocator = .{ .child_allocator = arena };
    const ts_arena = ts_arena_state.allocator();

    var stdout_buf: [MAX_BUF_SIZE]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const writer = &stdout_writer.interface;

    try gitnews.fetch(ts_arena, writer);

    try writer.flush();
}
