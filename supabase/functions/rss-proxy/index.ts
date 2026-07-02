const RSS_URL =
  'https://news.google.com/rss/search?q=%E0%B8%82%E0%B9%88%E0%B8%B2%E0%B8%A7%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%A8%E0%B8%B6%E0%B8%81%E0%B8%A9%E0%B8%B2&hl=th&gl=TH&ceid=TH:th'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS })
  }

  try {
    const upstream = await fetch(RSS_URL, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; RSS-Reader/1.0)' },
    })

    if (!upstream.ok) {
      throw new Error(`Upstream returned ${upstream.status}`)
    }

    const xml = await upstream.text()

    return new Response(xml, {
      headers: {
        ...CORS_HEADERS,
        'Content-Type': 'application/rss+xml; charset=utf-8',
        'Cache-Control': 'public, max-age=900',
      },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 502,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    })
  }
})
