import QtQuick
import QtQuick.Effects
import qs.Commons

// Official Omarchy pixel-O stays theme-foreground. The RSS glyph is the
// unread accent: dim when caught up, urgent when something is new.
Item {
  id: root

  property real size: Style.bar.iconCanvas
  property color foreground: Color.foreground
  property color unreadColor: Color.urgent
  property bool unread: false
  property string fontFamily: Style.font.family

  width: size
  height: size

  Image {
    id: oSrc
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/omarchy-o.png")
    fillMode: Image.PreserveAspectFit
    visible: false
    sourceSize.width: Math.round(root.size * 2)
    sourceSize.height: Math.round(root.size * 2)
  }

  MultiEffect {
    anchors.fill: oSrc
    source: oSrc
    colorization: 1.0
    colorizationColor: root.foreground
  }

  Text {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: "󰑫"
    color: root.unread ? root.unreadColor : Qt.darker(root.foreground, 1.6)
    font.family: root.fontFamily
    font.pixelSize: Math.max(8, Math.round(root.size * 0.4))
    textFormat: Text.PlainText
  }
}
