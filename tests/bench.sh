#!/bin/sh
# Footprint receipts over 60 s at the default 3 s interval: CRIS with defaults and with every option,
# next to a program that does nothing but wake every 3 s (the floor any monitor pays).
set -e
cd "$(dirname "$0")/.."
flags=$(grep -o -- '-Os [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
cc $flags -o /tmp/cris-bench cris.c
printf '%s\n' '#include <sys/syscall.h>' '__asm__(".globl _start\n_start: and $-16, %rsp\n call run");' \
  'void run(void) { for (long n;;) { n = SYS_poll; __asm__ volatile("syscall" : "+a"(n) : "D"(0), "S"(0), "d"(3000) : "rcx", "r11", "memory"); } }' \
  > /tmp/cris-idle.c && cc $flags -o /tmp/cris-idle /tmp/cris-idle.c
env -i /tmp/cris-bench >/dev/null & a=$!; env -i /tmp/cris-bench tgspn 3 / >/dev/null & b=$!; env -i /tmp/cris-idle & c=$!
sleep 60
for p in $a $b $c; do
  read -r ns _ < /proc/$p/schedstat
  printf '%-12s %5s KB RAM  %4s us CPU per tick\n' "$([ $p = $a ] && echo defaults || { [ $p = $b ] && echo 'all options' || echo 'do nothing'; })" \
    "$(awk '/VmRSS/{print $2}' /proc/$p/status)" $((ns / 20000))
done
echo "binary: $(stat -c %s /tmp/cris-bench) bytes"
kill $a $b $c; rm -f /tmp/cris-bench /tmp/cris-idle /tmp/cris-idle.c
