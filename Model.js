// Official Omarchy / Omacom RSS only. Parse, sanitize, unread policy, grouping.
// Qt-free so node can check the same functions the QML imports.

var FEED_URL = "https://omarchy.org/news/rss.xml"
var NEWS_INDEX_URL = "https://omarchy.org/news"
var MAX_FEED_BYTES = 1048576
var MAX_TITLE = 200
var MAX_CREATOR = 80
var MAX_DEK = 280
var MAX_BODY = 20000
var MAX_BODY_TOKENS = 400
var MAX_TOOLTIP = 200
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function feedUrl() {
  return FEED_URL
}

function newsIndexUrl() {
  return NEWS_INDEX_URL
}

function trim(value) {
  return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
}

function unwrapCdata(value) {
  var text = String(value === undefined || value === null ? "" : value)
  var match = text.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/)
  return match ? match[1] : text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
}

function decodeEntities(value) {
  var text = String(value === undefined || value === null ? "" : value)
  text = text.replace(/&#x([0-9a-fA-F]+);/g, function(_, hex) {
    var code = parseInt(hex, 16)
    return isFinite(code) ? String.fromCharCode(code) : ""
  })
  text = text.replace(/&#(\d+);/g, function(_, dec) {
    var code = parseInt(dec, 10)
    return isFinite(code) ? String.fromCharCode(code) : ""
  })
  return text
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&apos;/gi, "'")
}

function hostOf(url) {
  var match = String(url || "").match(/^https:\/\/([^\/?#]+)/i)
  return match ? match[1].toLowerCase() : ""
}

function isOmarchyHost(host) {
  return host === "omarchy.org" || host === "www.omarchy.org"
}

function isHttpsUrl(url) {
  var s = String(url || "")
  if (s.length > 2048) return false
  if (s.indexOf("@") !== -1) return false
  return /^https:\/\/[A-Za-z0-9.-]+(?::\d+)?(?:[/?#][^\s"'<>]*)?$/i.test(s)
}

function utf8ByteLength(value) {
  var s = String(value || "")
  var n = 0
  var i
  for (i = 0; i < s.length; i++) {
    var c = s.charCodeAt(i)
    if (c <= 0x7f) n += 1
    else if (c <= 0x7ff) n += 2
    else if (c >= 0xd800 && c <= 0xdfff) {
      n += 4
      i += 1
    } else n += 3
  }
  return n
}

function plainLabel(value, maxLen) {
  var text = stripTags(value)
  text = text.replace(/[<>&]/g, "")
  text = text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
  var max = Number(maxLen)
  if (!isFinite(max) || max <= 0) max = MAX_TITLE
  if (text.length > max) text = text.slice(0, max)
  return text
}

function isCanonicalArticleUrl(url) {
  if (!isHttpsUrl(url)) return false
  return isOmarchyHost(hostOf(url))
}

function firstTag(block, name) {
  var escaped = String(name).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  var match = String(block || "").match(new RegExp("<" + escaped + "(\\s[^>]*)?>([\\s\\S]*?)</" + escaped + ">", "i"))
  if (!match) return { attrs: "", value: "" }
  return { attrs: match[1] || "", value: decodeEntities(unwrapCdata(match[2])) }
}

function stripTags(html) {
  return trim(decodeEntities(String(html || "").replace(/<[^>]+>/g, " ")).replace(/\s+/g, " "))
}

function extractHref(attrs) {
  var match = String(attrs || "").match(/\bhref\s*=\s*("([^"]*)"|'([^']*)')/i)
  if (!match) return ""
  return trim(decodeEntities(match[2] !== undefined ? match[2] : match[3]))
}

function htmlTagName(inner) {
  var match = String(inner || "").match(/^\/?\s*([A-Za-z][A-Za-z0-9]*)/)
  return match ? match[1].toLowerCase() : ""
}

function htmlTagIsClose(inner) {
  return /^\s*\//.test(String(inner || ""))
}

function isBreakTag(name) {
  return name === "p" || name === "br" || name === "div" || name === "li"
    || name === "h1" || name === "h2" || name === "h3" || name === "tr"
    || name === "blockquote"
}

function sanitizeBodyText(value) {
  return String(value || "")
    .replace(/[<>&]/g, "")
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
}

function pushBodyToken(segments, used, max, token) {
  if (segments.length >= MAX_BODY_TOKENS) return -1
  if (token.kind === "break") {
    if (segments.length === 0 || segments[segments.length - 1].kind === "break") return used
    segments.push({ kind: "break", text: "" })
    return used
  }
  var text = sanitizeBodyText(token.text)
  if (!text) return used
  if (used >= max) return -1
  if (used + text.length > max) text = text.slice(0, max - used)
  if (!text) return -1
  var next = { kind: token.kind, text: text }
  if (token.kind === "link") next.href = token.href
  segments.push(next)
  return used + text.length
}

function pushTextWithBareUrls(segments, used, max, chunk) {
  var text = sanitizeBodyText(decodeEntities(chunk))
  if (!text) return used
  var re = /https:\/\/[A-Za-z0-9.-]+(?::\d+)?(?:\/[^\s]*)?/g
  var last = 0
  var match
  while ((match = re.exec(text))) {
    if (match.index > last) {
      used = pushBodyToken(segments, used, max, { kind: "text", text: text.slice(last, match.index) })
      if (used < 0) return used
    }
    if (isHttpsUrl(match[0])) {
      used = pushBodyToken(segments, used, max, { kind: "link", text: match[0], href: match[0] })
    } else {
      used = pushBodyToken(segments, used, max, { kind: "text", text: match[0] })
    }
    if (used < 0) return used
    last = match.index + match[0].length
  }
  if (last < text.length)
    used = pushBodyToken(segments, used, max, { kind: "text", text: text.slice(last) })
  return used
}

function bodyTokens(html, maxLen) {
  var raw = String(html || "")
  var max = Number(maxLen)
  if (!isFinite(max) || max <= 0) max = MAX_BODY
  var segments = []
  var used = 0
  var i = 0
  while (i < raw.length && used >= 0 && segments.length < MAX_BODY_TOKENS) {
    if (raw.charAt(i) !== "<") {
      var lt = raw.indexOf("<", i)
      if (lt < 0) lt = raw.length
      used = pushTextWithBareUrls(segments, used, max, raw.slice(i, lt))
      i = lt
      continue
    }
    if (raw.slice(i, i + 4) === "<!--") {
      var endComment = raw.indexOf("-->", i + 4)
      i = endComment < 0 ? raw.length : endComment + 3
      continue
    }
    var gt = raw.indexOf(">", i)
    if (gt < 0) break
    var inner = raw.slice(i + 1, gt)
    var name = htmlTagName(inner)
    if (name === "a" && !htmlTagIsClose(inner)) {
      var href = extractHref(" " + inner)
      var rest = raw.slice(gt + 1)
      var closeMatch = rest.match(/<\s*\/\s*a\s*>/i)
      var labelHtml = closeMatch ? rest.slice(0, closeMatch.index) : rest
      var label = stripTags(labelHtml)
      if (isHttpsUrl(href))
        used = pushBodyToken(segments, used, max, { kind: "link", text: label || href, href: href })
      else
        used = pushBodyToken(segments, used, max, { kind: "text", text: label })
      i = closeMatch ? gt + 1 + closeMatch.index + closeMatch[0].length : raw.length
      continue
    }
    if (isBreakTag(name))
      used = pushBodyToken(segments, used, max, { kind: "break", text: "" })
    i = gt + 1
  }
  return segments
}

function bodyParagraphs(html, maxLen) {
  var tokens = bodyTokens(html, maxLen)
  var paragraphs = []
  var current = []
  var i
  function flush() {
    if (!current.length) return
    paragraphs.push(current)
    current = []
  }
  for (i = 0; i < tokens.length; i++) {
    var token = tokens[i]
    if (token.kind === "break") {
      flush()
      continue
    }
    if (token.kind === "link") {
      current.push({ kind: "link", text: token.text, href: token.href })
      continue
    }
    var parts = String(token.text || "").split(/(\s+)/)
    var j
    for (j = 0; j < parts.length; j++) {
      if (!parts[j]) continue
      current.push({ kind: "text", text: parts[j] })
    }
  }
  flush()
  return paragraphs
}

function cachedBody(item) {
  if (!item || typeof item !== "object") return []
  if (item.body && item.body.length) return item.body
  return bodyParagraphs(item.content || "", MAX_BODY)
}

function isRss20(xml) {
  return /<rss\b[^>]*\bversion\s*=\s*["']2\.0["']/i.test(String(xml || ""))
    || /<rss\b[^>]*\bversion\s*=\s*2\.0\b/i.test(String(xml || ""))
}

function feedSelfHref(xml) {
  var links = String(xml || "").match(/<atom:link\b[^>]*>/gi) || []
  var i
  for (i = 0; i < links.length; i++) {
    var tag = links[i]
    if (!/\brel\s*=\s*["']self["']/i.test(tag)) continue
    var href = extractHref(tag)
    if (href) return href
  }
  return trim(firstTag(xml, "link").value)
}

function isOfficialFeed(xml) {
  if (!isRss20(xml)) return false
  if (!/<channel\b/i.test(String(xml || ""))) return false
  var selfHref = feedSelfHref(xml)
  if (selfHref === FEED_URL || selfHref === NEWS_INDEX_URL) return true
  return isOmarchyHost(hostOf(selfHref))
}

function parsePubMs(value) {
  var parsed = Date.parse(String(value || ""))
  return isFinite(parsed) ? parsed : 0
}

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function dayKey(ms) {
  var date = new Date(ms)
  if (!isFinite(date.getTime())) return ""
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function dayLabel(ms, nowMs) {
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var key = dayKey(ms)
  if (!key) return ""
  if (key === dayKey(now)) return "Today"
  if (key === dayKey(now - 86400000)) return "Yesterday"
  var date = new Date(ms)
  return date.getDate() + " " + MONTHS[date.getMonth()]
}

function relativeTime(ms, nowMs) {
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var then = Number(ms) || 0
  if (!then) return ""
  var delta = now - then
  if (delta < 0) delta = 0
  var seconds = Math.floor(delta / 1000)
  if (seconds < 45) return "just now"
  var minutes = Math.floor(seconds / 60)
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  if (dayKey(then) === dayKey(now - 86400000)) return "Yesterday"
  return dayLabel(then, now)
}

function parseItem(block) {
  var title = trim(firstTag(block, "title").value)
  var link = trim(firstTag(block, "link").value)
  var guidTag = firstTag(block, "guid")
  var guid = trim(guidTag.value)
  var creator = trim(firstTag(block, "dc:creator").value)
  var description = firstTag(block, "description").value
  var encoded = firstTag(block, "content:encoded").value
  var pubDate = trim(firstTag(block, "pubDate").value)
  var identity = guid || link
  if (!identity) return null
  var canonical = isCanonicalArticleUrl(link) ? link : (isCanonicalArticleUrl(guid) ? guid : "")
  if (!canonical) return null
  var pubMs = parsePubMs(pubDate)
  var source = encoded || description
  return {
    identity: identity,
    title: plainLabel(title || "Untitled", MAX_TITLE),
    link: canonical,
    guid: guid,
    pubDate: pubDate,
    pubMs: pubMs,
    creator: plainLabel(creator, MAX_CREATOR),
    dek: plainLabel(description, MAX_DEK),
    content: plainLabel(source, MAX_BODY),
    html: String(source).slice(0, MAX_BODY * 2),
    body: bodyParagraphs(source, MAX_BODY)
  }
}

function parseFeed(xml) {
  var raw = String(xml || "")
  if (raw.length > MAX_FEED_BYTES) {
    return { ok: false, error: "Feed larger than 1 MiB", items: [] }
  }
  if (!isOfficialFeed(raw)) {
    return { ok: false, error: "Not the official Omarchy News RSS 2.0 feed", items: [] }
  }
  var parts = raw.split(/<item\b/i)
  var items = []
  var seen = {}
  var i
  for (i = 1; i < parts.length; i++) {
    var close = parts[i].split(/<\/item>/i)[0]
    var item = parseItem(close)
    if (!item) continue
    if (seen[item.identity]) continue
    seen[item.identity] = true
    items.push(item)
  }
  items.sort(function(a, b) { return (b.pubMs || 0) - (a.pubMs || 0) })
  return { ok: true, error: "", items: items }
}

function emptyReadState() {
  return { firstSeenAt: "", firstSeenAtMs: 0, read: {} }
}

function parseReadState(raw) {
  var state = emptyReadState()
  if (!raw) return state
  var parsed
  try {
    parsed = JSON.parse(String(raw))
  } catch (e) {
    return state
  }
  if (!parsed || typeof parsed !== "object") return state
  var first = parsed.firstSeenAt || parsed.firstSeen || ""
  var firstMs = Number(parsed.firstSeenAtMs)
  if (!isFinite(firstMs) || firstMs <= 0) firstMs = parsePubMs(first)
  state.firstSeenAt = String(first || "")
  state.firstSeenAtMs = firstMs || 0
  var read = parsed.read
  if (Array.isArray(read)) {
    var i
    for (i = 0; i < read.length; i++) {
      if (read[i]) state.read[String(read[i])] = true
    }
  } else if (read && typeof read === "object") {
    var key
    for (key in read) {
      if (read[key]) state.read[String(key)] = true
    }
  }
  return state
}

function serializeReadState(state) {
  var src = state || emptyReadState()
  return {
    firstSeenAt: src.firstSeenAt || "",
    firstSeenAtMs: src.firstSeenAtMs || 0,
    read: src.read || {}
  }
}

function isoNow(ms) {
  return new Date(ms).toISOString()
}

function ingestItems(items, readState, nowMs) {
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var state = readState || emptyReadState()
  var nextRead = {}
  var key
  for (key in (state.read || {})) nextRead[key] = true
  var firstMs = Number(state.firstSeenAtMs) || 0
  var firstAt = state.firstSeenAt || ""
  var list = items || []
  var i
  if (!firstMs) {
    firstMs = now
    firstAt = isoNow(now)
    for (i = 0; i < list.length; i++) {
      if (list[i] && list[i].identity) nextRead[list[i].identity] = true
    }
  }
  return {
    firstSeenAt: firstAt,
    firstSeenAtMs: firstMs,
    read: nextRead
  }
}

function isUnread(item, readState) {
  if (!item || !item.identity) return false
  var firstMs = readState && readState.firstSeenAtMs ? Number(readState.firstSeenAtMs) : 0
  if (!firstMs) return false
  if ((Number(item.pubMs) || 0) <= firstMs) return false
  if (readState.read && readState.read[item.identity]) return false
  return true
}

function decorateItems(items, readState, nowMs) {
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var list = items || []
  var out = []
  var i
  for (i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item) continue
    var copy = {}
    var key
    for (key in item) copy[key] = item[key]
    copy.unread = isUnread(item, readState)
    copy.relative = relativeTime(item.pubMs, now)
    copy.dayKey = dayKey(item.pubMs)
    copy.dayLabel = dayLabel(item.pubMs, now)
    copy.index = i
    out.push(copy)
  }
  return out
}

function unreadCount(items) {
  var list = items || []
  var n = 0
  var i
  for (i = 0; i < list.length; i++) if (list[i] && list[i].unread) n += 1
  return n
}

function badgeLabel(count) {
  var n = Number(count) || 0
  if (n <= 0) return ""
  if (n > 9) return "9+"
  return String(n)
}

function latestHeadline(items) {
  var list = items || []
  var i
  for (i = 0; i < list.length; i++) {
    if (list[i] && list[i].unread && list[i].title) return list[i].title
  }
  return list.length && list[0] && list[0].title ? list[0].title : ""
}

function tooltipText(items, count) {
  var n = Number(count) || 0
  if (n > 1) return plainLabel(n + " new announcements", MAX_TOOLTIP)
  var headline = latestHeadline(items)
  return plainLabel(headline || "Omarchy News", MAX_TOOLTIP)
}

function groupItems(items) {
  var list = items || []
  var groups = []
  var index = {}
  var i
  for (i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item) continue
    var label = item.dayLabel || ""
    if (!index[label]) {
      index[label] = { label: label, items: [] }
      groups.push(index[label])
    }
    index[label].items.push(item)
  }
  return groups
}

function copyReadState(readState) {
  var now = readState && Number(readState.firstSeenAtMs) > 0 ? Number(readState.firstSeenAtMs) : Date.now()
  return ingestItems([], readState, now)
}

function markRead(readState, identity) {
  var state = copyReadState(readState)
  if (identity) state.read[String(identity)] = true
  return state
}

function markUnread(readState, identity) {
  var state = copyReadState(readState)
  if (identity && state.read) delete state.read[String(identity)]
  return state
}

function markAllRead(readState, items) {
  var state = copyReadState(readState)
  var list = items || []
  var i
  for (i = 0; i < list.length; i++) {
    if (list[i] && list[i].identity) state.read[list[i].identity] = true
  }
  return state
}

function toggleRead(readState, identity, unread) {
  if (unread) return markRead(readState, identity)
  return markUnread(readState, identity)
}

function clampRefreshMinutes(value) {
  var n = parseInt(String(value === undefined || value === null ? "" : value), 10)
  if (!isFinite(n)) return 15
  if (n < 5) return 5
  if (n > 1440) return 1440
  return n
}

function serializeFeed(items, fetchedAt) {
  return { fetchedAt: fetchedAt || "", items: items || [] }
}

function parseFeedCache(raw) {
  if (!raw) return { fetchedAt: "", items: [] }
  try {
    var parsed = JSON.parse(String(raw))
    if (!parsed || typeof parsed !== "object") return { fetchedAt: "", items: [] }
    var items = Array.isArray(parsed.items) ? parsed.items : []
    var i
    for (i = 0; i < items.length; i++) {
      if (items[i] && !items[i].body)
        items[i].body = cachedBody(items[i])
    }
    return {
      fetchedAt: String(parsed.fetchedAt || ""),
      items: items
    }
  } catch (e) {
    return { fetchedAt: "", items: [] }
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    FEED_URL: FEED_URL,
    NEWS_INDEX_URL: NEWS_INDEX_URL,
    MAX_FEED_BYTES: MAX_FEED_BYTES,
    feedUrl: feedUrl,
    newsIndexUrl: newsIndexUrl,
    isHttpsUrl: isHttpsUrl,
    isCanonicalArticleUrl: isCanonicalArticleUrl,
    utf8ByteLength: utf8ByteLength,
    plainLabel: plainLabel,
    stripTags: stripTags,
    bodyTokens: bodyTokens,
    bodyParagraphs: bodyParagraphs,
    parseFeed: parseFeed,
    emptyReadState: emptyReadState,
    parseReadState: parseReadState,
    serializeReadState: serializeReadState,
    ingestItems: ingestItems,
    decorateItems: decorateItems,
    unreadCount: unreadCount,
    badgeLabel: badgeLabel,
    latestHeadline: latestHeadline,
    tooltipText: tooltipText,
    groupItems: groupItems,
    markRead: markRead,
    markUnread: markUnread,
    markAllRead: markAllRead,
    toggleRead: toggleRead,
    clampRefreshMinutes: clampRefreshMinutes,
    copyReadState: copyReadState,
    serializeFeed: serializeFeed,
    parseFeedCache: parseFeedCache,
    relativeTime: relativeTime,
    dayLabel: dayLabel
  }
}
