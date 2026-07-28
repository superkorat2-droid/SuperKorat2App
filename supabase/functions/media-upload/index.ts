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

/**
 * ออก "ตั๋ว" ให้เบราว์เซอร์เอาไปยิง PHP เอง
 *
 * ทำไมไม่ให้ Edge Function ยิงเอง: Cloudflare หน้าโดเมนของเขตบล็อกคำขอที่มาจาก
 * ศูนย์ข้อมูล (ตอบ 403 Attention Required!) ส่วนคำขอจากเบราว์เซอร์ผู้ใช้ผ่านปกติ
 *
 * ทำไมไม่ส่ง UPLOAD_SECRET ไปให้เบราว์เซอร์: เคยรั่วมาแล้วเพราะฝังใน bundle
 * ตั๋วนี้เซ็นด้วย HMAC ของความลับ อายุ 2 นาที และผูกกับ category ที่ขอ
 * ต่อให้ใครดักไปได้ก็ทำได้แค่อัปไฟล์เข้าโฟลเดอร์เดิมภายในสองนาที
 * และถอดกลับเป็นความลับไม่ได้
 */
const TICKET_TTL_SEC = 120

async function issueTicket(purpose: 'upload' | 'delete', category: string) {
  const exp   = Math.floor(Date.now() / 1000) + TICKET_TTL_SEC
  const nonce = crypto.randomUUID().replace(/-/g, '').slice(0, 16)
  const payload = `${purpose}.${category}.${exp}.${nonce}`

  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(UPLOAD_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload))
  const sig = [...new Uint8Array(sigBuf)].map(b => b.toString(16).padStart(2, '0')).join('')

  return { ticket: `${payload}.${sig}`, exp }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== 'POST')    return json({ error: 'method not allowed' }, 405)

  const auth = await requireApprovedUser(req)
  if (auth.error) return auth.error

  if (!UPLOAD_API_URL || !UPLOAD_SECRET) {
    return json({ error: 'not_configured', message: 'ยังไม่ได้ตั้งค่า UPLOAD_API_URL / UPLOAD_API_SECRET บนเซิร์ฟเวอร์' }, 500)
  }

  try {
    const body = await req.json().catch(() => ({}))
    const purpose = body.purpose === 'delete' ? 'delete' : 'upload'
    const category = String(body.category || 'misc').replace(/[^a-z0-9_-]/gi, '') || 'misc'

    const { ticket, exp } = await issueTicket(purpose, category)
    const uploadUrl = UPLOAD_API_URL
    const deleteUrl = UPLOAD_API_URL.replace(/upload\.php$/, 'delete.php')

    return json({
      ticket,
      exp,
      endpoint: purpose === 'delete' ? deleteUrl : uploadUrl,
      category,
    })
  } catch (e) {
    return json({ error: (e as Error).message || 'ticket failed' }, 500)
  }
})
