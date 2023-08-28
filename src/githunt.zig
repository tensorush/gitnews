const std = @import("std");

pub const BODY_CAP: u16 = 1 << 13;

pub const Error = error{
    StreamTooLong,
} || std.mem.Allocator.Error || std.os.WriteError || std.http.Client.Request.WaitError || std.http.Client.Request.ReadError || std.json.ParseError(std.json.Scanner);

pub fn requestItems(
    allocator: std.mem.Allocator,
    wait_group: *std.Thread.WaitGroup,
    client: *std.http.Client,
    headers: std.http.Headers,
    item_ids: []const u32,
    writer: anytype,
) void {
    defer wait_group.finish();

    for (item_ids) |item_id| {
        const uri_str = std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{item_id}) catch unreachable;
        const uri = std.Uri.parse(uri_str) catch unreachable;

        var req = client.request(.GET, uri, headers, .{}) catch unreachable;
        defer req.deinit();

        req.start() catch unreachable;
        req.wait() catch unreachable;

        const body = req.reader().readAllAlloc(allocator, BODY_CAP) catch unreachable;

        const item = std.json.parseFromSliceLeaky(std.json.Value, allocator, body, .{}) catch unreachable;

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

        const source_uri = std.Uri.parse(url) catch unreachable;
        if (source_uri.host) |host| {
            if (std.mem.containsAtLeast(u8, host, 1, "github")) {
                writer.print("Title: {s}\nURL: {s}\n\n", .{ title, url }) catch unreachable;
            }
        }
    }
}
