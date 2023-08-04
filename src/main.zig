const std = @import("std");

const BODY_LEN = 1 << 14;

const Error = error{
    StreamTooLong,
} || std.mem.Allocator.Error || std.os.WriteError || std.http.Client.Request.WaitError || std.http.Client.Request.ReadError || std.json.ParseError(std.json.Scanner);

pub fn main() Error!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        @panic("PANIC: Memory leak has occurred!");
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    try writer.writeAll("content-type: text/plain\n\n");

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    const top_uri = try std.Uri.parse("https://hacker-news.firebaseio.com/v0/topstories.json");

    var top_req = try client.request(.GET, top_uri, headers, .{});
    defer top_req.deinit();

    try top_req.start();
    try top_req.wait();

    const top_body = try top_req.reader().readAllAlloc(allocator, BODY_LEN);

    const item_ids = try std.json.parseFromSliceLeaky([500]u32, allocator, top_body, .{});

    for (item_ids[0..100]) |item_id| {
        const uri_str = try std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{item_id});
        const uri = try std.Uri.parse(uri_str);

        var req = try client.request(.GET, uri, headers, .{});
        defer req.deinit();

        try req.start();
        try req.wait();

        const body = try req.reader().readAllAlloc(allocator, BODY_LEN);

        const item = try std.json.parseFromSliceLeaky(std.json.Value, allocator, body, .{});

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

        if ((try std.Uri.parse(url)).host) |host| {
            if (std.mem.containsAtLeast(u8, host, 1, "github")) {
                try writer.print("Title: {s}\nURL: {s}\n\n", .{ title, url });
            }
        }
    }

    try buf_writer.flush();
}
