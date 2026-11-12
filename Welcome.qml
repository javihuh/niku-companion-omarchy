import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

PanelWindow {
  id: root
  property bool open: false
  property string initialName: ""
  property bool saving: false
  property string errorText: ""
  signal accepted(string name)

  visible: open
  implicitWidth: Math.min(480, screen ? screen.width : 480)
  implicitHeight: form.implicitHeight + 48
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "niku-companion-welcome"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  onOpenChanged: {
    if (open) {
      nameField.text = initialName;
      errorText = "";
      Qt.callLater(function() { nameField.forceActiveFocus(); });
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 20
    color: Commons.Color.background
    border.color: Commons.Color.accent
    border.width: 1

    Column {
      id: form
      anchors.centerIn: parent
      width: parent.width - 48
      spacing: 16

      Text {
        width: parent.width
        text: "ᨳ𐔌՞҂ ˕ ֊՞𐦯ᜊ"
        color: Commons.Color.accent
        font.family: Commons.Style.font.family
        font.pixelSize: 32
        horizontalAlignment: Text.AlignHCenter
      }
      Text {
        width: parent.width
        text: "Niku Companion\n¿Cómo quieres que te llame?"
        textFormat: Text.PlainText
        color: Commons.Color.foreground
        font.family: Commons.Style.font.family
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Tu nombre"
        palette.base: Commons.Color.background
        palette.text: Commons.Color.foreground
        palette.placeholderText: Commons.Color.muted
        palette.highlight: Commons.Color.accent
        palette.highlightedText: Commons.Color.background
        maximumLength: 60
        enabled: !root.saving
        onAccepted: if (!root.saving) root.accepted(text)
      }
      Text {
        width: parent.width
        text: "Tu nombre se guarda solo en este equipo. Puedes cambiarlo después."
        color: Commons.Color.foreground
        font.family: Commons.Style.font.family
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
      }
      Button {
        width: parent.width
        text: root.saving ? "Guardando…" : "Guardar"
        palette.button: Commons.Color.background
        palette.buttonText: Commons.Color.foreground
        palette.highlight: Commons.Color.accent
        enabled: !root.saving
        onClicked: root.accepted(nameField.text)
      }
      Button {
        width: parent.width
        text: "Continuar sin nombre"
        palette.button: Commons.Color.background
        palette.buttonText: Commons.Color.foreground
        palette.highlight: Commons.Color.accent
        enabled: !root.saving
        onClicked: root.accepted("")
      }
      Text {
        width: parent.width
        visible: text.length > 0
        text: root.errorText
        textFormat: Text.PlainText
        color: Commons.Color.urgent
        font.pixelSize: 13
        wrapMode: Text.WordWrap
      }
    }
  }
}
