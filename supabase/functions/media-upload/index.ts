// media-upload — ตัวกลางระหว่างเว็บกับ PHP host ของเขต
//
// ทำไมต้องมี: เดิมเว็บยิง upload.php ตรง ๆ โดยแนบ X-Upload-Secret ที่มาจาก
// VITE_UPLOAD_API_SECRET ซึ่ง Vite ฝังลงไฟล์ JS ที่ใครก็โหลดได้
// → ความลับหลุดสู่สาธารณะ ใครก็อัปโหลด/ลบไฟล์บนเซิร์ฟเวอร์เขตได้โดยไม่ต้องล็อกอิน
// ตอนนี้ความลับอยู่แค่ฝั่งนี้ (supabase secrets) และผู้เรียกต้องมี JWT ที่ถูกต้อง
//
// ไม่จำกัดเฉพาะ admin — ศน./staff ต้องอัปรูปข่าวและแบนเนอร์ได้อยู่แล้ว
// ความเป็น admin-only ของ "คลังภาพ" มาจาก RLS ของตาราง image_library ไม่ใช่จากที่นี่
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL     = Deno.env.get('SUPABASE_URL')!
const ADMIN_SECRET_KEY = Deno.env.get('ADMIN_SECRET_KEY')!
const UPLOAD_API_URL   = Deno.env.get('UPLOAD_API_URL')    || ''   // .../upload.php
const UPLOAD_SECRET    = Deno.env.get('UPLOAD_API_SECRET') || ''

const admin = createClient(SUPABASE_URL, ADMIN_SECRET_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}

/** ผู้เรียกต้องล็อกอินและผ่านการอนุมัติแล้วเท่านั้น */
async function requireApprovedUser(req: Request) {
  const token = (req.headers.get('Authorization') || '').replace('Bearer ', '')
  if (!token) return { error: json({ error: 'unauthorized' }, 401) }

  const { data: { user }, error: userErr } = await admin.auth.getUser(token)
  if (userErr || !user) return { error: json({ error: 'unauthorized' }, 401) }

  const { data: profile } = await admin
    .from('profiles').select('role, is_approved, is_active').eq('id', user.id).single()

  if (!profile || profile.is_approved === false || profile.is_active === false) {
    return { error: json({ error: 'forbidden' }, 403) }
  }
  return { user, profile }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== 'POST')    return json({ error: 'method not allowed' }, 405)

  const auth = await requireApprovedUser(req)
  if (auth.error) return auth.error

  if (!UPLOAD_API_URL || !UPLOAD_SECRET) {
    return json({ error: 'not_configured', message: 'ยังไม่ได้ตั้งค่า UPLOAD_API_URL / UPLOAD_API_SECRET บนเซิร์ฟเวอร์' }, 500)
  }

  const contentType = req.headers.get('content-type') || ''

  try {
    // ── ลบไฟล์ (ส่ง JSON มา) ────────────────────────────────────────────
    if (contentType.includes('application/json')) {
      const body = await req.json()
      if (body.action !== 'delete' || !body.url) return json({ error: 'bad request' }, 400)

      const res = await fetch(UPLOAD_API_URL.replace(/upload\.php$/, 'delete.php'), {
        method: 'POST',
        headers: { 'X-Upload-Secret': UPLOAD_SECRET, 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: body.url }),
      })
      const data = await res.json().catch(() => ({}))
      return json(data, res.ok ? 200 : res.status)
    }

    // ── อัปโหลด (multipart ส่งต่อทั้งก้อน) ──────────────────────────────
    // อ่าน formData แล้วประกอบใหม่ ไม่ส่ง body ดิบต่อ เพราะต้องคุมว่า category
    // เป็นค่าที่ยอมรับได้และไม่ให้แนบฟิลด์แปลกปลอมเข้าไปที่ PHP
    const form = await req.formData()
    const file = form.get('file')
    if (!(file instanceof File)) return json({ error: 'missing file' }, 400)

    const category = String(form.get('category') || 'misc').replace(/[^a-z0-9_-]/gi, '') || 'misc'

    const fwd = new FormData()
    fwd.append('file', file, file.name)
    fwd.append('category', category)

    const res = await fetch(UPLOAD_API_URL, {
      method: 'POST',
      headers: { 'X-Upload-Secret': UPLOAD_SECRET },
      body: fwd,
    })
    const data = await res.json().catch(() => ({}))
    return json(data, res.ok ? 200 : res.status)
  } catch (e) {
    return json({ error: (e as Error).message || 'upload failed' }, 500)
  }
})
