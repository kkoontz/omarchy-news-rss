import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var article: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property var news: null

  readonly property color dim: Qt.darker(foreground, 1.5)

  signal backRequested()

  function openOriginal() {
    if (news && news.openOriginal) news.openOriginal(article)
  }

  function markUnread() {
    if (news && news.markUnread && article && article.identity)
      news.markUnread(article.identity)
  }

  function toggleRead() {
    if (!news || !news.toggleRead || !article) return
    news.toggleRead(article.identity, article.unread === true)
  }

  function copyLink() {
    if (news && news.copyLink && article) news.copyLink(article.link)
  }

  function scrollBody(pixelDelta, angleDelta) {
    var maxY = Math.max(0, bodyScroll.contentHeight - bodyScroll.height)
    if (maxY <= 0) return
    var dy = pixelDelta !== 0 ? pixelDelta * 2.4 : (angleDelta / 120) * Style.space(64)
    bodyScroll.contentY = Math.max(0, Math.min(maxY, bodyScroll.contentY - dy))
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
      root.backRequested()
      event.accepted = true
    } else if (event.text === "o" || event.text === "O") {
      root.openOriginal()
      event.accepted = true
    } else if (event.text === "y" || event.text === "Y") {
      root.copyLink()
      event.accepted = true
    } else if (event.text === "x" || event.text === "X" || event.text === "m" || event.text === "M") {
      root.toggleRead()
      event.accepted = true
    }
  }

  Column {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.space(8)

    Row {
      spacing: Style.space(14)

      Text {
        text: "Back"
        color: backMouse.containsMouse ? Style.hoverStateColor(root.foreground, Color.accent) : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true

        MouseArea {
          id: backMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.backRequested()
        }
      }

      Text {
        text: "Open original"
        color: originalMouse.containsMouse ? Style.hoverStateColor(root.foreground, Color.accent) : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall

        MouseArea {
          id: originalMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openOriginal()
        }
      }

      Text {
        text: article && article.unread ? "Mark read" : "Mark unread"
        color: unreadMouse.containsMouse ? Style.hoverStateColor(root.foreground, Color.accent) : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall

        MouseArea {
          id: unreadMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleRead()
        }
      }
    }

    Text {
      width: parent.width
      text: article && article.title ? article.title : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      text: {
        if (!article) return ""
        var bits = []
        if (article.creator) bits.push(article.creator)
        if (article.relative) bits.push(article.relative)
        return bits.join(" · ")
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }
  }

  Flickable {
    id: bodyScroll
    anchors.top: header.bottom
    anchors.topMargin: Style.space(12)
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    contentWidth: width
    contentHeight: bodyText.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    flickDeceleration: 2800
    maximumFlickVelocity: 9000
    WheelHandler {
      onWheel: function(event) {
        root.scrollBody(event.pixelDelta.y, event.angleDelta.y)
        event.accepted = true
      }
    }

    Text {
      id: bodyText
      width: bodyScroll.width
      text: article && article.content ? article.content : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
      textFormat: Text.RichText
      onLinkActivated: function(link) {
        if (root.news && root.news.openHttps) root.news.openHttps(link)
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: bodyText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
      }
    }
  }
}
