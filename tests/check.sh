#!/bin/sh
# Builds cris exactly as the widget does, then checks every option against the system.
set -e
cd "$(dirname "$0")/.."
/usr/lib/qt6/bin/qmlformat BarWidget.qml >/dev/null || { echo "FAIL: BarWidget.qml does not parse"; exit 1; }
flags=$(grep -o -- '-O[sz] [^"]*-o "' BarWidget.qml); flags=${flags% -o \"}
out=build/check; mkdir -p $out
cc $flags -o cris cris.c
readelf -lW cris | grep -q "RWE" && { echo "FAIL: writable and executable segment"; exit 1; }
fail() { echo "FAIL $1: $2"; exit 1; }
variant() { sed "$2" cris.c > $out/$1.c && cc $flags -o $out/$1 $out/$1.c; }  # cris with one path or constant swapped
printf '0-99999\n' > $out/cpus; variant online "s#/sys/devices/system/cpu/online#$PWD/$out/cpus#"
timeout 10.5 $out/online c 1 > $out/online.out & hp=$!; (sleep 1.5; printf '0\n' > $out/cpus) &
ram0=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t+.5}' /proc/meminfo)  # before and after the sample
first=$(timeout 2 ./cris | head -1); line=$(timeout 3 ./cris crp 1 / | sed -n 2p); full=$(timeout 3 ./cris crpf 1 / | sed -n 2p)
case $first in *"i: …"*) ;; *) fail pending "$first" ;; esac
echo "$line" | grep -Eq '^c: [0-9]+% r: [0-9]+% i: ([0-9]+ ms|down) s: [0-9]+%$' || fail format "$line"
echo "$full" | grep -Eq '^cpu: [0-9]+% ram: [0-9]+% net: ([0-9]+ ms|down) disk: [0-9]+%$' || fail full "$full"
[ "${line##*s: }" = "$(df -P / | awk 'NR==2{print $5}')" ] || fail disk "$line"
ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", (t-a)*100/t+.5}' /proc/meminfo); got=${line#*r: }; got=${got%%%*}
[ $ram0 -lt $ram ] && lo=$ram0 hi=$ram || lo=$ram hi=$ram0
[ $got -ge $((lo - 1)) ] && [ $got -le $((hi + 1)) ] || fail ram "$got vs $ram0..$ram"
all=$(timeout 3 ./cris crtgspn 1 / /nope | sed -n 2p)
echo "$all" | grep -Eq '^c: [0-9]+% t: ([0-9]+°|n/a) g: ([0-9]+%( t: [0-9]+°)?|off|n/a) r: [0-9]+% sw: [0-9]+% i: ([0-9]+ ms|down) ↓[0-9.]+[KM] ↑[0-9.]+[KM] s: [0-9]+% nope: \?$' || fail options "$all"
[ -z "$(timeout 2 ./cris "" 1 | head -1)" ] || fail off "everything off should print an empty line"
case $(timeout 2 ./cris rp 1 / | head -1) in "r: "*) ;; *) fail nocpu "cpu off should start the line with r:" ;; esac
[ "$(timeout 2 ./cris p 1 | head -1)" = "i: …" ] || fail ping-only "ping alone should print only i: …"
n=$(timeout 4.5 ./cris c 1 | wc -l); [ "$n" -eq 5 ] || fail ticks "4.5 s at 1 s ticks gave $n lines, not 5"
variant dead 's/0x01010101/0x017100cb/'  # 203.0.113.1, TEST-NET
timeout 3 $out/dead crp 1 | sed -n 2p | grep -q 'i: down' || fail down "unreachable host should read down"
variant noping 's/IPPROTO_ICMP)/255)/'  # a socket the kernel refuses, like a ping_group_range without us
[ "$(timeout 2 $out/noping p 1 | sed -n 2p)" = "i: n/a" ] || fail noping "no ping socket should read n/a"
variant nohw 's#/sys/class/drm/#/nonexistent/#; s#/sys/class/hwmon/#/nonexistent/#'  # no GPU, no CPU sensor
[ "$(timeout 3 $out/nohw tgf 1 | sed -n 2p)" = "temp: n/a gpu: n/a" ] || fail nohw "missing sensors should read n/a"
variant nomem 's#/proc/meminfo#/nonexistent#'  # used to divide by zero
[ "$(timeout 3 $out/nomem rs 1 | sed -n 2p)" = "r: 0% sw: 0%" ] || fail nomem "unreadable meminfo should read 0%, not crash"
wait $hp || true  # CPU hotplug, started first: 100000 CPUs online, then 1 after 1.5 s; cris recounts every 8th tick
[ "$(sed -n 2p $out/online.out)" = "c: 100%" ] || fail hotplug "100000 CPUs online should read 100%: $(sed -n 2p $out/online.out)"
[ "$(sed -n 10p $out/online.out)" != "c: 100%" ] || fail hotplug "after CPUs went offline the share should be recounted"
rm -rf $out
echo "ok: $line"
echo "ok: $full"
echo "ok: $all"
