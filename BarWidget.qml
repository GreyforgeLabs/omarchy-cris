import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// CRIS: the bar shows whatever cris.c prints. It builds once into ~/.cache (a write inside the plugin
// folder would retrigger the shell's plugin reload), then runs as one tiny process.
BarWidget {
  id: root
  function on(k) { return String(setting(k, false)) === "true" }
  // A settings change replaces the sampler with one started with the new arguments.
  readonly property var args: [(on("cpuTemp") ? "t" : "") + (on("gpu") ? "g" : "") + (on("swap") ? "s" : ""),
    String(setting("interval", 3)), String(setting("pingHost", "1.1.1.1")), String(setting("disks", "/"))]
  implicitWidth: t.implicitWidth + Style.spaceReal(16); implicitHeight: barSize
  Text {
    id: t; anchors.centerIn: parent; color: bar ? bar.barForeground : Color.foreground; renderType: Text.NativeRendering
    font { family: bar ? bar.fontFamily : Style.font.family; pixelSize: Style.font.body }
  }
  Instantiator {
    model: [root.args]
    Process {
      running: true
      command: ["sh", "-c", 'b=$HOME/.cache/omarchy-cris; [ "$b" -nt "$1" ] || cc -Os -static -nostdlib -fno-pie -no-pie -fno-stack-protector -fno-asynchronous-unwind-tables -s -Wl,-n,--build-id=none -o "$b" "$1" && exec "$b" "$2" "$3" "$4" "$5"',
        "sh", Qt.resolvedUrl("cris.c").toString().slice(7)].concat(modelData)
      stdout: SplitParser { onRead: line => t.text = line }
    }
  }
}
