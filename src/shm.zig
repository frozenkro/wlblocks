const std = @import("std");
const io = @import("io_util.zig");
const posix = std.posix;
const os = std.os;
const cstd = @cImport({
    @cInclude("stdlib.h");
});
const wl = @cImport({
    @cInclude("wayland-client.h");
});
const xdg = @import("xdg.zig");

const ShmError = error{
    Enoent,
    MksTempFailure,
    NoBufCreated,
};

const SetCloexecOrCloseError = posix.FcntlError;
const CreateTmpFileError = ShmError || SetCloexecOrCloseError || posix.UnlinkError;
const CreateAnonymousFileError = std.fmt.BufPrintError || posix.TruncateError || CreateTmpFileError;
const CreateBufferError = CreateAnonymousFileError || posix.MMapError;

const fd_t = posix.fd_t;

pub var shm: *wl.wl_shm = undefined;
pub var shm_data: [*]u32 = undefined;

fn set_cloexec_or_close(fd: fd_t) SetCloexecOrCloseError!fd_t {
    const flags = try posix.fcntl(fd, posix.F.GETFD, 0);
    _ = posix.fcntl(fd, posix.F.SETFD, flags | posix.FD_CLOEXEC) catch |err| {
        posix.close(fd);
        return err;
    };

    return fd;
}

fn create_tmpfile_cloexec(tmpname: *[:0]u8) CreateTmpFileError!fd_t {
    const fd_c: c_int = cstd.mkstemp(@ptrCast(tmpname.*));
    if (fd_c == -1) {
        const err: posix.E = @enumFromInt(std.c._errno().*);
        io.print("ERRNO: {s}\n", .{@tagName(err)});
        return ShmError.MksTempFailure;
    }

    var fd: fd_t = @intCast(fd_c);
    fd = try set_cloexec_or_close(fd);
    try posix.unlink(tmpname.*);

    return fd;
}

fn os_create_anonymous_file(size: usize) CreateAnonymousFileError!fd_t {
    const template = "/wlblocks-shared-XXXXXX";

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const xdg_runtime_dir = try get_runtime_dir();
    var name = try std.fmt.bufPrintZ(&path_buf, "{s}{s}", .{ xdg_runtime_dir, template });

    const fd = try create_tmpfile_cloexec(&name);

    posix.ftruncate(fd, size) catch |err| {
        posix.close(fd);
        return err;
    };

    return fd;
}

fn get_runtime_dir() ShmError![:0]const u8 {
    const path = posix.getenvZ("XDG_RUNTIME_DIR") orelse {
        return ShmError.Enoent;
    };
    return path;
}

pub fn create_buffer(width: i32, height: i32) CreateBufferError!*wl.wl_buffer {
    const stride = width * 4;
    const size = stride * height;

    const fd = try os_create_anonymous_file(@intCast(size));
    const sharedmap: std.os.linux.MAP = .{ .TYPE = std.os.linux.MAP_TYPE.SHARED };

    const mmap_result = posix.mmap(null, @intCast(size), posix.PROT.READ | posix.PROT.WRITE, sharedmap, @intCast(fd), 0) catch |err| {
        io.print("Failed to mmap\n", .{});
        posix.close(fd);
        return err;
    };
    shm_data = @ptrCast(mmap_result);

    const pool: ?*wl.wl_shm_pool = wl.wl_shm_create_pool(shm, fd, @intCast(size));
    const buff: ?*wl.wl_buffer = wl.wl_shm_pool_create_buffer(pool, 0, width, height, stride, wl.WL_SHM_FORMAT_ARGB8888);
    wl.wl_shm_pool_destroy(pool);

    if (buff == null) {
        return ShmError.NoBufCreated;
    } else {
        return buff.?;
    }
}

pub fn draw(grid: [][]u32) void {
    const height = grid.len;
    if (height == 0) {
        return;
    }
    const width = grid[0].len;

    const shm_x_min = getHrizOffset(width);
    const shm_y_min = getVertOffset(height);
    var pixel = shm_x_min * shm_y_min;
    var grid_y: u32 = 0;
    while (grid_y < height) : (grid_y += 1) {
        var grid_x: u32 = 0;
        while (grid_x < width) : (grid_x += 1) {
            shm_data[pixel] = grid[grid_y][grid_x];
            pixel += 1;
        }
        pixel += shm_x_min * 2;
    }
}

fn getVertOffset(height: u32) u32 {
    if (xdg.height <= height) {
        return 0;
    }
    const margin = xdg.height - height;
    return @divTrunc(margin, 2);
}
fn getHrizOffset(width: u32) u32 {
    if (xdg.width <= width) {
        return 0;
    }
    const margin = xdg.width - width;
    return @divTrunc(margin, 2);
}
