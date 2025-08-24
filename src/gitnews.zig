const std = @import("std");

const MAX_BODY_SIZE = 1 << 13;
const MAX_NUM_TOP_STORIES = 1 << 9;
const BASE_URL = "https://hacker-news.firebaseio.com/v0/";
const ALLOWED_DOMAINS = .{
    "git",
    ".me",
    ".io",
    ".it",
    ".sh",
    ".dev",
    ".net",
    ".org",
    ".page",
};
const BANNED_WORDS = .{
    // Abbreviations
    "AI",
    "GPT",
    "LLM",
    "MCP",
    "NLP",
    "TTS",
    // Names
    "Grok",
    "Gemma",
    "Llama",
    "Claude",
    "Docker",
    "Gemini",
    "Python",
    "PyTorch",
    "Whisper",
    "JavaScript",
    // Terms
    "deep",
    "vibe",
    "agent",
    "crypto",
    "neural",
    "prompt",
    "chatbot",
    "training",
    "assistant",
    "diffusion",
    "embedding",
};

pub fn fetch(
    ts_arena: std.mem.Allocator,
    writer: *std.io.Writer,
) !void {
    var client: std.http.Client = .{ .allocator = ts_arena };
    defer client.deinit();

    var top_body_buf: [MAX_BODY_SIZE]u8 = undefined;
    var top_body_writer: std.io.Writer = .fixed(&top_body_buf);

    const fetch_res = try client.fetch(.{
        .response_writer = &top_body_writer,
        .location = .{ .url = BASE_URL ++ "topstories.json" },
    });

    switch (fetch_res.status) {
        .ok => {},
        else => |status| @panic(@tagName(status)),
    }

    const top_body = top_body_writer.buffered();
    if (top_body.len > 0) {
        var top_story_idx_iter = std.mem.tokenizeScalar(u8, top_body[1 .. top_body.len - 1], ',');
        var top_story_idxs_buf: [MAX_NUM_TOP_STORIES]u32 = undefined;
        var top_story_idxs: std.ArrayList(u32) = .initBuffer(&top_story_idxs_buf);
        while (top_story_idx_iter.next()) |top_story_idx| {
            top_story_idxs.appendAssumeCapacity(try std.fmt.parseInt(u32, top_story_idx, 10));
        }

        const num_chunks = top_story_idxs.items.len / try std.Thread.getCpuCount();
        const chunk_size = top_story_idxs.items.len / num_chunks;

        try writer.writeAll("\x1b[1;31m-Hacker News\n\x1b[1;32m+Git News\x1b[0m\n");

        var total_count: u16 = 0;

        var timer = try std.time.Timer.start();
        const start = timer.lap();

        {
            var thread_pool: std.Thread.Pool = undefined;
            try thread_pool.init(.{ .allocator = ts_arena });
            defer thread_pool.deinit();

            var wait_group: std.Thread.WaitGroup = .{};
            defer wait_group.wait();

            var chunk_idx: u32 = 0;
            while (chunk_idx < num_chunks) : (chunk_idx += 1) {
                thread_pool.spawnWg(&wait_group, fetchChunk, .{
                    ts_arena,
                    &client,
                    top_story_idxs.items[chunk_idx * chunk_size .. (chunk_idx + 1) * chunk_size],
                    &total_count,
                    writer,
                });
            }
        }

        try writer.print(
            \\
            \\Total count: {d}
            \\Total duration: {D}
            \\
        , .{ total_count, timer.read() - start });
    }
}

fn fetchChunk(
    ts_arena: std.mem.Allocator,
    client: *std.http.Client,
    item_ids: []const u32,
    total_count: *u16,
    writer: *std.io.Writer,
) void {
    outer: for (item_ids) |item_id| {
        const item_url = std.fmt.allocPrint(ts_arena, BASE_URL ++ "item/{d}.json", .{item_id}) catch |err| @panic(@errorName(err));

        var item_body_buf: [MAX_BODY_SIZE]u8 = undefined;
        var item_body_writer: std.io.Writer = .fixed(&item_body_buf);

        const fetch_res = client.fetch(.{
            .response_writer = &item_body_writer,
            .location = .{ .url = item_url },
        }) catch |err| @panic(@errorName(err));

        switch (fetch_res.status) {
            .ok => {},
            else => |status| @panic(@tagName(status)),
        }

        const item_body = item_body_writer.buffered();
        if (item_body.len > 0) {
            const item = std.json.parseFromSliceLeaky(
                std.json.Value,
                ts_arena,
                item_body,
                .{},
            ) catch |err| @panic(@errorName(err));

            const title = if (item.object.get("title")) |title| title.string else continue;
            const url = if (item.object.get("url")) |url| url.string else continue;
            const uri = std.Uri.parse(url) catch |err| @panic(@errorName(err));

            if (uri.host) |host| {
                inline for (ALLOWED_DOMAINS) |ALLOWED_HOST| {
                    if (std.mem.indexOf(u8, host.percent_encoded, ALLOWED_HOST)) |_| {
                        inline for (BANNED_WORDS) |BANNED_WORD| {
                            if (std.ascii.indexOfIgnoreCase(title, BANNED_WORD)) |_| continue :outer;
                        }
                        writer.print(
                            \\
                            \\- Title: {s}
                            \\  Post: https://news.ycombinator.com/item?id={d}
                            \\  Site: {s}
                            \\
                        , .{ title, item_id, url }) catch |err| @panic(@errorName(err));
                        total_count.* += 1;
                        continue :outer;
                    }
                }
            }
        }
    }
}
