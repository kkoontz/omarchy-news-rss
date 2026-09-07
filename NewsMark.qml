import QtQuick
import qs.Commons

Item {
  id: root

  property real size: Style.bar.iconCanvas
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  width: size
  height: size

  Text {
    anchors.centerIn: parent
    text: "󰑪"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Math.round(root.size)
    textFormat: Text.PlainText
  }
}
