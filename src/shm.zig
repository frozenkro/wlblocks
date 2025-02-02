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
};

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

fn os_create_anonymous_file(size: u64) ShmError!usize {
    const template: []u8 = "/wlblocks-shared-XXXXXX";
    const name: *u8 = null;
    var fd: usize = 0;

    const path: []u8 = posix.getenv("XDG_RUNTIME_DIR");
    if (path == null) {
        return ShmError.Enoent;
    }



}
