const std = @import("std");

const stdout = std.io.getStdOut().writer();

fn print_err(err: anyerror) void {
    std.debug.print("Error when printing to console: {any}\n", .{err});
}

pub fn print(message: []u8) void {
    stdout.print(message) catch |err| {
        print_err(err);
    };
}
