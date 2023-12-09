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

Yeah, enabled debugging in the database and also set some additional env vars in docker-compose for debugging; I'm now getting debug logs from the various scripts right away.

Notable that the container starts, I get those socket file issues, and during that time the `/usr/bin/perl -wT /usr/bin/zmdc.pl startup` process is consuming 100% CPU and in Run state. After ~14 minutes the CPU usage drops to ~53% and it starts up:

```
root@13f0d8732d7d:/var/log/zm# cat zmdc.log 
12/08/23 09:05:01.758848 zmdc[69].FAT [main:195] [Can't connect to zmdc.pl server process at /run/zm/zmdc.sock: No such file or directory]
12/08/23 09:19:19.202723 zmdc[71].INF [ZMServer:411] [Server starting at 23/12/08 09:19:19]
12/08/23 09:19:20.301471 zmdc[71].INF [ZMServer:411] [Socket should be open at /run/zm/zmdc.sock]
12/08/23 09:37:26.715231 zmdc[46].DB1 [ZoneMinder::Logger:321] [LogOpts: level=DB9/DB1, screen=OFF, database=INF, logfile=DB1->/var/log/zm/zmdc.log, syslog=OFF]
12/08/23 09:37:26.715443 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 1]
12/08/23 09:37:26.915572 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 2]
12/08/23 09:37:27.115778 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 3]
12/08/23 09:37:27.315954 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 4]
12/08/23 09:37:27.516128 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 5]
12/08/23 09:37:27.716303 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 6]
12/08/23 09:37:27.916493 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 7]
12/08/23 09:37:28.116717 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 8]
12/08/23 09:37:28.316915 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 9]
12/08/23 09:37:28.518404 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 10]
12/08/23 09:37:28.718611 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 11]
12/08/23 09:37:28.918794 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 12]
12/08/23 09:37:29.118976 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 13]
12/08/23 09:37:29.319175 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 14]
12/08/23 09:37:29.519385 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 15]
12/08/23 09:37:29.719584 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 16]
12/08/23 09:37:29.919756 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 17]
12/08/23 09:37:30.119933 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 18]
12/08/23 09:37:30.320115 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 19]
12/08/23 09:37:30.520287 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 20]
12/08/23 09:37:30.720479 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 21]
12/08/23 09:37:30.920667 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 22]
12/08/23 09:37:31.120846 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 23]
12/08/23 09:37:31.321082 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 24]
12/08/23 09:37:31.521252 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 25]
12/08/23 09:37:31.721432 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 26]
12/08/23 09:37:31.921612 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 27]
12/08/23 09:37:32.121797 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 28]
12/08/23 09:37:32.322000 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 29]
12/08/23 09:37:32.522203 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 30]
12/08/23 09:37:32.722397 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 31]
12/08/23 09:37:32.922629 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 32]
12/08/23 09:37:33.122842 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 33]
12/08/23 09:37:33.323039 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 34]
12/08/23 09:37:33.523231 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 35]
12/08/23 09:37:33.723433 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 36]
12/08/23 09:37:33.923620 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 37]
12/08/23 09:37:34.123808 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 38]
12/08/23 09:37:34.323998 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 39]
12/08/23 09:37:34.524171 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 40]
12/08/23 09:37:34.724335 zmdc[46].DB1 [main:194] [Waiting for zmdc.pl server process at /run/zm/zmdc.sock, attempt 41]
12/08/23 09:37:34.724426 zmdc[46].FAT [main:195] [Can't connect to zmdc.pl server process at /run/zm/zmdc.sock: No such file or directory]
12/08/23 09:51:32.618669 zmdc[48].DB1 [ZoneMinder::Logger:321] [LogOpts: level=DB9/DB1, screen=OFF, database=INF, logfile=DB1->/var/log/zm/zmdc.log, syslog=OFF]
12/08/23 09:51:32.618811 zmdc[48].INF [ZMServer:411] [Server starting at 23/12/08 09:51:32]
12/08/23 09:51:32.653869 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmc]
12/08/23 09:51:32.655789 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmfilter.pl]
12/08/23 09:51:32.657181 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmaudit.pl]
12/08/23 09:51:32.658549 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmtrigger.pl]
12/08/23 09:51:32.659736 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmx10.pl]
12/08/23 09:51:32.660950 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmwatch.pl]
12/08/23 09:51:32.662175 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmupdate.pl]
12/08/23 09:51:32.663664 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmstats.pl]
12/08/23 09:51:32.664961 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmtrack.pl]
12/08/23 09:51:32.667051 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmcontrol.pl]
12/08/23 09:51:32.668470 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zm_rtsp_server]
12/08/23 09:51:32.669838 zmdc[48].DB1 [ZMServer:863] [killall -q -s TERM zmtelemetry.pl]
12/08/23 09:51:33.671441 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmc]
12/08/23 09:51:33.673627 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmfilter.pl]
12/08/23 09:51:33.675392 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmaudit.pl]
12/08/23 09:51:33.677219 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmtrigger.pl]
12/08/23 09:51:33.678941 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmx10.pl]
12/08/23 09:51:33.680940 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmwatch.pl]
12/08/23 09:51:33.682424 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmupdate.pl]
12/08/23 09:51:33.683651 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmstats.pl]
12/08/23 09:51:33.684909 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmtrack.pl]
12/08/23 09:51:33.686577 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmcontrol.pl]
12/08/23 09:51:33.688052 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zm_rtsp_server]
12/08/23 09:51:33.689277 zmdc[48].DB1 [ZMServer:869] [killall -q -s KILL zmtelemetry.pl]
12/08/23 09:51:33.690841 zmdc[48].INF [ZMServer:411] [Socket should be open at /run/zm/zmdc.sock]
```

Note that it looks like the debug logging WAS from the ZM configuration not the env vars; the env vars don't seem to do anything.

So, I put the strace stuff back in, but now it seems like the zmdc behavior is different, it's only using 22% CPU. It's still failing to start zmdc correctly, but doesn't appear to be hogging all the CPU; maybe a side-effect of `strace`?

```
www-data      34 70.9  0.0   5032  3456 ?        R    10:38   1:19 strace -ff -o /var/log/zm/strace /usr/bin/zmpkg.pl start
www-data      51 21.9  0.0  26108 14648 ?        R    10:38   0:24 /usr/bin/perl -wT /usr/bin/zmdc.pl startup
```

a bit later, right now:

```
www-data      34 70.7  0.0   5032  3456 ?        R    10:38   6:23 strace -ff -o /var/log/zm/strace /usr/bin/zmpkg.pl start
www-data      51 22.0  0.0  26108 14648 ?        t    10:38   1:59 /usr/bin/perl -wT /usr/bin/zmdc.pl startup
```

Ok, with strace, it's been running 17 minutes now and still just stuck in the prlimit64/close loop but only usng 22% CPU.

Let's try this with strace at startup toggleable by an env var, and then I'll start everything fresh from scratch and not strace, but attach once the process is running. Now I'll be able to set STRACE_ZMPKG=true if I want to strace at startup.

Ok, just started without strace,

```
www-data      71 99.7  0.0  26088 14636 ?        R    11:04   0:42 /usr/bin/perl -wT /usr/bin/zmdc.pl startup
```

```
root@c704e30eca79:/# strace -p 71 -f
strace: attach: ptrace(PTRACE_SEIZE, 71): Operation not permitted
```

can't do that from within the container, need to find the process on the host and strace from there. I do that, and it appears to be still stuck in the prlimit64/close loop.

Ok, I let that run for 40 minutes with strace attached to the process (from the host) and it never got out of the loop.

**Ok,** At this point, it's clear that something just REALLY isn't working, and it doesn't make any sense. I could try running the container privileged, and I could try setting a limit on the number of open files in the container. Other than that, I think I need to either start over from scratch, or look at other _working_ images and see what's different about mine.
