const std = @import("std");

const stdout = std.io.getStdOut().writer();

fn print_err(err: anyerror) void {
    std.debug.print("Error when printing to console: {any}\n", .{err});
}

pub fn print(comptime message: []const u8, args: anytype) void {
    stdout.print(message, args) catch |err| {
        print_err(err);
    };
}
