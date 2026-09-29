#!/bin/sh
# Builds cris exactly as the widget does, then checks every option against the system.
set -e
cd "$(dirname "$0")/.."
/usr/lib/qt6/bin/qmlformat BarWidget.qml >/dev/null || { echo "FAIL: BarWidget.qml does not parse"; exit 1; }
flags=$(grep -o -- '-Os [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
cc $flags -o cris cris.c
fail() { echo "FAIL $1: $2"; exit 1; }
first=$(timeout 2 ./cris | head -1); line=$(timeout 3 ./cris p 1 / | sed -n 2p)
[ "$first" = "${first%net: …*}net: …${first#*net: …}" ] || fail pending "$first"
echo "$line" | grep -Eq '^cpu: [0-9]+% ram: [0-9]+% net: ([0-9]+ ms|down) disk: [0-9]+%$' || fail format "$line"
[ "${line##*disk: }" = "$(df -P / | awk 'NR==2{print $5}')" ] || fail disk "$line"
ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t+.5}' /proc/meminfo); got=${line#*ram: }; got=${got%%%*}
[ $((got - ram)) -le 1 ] && [ $((ram - got)) -le 1 ] || fail ram "$got vs $ram"
all=$(timeout 3 ./cris tgspn 1 / /nope | sed -n 2p)
echo "$all" | grep -Eq '^cpu: [0-9]+%( [0-9]+°)? (gpu: ([0-9]+%( [0-9]+°)?|off) )?ram: [0-9]+% swap: [0-9]+% net: ([0-9]+ ms|down) ↓[0-9.]+[KM] ↑[0-9.]+[KM] disk: [0-9]+% nope: \?$' || fail options "$all"
[ "$(timeout 2 ./cris "" 1 | head -1 | grep -c -E 'net|disk')" = 0 ] || fail off "options off still print net or disk"
sed 's/0x01010101/0x017100cb/' cris.c > /tmp/cris-dead.c && cc $flags -o /tmp/cris-dead /tmp/cris-dead.c  # 203.0.113.1, TEST-NET
timeout 3 /tmp/cris-dead p 1 | sed -n 2p | grep -q 'net: down' || fail down "unreachable host should read down"
rm -f /tmp/cris-dead /tmp/cris-dead.c
echo "ok: $line"
echo "ok: $all"
