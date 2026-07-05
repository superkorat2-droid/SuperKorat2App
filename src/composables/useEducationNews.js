import { ref, readonly } from 'vue'

// ── Module-level cache (shared across all component usages) ─────────────────
const _items   = ref([])
const _loading = ref(false)
const _error   = ref(null)
let   _cacheTs = 0
const CACHE_TTL = 15 * 60 * 1000

// ── Regex-based RSS item parser ─────────────────────────────────────────────
// Avoids DOMParser <link> quirk in XML mode on some browsers
function extractTag(block, tag) {
  const re = new RegExp(
    `<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`,
    'i',
  )
  const m = block.match(re)
  return m ? m[1].trim() : ''
}

function parseItems(xml, max = 25) {
  const items = []
  const itemRe = /<item>([\s\S]*?)<\/item>/g
  let m
  while ((m = itemRe.exec(xml)) !== null && items.length < max) {
    const block = m[1]
    const item = {
      title:   extractTag(block, 'title'),
      link:    extractTag(block, 'link'),
      pubDate: extractTag(block, 'pubDate'),
      source:  extractTag(block, 'source'),
    }
    if (item.title && item.link) items.push(item)
  }
  return items
}

// ── Composable ──────────────────────────────────────────────────────────────
export function useEducationNews() {
  const proxyUrl = import.meta.env.DEV
    ? '/rss-proxy'
    : import.meta.env.VITE_NEWS_RSS_URL

  async function fetchNews(force = false) {
    if (!force && _cacheTs && Date.now() - _cacheTs < CACHE_TTL) return

    _loading.value = true
    _error.value   = null
    try {
      const res = await fetch(proxyUrl)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const xml = await res.text()
      if (!xml.includes('<item>')) throw new Error('Invalid RSS response')
      _items.value = parseItems(xml)
      _cacheTs     = Date.now()
    } catch (err) {
      _error.value = err.message || 'โหลดข่าวไม่สำเร็จ'
      if (!_items.value.length) _items.value = []
    } finally {
      _loading.value = false
    }
  }

  return {
    news:      readonly(_items),
    loading:   readonly(_loading),
    error:     readonly(_error),
    fetchNews,
  }
}
