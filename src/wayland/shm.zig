const std = @import("std");
const posix = std.posix;
const os = std.os;
const b = @import("binder.zig");
const io = @import("../io_util.zig");
const xdg = @import("xdg.zig");
const cstd = @cImport({
    @cInclude("stdlib.h");
});
const wl = @cImport({
    @cInclude("wayland-client.h");
});

const PixelMatrix = @import("../mtx/pixel_matrix.zig").PixelMatrix;

const CreateAnonymousFileError = std.fmt.BufPrintError || posix.TruncateError || ShmError;
const CreateBufferError = CreateAnonymousFileError || posix.MMapError;

const fd_t = posix.fd_t;
const ShmError = error{
    Enoent,
    MksTempFailure,
    NoBufCreated,
    CloexecFailed,
    UnlinkFailed,
    ShmNotBound,
};

pub const WlShm = struct {
    shm: ?*wl.wl_shm,
    shm_data: ?[*]u32,
    buffer: ?*wl.wl_buffer,

    pub fn init() WlShm {
        return WlShm{
            .shm = null,
            .shm_data = null,
            .buffer = null,
        };
    }

    fn bind(ptr: *anyopaque, shm: *anyopaque) void {
        const self: *WlShm = @ptrCast(@alignCast(ptr));
        self.shm = @ptrCast(shm);
    }

    pub fn binder(self: *WlShm) b.Binder {
        return .{
            .ptr = self,
            .bindFn = bind,
            .interface_name = "wl_shm",
            .interface = &wl.wl_shm_interface,
            .version = 1,
        };
    }

    pub fn initBuffer(self: *WlShm, width: u32, height: u32) CreateBufferError!void {
        if (self.shm == null) {
            return CreateBufferError.ShmNotBound;
        }

        const stride = width * 4;
        const size = stride * height;

        const fd = try createAnonymousFile(@intCast(size));
        const sharedmap: std.os.linux.MAP = .{ .TYPE = std.os.linux.MAP_TYPE.SHARED };

        const mmap_result = posix.mmap(
            null,
            @intCast(size),
            posix.PROT.READ | posix.PROT.WRITE,
            sharedmap,
            @intCast(fd),
            0,
        ) catch |err| {
            io.print("Failed to mmap\n", .{});
            posix.close(fd);
            return err;
        };
        self.shm_data = @ptrCast(mmap_result);

        const pool: ?*wl.wl_shm_pool = wl.wl_shm_create_pool(self.shm, fd, @intCast(size));
        defer wl.wl_shm_pool_destroy(pool);

        const buff: ?*wl.wl_buffer = wl.wl_shm_pool_create_buffer(
            pool,
            0,
            @intCast(width),
            @intCast(height),
            @intCast(stride),
            wl.WL_SHM_FORMAT_ARGB8888,
        );

        if (buff != null) {
            self.buffer = buff;
        } else {
            return ShmError.NoBufCreated;
        }
    }
};

fn setCloexec(fd: fd_t) posix.FcntlError!fd_t {
    const flags = try posix.fcntl(fd, posix.F.GETFD, 0);
    _ = posix.fcntl(fd, posix.F.SETFD, flags | posix.FD_CLOEXEC) catch |err| {
        posix.close(fd);
        return err;
    };

    return fd;
}

fn createTmpfileCloexec(tmpname: *[:0]u8) ShmError!fd_t {
    const fd_c: c_int = cstd.mkstemp(@ptrCast(tmpname.*));
    if (fd_c == -1) {
        const err: posix.E = @enumFromInt(std.c._errno().*);
        io.print("ERRNO: {s}\n", .{@tagName(err)});
        return ShmError.MksTempFailure;
    }

    var fd: fd_t = @intCast(fd_c);
    fd = setCloexec(fd) catch |err| {
        io.print("Error setting cloexec on fd: '{d}'\nError: {s}", .{ fd, @errorName(err) });
        return ShmError.CloexecFailed;
    };
    posix.unlink(tmpname.*) catch |err| {
        io.print("Error unlinking tmp file name '{s}'\nError: {s}", .{ tmpname, @errorName(err) });
        return ShmError.UnlinkFailed;
    };

    return fd;
}

fn createAnonymousFile(size: usize) CreateAnonymousFileError!fd_t {
    const template = "/wlblocks-shared-XXXXXX";

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const xdg_runtime_dir = try getRuntimeDir();
    var name = try std.fmt.bufPrintZ(&path_buf, "{s}{s}", .{ xdg_runtime_dir, template });

    const fd = try createTmpfileCloexec(&name);

    posix.ftruncate(fd, size) catch |err| {
        posix.close(fd);
        return err;
    };

    return fd;
}

fn getRuntimeDir() ShmError![:0]const u8 {
    const path = posix.getenvZ("XDG_RUNTIME_DIR") orelse {
        return ShmError.Enoent;
    };
    return path;
}

pub fn draw(mtx: PixelMatrix, shm_data: [*]u32) void {
    const x_off = getHrizOffset(mtx.width);
    const y_off = getVertOffset(mtx.height);
    var pixel = (y_off.pre * xdg.width) + x_off.pre;

    for (mtx.rows) |row| {
        for (row) |val| {
            shm_data[pixel] = val;
            pixel += 1;
        }
        pixel += x_off.pre + x_off.post;
    }
}

const Offset = struct { pre: usize, post: usize };
fn getVertOffset(height: usize) Offset {
    if (xdg.height <= height) {
        return Offset{ .pre = 0, .post = 0 };
    }
    const margin = xdg.height - height;
    const pre = @divTrunc(margin, 2);
    const post = if (margin % 2 == 0) pre else pre + 1;
    return Offset{ .pre = pre, .post = post };
}
fn getHrizOffset(width: usize) Offset {
    if (xdg.width <= width) {
        return Offset{ .pre = 0, .post = 0 };
    }
    const margin = xdg.width - width;
    const pre = @divTrunc(margin, 2);
    const post = if (margin % 2 == 0) pre else pre + 1;
    return Offset{ .pre = pre, .post = post };
}
