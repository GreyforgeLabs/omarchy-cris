// CRIS: cpu, ram, internet (ping), storage as one line of bar text. x86-64 Linux, no libc.
// usage: cris [options] [seconds] [ipv4] [mounts]   options: t = cpu temperature, g = GPU load and temperature, s = swap
// mounts: space- or comma-separated, default "/"; the first is labelled disk, the rest by their last path component
#include <netinet/in.h>
#include <poll.h>
#include <sys/statfs.h>
#include <sys/syscall.h>
#include <time.h>
#define S(n, a, b, c) sys(n, (long)(a), (long)(b), (long)(c), 0, 0)
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
static char *put(char *o, const char *s, long n) {  // s, then n unless n < 0
  char d[20], *e = d;
  while (*s) *o++ = *s++;
  if (n >= 0) do *e++ = '0' + n % 10; while (n /= 10);
  while (e > d) *o++ = *--e;
  return o;
}
static long rd(long fd, char *b, long n) { long r = fd < 0 ? 0 : S(SYS_pread64, fd, b, n - 1); b[r > 0 ? r : 0] = 0; return r; }
static long val(long fd) { char t[24], *p = t; rd(fd, t, sizeof t); return num(&p); }
static long opn(char *p, char *end) { *end = 0; return S(SYS_open, p, 0, 0); }
static char *deg(char *o, long md) { return md < 0 ? o : put(put(o, " ", (md + 500) / 1000), "°", -1); }  // millidegrees

void run(long *sp) {
  char **av = (char **)(sp + 1), *opt = sp[0] > 1 ? av[1] : "", b[2048], t[16], p[96], *q, *o;
  long tick = sp[0] > 2 ? (q = av[2], num(&q) * 1000) : 3000, ft = -1, fg = -1, fr = -1, fh = -1, sw = 0, gap = 0, gw = -99999, gl = 0, gt = -1, x;
  struct sockaddr_in a = { AF_INET, 0, { 0x01010101 } };  // 1.1.1.1 unless given
  unsigned char ip[4] = { 0 };  // dotted IPv4; anything unparsable keeps 1.1.1.1
  if (sp[0] > 3) for (int i = (q = av[3], 0); i < 4; i++) ip[i] = num(&q);
  if (*(unsigned *)ip) a.sin_addr.s_addr = *(unsigned *)ip;
  for (; *opt; opt++) {
    if (*opt == 's') sw = 1;
    if (*opt == 't')  // first CPU sensor: AMD k10temp/zenpower or Intel coretemp
      for (long i = 0; i < 32 && ft < 0; i++, S(SYS_close, x, 0, 0))
        if ((x = opn(p, put(put(p, "/sys/class/hwmon/hwmon", i), "/name", -1))) >= 0 && rd(x, t, sizeof t) &&
            (is(t, "k10temp") || is(t, "zenpower") || is(t, "coretemp")))
          ft = opn(p, put(put(p, "/sys/class/hwmon/hwmon", i), "/temp1_input", -1));
    if (*opt == 'g')  // first GPU with a load counter (amdgpu), plus its own hwmon for temperature
      for (long c = 0; c < 8 && fg < 0; c++)
        if ((fg = opn(p, put(put(p, "/sys/class/drm/card", c), "/device/gpu_busy_percent", -1))) >= 0) {
          fr = opn(p, put(put(p, "/sys/class/drm/card", c), "/device/power/runtime_status", -1));
          // Each read resets the runtime-PM idle timer: with runtime PM on, read only once per autosuspend delay so it can sleep.
          if (rd(x = opn(p, put(put(p, "/sys/class/drm/card", c), "/device/power/control", -1)), t, sizeof t) && *t == 'a')
            gap = val(opn(p, put(put(p, "/sys/class/drm/card", c), "/device/power/autosuspend_delay_ms", -1))) + 1000;
          S(SYS_close, x, 0, 0);
          for (long k = 0; k < 32 && fh < 0; k++)
            fh = opn(p, put(put(put(p, "/sys/class/drm/card", c), "/device/hwmon/hwmon", k), "/temp1_input", -1));
        }
  }
  if (tick < 1000) tick = 1000;
  char dp[8][256], dl[8][24], *dk = sp[0] > 4 ? av[4] : "/";
  int nd = 0;
  while (*dk && nd < 8) {
    if (*dk == ' ' || *dk == ',') { dk++; continue; }
    char *e = dp[nd], *l = dl[nd], *base = dp[nd];
    while (*dk && *dk != ' ' && *dk != ',') if (e < dp[nd] + 255) *e++ = *dk++; else dk++;
    *e = 0;
    for (e = dp[nd]; *e; e++) if (*e == '/' && e[1]) base = e + 1;
    for (e = nd ? base : "disk"; *e && l < dl[nd] + 23;) *l++ = *e++;
    *l = 0, nd++;
  }
  unsigned short h[4] = { 8 }, r[4];  // ICMP echo request; the kernel fills id and checksum
  unsigned long m[16], nc = 0, n = S(SYS_sched_getaffinity, 0, sizeof m, m);
  for (unsigned long i = 0; i < n * 8; i++) nc += m[i / 64] >> i % 64 & 1;
  long ic = S(SYS_socket, AF_INET, SOCK_DGRAM, IPPROTO_ICMP), fc = S(SYS_open, "/sys/fs/cgroup/cpu.stat", 0, 0),
       fm = S(SYS_open, "/proc/meminfo", 0, 0), pu = 0, pw = 0, left;
  struct pollfd w = { ic, POLLIN, 0 };
  struct statfs f;
  for (;;) {
    long t0 = ms(), rtt = -1;
    h[3]++, sys(SYS_sendto, ic, (long)h, sizeof h, (long)&a, sizeof a);
    long us = val(fc), cpu = pw ? (us - pu) / ((t0 - pw) * 10 * nc) : 0;  // usage_usec: busy time over all CPUs
    pu = us, pw = t0;
    rd(fm, b, sizeof b);
    long mt = key(b, "MemTotal:"), ma = key(b, "MemAvailable:"), st = key(b, "SwapTotal:"), sf = key(b, "SwapFree:");
    while ((left = t0 + 1000 - ms()) > 0 && S(SYS_poll, &w, 1, left) > 0 && S(SYS_read, ic, r, sizeof r) > 0)
      if (r[3] == h[3]) { rtt = ms() - t0; break; }  // skip late replies to earlier pings

    o = deg(put(put(b, "cpu: ", cpu > 100 ? 100 : cpu), "%", -1), ft < 0 ? -1 : val(ft));
    if (fg >= 0 && (rd(fr, t, sizeof t), *t == 's')) o = put(o, " gpu: off", -1);  // suspended: a read would wake it
    else if (fg >= 0) {
      if (t0 - gw >= gap) gl = val(fg), gt = fh < 0 ? -1 : val(fh), gw = t0;
      o = deg(put(put(o, " gpu: ", gl), "%", -1), gt);
    }
    o = put(put(o, " ram: ", (100 * (mt - ma) + mt / 2) / mt), "%", -1);
    if (sw) o = put(put(o, " swap: ", st ? (100 * (st - sf) + st / 2) / st : 0), "%", -1);
    o = rtt < 0 ? put(o, " net: down", -1) : put(put(o, " net: ", rtt), " ms", -1);
    for (int i = 0; i < nd; i++) {  // used / (used + avail), rounded up like df
      o = put(put(put(o, " ", -1), dl[i], -1), ": ", -1);
      if (S(SYS_statfs, dp[i], &f, 0) < 0) { o = put(o, "?", -1); continue; }
      long du = f.f_blocks - f.f_bfree, dt = du + f.f_bavail;
      o = put(put(o, "", dt ? (100 * du + dt - 1) / dt : 0), "%", -1);
    }
    o = put(o, "\n", -1);
    if (S(SYS_write, 1, b, o - b) < 0) S(SYS_exit, 0, 0, 0);  // the bar went away
    S(SYS_poll, 0, 0, tick - (ms() - t0));  // sleep out the tick
  }
}
