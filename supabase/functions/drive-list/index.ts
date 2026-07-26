// drive-list — proxy อ่านรายการไฟล์ในโฟลเดอร์ Google Drive สาธารณะ
//
// ทำไมต้องมี proxy: Drive API ต้องใช้ API key และตัวแปร VITE_* ทุกตัวถูกรวมลง
// JS bundle สาธารณะตอน build (บทเรียนจากเคส service_role key รั่ว) key จึงต้องอยู่
// ฝั่งเซิร์ฟเวอร์เท่านั้น — ตั้งด้วย `supabase secrets set GOOGLE_API_KEY=...`
//
// อ่านได้เฉพาะโฟลเดอร์ที่แชร์แบบ "ทุกคนที่มีลิงก์" — API key อ่านของสาธารณะได้อย่างเดียว
// ไม่ต้องมี OAuth และผู้ชมไม่ต้องล็อกอิน Google

const DRIVE_API = 'https://www.googleapis.com/drive/v3/files'

// id ของ Drive เป็น base64url — ตรวจก่อนเสมอ กันการยัดอักขระแปลกต่อท้าย q ที่ส่งไป Google
const ID_RE = /^[A-Za-z0-9_-]{10,120}$/

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8', ...extra },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS })
  }

  const apiKey = Deno.env.get('GOOGLE_API_KEY')
  if (!apiKey) {
    return json({ error: 'not_configured', message: 'ยังไม่ได้ตั้งค่า GOOGLE_API_KEY บนเซิร์ฟเวอร์' }, 500)
  }

  const url      = new URL(req.url)
  const folderId = (url.searchParams.get('folderId') || '').trim()
  const pageToken = (url.searchParams.get('pageToken') || '').trim()

  if (!ID_RE.test(folderId)) {
    return json({ error: 'bad_folder_id', message: 'รหัสโฟลเดอร์ไม่ถูกต้อง' }, 400)
  }
  if (pageToken && !/^[A-Za-z0-9_\-=~.]{1,512}$/.test(pageToken)) {
    return json({ error: 'bad_page_token', message: 'pageToken ไม่ถูกต้อง' }, 400)
  }

  try {
    const q = new URLSearchParams({
      q: `'${folderId}' in parents and trashed = false`,
      fields: 'nextPageToken,files(id,name,mimeType,size,modifiedTime,iconLink,thumbnailLink,webViewLink)',
      // โฟลเดอร์ขึ้นก่อนเสมอ แล้วเรียงชื่อแบบธรรมชาติ (เลข 2 มาก่อน 10)
      orderBy: 'folder,name_natural',
      pageSize: '1000',
      supportsAllDrives: 'true',
      includeItemsFromAllDrives: 'true',
      key: apiKey,
    })
    if (pageToken) q.set('pageToken', pageToken)

    const upstream = await fetch(`${DRIVE_API}?${q}`)
    const data = await upstream.json()

    if (!upstream.ok) {
      const reason = data?.error?.errors?.[0]?.reason || ''
      // เคสที่จะเจอบ่อยที่สุด: ลืมตั้งค่าแชร์โฟลเดอร์ — แยกข้อความให้ผู้ใช้แก้ได้เอง
      if (upstream.status === 404 || reason === 'notFound') {
        return json({
          error: 'not_public',
          message: 'ไม่พบโฟลเดอร์ หรือยังไม่ได้แชร์แบบ "ทุกคนที่มีลิงก์ → ผู้อ่าน"',
        }, 404)
      }
      if (upstream.status === 403) {
        return json({
          error: 'forbidden',
          message: reason === 'rateLimitExceeded'
            ? 'เรียก Google Drive บ่อยเกินไป ลองใหม่อีกครั้ง'
            : 'API key ไม่มีสิทธิ์เรียก Drive API (ตรวจว่าเปิด Drive API แล้ว และไม่ได้ตั้งจำกัดแบบ HTTP referrer)',
        }, 403)
      }
      return json({ error: 'upstream', message: data?.error?.message || `Drive API ตอบ ${upstream.status}` }, 502)
    }

    return json(
      { files: data.files ?? [], nextPageToken: data.nextPageToken ?? null },
      200,
      // cache ฝั่ง CDN/เบราว์เซอร์ 10 นาที — Drive ไม่ได้เปลี่ยนบ่อย และกันยิงซ้ำจากหน้าแรกที่คนเข้าเยอะ
      { 'Cache-Control': 'public, max-age=600' },
    )
  } catch (err) {
    return json({ error: 'fetch_failed', message: String(err) }, 502)
  }
})
