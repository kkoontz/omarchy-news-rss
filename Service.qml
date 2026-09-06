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
  property int refreshMinutes: 15
  property bool canUndoMarkAll: false
  property var undoReadState: null
  property string statusNote: ""

  property var ioQueue: []
  property var ioJob: null
  property string ioBuf: ""
  property string ioPayload: ""
  property string fetchBuf: ""
  property bool fetchOverflow: false

  readonly property string pluginId: "io.github.kkoontz.omarchy-news-rss"
  readonly property string pluginDir: {
    var dir = ""
    if (manifest && manifest.__sourceDir)
      dir = String(manifest.__sourceDir)
    else
      dir = String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")
    return dir.replace(/\/$/, "")
  }
  readonly property string helperPath: root.pluginDir + "/helper/io.sh"
  readonly property int maxFeedBytes: Model.MAX_FEED_BYTES || 1048576

  function hydrateSettings(settings) {
    var next = Model.clampRefreshMinutes(settings ? settings.refreshMinutes : 15)
    if (next === root.refreshMinutes) return
    root.refreshMinutes = next
    pollTimer.interval = next * 60 * 1000
  }

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

  function enqueueIo(job) {
    var next = []
    var i
    for (i = 0; i < root.ioQueue.length; i++) next.push(root.ioQueue[i])
    next.push(job)
    root.ioQueue = next
    root.pumpIo()
  }

  function pumpIo() {
    if (ioProc.running || root.ioQueue.length === 0) return
    var job = root.ioQueue[0]
    var rest = []
    var i
    for (i = 1; i < root.ioQueue.length; i++) rest.push(root.ioQueue[i])
    root.ioQueue = rest
    root.ioJob = job
    root.ioBuf = ""
    root.ioPayload = job.payload || ""
    if (job.op === "init")
      ioProc.command = ["/usr/bin/bash", root.helperPath, "init"]
    else if (job.op === "read")
      ioProc.command = ["/usr/bin/bash", root.helperPath, "read", job.name]
    else if (job.op === "write")
      ioProc.command = ["/usr/bin/bash", root.helperPath, "write", job.name]
    else
      return
    ioProc.stdinEnabled = job.op === "write"
    ioProc.running = true
  }

  function persistRead() {
    if (!root.dirReady) return
    root.enqueueIo({
      op: "write",
      name: "read",
      payload: JSON.stringify(Model.serializeReadState(root.readState), null, 2) + "\n"
    })
  }

  function persistFeed() {
    if (!root.dirReady) return
    root.enqueueIo({
      op: "write",
      name: "feed",
      payload: JSON.stringify(Model.serializeFeed(root.rawItems, root.fetchedAt), null, 2) + "\n"
    })
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
      if (!ioProc.running && root.ioQueue.length === 0 && !root.ioJob)
        root.enqueueIo({ op: "init" })
      return
    }
    if (fetchProc.running) {
      root.queuedRefresh = true
      return
    }
    root.refreshing = true
    root.fetchOverflow = false
    root.fetchBuf = ""
    fetchProc.command = ["/usr/bin/bash", root.helperPath, "fetch"]
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
    root.undoReadState = Model.copyReadState(root.readState)
    root.readState = Model.markAllRead(root.readState, root.rawItems)
    root.canUndoMarkAll = true
    root.statusNote = "Marked all read"
    undoTimer.restart()
    root.publish()
    persistRead()
  }

  function undoMarkAll() {
    if (!root.canUndoMarkAll || !root.undoReadState) return
    root.readState = root.undoReadState
    root.undoReadState = null
    root.canUndoMarkAll = false
    root.statusNote = ""
    undoTimer.stop()
    root.publish()
    persistRead()
  }

  function toggleRead(identity, unread) {
    root.readState = Model.toggleRead(root.readState, identity, unread)
    root.publish()
    persistRead()
  }

  function copyLink(url) {
    if (!Model.isHttpsUrl(url)) return
    Quickshell.execDetached(["wl-copy", "--", url])
    root.statusNote = "Copied link"
    noteTimer.restart()
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

  Component.onCompleted: root.enqueueIo({ op: "init" })

  Timer {
    id: pollTimer
    interval: root.refreshMinutes * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  Timer {
    id: undoTimer
    interval: 5000
    repeat: false
    onTriggered: {
      root.canUndoMarkAll = false
      root.undoReadState = null
      if (root.statusNote === "Marked all read") root.statusNote = ""
    }
  }

  Timer {
    id: noteTimer
    interval: 1800
    repeat: false
    onTriggered: if (root.statusNote === "Copied link") root.statusNote = ""
  }

  Timer {
    id: clockTick
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.publish()
  }

  Process {
    id: ioProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (root.ioBuf.length + String(chunk).length > root.maxFeedBytes + 1) {
          ioProc.signal(15)
          return
        }
        root.ioBuf += chunk
      }
    }
    onStarted: {
      if (!root.ioJob || root.ioJob.op !== "write") return
      var payload = root.ioPayload
      var n = Model.utf8ByteLength(payload)
      if (n < 1 || n > root.maxFeedBytes) {
        ioProc.signal(15)
        return
      }
      write(String(n) + "\n" + payload)
    }
    onExited: function(exitCode) {
      var job = root.ioJob
      root.ioJob = null
      if (!job) {
        root.pumpIo()
        return
      }
      if (job.op === "init") {
        root.dirReady = exitCode === 0
        if (!root.dirReady) {
          root.lastError = "Could not create news state directory"
        } else {
          root.enqueueIo({ op: "read", name: "feed" })
          root.enqueueIo({ op: "read", name: "read" })
        }
      } else if (job.op === "read" && job.name === "feed") {
        if (exitCode === 0) root.applyCache(root.ioBuf)
        else {
          root.feedLoaded = true
          root.publish()
        }
      } else if (job.op === "read" && job.name === "read") {
        if (exitCode === 0) root.applyRead(root.ioBuf)
        else {
          root.readLoaded = true
          root.publish()
        }
        if (root.feedLoaded && root.readLoaded) {
          root.queuedRefresh = false
          root.refresh()
        }
      }
      root.pumpIo()
    }
  }

  Process {
    id: fetchProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        var piece = String(chunk)
        if (root.fetchBuf.length + piece.length > root.maxFeedBytes + 1) {
          root.fetchOverflow = true
          fetchProc.signal(15)
          return
        }
        root.fetchBuf += piece
      }
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (root.fetchOverflow || root.fetchBuf.length > root.maxFeedBytes) {
        root.lastError = "Could not refresh Omarchy News"
        root.offline = root.rawItems.length > 0
        root.publish()
      } else if (exitCode === 0 && root.fetchBuf.replace(/^\s+|\s+$/g, "").length > 0) {
        root.applyFeedXml(root.fetchBuf)
      } else if (root.rawItems.length) {
        root.lastError = ""
        root.offline = false
        root.publish()
      } else {
        root.lastError = "Could not refresh Omarchy News"
        root.publish()
      }
      if (root.queuedRefresh) {
        root.queuedRefresh = false
        root.refresh()
      }
    }
  }
}
