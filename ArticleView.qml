import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var article: null
  property color foreground: Color.foreground
  property color linkColor: Color.accent
  property string fontFamily: Style.font.family
  property var news: null

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property var paragraphs: {
    if (article && article.body && article.body.length) return article.body
    if (!article || !article.content) return []
    return Model.bodyParagraphs(article.content, 20000)
  }

  signal backRequested()

  function openOriginal() {
    if (news && news.openOriginal) news.openOriginal(article)
  }

  function toggleRead() {
    if (!news || !news.toggleRead || !article) return
    news.toggleRead(article.identity, article.unread === true)
  }

  function copyLink() {
    if (news && news.copyLink && article) news.copyLink(article.link)
  }

  function openHref(href) {
    if (news && news.openHttps) news.openHttps(href)
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
        textFormat: Text.PlainText

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
        color: originalMouse.containsMouse ? Qt.lighter(root.linkColor, 1.2) : root.linkColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        textFormat: Text.PlainText

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
        textFormat: Text.PlainText

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
    contentHeight: bodyColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: bodyColumn
      width: bodyScroll.width
      spacing: Style.space(10)

      Repeater {
        model: root.paragraphs

        Flow {
          required property var modelData
          readonly property var tokens: modelData
          width: bodyColumn.width
          spacing: 0

          Repeater {
            model: tokens

            Text {
              id: tokenLabel
              required property var modelData
              readonly property bool isLink: modelData && modelData.kind === "link"
              text: modelData && modelData.text ? modelData.text : ""
              color: tokenLabel.isLink
                ? (tokenMouse.containsMouse ? Qt.lighter(root.linkColor, 1.2) : root.linkColor)
                : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              width: Math.min(Math.max(implicitWidth, 1), bodyColumn.width)
              textFormat: Text.PlainText

              MouseArea {
                id: tokenMouse
                anchors.fill: parent
                enabled: tokenLabel.isLink
                hoverEnabled: tokenLabel.isLink
                cursorShape: tokenLabel.isLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (tokenLabel.isLink) root.openHref(tokenLabel.modelData.href)
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    visible: bodyScroll.interactive
    anchors.fill: bodyScroll
    z: 2
    acceptedButtons: Qt.NoButton
    onWheel: function(wheel) {
      if (bodyScroll.contentHeight <= bodyScroll.height) return
      var maxY = bodyScroll.contentHeight - bodyScroll.height
      var dy = 0
      if (Math.abs(wheel.angleDelta.y) >= 80)
        dy = (wheel.angleDelta.y / 120) * Style.space(56)
      else if (wheel.pixelDelta.y !== 0)
        dy = wheel.pixelDelta.y * 3
      else
        dy = wheel.angleDelta.y * 0.5
      if (dy === 0) return
      bodyScroll.contentY = Math.max(0, Math.min(maxY, bodyScroll.contentY - dy))
      wheel.accepted = true
    }
  }
}
