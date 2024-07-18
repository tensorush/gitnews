const std = @import("std");

const MAX_BODY_LEN: usize = 1 << 13;
const MAX_NUM_TOP_STORIES: usize = 1 << 9;

pub fn fetch(allocator: std.mem.Allocator, writer: anytype) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var top_body_buf: [MAX_BODY_LEN]u8 = undefined;
    var top_body = std.ArrayListUnmanaged(u8).initBuffer(top_body_buf[0..]);

    const res = try client.fetch(.{
        .response_storage = .{ .static = &top_body },
        .location = .{ .url = "https://hacker-news.firebaseio.com/v0/topstories.json" },
    });

    switch (res.status) {
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
                thread_pool.spawnWg(&wait_group, fetchChunk, .{
                    allocator,
                    &client,
                    top_story_idxs.constSlice()[chunk_idx * chunk_size .. (chunk_idx + 1) * chunk_size],
                    writer,
                });
            }
        }

        try writer.print("Total duration: {}\n", .{std.fmt.fmtDuration(timer.read() - start)});
    }
}

fn fetchChunk(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    item_ids: []const u32,
    writer: anytype,
) void {
    for (item_ids) |item_id| {
        const item_url = std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{item_id}) catch |err| @panic(@errorName(err));

        var item_body_buf: [MAX_BODY_LEN]u8 = undefined;
        var item_body = std.ArrayListUnmanaged(u8).initBuffer(item_body_buf[0..]);

        const res = client.fetch(.{
            .response_storage = .{ .static = &item_body },
            .location = .{ .url = item_url },
        }) catch |err| @panic(@errorName(err));

        switch (res.status) {
            .ok => {},
            else => |status| @panic(@tagName(status)),
        }

        if (item_body.items.len > 0) {
            const item = std.json.parseFromSliceLeaky(std.json.Value, allocator, item_body.items, .{}) catch |err| @panic(@errorName(err));

            var title: []const u8 = undefined;
            if (item.object.get("title")) |t| {
                title = t.string;
            } else {
                continue;
            }

            var url: []const u8 = undefined;
            if (item.object.get("url")) |u| {
                url = u.string;
            } else {
                continue;
            }

            const uri = std.Uri.parse(url) catch |err| @panic(@errorName(err));
            if (uri.host) |host| {
                if (std.mem.containsAtLeast(u8, host.percent_encoded, 1, "github") or
                    std.mem.containsAtLeast(u8, host.percent_encoded, 1, "codeberg") or
                    std.mem.containsAtLeast(u8, host.percent_encoded, 1, "gitlab") or
                    std.mem.containsAtLeast(u8, host.percent_encoded, 1, "sr.ht") or
                    std.mem.containsAtLeast(u8, host.percent_encoded, 1, "srht"))
                {
                    writer.print("Title: {s}\nURL: {s}\n\n", .{ title, url }) catch |err| @panic(@errorName(err));
                }
            }
        }
    }
}
