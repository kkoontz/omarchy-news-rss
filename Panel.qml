import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.kkoontz.omarchy-news-rss"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var news: null

  property int selectedIndex: 0
  property var article: null
  property bool showingArticle: false
  property bool showingHelp: false

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: root.barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(contentForeground, 1.5)
  readonly property var themeShell: Color.shellValues
  readonly property color linkColor: root.themeLinkColor(root.contentForeground)

  // Accent is gold on Omarchs — same as body text — so Color.accent is
  // invisible as a link color. Use the other Hyprland border stop (purple
  // on that theme). Never return a color that matches the body.
  function channel(v) {
    var n = Number(v)
    if (!isFinite(n)) return 0
    return n > 1 ? n / 255 : n
  }

  function colorDist(a, b) {
    if (a === undefined || b === undefined) return 0
    return Math.abs(root.channel(a.r) - root.channel(b.r))
      + Math.abs(root.channel(a.g) - root.channel(b.g))
      + Math.abs(root.channel(a.b) - root.channel(b.b))
  }

  function colorFar(a, b) {
    return root.colorDist(a, b) > 0.35
  }

  function hexFar(hex, color) {
    var n = parseInt(hex, 16)
    if (!isFinite(n)) return false
    var r = ((n >> 16) & 255) / 255
    var g = ((n >> 8) & 255) / 255
    var b = (n & 255) / 255
    return Math.abs(r - root.channel(color.r))
      + Math.abs(g - root.channel(color.g))
      + Math.abs(b - root.channel(color.b)) > 0.35
  }

  function themeBorder() {
    var values = root.themeShell || {}
    return values["hyprland.active-border"]
      || values["hyprland.active-border-foreground"]
      || ""
  }

  function themeLinkColor(foreground) {
    if (root.colorFar(Color.accent, foreground)) return Color.accent
    var hexes = String(root.themeBorder()).match(/[0-9A-Fa-f]{6}/g) || []
    var i
    for (i = 0; i < hexes.length; i++) {
      if (root.hexFar(hexes[i], foreground)) return "#" + hexes[i]
    }
    if (root.colorFar(Color.muted, foreground)) return Color.muted
    var hue = foreground.hslHue
    if (isNaN(hue)) hue = 0.12
    return Qt.hsla((hue + 0.65) % 1.0, 0.72, 0.58, 1)
  }
  readonly property var items: news && news.items ? news.items : []
  readonly property var grouped: news && news.grouped ? news.grouped : []
  readonly property int unreadCount: news ? news.unreadCount : 0
  readonly property bool refreshing: news ? news.refreshing : false
  readonly property bool offline: news ? news.offline : false
  readonly property string lastError: news && news.lastError ? news.lastError : ""
  readonly property string updatedLabel: {
    if (refreshing) return "Updating…"
    if (news && news.fetchedRelative) return "Updated " + news.fetchedRelative
    return "Not updated yet"
  }
  readonly property bool canUndo: !!(news && news.canUndoMarkAll)
  readonly property string subtitle: {
    if (news && news.statusNote === "Copied link") return "Copied link"
    if (canUndo) return "Marked all read · press z to undo"
    var bits = []
    if (unreadCount > 0) bits.push(unreadCount === 1 ? "1 unread" : unreadCount + " unread")
    else bits.push("Caught up")
    bits.push(updatedLabel)
    return bits.join(" · ")
  }
  readonly property var selectedItem: {
    if (selectedIndex < 0 || selectedIndex >= items.length) return null
    return items[selectedIndex]
  }
  readonly property int rowHeight: Style.space(70)
  readonly property int listRows: 6

  function open() {
    root.showingArticle = false
    root.article = null
    if (listScroll) listScroll.contentY = 0
    if (news && news.refresh) news.refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.showingHelp = false
    root.showingArticle = false
    root.article = null
    root.controller.hide()
  }

  function dismissOrClose() {
    if (root.showingHelp) {
      root.showingHelp = false
      return
    }
    if (root.showingArticle) {
      root.backToList()
      return
    }
    root.close()
  }

  function applyWheel(flick, pixelY, angleY) {
    if (!flick || flick.contentHeight <= flick.height) return
    var maxY = flick.contentHeight - flick.height
    var dy = 0
    // Classic notches are 120. Hyprland high-res wheels send many tiny
    // pixelDeltas instead; those have to be scaled or the bar barely moves.
    if (Math.abs(angleY) >= 80)
      dy = (angleY / 120) * root.rowHeight
    else if (pixelY !== 0)
      dy = pixelY * 3
    else
      dy = angleY * 0.5
    if (dy === 0) return
    flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - dy))
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function moveSelection(dy) {
    if (showingArticle || items.length === 0) return
    var next = selectedIndex + dy
    if (next < 0) next = 0
    if (next > items.length - 1) next = items.length - 1
    selectedIndex = next
  }

  function openSelected() {
    var item = selectedItem
    if (!item) return
    openArticle(item)
  }

  function openArticle(item) {
    if (!item) return
    root.article = item
    root.showingArticle = true
    if (news && news.markRead && item.identity) news.markRead(item.identity)
    Qt.callLater(function() {
      if (articleView) articleView.forceActiveFocus()
    })
  }

  function backToList() {
    root.showingArticle = false
    root.article = null
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function toggleSelectedRead() {
    var item = selectedItem
    if (!item || !news || !news.toggleRead) return
    news.toggleRead(item.identity, item.unread)
  }

  function copySelectedLink() {
    var item = selectedItem
    if (!item || !news || !news.copyLink) return
    news.copyLink(item.link)
  }

  function handleTextKey(text) {
    if (text === "?") {
      root.showingHelp = !root.showingHelp
      return
    }
    if (root.showingHelp) return
    if (showingArticle) return
    if (text === "o" || text === "O") {
      if (news && selectedItem) news.openOriginal(selectedItem)
    } else if (text === "y" || text === "Y") {
      copySelectedLink()
    } else if (text === "r" || text === "R") {
      if (news) news.refresh()
    } else if (text === "m" || text === "M" || text === "x" || text === "X") {
      toggleSelectedRead()
    } else if (text === "z" || text === "Z") {
      if (news && news.undoMarkAll) news.undoMarkAll()
    } else if (text === "c" || text === "C" || text === "A") {
      if (news) news.markAllRead()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: root.showingArticle ? articleView : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(Style.space(520), Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.showingArticle
      onMoveRequested: function(dx, dy) { if (!root.showingHelp) root.moveSelection(dy) }
      onActivateRequested: { if (!root.showingHelp) root.openSelected() }
      onCloseRequested: root.dismissOrClose()
      onDeleteRequested: { if (!root.showingHelp) root.toggleSelectedRead() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { root.handleTextKey(t) }

      Flickable {
        id: listScroll
        visible: !root.showingArticle
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: listColumn
          width: listScroll.width
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: "OMARCHY NEWS"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            font.letterSpacing: 1.2
            textFormat: Text.PlainText
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width - refreshBtn.width - Style.space(8)
              text: root.subtitle
              color: root.canUndo
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              textFormat: Text.PlainText

              MouseArea {
                anchors.fill: parent
                enabled: root.canUndo
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.news && root.news.undoMarkAll) root.news.undoMarkAll()
              }
            }

            PanelActionButton {
              id: refreshBtn
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: !root.refreshing
              onClicked: if (root.news) root.news.refresh()
            }
          }

          Text {
            visible: root.lastError !== ""
            width: parent.width
            text: root.offline
              ? "Offline · showing last cached announcements"
              : root.lastError
            color: root.offline ? root.dim : (root.bar && root.bar.urgent ? root.bar.urgent : Color.urgent)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            visible: root.items.length === 0
            width: parent.width
            text: root.lastError !== "" && !root.offline
              ? "Could not load Omarchy News."
              : "No announcements yet."
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Repeater {
            model: root.grouped

            Column {
              required property var modelData
              width: listColumn.width
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: modelData.label
                color: root.dim
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                topPadding: Style.space(6)
                textFormat: Text.PlainText
              }

              Repeater {
                model: modelData.items

                CursorSurface {
                  id: row
                  required property var modelData
                  required property int index
                  width: listColumn.width
                  implicitHeight: rowColumn.implicitHeight + Style.space(12)
                  foreground: root.contentForeground
                  accent: Color.accent
                  hasCursor: modelData.index === root.selectedIndex
                  radius: Style.cornerRadius

                  Row {
                    id: rowInner
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)

                    Rectangle {
                      width: Style.space(6)
                      height: Style.space(6)
                      radius: width / 2
                      anchors.verticalCenter: parent.verticalCenter
                      color: row.modelData.unread
                        ? (root.bar && root.bar.urgent ? root.bar.urgent : Color.urgent)
                        : "transparent"
                      border.width: row.modelData.unread ? 0 : 1
                      border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.25)
                    }

                    Column {
                      id: rowColumn
                      width: parent.width - Style.space(20)
                      spacing: Style.space(2)

                      Text {
                        width: parent.width
                        text: row.modelData.title || ""
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: row.modelData.unread
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }

                      Text {
                        width: parent.width
                        text: {
                          var bits = []
                          if (row.modelData.creator) bits.push(row.modelData.creator)
                          if (row.modelData.relative) bits.push(row.modelData.relative)
                          return bits.join(" · ")
                        }
                        color: root.dim
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }

                      Text {
                        width: parent.width
                        text: row.modelData.dek || ""
                        color: root.dim
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }
                    }
                  }

                  HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                      if (hovered && row.modelData && row.modelData.index >= 0)
                        root.selectedIndex = row.modelData.index
                    }
                  }

                  TapHandler {
                    onTapped: root.openArticle(row.modelData)
                  }
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "All news on omarchy.org/news"
            color: footerMouse.containsMouse
              ? Qt.lighter(root.linkColor, 1.18)
              : root.linkColor
            font.underline: true
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText

            MouseArea {
              id: footerMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.news) root.news.openNewsIndex()
            }
          }
        }
      }

      MouseArea {
        visible: listScroll.visible && listScroll.interactive
        anchors.fill: listScroll
        z: 2
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
          root.applyWheel(listScroll, wheel.pixelDelta.y, wheel.angleDelta.y)
          wheel.accepted = true
        }
      }

      ArticleView {
        id: articleView
        visible: root.showingArticle
        anchors.fill: parent
        article: root.article
        foreground: root.contentForeground
        linkColor: root.linkColor
        fontFamily: root.contentFontFamily
        news: root.news
        onBackRequested: root.backToList()
      }

      Rectangle {
        visible: root.showingHelp
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
        z: 4

        MouseArea {
          anchors.fill: parent
          onClicked: root.showingHelp = false
        }

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            width: parent.width
            text: "KEYS"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
            textFormat: Text.PlainText
          }

          Repeater {
            model: [
              "j k / arrows   move",
              "Enter          read in panel",
              "o              open original",
              "y              copy link",
              "x / m          toggle unread",
              "c / Shift+A    mark all read",
              "z              undo mark all",
              "r              refresh",
              "?              this help",
              "Esc            back / close"
            ]

            Text {
              required property string modelData
              width: parent.width
              text: modelData
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              textFormat: Text.PlainText
            }
          }
        }
      }
    }
  }
}
