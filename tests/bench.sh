#!/bin/sh
# Footprint receipts at the real 3 s interval over 60 s: binary size, resident memory, CPU per tick (schedstat).
set -e
cd "$(dirname "$0")/.."
flags=$(grep -o -- '-Os [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
cc $flags -o /tmp/cris-bench cris.c
/tmp/cris-bench >/dev/null & a=$!; /tmp/cris-bench tgs 3 1.1.1.1 / >/dev/null & b=$!; sleep 60
for p in $a $b; do
  read -r ns _ < /proc/$p/schedstat
  echo "$([ $p = $a ] && echo defaults || echo 'all options'): $(stat -c %s /tmp/cris-bench) bytes, $(awk '/VmRSS/{print $2}' /proc/$p/status) KB RSS, $((ns / 20000)) us CPU per tick"
done
kill $a $b; rm -f /tmp/cris-bench
