# docker-zoneminder

Modern, best-practices Debian-based Zoneminder container

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

**IMPORTANT:** This is a personal project only. PRs are accepted, but this is not supported and "issues" will likely not be fixed or responded to. This is only for people who understand the details of everything invovled.

This repo attempts to provide a modern, best-practices Docker image for current ZoneMinder versions, using a current Debian version base. The image provides ZoneMinder and Apache but (like a proper Docker image) requires an external MySQL server. The image is vehemently NOT auto-updating, as doing so in a Docker image is a mortal sin. If you want to update, then pull a newer tag.

**NOTE:** If you want to use the event server, then you'll need to mount the appropriate configuration files in to the image at ``/etc/zm/es_rules.json``, ``/etc/zm/zmeventnotification.ini``, and ``/etc/zm/secrets.ini``; examples are included in this repo.

## Troubleshooting Notes

* Web UI loads but logs show zmdc failing with `Can't connect to zmdc.pl server process at /run/zm/zmdc.sock: No such file or directory` and zmpkg reporting `Unable to run "/usr/bin/zmdc.pl startup", output is "Starting server", status is 255` and then every subsequent zmpkg log reporting `Unable to run "/usr/bin/zmdc.pl start <anything>", output is "Unable to connect to server using socket at /run/zm/zmdc.sock", status is 255`

```
this is PID 52, which is the `/usr/bin/zmdc.pl startup` process...

socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 7
connect(7, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
close(7)                                = 0
socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0) = 7
connect(7, {sa_family=AF_UNIX, sun_path="/var/run/nscd/socket"}, 110) = -1 ENOENT (No such file or directory)
close(7)                                = 0
newfstatat(AT_FDCWD, "/etc/nsswitch.conf", {st_mode=S_IFREG|0644, st_size=494, ...}, 0) = 0
newfstatat(AT_FDCWD, "/", {st_mode=S_IFDIR|0755, st_size=4096, ...}, 0) = 0
openat(AT_FDCWD, "/etc/nsswitch.conf", O_RDONLY|O_CLOEXEC) = 7
newfstatat(7, "", {st_mode=S_IFREG|0644, st_size=494, ...}, AT_EMPTY_PATH) = 0
read(7, "# /etc/nsswitch.conf\n#\n# Example"..., 4096) = 494
read(7, "", 4096)                       = 0
newfstatat(7, "", {st_mode=S_IFREG|0644, st_size=494, ...}, AT_EMPTY_PATH) = 0
close(7)

openat(AT_FDCWD, "/lib/x86_64-linux-gnu/glibc-hwcaps/x86-64-v2/libnss_db.so.2", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)

then it does a SELECT from the Configuration table, which works...

socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0) = 4
fcntl(4, F_GETFD)                       = 0x1 (flags FD_CLOEXEC)
fcntl(4, F_SETFD, FD_CLOEXEC)           = 0
ioctl(4, TCGETS, 0x7ffc433de440)        = -1 ENOTTY (Inappropriate ioctl for device)
lseek(4, 0, SEEK_CUR)                   = -1 ESPIPE (Illegal seek)
fcntl(4, F_SETFD, FD_CLOEXEC)           = 0
ioctl(4, TCGETS, 0x7ffc433de440)        = -1 ENOTTY (Inappropriate ioctl for device)
lseek(4, 0, SEEK_CUR)                   = -1 ESPIPE (Illegal seek)
connect(4, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
write(1, "Starting server\n", 16)       = 16
close(4)                                = 0

...

rt_sigprocmask(SIG_SETMASK, ~[RTMIN RT_1], [], 8) = 0
clone(child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7f2bf91bca10) = 54
rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0
ioctl(2, TCGETS, 0x7ffc433de5e0)        = -1 ENOTTY (Inappropriate ioctl for device)
ioctl(2, TCGETS, 0x7ffc433de5e0)        = -1 ENOTTY (Inappropriate ioctl for device)
sendto(7, "\1\0\0\0\16", 5, MSG_DONTWAIT|MSG_NOSIGNAL, NULL, 0) = 5
recvfrom(7, "\7\0\0\1\0\0\0\2\0\0\0", 16384, MSG_DONTWAIT, NULL, NULL) = 11
openat(AT_FDCWD, "/var/log/zm/zmdc.log", O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC, 0666) = 4

...

socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0) = 5
fcntl(5, F_SETFD, FD_CLOEXEC)           = 0
ioctl(5, TCGETS, 0x7ffc433de440)        = -1 ENOTTY (Inappropriate ioctl for device)
lseek(5, 0, SEEK_CUR)                   = -1 ESPIPE (Illegal seek)
fcntl(5, F_SETFD, FD_CLOEXEC)           = 0
ioctl(5, TCGETS, 0x7ffc433de440)        = -1 ENOTTY (Inappropriate ioctl for device)
lseek(5, 0, SEEK_CUR)                   = -1 ESPIPE (Illegal seek)
connect(5, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
getpid()                                = 52
write(4, "12/07/23 13:16:25.628570 zmdc[52"..., 118) = 118
clock_nanosleep(CLOCK_REALTIME, 0, {tv_sec=0, tv_nsec=200000000}, NULL) = 0
connect(5, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
getpid()                                = 52
write(4, "12/07/23 13:16:25.828838 zmdc[52"..., 118) = 118
clock_nanosleep(CLOCK_REALTIME, 0, {tv_sec=0, tv_nsec=200000000}, NULL) = 0
connect(5, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
getpid()                                = 52
write(4, "12/07/23 13:16:26.029114 zmdc[52"..., 118) = 118
clock_nanosleep(CLOCK_REALTIME, 0, {tv_sec=0, tv_nsec=200000000}, NULL) = 0
connect(5, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
getpid()                                = 52
write(4, "12/07/23 13:16:26.229397 zmdc[52"..., 118) = 118
clock_nanosleep(CLOCK_REALTIME, 0, {tv_sec=0, tv_nsec=200000000}, NULL) = 0
connect(5, {sa_family=AF_UNIX, sun_path="/run/zm/zmdc.sock"}, 110) = -1 ENOENT (No such file or directory)
getpid()                                = 52

So that looks like it says it's starting the server, forks off PID 54, and then tries to connect to /run/zm/zmdc.sock

So what does 54 do?

It writes a PID file, and then goes into a loop calling `prlimit64` to set its RLIMIT_NOFILE (with the same arguments every time) and closing FDs from zero up to... 87373448? Or, it just keeps going. In fact, it's still going, after like an hour.

Yup, that literally just continued until it filled up my `/home` with a 106GB log file from strace, just showing the process closing ever-increasing FD numbers.
```

Ok, as of the commit that introduced this line I ripped out essentially all of the custom stuff in the image and also have it running an update before installing packages. This is an improvement... zmdc eventually starts, but it's taking fourteen (14) minutes!

```
12/08/23 09:05:01.758848 zmdc[69].FAT [main:195] [Can't connect to zmdc.pl server process at /run/zm/zmdc.sock: No such file or directory]
12/08/23 09:19:19.202723 zmdc[71].INF [ZMServer:411] [Server starting at 23/12/08 09:19:19]
12/08/23 09:19:20.301471 zmdc[71].INF [ZMServer:411] [Socket should be open at /run/zm/zmdc.sock]
```

Going to retry that with debug-level logging enabled... since `ZM_DBG_LEVEL=9` doesn't seem to do anything...
