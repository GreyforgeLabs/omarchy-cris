import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// CRIS: the bar shows whatever cris.c prints. It is compiled once into ~/.cache (a write inside the plugin
// folder would retrigger the shell's plugin reload) and runs as one tiny process. Click for settings.
BarWidget {
  id: root
  property bool menu: false
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property var shows: [["cpuTemp", "cpu temp", "t"], ["gpu", "gpu", "g"], ["swap", "swap", "s"], ["ping", "ping", "p"], ["speed", "speed", "n"]]
  readonly property var disks: String(setting("disks", "/")).split(" ").filter(d => d)
  readonly property int every: Number(setting("interval", 3))
  function on(k) { return String(setting(k, k === "ping")) === "true" }  // ping is the only option on by default
  function set(k, v) {  // persist one setting in this widget's shell.json entry
    const e = { id: moduleName }
    for (const x in settings) if (x !== "id") e[x] = settings[x]
    e[k] = v, settings = e
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, e)
  }
  function close() { menu = false }
  implicitWidth: t.implicitWidth + Style.spaceReal(16); implicitHeight: barSize

  component Label: Text { color: root.fg; font.family: root.fam; font.pixelSize: Style.font.body; renderType: Text.NativeRendering }
  component Opt: Label {  // bright when on, dim when off; click to change
    property bool lit
    signal pick
    opacity: lit ? 1 : 0.4
    MouseArea { anchors.fill: parent; onClicked: parent.pick() }
  }

  Label { id: t; anchors.centerIn: parent }
  MouseArea { anchors.fill: parent; onClicked: root.menu = !root.menu }
  Instantiator {  // a settings change swaps in a sampler started with the new arguments
    model: [[root.shows.filter(s => root.on(s[0])).map(s => s[2]).join(""), String(root.every)].concat(root.disks)]
    Process {
      running: true
      command: ["sh", "-c", 'b=$HOME/.cache/omarchy-cris; [ "$b" -nt "$1" ] || cc -Os -static -nostdlib -fno-pie -no-pie -fno-stack-protector -fno-asynchronous-unwind-tables -fno-ident -fcf-protection=none -Wa,-mx86-used-note=no -s -Wl,-n,--build-id=none -o "$b" "$1" || { echo "cris needs gcc: sudo pacman -S gcc"; exit; }; shift; exec env -i "$b" "$@"',
        "sh", Qt.resolvedUrl("cris.c").toString().slice(7)].concat(modelData)
      stdout: SplitParser { onRead: line => t.text = line }
    }
  }

  Loader {  // the settings card exists only while it is open
    active: root.menu
    sourceComponent: PopupCard {
      anchorItem: root; bar: root.bar; owner: root; open: true
      contentWidth: fittedContentWidth(rows.implicitWidth + Style.spacing.popupPadding * 2)
      contentHeight: fittedContentHeight(rows.implicitHeight)
      Grid {
        id: rows; columns: 2; columnSpacing: Style.space(16); rowSpacing: Style.space(6)
        FileView { id: mounts; path: "/proc/mounts"; blockLoading: true }
        Label { text: "show"; opacity: 0.6 }
        Row { spacing: Style.space(12); Repeater { model: root.shows; Opt { text: modelData[1]; lit: root.on(modelData[0]); onPick: root.set(modelData[0], !lit) } } }
        Label { text: "every"; opacity: 0.6 }
        Row { spacing: Style.space(12); Repeater { model: [1, 3, 5, 10]; Opt { text: modelData + "s"; lit: root.every === modelData; onPick: root.set("interval", modelData) } } }
        Label { text: "disks"; opacity: 0.6 }
        Row {
          spacing: Style.space(12)
          Repeater {  // the first mount point of each block device, plus any path already chosen
            model: [...new Set(mounts.text().split("\n").map(l => l.split(" ")).filter(m => m[0].startsWith("/dev/"))
              .filter((m, i, a) => a.findIndex(n => n[0] === m[0]) === i).map(m => m[1]).concat(root.disks))]
            Opt {
              text: modelData; lit: root.disks.includes(modelData)
              onPick: root.set("disks", (lit ? root.disks.filter(d => d !== modelData) : root.disks.concat(modelData)).join(" "))
            }
          }
        }
      }
    }
  }
}
