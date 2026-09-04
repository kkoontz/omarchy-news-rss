import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: ({})

  property var items: []
  property var grouped: []
  property var rawItems: []
  property var readState: Model.emptyReadState ? Model.emptyReadState() : ({ firstSeenAt: "", firstSeenAtMs: 0, read: {} })
  property int unreadCount: 0
  property string latestHeadline: ""
  property string tooltipText: "Omarchy News"
  property string badgeText: ""
  property string fetchedAt: ""
  property string fetchedRelative: ""
  property bool refreshing: false
  property bool queuedRefresh: false
  property string lastError: ""
  property bool offline: false
  property bool feedLoaded: false
  property bool readLoaded: false
  property bool dirReady: false

  readonly property string pluginId: "io.github.kkoontz.omarchy-news-rss"
  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string stateDir: homeDir + "/.local/state/omarchy/omarchy-news"
  readonly property string feedPath: stateDir + "/feed.json"
  readonly property string readPath: stateDir + "/read.json"
  readonly property var fetchCommand: [
    "curl", "-fsS",
    "--proto", "=https",
    "--max-time", "10",
    "--max-redirs", "0",
    "--max-filesize", "1048576",
    "--noproxy", "*",
    Model.feedUrl()
  ]

  function publish() {
    var decorated = Model.decorateItems(root.rawItems, root.readState, Date.now())
    root.items = decorated
    root.grouped = Model.groupItems(decorated)
    root.unreadCount = Model.unreadCount(decorated)
    root.latestHeadline = Model.latestHeadline(decorated)
    root.tooltipText = Model.tooltipText(decorated, root.unreadCount)
    root.badgeText = Model.badgeLabel(root.unreadCount)
    root.fetchedRelative = root.fetchedAt ? Model.relativeTime(Date.parse(root.fetchedAt), Date.now()) : ""
  }

  function persistRead() {
    if (!root.dirReady) return
    readFile.setText(JSON.stringify(Model.serializeReadState(root.readState), null, 2) + "\n")
  }

  function persistFeed() {
    if (!root.dirReady) return
    feedFile.setText(JSON.stringify(Model.serializeFeed(root.rawItems, root.fetchedAt), null, 2) + "\n")
  }

  function applyCache(raw) {
    var cached = Model.parseFeedCache(raw)
    if (cached.items && cached.items.length) {
      root.rawItems = cached.items
      root.fetchedAt = cached.fetchedAt || ""
      root.offline = true
    }
    root.feedLoaded = true
    root.publish()
  }

  function applyRead(raw) {
    root.readState = Model.parseReadState(raw)
    root.readLoaded = true
    root.publish()
  }

  function applyFeedXml(xml) {
    var parsed = Model.parseFeed(xml)
    if (!parsed.ok) {
      root.lastError = parsed.error || "Could not parse the Omarchy News feed"
      root.offline = root.rawItems.length > 0
      root.publish()
      return
    }
    root.readState = Model.ingestItems(parsed.items, root.readState, Date.now())
    root.rawItems = parsed.items
    root.fetchedAt = new Date().toISOString()
    root.lastError = ""
    root.offline = false
    root.publish()
    persistFeed()
    persistRead()
  }

  function refresh() {
    if (!root.dirReady) {
      root.queuedRefresh = true
      ensureDir.running = true
      return
    }
    if (fetchProc.running) {
      root.queuedRefresh = true
      return
    }
    root.refreshing = true
    fetchProc.command = root.fetchCommand
    fetchProc.running = true
  }

  function markRead(identity) {
    root.readState = Model.markRead(root.readState, identity)
    root.publish()
    persistRead()
  }

  function markUnread(identity) {
    root.readState = Model.markUnread(root.readState, identity)
    root.publish()
    persistRead()
  }

  function markAllRead() {
    root.readState = Model.markAllRead(root.readState, root.rawItems)
    root.publish()
    persistRead()
  }

  function openHttps(url) {
    if (!Model.isHttpsUrl(url)) return
    Quickshell.execDetached(["omarchy-launch-browser", url])
  }

  function openOriginal(item) {
    if (!item) return
    root.openHttps(item.link)
    if (item.identity) root.markRead(item.identity)
  }

  function openNewsIndex() {
    root.openHttps(Model.newsIndexUrl())
  }

  Timer {
    interval: 15 * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: clockTick
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.publish()
  }

  Process {
    id: ensureDir
    command: ["mkdir", "-p", root.stateDir]
    running: true
    onExited: function(exitCode) {
      root.dirReady = exitCode === 0
      if (!root.dirReady) {
        root.lastError = "Could not create " + root.stateDir
        return
      }
      feedFile.reload()
      readFile.reload()
      if (root.queuedRefresh) {
        root.queuedRefresh = false
        root.refresh()
      }
    }
  }

  FileView {
    id: feedFile
    path: root.feedPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyCache(text())
    onLoadFailed: {
      root.feedLoaded = true
      root.publish()
    }
  }

  FileView {
    id: readFile
    path: root.readPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyRead(text())
    onLoadFailed: {
      root.readLoaded = true
      root.publish()
    }
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.refreshing = false
        if (text && root.trimCheck(text)) root.applyFeedXml(text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && root.trimCheck(text)) root.lastError = "Could not refresh Omarchy News"
      }
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0) {
        root.offline = root.rawItems.length > 0
        if (!root.lastError) root.lastError = "Could not refresh Omarchy News"
        root.publish()
      }
      if (root.queuedRefresh) {
        root.queuedRefresh = false
        root.refresh()
      }
    }
  }

  function trimCheck(value) {
    return String(value || "").replace(/^\s+|\s+$/g, "").length > 0
  }
}
