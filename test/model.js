#!/usr/bin/env node
const assert = require("assert")
const Model = require("../Model.js")

assert.strictEqual(Model.isHttpsUrl("https://omarchy.org/news"), true)
assert.strictEqual(Model.isHttpsUrl("https://evil.example/@omarchy.org/"), false)
assert.strictEqual(Model.isHttpsUrl("https://evil@omarchy.org/news"), false)
assert.strictEqual(Model.isHttpsUrl("http://omarchy.org/news"), false)

const dirty = '<p>Hello <img src="http://127.0.0.1/x"> <a href="https://omarchy.org/x">link</a></p>'
const plain = Model.plainLabel(dirty, 200)
assert.ok(!plain.includes("<"))
assert.ok(!plain.includes(">"))
assert.ok(!plain.includes("&"))
assert.ok(plain.includes("Hello"))
assert.ok(plain.includes("link"))

const xml = `<?xml version="1.0"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<channel>
<title>Omarchy News</title>
<link>https://omarchy.org/news</link>
<atom:link rel="self" href="https://omarchy.org/news/rss.xml"/>
<item>
<title>We can &lt;img src="http://127.0.0.1/x"&gt; fix</title>
<link>https://omarchy.org/news/2026/09/example</link>
<guid>https://omarchy.org/news/2026/09/example</guid>
<description>&lt;p&gt;dek with &lt;script&gt;no&lt;/script&gt;&lt;/p&gt;</description>
<content:encoded><![CDATA[<p>Body <img src="http://127.0.0.1/leak.png"> more</p>]]></content:encoded>
<pubDate>Sat, 06 Sep 2026 12:00:00 GMT</pubDate>
</item>
</channel>
</rss>`

const parsed = Model.parseFeed(xml)
assert.strictEqual(parsed.ok, true)
assert.strictEqual(parsed.items.length, 1)
assert.ok(!parsed.items[0].title.includes("<"))
assert.ok(!parsed.items[0].content.includes("<img"))
assert.ok(!parsed.items[0].content.includes("127.0.0.1"))
assert.ok(parsed.items[0].content.includes("Body"))

const tip = Model.tooltipText(parsed.items, 1)
assert.ok(!tip.includes("<"))

console.log("ok")
