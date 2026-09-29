// CRIS: CPU, RAM, Internet, Storage as one line of bar text. x86-64 Linux, no libc.
// usage: cris [options [seconds [mount...]]]   (no arguments: cris p 3 /)
// options: p ping 1.1.1.1, n network speed, t CPU temperature, g GPU load and temperature, s swap, f full labels
#include <linux/sockios.h>
#include <netinet/in.h>
#include <sys/statfs.h>
#include <sys/syscall.h>
#include <time.h>
#define S(n, a, b, c) sys(n, (long)(a), (long)(b), (long)(c), 0, 0)
#define ON(c) (on >> ((c) & 31) & 1)
#define L(full, short) (ON('f') ? full : short)  // labels: c r i s by default, cpu ram net disk with f
__asm__(".globl _start\n_start: mov %rsp, %rdi\n and $-16, %rsp\n call run");

static long sys(long n, long a, long b, long c, long e, long f) {
  register long r10 __asm__("r10") = 0, r8 __asm__("r8") = e, r9 __asm__("r9") = f;
  __asm__ volatile("syscall" : "+a"(n) : "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "memory");
  return n;
}
static long ms(void) { struct timespec t; S(SYS_clock_gettime, CLOCK_MONOTONIC, &t, 0); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }
static long num(char **p) { long n = 0; while (**p && (**p < '0' || **p > '9')) ++*p; while (**p >= '0' && **p <= '9') n = n * 10 + *(*p)++ - '0'; return n; }
static char *is(char *s, const char *pre) { while (*pre) if (*s++ != *pre++) return 0; return s; }  // s after pre, or 0
static long key(char *b, const char *k) { char *q; for (; *b; b++) if ((q = is(b, k))) return num(&q); return 0; }
static char *f(char *o, const char *s, long n, const char *z) {  // s with # replaced by n and $ by z
  char d[20], *e;
  for (; *s; s++)
    if (*s == '$') for (e = (char *)z; *e;) *o++ = *e++;
    else if (*s != '#') *o++ = *s;
    else { for (e = d; *e++ = '0' + n % 10, n /= 10;); while (e > d) *o++ = *--e; }
  return o;
}
static long rd(long fd, char *b, long n) { long r = fd < 0 ? 0 : S(SYS_pread64, fd, b, n - 1); b[r > 0 ? r : 0] = 0; return r; }
static long val(long fd) { char t[24], *p = t; rd(fd, t, sizeof t); return num(&p); }
static long at(const char *s, long n, const char *z) { char p[128]; *f(p, s, n, z) = 0; return S(SYS_open, p, 0, 0); }
static char *spd(char *o, const char *s, long b) {  // bytes/s as 999K, 1.2M or 12M
  return b < 1000000 ? f(o, "$#K", b / 1000, s) : b < 10000000 ? f(f(o, "$#.", b / 1000000, s), "#M", b / 100000 % 10, 0) : f(o, "$#M", b / 1000000, s);
}

void run(long *sp) {
  char **av = (char **)(sp + 1), *op = sp[0] > 1 ? av[1] : "p", *root = "/", **dk = sp[0] > 2 ? av + 3 : &root;
  char b[2048], t[16], p[96], nic[20] = "", *q, *o, *l;
  long on = 0, nd = sp[0] > 2 ? sp[0] - 3 : 1, tick = sp[0] > 2 ? (q = av[2], num(&q) * 1000) : 3000;
  long ft = -1, fg = -1, fr = -1, fh = -1, gap = 0, gw = -99999, gl = 0, gt = -1, x, pi = 0, pw = 0, prx = 0, ptx = 0;
  for (q = op; *q; q++) on |= 1L << (*q & 31);
  for (long i = 0; ON('t') && i < 32 && ft < 0; i++, S(SYS_close, x, 0, 0))  // AMD k10temp/zenpower or Intel coretemp
    if (rd(x = at("/sys/class/hwmon/hwmon#/name", i, 0), t, sizeof t) && (is(t, "k10temp") || is(t, "zenpower") || is(t, "coretemp")))
      ft = at("/sys/class/hwmon/hwmon#/temp1_input", i, 0);
  for (long c = 0; ON('g') && c < 8 && fg < 0; c++)  // first GPU with a load counter (amdgpu) and its own temperature
    if ((fg = at("/sys/class/drm/card#/device/gpu_busy_percent", c, 0)) >= 0) {
      *f(p, "/sys/class/drm/card#/device/", c, 0) = 0;
      fr = at("$power/runtime_status", 0, p);
      // Each read resets the runtime-PM idle timer: with runtime PM on, read once per autosuspend delay so it can sleep.
      if (rd(x = at("$power/control", 0, p), t, sizeof t) && *t == 'a') gap = val(at("$power/autosuspend_delay_ms", 0, p)) + 1000;
      for (long k = 0; k < 32 && fh < 0; k++) fh = at("$hwmon/hwmon#/temp1_input", k, p);
    }
  unsigned short h[4] = { 8 }, r[4];  // ICMP echo request; the kernel fills id and checksum
  unsigned long m[16], nc = 0, n = S(SYS_sched_getaffinity, 0, sizeof m, m);
  for (unsigned long i = 0; i < n * 8; i++) nc += m[i / 64] >> i % 64 & 1;
  struct sockaddr_in a = { AF_INET, 0, { 0x01010101 } };  // 1.1.1.1
  long ic = ON('p') ? S(SYS_socket, AF_INET, SOCK_DGRAM | SOCK_NONBLOCK, IPPROTO_ICMP) : -1, rtt, fu = S(SYS_open, "/proc/uptime", 0, 0),
       fm = S(SYS_open, "/proc/meminfo", 0, 0), fn = ON('n') ? S(SYS_open, "/proc/net/route", 0, 0) : -1,
       fd = fn < 0 ? -1 : S(SYS_open, "/proc/net/dev", 0, 0);
  struct statfs sf;
  struct timespec s0, ts;
  S(SYS_ioctl, ic, SIOCGSTAMPNS, &ts);  // turns on kernel receive timestamps, so a reply never has to wake us
  if (tick < 1000) tick = 1000;
  for (;;) {
    long t0 = ms(), rx = 0, tx = 0, id;
    for (rtt = h[3] ? -1 : -2; ic >= 0 && S(SYS_read, ic, r, sizeof r) > 0;)  // the reply to last tick's ping
      if (r[3] == h[3] && !S(SYS_ioctl, ic, SIOCGSTAMPNS, &ts)) rtt = (ts.tv_sec - s0.tv_sec) * 1000 + (ts.tv_nsec - s0.tv_nsec) / 1000000;
    if (ic >= 0) h[3]++, S(SYS_clock_gettime, CLOCK_REALTIME, &s0, 0), sys(SYS_sendto, ic, (long)h, sizeof h, (long)&a, sizeof a);
    rd(fu, b, 64), q = b, num(&q), num(&q), id = num(&q) * 100, id += num(&q);  // idle centiseconds over all CPUs
    long cpu = pw ? 100 - 1000 * (id - pi) / ((t0 - pw) * nc) : 0;
    rd(fm, b, 640);
    long mt = key(b, "MemTotal:"), ma = key(b, "MemAvailable:"), st = key(b, "SwapTotal:"), sw = key(b, "SwapFree:");
    if (fn >= 0) {  // traffic of the interface holding the default route (the line whose destination is 00000000)
      for (rd(fn, b, 1024), q = b; *q; q = l + (*l != 0)) {
        for (o = q; *o && *o != '\t'; o++);
        for (l = o; *l && *l != '\n'; l++);
        if (is(o, "\t00000000\t")) break;
      }
      for (x = 0; x < 16 && q + x < o; x++) p[x] = q[x];
      p[x] = ':', p[x + 1] = 0;
      if (!(l = is(nic, p)) || *l) for (x = 0, prx = ptx = 0; (nic[x] = p[x]); x++);  // new interface: restart the rate
      for (rd(fd, b, sizeof b), q = b; *q; q++)  // "  name: rx_bytes packets errs drop fifo frame compressed multicast tx_bytes"
        if ((q == b || q[-1] == ' ' || q[-1] == '\n') && (o = is(q, nic))) {
          for (rx = num(&o), x = 0; x < 8; x++) tx = num(&o);
          break;
        }
    }

    o = f(b, "$: #%", cpu < 0 ? 0 : cpu > 100 ? 100 : cpu, L("cpu", "c"));
    if (ft >= 0) o = f(o, " $: #°", (val(ft) + 500) / 1000, L("temp", "t"));  // millidegrees
    if (fg >= 0 && (rd(fr, t, sizeof t), *t == 's')) o = f(o, " $: off", 0, L("gpu", "g"));  // suspended: a read would wake it
    else if (fg >= 0) {
      if (t0 - gw >= gap) gl = val(fg), gt = fh < 0 ? -1 : val(fh), gw = t0;
      o = f(o, " $: #%", gl, L("gpu", "g"));
      if (gt >= 0) o = f(o, " $: #°", (gt + 500) / 1000, L("temp", "t"));
    }
    o = f(o, " $: #%", (100 * (mt - ma) + mt / 2) / mt, L("ram", "r"));
    if (ON('s')) o = f(o, " $: #%", st ? (100 * (st - sw) + st / 2) / st : 0, L("swap", "sw"));
    if (ON('p') || fn >= 0) o = f(o, " $:", 0, L("net", "i"));
    if (ON('p')) o = f(o, ic < 0 ? " n/a" : rtt == -2 ? " …" : rtt < 0 ? " down" : " # ms", rtt, 0);
    if (fn >= 0) o = spd(spd(o, " ↓", prx && rx > prx ? (rx - prx) * 1000 / (t0 - pw) : 0),
                         " ↑", ptx && tx > ptx ? (tx - ptx) * 1000 / (t0 - pw) : 0);
    for (long i = 0; i < nd; i++) {  // used / (used + avail), rounded up like df; labelled by last path component
      for (q = l = dk[i]; *q; q++) if (*q == '/' && q[1]) l = q + 1;
      long du = S(SYS_statfs, dk[i], &sf, 0) < 0 ? -1 : (long)(sf.f_blocks - sf.f_bfree), dt = du + (long)sf.f_bavail;
      o = du < 0 ? f(o, " $: ?", 0, i ? l : L("disk", "s")) : f(o, " $: #%", dt ? (100 * du + dt - 1) / dt : 0, i ? l : L("disk", "s"));
    }
    *o++ = '\n', pi = id, pw = t0, prx = rx, ptx = tx;
    if (S(SYS_write, 1, b, o - b) < 0) S(SYS_exit, 0, 0, 0);  // the bar went away
    S(SYS_poll, 0, 0, tick - (ms() - t0));  // sleep out the tick
  }
}
