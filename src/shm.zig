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

const ShmError = error{
    Enoent,
    NoFd,
    NoFlags,
    FileSizeError,
};

const CreateAnonymousFileError = std.fmt.BufPrintError || posix.TruncateError || ShmError;
const CreateBufferError = CreateAnonymousFileError || posix.MMapError;

pub var shm: ?*wl.wl_shm = null;
pub var shm_data: ?*anyopaque = null;

fn set_cloexec_or_close(fd: usize) ShmError!usize {
    if (fd == -1) {
        return ShmError.NoFd;
    }

    const flags = posix.fcntl(fd, posix.F.GETFD, 0);
    if (flags == -1 || (posix.fcntl(fd, posix.F.SETFD, flags | posix.FD_CLOEXEC) == -1)) {
        posix.close(fd);
        return ShmError.NoFlags;
    }

    return fd;
}

fn create_tmpfile_cloexec(tmpname: *u8) !i32 {
    const fd_c: c_int = cstd.mkstemp(tmpname);
    var fd: i32 = @intCast(fd_c);
    if (fd >= 0) {
        fd = set_cloexec_or_close(fd);
        posix.unlink(tmpname);
    }
}

fn os_create_anonymous_file(size: u64) CreateAnonymousFileError!i32 {
    const template = "/wlblocks-shared-XXXXXX";

    const path = try get_runtime_dir();
    const buf: [path.len + template.len]u8 = undefined;
    const name = try std.fmt.bufPrint(&buf, "{s}{s}", .{ path, template });

    const fd = try create_tmpfile_cloexec(name);
    if (fd == -1) {
        return ShmError.NoFd;
    }

    if (try posix.ftruncate(@intCast(fd), size) < 0) {
        posix.close(fd);
        return ShmError.FileSizeError;
    }

    return fd;
}

fn get_runtime_dir() ShmError![]u8 {
    const path: []u8 = posix.getenv("XDG_RUNTIME_DIR") orelse {
        return ShmError.Enoent;
    };
    return path;
}

pub fn create_buffer(width: usize, height: usize) CreateBufferError!*wl.wl_buffer {
    const stride = width * 4;
    const size = stride * height;

    const fd = try os_create_anonymous_file(size);
    const sharedmap: std.os.linux.MAP = .{ .TYPE = std.os.linux.MAP_TYPE.SHARED };

    const mmap_result = posix.mmap(null, size, posix.PROT.READ | posix.PROT.WRITE, sharedmap, @intCast(fd), 0) catch |err| {
        io.print("Failed to mmap\n", .{});
        posix.close(fd);
        return err;
    };
    shm_data = @ptrCast(mmap_result);

    const pool: *wl.wl_shm_pool = wl.wl_shm_create_pool(shm, fd, @intCast(size));
    const buff: *wl.wl_buffer = wl.wl_shm_pool_create_buffer(pool, 0, width, height, stride, wl.WL_SHM_FORMAT_ARGB8888);
    wl.wl_shm_pool_destroy(pool);

    return buff;
}
