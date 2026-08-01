// drive-check — ตรวจว่าไฟล์ Google Drive แชร์แบบสาธารณะจริงหรือยัง
//
// ก่อนหน้านี้ทั้งระบบไม่เคยตรวจเลย — จดหมายข่าว/เอกสารแค่ regex หา file id จาก URL
// แล้วขึ้นกล่องเตือนให้ผู้ใช้ไปตั้งค่าแชร์เอง กว่าจะรู้ว่าลืมก็ตอนภาพปกไม่ขึ้นบนหน้าเว็บแล้ว
//
// API key อ่านได้เฉพาะไฟล์สาธารณะ → ถ้า Drive ตอบ 404 แปลว่า "ยังไม่ได้แชร์" (หรือไม่มีจริง)
// ซึ่งพอดีกับสิ่งที่เราอยากรู้ ไม่ต้องใช้ OAuth
//
// ⚠️ **verify_jwt ของแพลตฟอร์มอย่างเดียวกันคนนอกไม่ได้** — ทดสอบแล้วพบว่า
// anon key ผ่านด่านนั้นได้สบาย ซึ่ง anon key เป็นของสาธารณะโดยตั้งใจ (อยู่ใน JS bundle)
// ใครก็ยิงฟังก์ชันนี้ได้ กลายเป็นเครื่องมือไล่เดาว่าไฟล์ Drive id ไหนมีอยู่จริง
// จึงต้อง **ตรวจผู้ใช้เองในฟังก์ชัน** แบบเดียวกับ media-upload / admin-users
// (ยังคงไม่ใส่ verify_jwt = false ใน config.toml ไว้เป็นด่านแรกอีกชั้น)
//
// key ตั้งด้วย `supabase secrets set GOOGLE_API_KEY=...` — ห้ามย้ายมาเป็น VITE_*
// เพราะ Vite ฝังตัวแปรพวกนั้นลง bundle สาธารณะ (บทเรียนจากเคส service_role key รั่ว)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const DRIVE_API = 'https://www.googleapis.com/drive/v3/files'

const admin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('ADMIN_SECRET_KEY') ?? '',
  { auth: { persistSession: false } },
)

/** ต้องเป็นสมาชิกที่อนุมัติแล้วและมีสิทธิ์ลงเนื้อหา — anon key ผ่านไม่ได้ */
const WRITER_ROLES = ['super_admin', 'admin', 'supervisor', 'staff']

async function requireWriter(req: Request) {
  const token = (req.headers.get('Authorization') || '').replace('Bearer ', '')
  if (!token) return { error: json({ ok: false, error: 'unauthorized' }, 401) }

  const { data: { user }, error: userErr } = await admin.auth.getUser(token)
  if (userErr || !user) return { error: json({ ok: false, error: 'unauthorized' }, 401) }

  const { data: profile } = await admin
    .from('profiles').select('role, is_approved, is_active').eq('id', user.id).single()

  if (!profile || profile.is_approved === false || profile.is_active === false
      || !WRITER_ROLES.includes(profile.role)) {
    return { error: json({ ok: false, error: 'forbidden' }, 403) }
  }
  return { user, profile }
}

// id ของ Drive เป็น base64url — กรองก่อนเสมอ ไม่ให้อักขระแปลกหลุดไปต่อใน URL ที่ส่งหา Google
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

  // ตรวจสิทธิ์ก่อนตรวจการตั้งค่าเสมอ — ไม่งั้นคนที่ไม่มี token จะได้ 500
  // พร้อมรู้สถานะการตั้งค่าของเซิร์ฟเวอร์ไปด้วย (เคยพลาดตรงนี้ใน media-upload มาแล้ว)
  const auth = await requireWriter(req)
  if (auth.error) return auth.error

  const apiKey = Deno.env.get('GOOGLE_API_KEY')
  if (!apiKey) {
    return json({ ok: false, error: 'not_configured', message: 'ยังไม่ได้ตั้งค่า GOOGLE_API_KEY บนเซิร์ฟเวอร์' }, 500)
  }

  const fileId = (new URL(req.url).searchParams.get('fileId') || '').trim()
  if (!ID_RE.test(fileId)) {
    return json({ ok: false, error: 'bad_file_id', message: 'รหัสไฟล์ไม่ถูกต้อง' }, 400)
  }

  try {
    const q = new URLSearchParams({
      fields: 'id,name,mimeType,size,modifiedTime',
      supportsAllDrives: 'true',
      key: apiKey,
    })
    const upstream = await fetch(`${DRIVE_API}/${fileId}?${q}`)
    const data = await upstream.json()

    if (!upstream.ok) {
      const reason = data?.error?.errors?.[0]?.reason || ''
      if (upstream.status === 404 || reason === 'notFound') {
        return json({
          ok: false,
          error: 'not_public',
          message: 'ยังไม่ได้แชร์แบบ "ทุกคนที่มีลิงก์" หรือไม่พบไฟล์นี้',
        }, 200)   // 200 เพราะ "ตรวจสำเร็จ ผลคือยังไม่สาธารณะ" ไม่ใช่คำขอผิดพลาด
      }
      if (upstream.status === 403) {
        return json({
          ok: false,
          error: 'forbidden',
          message: reason === 'rateLimitExceeded'
            ? 'เรียก Google Drive บ่อยเกินไป ลองใหม่อีกครั้ง'
            : 'API key ไม่มีสิทธิ์เรียก Drive API',
        }, 200)
      }
      return json({ ok: false, error: 'upstream', message: data?.error?.message || `Drive API ตอบ ${upstream.status}` }, 502)
    }

    return json({
      ok: true,
      id: data.id,
      name: data.name ?? '',
      mimeType: data.mimeType ?? '',
      size: data.size ?? null,
      modifiedTime: data.modifiedTime ?? null,
    })
  } catch (err) {
    return json({ ok: false, error: 'fetch_failed', message: String(err) }, 502)
  }
})
