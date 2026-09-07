import QtQuick
import qs.Commons

Text {
  id: root

  property var token: null
  property color foreground: Color.foreground
  property color linkColor: Color.accent
  property string fontFamily: Style.font.family
  property real maxWidth: 100

  readonly property bool isLink: !!(token && token.kind === "link")
  readonly property string href: token && token.href ? token.href : ""

  signal activated(string href)

  text: token && token.text ? token.text : ""
  color: root.isLink
    ? (runMouse.containsMouse ? Qt.lighter(root.linkColor, 1.18) : root.linkColor)
    : root.foreground
  font.family: root.fontFamily
  font.pixelSize: Style.font.body
  font.underline: root.isLink
  wrapMode: Text.Wrap
  width: Math.min(Math.max(implicitWidth, 1), root.maxWidth)
  textFormat: Text.PlainText

  MouseArea {
    id: runMouse
    anchors.fill: parent
    enabled: root.isLink
    hoverEnabled: root.isLink
    cursorShape: root.isLink ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.isLink) root.activated(root.href)
  }
}
