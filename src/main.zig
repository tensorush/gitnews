const std = @import("std");

const gitnews = @import("gitnews.zig");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    const gpa = gpa_state.allocator();
    defer if (gpa_state.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_state.allocator();
    defer arena_state.deinit();

    var tsa_state = std.heap.ThreadSafeAllocator{ .child_allocator = arena };
    const tsa = tsa_state.allocator();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    try gitnews.fetch(tsa, writer);

    try buf_writer.flush();
}
