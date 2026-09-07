import QtQuick
import qs.Commons

Flow {
  id: root

  property var tokens: []
  property color foreground: Color.foreground
  property color linkColor: Color.accent
  property string fontFamily: Style.font.family

  signal linkActivated(string href)

  width: parent ? parent.width : implicitWidth
  spacing: 0

  Repeater {
    model: root.tokens

    BodyRun {
      required property var modelData
      token: modelData
      foreground: root.foreground
      linkColor: root.linkColor
      fontFamily: root.fontFamily
      maxWidth: root.width
      onActivated: function(href) { root.linkActivated(href) }
    }
  }
}
