const std = @import("std");
const githunt = @import("githunt.zig");

const MAX_NUM_TOP_STORIES: usize = 1 << 9;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("Memory leak has occurred!");
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var thread_safe_allocator = std.heap.ThreadSafeAllocator{ .child_allocator = arena.allocator() };
    const allocator = thread_safe_allocator.allocator();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    var headers = std.http.Headers.init(allocator);
    defer headers.deinit();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var res = try client.fetch(allocator, .{ .location = .{ .url = "https://hacker-news.firebaseio.com/v0/topstories.json" }, .headers = headers });
    defer res.deinit();

    if (res.body) |body| {
        var top_story_idx_iter = std.mem.tokenizeScalar(u8, body[1 .. body.len - 1], ',');
        var top_story_idxs = try std.BoundedArray(u32, MAX_NUM_TOP_STORIES).init(0);
        while (top_story_idx_iter.next()) |top_story_idx| {
            top_story_idxs.appendAssumeCapacity(try std.fmt.parseInt(u32, top_story_idx, 10));
        }

        const num_chunks = top_story_idxs.len / try std.Thread.getCpuCount();
        const chunk_size = top_story_idxs.len / num_chunks;

        var timer = try std.time.Timer.start();
        const start = timer.lap();

        {
            var thread_pool: std.Thread.Pool = undefined;
            try thread_pool.init(.{ .allocator = allocator });
            defer thread_pool.deinit();

            var wait_group = std.Thread.WaitGroup{};
            defer wait_group.wait();

            var chunk_idx: u32 = 0;
            while (chunk_idx < num_chunks) : (chunk_idx += 1) {
                try thread_pool.spawn(githunt.fetchItems, .{ allocator, &wait_group, headers, &client, top_story_idxs.constSlice()[chunk_idx * chunk_size .. (chunk_idx + 1) * chunk_size], writer });
            }
        }

        try writer.print("Total duration: {}\n", .{std.fmt.fmtDuration(timer.read() - start)});

        try buf_writer.flush();
    }
}
