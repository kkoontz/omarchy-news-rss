import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.kkoontz.omarchy-news-rss"

  readonly property var news: bar && bar.shell
    ? bar.shell.serviceFor("io.github.kkoontz.omarchy-news-rss")
    : null

  readonly property int unreadCount: news ? news.unreadCount : 0
  readonly property string badgeText: news ? news.badgeText : ""
  readonly property string tooltipLabel: news && news.tooltipText ? news.tooltipText : "Omarchy News"
  readonly property color unreadColor: bar && bar.urgent ? bar.urgent : Color.urgent

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (news && news.refresh) news.refresh()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
    target.news = root.news
  }

  function hydrateService() {
    if (root.news && root.news.hydrateSettings)
      root.news.hydrateSettings(root.settings)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onNewsChanged: {
    injectPanel()
    root.hydrateService()
  }
  onSettingsChanged: {
    injectPanel()
    root.hydrateService()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    keepSpace: true
    tooltipText: root.tooltipLabel
    fixedWidth: Style.bar.iconSlot
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.news && root.news.refresh) root.news.refresh()
      } else if (buttonCode === Qt.MiddleButton) {
        if (root.news && root.news.markAllRead) root.news.markAllRead()
      } else {
        root.toggle()
      }
    }

    NewsMark {
      anchors.centerIn: parent
      size: Style.bar.iconCanvas
      foreground: button.foreground
      unreadColor: root.unreadColor
      unread: root.unreadCount > 0
      fontFamily: button.fontFamily
    }

    Rectangle {
      visible: root.badgeText !== ""
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(1)
      anchors.topMargin: Style.space(1)
      width: Math.max(Style.space(12), badgeLabel.implicitWidth + Style.space(6))
      height: Style.space(12)
      radius: height / 2
      color: root.unreadColor
      z: 2

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.badgeText
        color: Color.background
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        textFormat: Text.PlainText
      }
    }
  }
}
