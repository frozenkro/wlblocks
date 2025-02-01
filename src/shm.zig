const std = @import("std");
const posix = std.posix;
const mman = @cImport({
    @cInclude("sys/mman.h");
});
const errno = @cImport({
    @cInclude("errno.h");
});
const cstd = @cImport({
    @cInclude("stdlib.h");
});

fn set_cloexec_or_close(fd: usize) usize {
    var flags: i64 = 0;

    if (fd == -1) {
        return -1;
    }

    flags = posix.fcntl(fd, posix.F.GETFD, 0);
    if (flags == -1 || (posix.fcntl(fd, posix.F.SETFD, flags | posix.FD_CLOEXEC) == -1)) {
        posix.close(fd);
        return -1;
    }

    return fd;
}

fn create_tmpfile_cloexec(tmpname: *u8) usize {
    var fd: usize = 0;

    fd = cstd.mkstemp(tmpname);
    if (fd >= 0) {
        fd = set_cloexec_or_close(fd);
        posix.unlink(tmpname);
    }
}
