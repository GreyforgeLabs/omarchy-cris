# CRIS

    omarchy plugin add https://github.com/GreyforgeLabs/omarchy-cris --enable

**C**PU, **R**AM, **I**nternet, **S**torage. The lightest system monitor on the planet.

    c: 4% r: 57% i: 24 ms s: 75%

Click it for settings. Bright is on, dim is off:

    show    cpu  temp  gpu  ram  swap  ping  speed
    every   1s  3s  5s  10s
    labels  cris  full                        full: cpu: 4% ram: 57% net: 24 ms disk: 75%
    disks   /  /boot  /mnt/data               found automatically

## Why these four

- **cpu**: is the machine busy? One number for all cores.
- **ram**: real memory pressure (`MemTotal - MemAvailable`). Cache does not count as used.
- **internet**: latency, not bandwidth. Latency is what you feel in every page load, call, game and
  SSH session, and a ping shows a dead connection instantly. Want bandwidth anyway? Turn on speed.
- **storage**: space used. A full disk is the failure that silently breaks everything else.

## How light

|                                    | RAM       | CPU per 3 s tick  |
| ---------------------------------- | --------- | ----------------- |
| a program that only sleeps         | 12 KB     | ~60 µs            |
| **CRIS**                           | **16 KB** | **~70-120 µs**    |
| suckless slstatus (cpu, ram, disk) | 2,556 KB  | ~250 µs, no ping  |
| top (batch mode)                   | 6,100 KB  | ~11,000 µs        |
| btop                               | 32,188 KB |                   |

One 5 KB process per bar, with no libc and no environment: raw syscalls, files and socket opened once, one
wakeup per tick, nothing read that you did not turn on. The ping reply is timestamped by the kernel,
so it never wakes CRIS up. Measure it yourself: `tests/bench.sh` (the others were measured the same way, side by
side on the same machine, in September 2026).

x86-64 Linux. Compiles itself on first run with gcc, which Omarchy ships. MIT © Greyforge Labs.
