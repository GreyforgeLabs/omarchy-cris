# CRIS

    omarchy plugin add https://github.com/GreyforgeLabs/omarchy-cris --enable

**C**PU, **R**AM, **I**nternet, **S**torage. The most minimalistic resource monitor on the planet.

    cpu: 4% ram: 57% net: 24 ms disk: 75%

Four numbers, because these are the four that matter:

- **cpu**: is the machine busy? One number for all cores.
- **ram**: real memory pressure (`MemTotal - MemAvailable`). Cache is not counted as used.
- **net**: latency, not throughput. Latency is what you feel in every page load, call, game and SSH
  session, and a ping shows a dead connection instantly.
- **disk**: space left. A full disk is the failure that silently breaks everything else.

## Options

In the widget's settings. Anything left off is never read.

| Setting         | Default   |                                                         |
| --------------- | --------- | ------------------------------------------------------- |
| CPU temperature | off       | `cpu: 4% 52°`                                           |
| GPU             | off       | `gpu: 12% 45°` (AMD). Shows `off` while the GPU sleeps, and never wakes it |
| Swap            | off       | `swap: 3%`                                              |
| Update every    | 3 s       |                                                         |
| Ping host       | `1.1.1.1` | any IPv4 address                                        |
| Disks           | `/`       | mount points, e.g. `/ /home /mnt/data` → `disk: 75% home: 40% data: 91%` |

## Numbers

One 4 KB process with no libc: raw syscalls, files and socket kept open, asleep between ticks.
Measured at the 3 s interval with `tests/bench.sh`:

|                   | Binary       | RAM      | CPU per tick |
| ----------------- | ------------ | -------- | ------------ |
| CRIS              | 4.2 KB       | 28 KB    | 98 µs, including the ping |
| CRIS, all options | 4.2 KB       | 28 KB    | 358 µs (AMD GPU firmware reads are most of it) |
| suckless slstatus | 36 KB + libc | 2,588 KB | 240 µs, no ping |

x86-64 Linux, needs `cc`. MIT © Greyforge Labs.
