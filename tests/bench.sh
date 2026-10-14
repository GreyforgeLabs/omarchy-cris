#!/bin/sh
# Footprint receipts over 60 s at the default 3 s interval: CRIS with defaults and with every option,
# next to a program that does nothing but wake every 3 s (the floor any monitor pays).
set -e
cd "$(dirname "$0")/.."
flags=$(grep -o -- '-O[sz] [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
out=build/bench; mkdir -p $out
cc $flags -o $out/cris cris.c
printf '%s\n' '#include <sys/syscall.h>' '__asm__(".globl _start\n_start: and $-16, %rsp\n call run");' \
  'void run(void) { for (long n;;) { n = SYS_poll; __asm__ volatile("syscall" : "+a"(n) : "D"(0), "S"(0), "d"(3000) : "rcx", "r11", "memory"); } }' \
  > $out/idle.c && cc $flags -o $out/idle $out/idle.c
env -i $out/cris >/dev/null & a=$!; env -i $out/cris crtgspn 3 / >/dev/null & b=$!; env -i $out/idle & c=$!
sleep 60
for p in $a $b $c; do
  read -r ns _ < /proc/$p/schedstat
  printf '%-12s %5s KB RAM  %4s us CPU per tick\n' "$([ $p = $a ] && echo defaults || { [ $p = $b ] && echo 'all options' || echo 'do nothing'; })" \
    "$(awk '/VmRSS/{print $2}' /proc/$p/status)" $((ns / 20000))
done
echo "binary: $(stat -c %s $out/cris) bytes"
kill $a $b $c; rm -rf $out
