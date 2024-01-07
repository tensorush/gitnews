const std = @import("std");

pub fn fetchItems(
    allocator: std.mem.Allocator,
    wait_group: *std.Thread.WaitGroup,
    headers: std.http.Headers,
    client: *std.http.Client,
    item_ids: []const u32,
    writer: anytype,
) void {
    wait_group.start();
    defer wait_group.finish();

    for (item_ids) |item_id| {
        const item_url = std.fmt.allocPrint(allocator, "https://hacker-news.firebaseio.com/v0/item/{d}.json", .{item_id}) catch unreachable;

        var res = client.fetch(allocator, .{ .location = .{ .url = item_url }, .headers = headers }) catch unreachable;
        defer res.deinit();

        if (res.body) |body| {
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

            const uri = std.Uri.parse(url) catch unreachable;
            if (uri.host) |host| {
                if (std.mem.containsAtLeast(u8, host, 1, "github")) {
                    writer.print("Title: {s}\nURL: {s}\n\n", .{ title, url }) catch unreachable;
                }
            }
        }
    }
}
