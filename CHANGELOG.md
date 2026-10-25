# Changelog

## Unreleased

### Fixed
- A build that fails with gcc installed (wrong architecture, full disk, unwritable cache) no longer reads
  "cris needs gcc". It says the build failed, removes its temporary file and exits 1, so the widget retries it
  with the usual backoff. A missing compiler still asks for gcc.
- CPU and speed read `…` on the first tick, like the ping, instead of `c: 0%` and `↓0K ↑0K`. That first tick
  follows every start and every settings change. Speed also reads `…` for one tick after the default route
  moves to another interface. With no default route (offline) it reads `↓0K ↑0K` from the second
  tick, as before. The binary grows by 48 bytes, to 5,560.
- A home without `~/.cache` no longer loops on "build failed, retrying": the widget creates the directory
  before it compiles.

### Changed
- Tests: `tests/check.sh` runs the widget's own launch line (no compiler, a failing compiler, 4 bars starting
  together), checks the first-tick `…`, and builds into `build/` instead of leaving `./cris` in the repository.

## 1.0.1 — 2026-10-14

### Fixed
- CPU share stays right when CPUs go on or offline: the online count is re-read every 8th tick instead of once at start.
- RAM and swap read `0%` instead of stopping the sampler when `/proc/meminfo` cannot be read.
- Memory fields are parsed only when RAM or swap is shown, so a ping-only or speed-only line never scans an unfilled buffer.
- CPU temperature and GPU, when turned on but absent, read `n/a` (like the ping) instead of vanishing from the line.
- The widget restarts a sampler that was killed or crashed, after 5 s, doubling up to 5 min.
- The interval setting is validated: anything that is not a whole number of seconds of at least 1 falls back to 3 s.
- Sampler arguments are passed as JSON, so a mount point with any character in its name reaches the sampler intact.

### Changed
- Each tick sleeps with one `clock_nanosleep` to an absolute monotonic deadline (one syscall fewer per tick than
  `clock_gettime` + `poll`, and no 32-bit timeout limit for long intervals).
- Built with `-Oz`; syscalls of up to three arguments no longer load the unused argument registers. With the fixes
  above, the binary stays at 5,512 bytes.
- Tests: regression checks for each fix (missing sensors, ping socket refused, unreadable meminfo, CPU hotplug,
  tick count), a RAM check that tolerates a busy host, and all build output under `build/` in the repo.
