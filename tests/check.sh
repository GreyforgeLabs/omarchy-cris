#!/bin/sh
# Builds cris with the widget's own flags, then checks the output of every option against the system.
set -e
cd "$(dirname "$0")/.."
flags=$(grep -o -- '-Os [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
cc $flags -o cris cris.c
fail() { echo "FAIL $1: $2"; exit 1; }
line=$(timeout 3 ./cris "" 1 | sed -n 2p)
echo "$line" | grep -Eq '^cpu: [0-9]+% ram: [0-9]+% net: ([0-9]+ ms|down) disk: [0-9]+%$' || fail format "$line"
[ "${line##*disk: }" = "$(df -P / | awk 'NR==2{print $5}')" ] || fail disk "$line"
ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t+.5}' /proc/meminfo); got=${line#*ram: }; got=${got%%%*}
[ $((got - ram)) -le 1 ] && [ $((ram - got)) -le 1 ] || fail ram "$got vs $ram"
all=$(timeout 3 ./cris tgs 1 | sed -n 2p)
echo "$all" | grep -Eq '^cpu: [0-9]+%( [0-9]+°)? (gpu: ([0-9]+%( [0-9]+°)?|off) )?ram: [0-9]+% swap: [0-9]+% net' || fail options "$all"
multi=$(timeout 2 ./cris "" 1 1.1.1.1 "/ /nope" | head -1)
echo "$multi" | grep -Eq ' disk: [0-9]+% nope: \?$' || fail disks "$multi"
timeout 2 ./cris "" 1 203.0.113.1 | head -1 | grep -q 'net: down' || fail down "unreachable host should read down"
echo "ok: $line"
echo "ok: $all"
