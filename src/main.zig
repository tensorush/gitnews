const std = @import("std");
const githunt = @import("githunt.zig");

const CHUNK_SIZE: u16 = 25;
const NUM_TOP_STORIES: u16 = 500;

const log = std.log.scoped(.githunt);

const Error = error{
    UnexpectedRemainder,
    DivisionByZero,
    Overflow,
} || githunt.Error || std.Thread.CpuCountError || std.Thread.SpawnError || std.time.Timer.Error;

pub fn main() Error!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("PANIC: Memory leak has occurred!");
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var thread_safe_allocator = std.heap.ThreadSafeAllocator{ .child_allocator = arena.allocator() };
    const allocator = thread_safe_allocator.allocator();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    try writer.writeAll("content-type: text/plain\n\n");

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    const uri = try std.Uri.parse("https://hacker-news.firebaseio.com/v0/topstories.json");

    var req = try client.request(.GET, uri, headers, .{});
    defer req.deinit();

    try req.start();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, githunt.BODY_LEN);

    const item_ids = try std.json.parseFromSliceLeaky([NUM_TOP_STORIES]u32, allocator, body, .{});

    var timer = try std.time.Timer.start();
    const start = timer.lap();

    const num_chunks = try std.math.divExact(u16, NUM_TOP_STORIES, CHUNK_SIZE);

    {
        var thread_pool: std.Thread.Pool = undefined;
        try thread_pool.init(.{ .allocator = allocator });
        defer thread_pool.deinit();

        var wait_group = std.Thread.WaitGroup{};
        defer wait_group.wait();

        var chunk_idx: u32 = 0;
        while (chunk_idx < num_chunks) : (chunk_idx += 1) {
            wait_group.start();

            try thread_pool.spawn(githunt.requestItems, .{ allocator, &wait_group, &client, headers, item_ids[chunk_idx * CHUNK_SIZE ..][0..CHUNK_SIZE], writer });
        }
    }

    try buf_writer.flush();

    log.info("Total duration: {}", .{std.fmt.fmtDuration(timer.read() - start)});
}
