import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// CRIS: the bar shows whatever cris.c prints. It builds once into ~/.cache (a write inside the plugin
// folder would retrigger the shell's plugin reload), then runs as one tiny process. Click for settings.
BarWidget {
  id: root
  property bool menu: false
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string fam: bar ? bar.fontFamily : Style.font.family
  readonly property var disks: String(setting("disks", "/")).split(/[ ,]+/).filter(d => d)
  function on(k) { return String(setting(k, false)) === "true" }
  function set(k, v) {  // persist one setting in this widget's shell.json entry
    const e = { id: moduleName }
    for (const x in settings) if (x !== "id") e[x] = settings[x]
    e[k] = v, settings = e
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, e)
  }
  function close() { menu = false }
  // A settings change replaces the sampler with one started with the new arguments.
  readonly property var args: [(on("cpuTemp") ? "t" : "") + (on("gpu") ? "g" : "") + (on("swap") ? "s" : ""),
    String(setting("interval", 3)), String(setting("pingHost", "1.1.1.1")), disks.join(" ")]
  implicitWidth: t.implicitWidth + Style.spaceReal(16); implicitHeight: barSize

  component Label: Text { color: root.fg; font.family: root.fam; font.pixelSize: Style.font.body; renderType: Text.NativeRendering }
  component Opt: Label {  // dim when off; click to pick
    property bool lit
    signal pick
    opacity: lit ? 1 : 0.4
    MouseArea { anchors.fill: parent; onClicked: parent.pick() }
  }

  Label { id: t; anchors.centerIn: parent }
  MouseArea { anchors.fill: parent; onClicked: root.menu = !root.menu }
  Instantiator {
    model: [root.args]
    Process {
      running: true
      command: ["sh", "-c", 'b=$HOME/.cache/omarchy-cris; [ "$b" -nt "$1" ] || cc -Os -static -nostdlib -fno-pie -no-pie -fno-stack-protector -fno-asynchronous-unwind-tables -s -Wl,-n,--build-id=none -o "$b" "$1" && exec "$b" "$2" "$3" "$4" "$5"',
        "sh", Qt.resolvedUrl("cris.c").toString().slice(7)].concat(modelData)
      stdout: SplitParser { onRead: line => t.text = line }
    }
  }

  Loader {  // the settings card exists only while open
    active: root.menu
    sourceComponent: PopupCard {
      anchorItem: root; bar: root.bar; owner: root; open: true
      contentWidth: fittedContentWidth(rows.implicitWidth + Style.spacing.popupPadding * 2)
      contentHeight: fittedContentHeight(rows.implicitHeight)
      Grid {
        id: rows; columns: 2; columnSpacing: Style.space(16); rowSpacing: Style.space(6)
        FileView { id: mounts; path: "/proc/mounts"; blockLoading: true }
        Label { text: "show"; opacity: 0.6 }
        Row {
          spacing: Style.space(12)
          Repeater {
            model: [["cpuTemp", "cpu temp"], ["gpu", "gpu"], ["swap", "swap"]]
            Opt { text: modelData[1]; lit: root.on(modelData[0]); onPick: root.set(modelData[0], !lit) }
          }
        }
        Label { text: "every"; opacity: 0.6 }
        Row {
          spacing: Style.space(12)
          Repeater { model: [1, 3, 5, 10]; Opt { text: modelData + "s"; lit: Number(root.setting("interval", 3)) === modelData; onPick: root.set("interval", modelData) } }
        }
        Label { text: "ping"; opacity: 0.6 }
        Row {
          spacing: Style.space(12)
          Repeater {
            model: [...new Set(["1.1.1.1", "8.8.8.8", "9.9.9.9", String(root.setting("pingHost", "1.1.1.1"))])]
            Opt { text: modelData; lit: String(root.setting("pingHost", "1.1.1.1")) === modelData; onPick: root.set("pingHost", modelData) }
          }
        }
        Label { text: "disks"; opacity: 0.6 }
        Row {
          spacing: Style.space(12)
          Repeater {  // one entry per mounted block device, plus any custom paths already chosen
            model: [...new Set(mounts.text().split("\n").map(l => l.split(" ")).filter(f => f[0].startsWith("/dev/"))
              .filter((f, i, a) => a.findIndex(g => g[0] === f[0]) === i).map(f => f[1]).concat(root.disks))]
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
