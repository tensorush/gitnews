const std = @import("std");

const MAX_BODY_LEN: usize = 1 << 13;
const MAX_NUM_TOP_STORIES: usize = 1 << 9;
const BASE_URL = "https://hacker-news.firebaseio.com/v0/";
const ALLOWED_HOSTS = .{ "github", "gitlab", "pages.dev" };
const BANNED_WORDS = .{ " AI", " LLM", " NLP", " TTS", "iffusion" };

pub fn fetch(ts_arena: std.mem.Allocator, writer: anytype) !void {
    var client = std.http.Client{ .allocator = ts_arena };
    defer client.deinit();

    var top_body_buf: [MAX_BODY_LEN]u8 = undefined;
    var top_body = std.ArrayListUnmanaged(u8).initBuffer(top_body_buf[0..]);

    const fetch_res = try client.fetch(.{
        .response_storage = .{ .static = &top_body },
        .location = .{ .url = BASE_URL ++ "topstories.json" },
    });

    switch (fetch_res.status) {
        .ok => {},
        else => |status| @panic(@tagName(status)),
    }

    if (top_body.items.len > 0) {
        var top_story_idx_iter = std.mem.tokenizeScalar(u8, top_body.items[1 .. top_body.items.len - 1], ',');
        var top_story_idxs = try std.BoundedArray(u32, MAX_NUM_TOP_STORIES).init(0);
        while (top_story_idx_iter.next()) |top_story_idx| {
            top_story_idxs.appendAssumeCapacity(try std.fmt.parseInt(u32, top_story_idx, 10));
        }

        const num_chunks = top_story_idxs.len / try std.Thread.getCpuCount();
        const chunk_size = top_story_idxs.len / num_chunks;

        try writer.writeAll("\x1b[1;31m-Hacker News\n\x1b[1;32m+Git News\x1b[0m\n");

        var total_count: u16 = 0;

        var timer = try std.time.Timer.start();
        const start = timer.lap();

        {
            var thread_pool: std.Thread.Pool = undefined;
            try thread_pool.init(.{ .allocator = ts_arena });
            defer thread_pool.deinit();

            var wait_group = std.Thread.WaitGroup{};
            defer wait_group.wait();

            var chunk_idx: u32 = 0;
            while (chunk_idx < num_chunks) : (chunk_idx += 1) {
                thread_pool.spawnWg(&wait_group, fetchChunk, .{
                    ts_arena,
                    &client,
                    top_story_idxs.constSlice()[chunk_idx * chunk_size .. (chunk_idx + 1) * chunk_size],
                    &total_count,
                    writer,
                });
            }
        }

        try writer.print(
            \\
            \\Total count: {d}
            \\Total duration: {}
            \\
        , .{ total_count, std.fmt.fmtDuration(timer.read() - start) });
    }
}

fn fetchChunk(
    ts_arena: std.mem.Allocator,
    client: *std.http.Client,
    item_ids: []const u32,
    total_count: *u16,
    writer: anytype,
) void {
    outer: for (item_ids) |item_id| {
        const item_url = std.fmt.allocPrint(ts_arena, BASE_URL ++ "item/{d}.json", .{item_id}) catch |err| @panic(@errorName(err));

        var item_body_buf: [MAX_BODY_LEN]u8 = undefined;
        var item_body = std.ArrayListUnmanaged(u8).initBuffer(item_body_buf[0..]);

        const fetch_res = client.fetch(.{
            .response_storage = .{ .static = &item_body },
            .location = .{ .url = item_url },
        }) catch |err| @panic(@errorName(err));

        switch (fetch_res.status) {
            .ok => {},
            else => |status| @panic(@tagName(status)),
        }

        if (item_body.items.len > 0) {
            const item = std.json.parseFromSliceLeaky(
                std.json.Value,
                ts_arena,
                item_body.items,
                .{},
            ) catch |err| @panic(@errorName(err));

            const title = if (item.object.get("title")) |title| title.string else continue;
            const url = if (item.object.get("url")) |url| url.string else continue;
            const uri = std.Uri.parse(url) catch |err| @panic(@errorName(err));

            if (uri.host) |host| {
                inline for (ALLOWED_HOSTS) |ALLOWED_HOST| {
                    if (std.mem.containsAtLeast(u8, host.percent_encoded, 1, ALLOWED_HOST)) {
                        inline for (BANNED_WORDS) |BANNED_WORD| {
                            if (std.mem.containsAtLeast(u8, title, 1, BANNED_WORD)) continue :outer;
                        }
                        writer.print(
                            \\
                            \\- Title: {s}
                            \\  Post: https://news.ycombinator.com/item?id={d}
                            \\  Site: {s}
                            \\
                        , .{ title, item_id, url }) catch |err| @panic(@errorName(err));
                        total_count.* += 1;
                    }
                }
            }
        }
    }
}
