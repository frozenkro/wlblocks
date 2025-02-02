const std = @import("std");
const posix = std.posix;
const os = std.os;
const cstd = @cImport({
    @cInclude("stdlib.h");
});

const ShmError = error{
    Enoent,
    NoFd,
    NoFlags,
    FileSizeError,
};

const CreateAnonymousFileError = std.fmt.BufPrintError || posix.TruncateError || ShmError;

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

fn create_tmpfile_cloexec(tmpname: *u8) !usize {
    const fd_c: c_int = cstd.mkstemp(tmpname);
    var fd: usize = @intCast(fd_c);
    if (fd >= 0) {
        fd = set_cloexec_or_close(fd);
        posix.unlink(tmpname);
    }
}

fn os_create_anonymous_file(size: u64) CreateAnonymousFileError!usize {
    const template: []u8 = "/wlblocks-shared-XXXXXX";

    const path: []u8 = posix.getenv("XDG_RUNTIME_DIR");
    if (path == null) {
        return ShmError.Enoent;
    }

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
