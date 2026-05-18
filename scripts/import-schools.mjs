/**
 * import-schools.mjs
 * นำเข้าข้อมูลโรงเรียน 175 แห่งจาก Excel → Supabase
 *
 * วิธีใช้:
 *   1. npm install xlsx          (ถ้ายังไม่มี)
 *   2. ใส่ SERVICE_ROLE_KEY ด้านล่าง (จาก Supabase Dashboard > Settings > API)
 *   3. node scripts/import-schools.mjs
 */

import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'
import { read, utils } from 'xlsx'

// ─── Config ───────────────────────────────────────────────────────
const SUPABASE_URL      = 'https://fcxlmubgsovvxyzvmbna.supabase.co'
const SERVICE_ROLE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjeGxtdWJnc292dnh5enZtYm5hIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDI2NTgxNCwiZXhwIjoyMDg5ODQxODE0fQ.mcweq8nUsXMfHbdhk2bwKcxWBXXAA8uEAcHVbZcP0Mk'  // ← ใส่ key จาก Supabase > Settings > API
const DEFAULT_PASSWORD  = 'Korat2@2569'
const EXCEL_PATH        = 'C:\\Users\\Lenovo\\Downloads\\_สพป.นม.2 (1).xlsx'
const DELAY_MS          = 200  // หน่วง ms ระหว่าง request (ป้องกัน rate limit)
// ─────────────────────────────────────────────────────────────────

if (SERVICE_ROLE_KEY === 'YOUR_SERVICE_ROLE_KEY_HERE') {
  console.error('❌ กรุณาใส่ SERVICE_ROLE_KEY ก่อนรัน script')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
})

const sleep = ms => new Promise(r => setTimeout(r, ms))

// ─── อ่าน Excel ──────────────────────────────────────────────────
console.log('📖 กำลังอ่านไฟล์ Excel...')
const workbook = read(readFileSync(EXCEL_PATH))
const sheet    = workbook.Sheets[workbook.SheetNames[0]]
const rows     = utils.sheet_to_json(sheet, { header: 1, defval: '' })

const data = rows.slice(1).filter(r => r[0] && String(r[0]).trim())
console.log(`📋 พบข้อมูล ${data.length} โรงเรียน\n`)

// ─── โหลด Auth users ที่มีอยู่แล้ว (เพื่อ skip ถ้า email ซ้ำ) ──
console.log('🔍 ตรวจสอบ Auth users ที่มีอยู่...')
const existingMap = {}
let page = 1
while (true) {
  const { data: { users }, error } = await supabase.auth.admin.listUsers({ page, perPage: 1000 })
  if (error || !users?.length) break
  users.forEach(u => { existingMap[u.email] = u.id })
  if (users.length < 1000) break
  page++
}
console.log(`   พบ users เดิม: ${Object.keys(existingMap).length} คน\n`)

// ─── Loop import ─────────────────────────────────────────────────
let ok = 0, skip = 0, fail = 0

for (let i = 0; i < data.length; i++) {
  const row = data[i]

  const dmc_code    = String(row[0]).trim()
  const per_code    = String(row[1]).trim()
  const school_code = String(row[2]).trim()
  const name        = String(row[3]).trim()
  const village_no  = String(row[4]).trim()
  const village_name= String(row[5]).trim()
  const subdistrict = String(row[6]).trim()
  const district    = String(row[7]).trim()
  const postal_code = String(row[8]).trim()
  const school_group= String(row[9]).trim()
  const email       = String(row[11]).trim()
  const website_raw = String(row[12]).trim()
  const distance_km = row[13] !== '' ? Number(row[13]) : null
  const lat         = row[14] !== '' ? Number(row[14]) : null
  const lng         = row[15] !== '' ? Number(row[15]) : null

  // กรอง website ที่เป็น obec.go.th fallback (ไม่มีเว็บจริง)
  const website_url = website_raw.includes('school.obec.go.th') ? '' : website_raw

  if (!dmc_code || !email) { skip++; continue }

  process.stdout.write(`[${i+1}/${data.length}] ${dmc_code} ${name} ... `)

  // ── 1. Upsert school ───────────────────────────────────────
  const { data: schoolRow, error: schoolErr } = await supabase
    .from('schools')
    .upsert({
      dmc_code, per_code, school_code,
      name, village_no, village_name,
      subdistrict, district, postal_code, school_group,
      email, website_url,
      distance_km, lat, lng,
    }, { onConflict: 'dmc_code' })
    .select('id')
    .single()

  if (schoolErr) {
    console.log(`❌ schools: ${schoolErr.message}`)
    fail++; continue
  }

  const schoolId = schoolRow.id

  // ── 2. Create / get Auth user ──────────────────────────────
  let userId = existingMap[email]

  if (!userId) {
    const { data: authData, error: authErr } = await supabase.auth.admin.createUser({
      email,
      password: DEFAULT_PASSWORD,
      email_confirm: true,
      user_metadata: { dmc_code, school_name: name },
    })
    if (authErr) {
      console.log(`❌ auth: ${authErr.message}`)
      fail++; continue
    }
    userId = authData.user.id
    existingMap[email] = userId
  }

  // ── 3. Upsert profile ──────────────────────────────────────
  const { error: profileErr } = await supabase
    .from('profiles')
    .upsert({
      id:          userId,
      role:        'school',
      school_id:   schoolId,
      school_name: name,
      is_approved: true,
      is_active:   true,
    }, { onConflict: 'id' })

  if (profileErr) {
    console.log(`❌ profile: ${profileErr.message}`)
    fail++; continue
  }

  console.log('✅')
  ok++
  await sleep(DELAY_MS)
}

// ─── สรุป ─────────────────────────────────────────────────────────
console.log('\n══════════════════════════════')
console.log(`✅ สำเร็จ  : ${ok} โรงเรียน`)
console.log(`⏭  ข้ามแล้ว: ${skip} โรงเรียน`)
console.log(`❌ ล้มเหลว : ${fail} โรงเรียน`)
console.log('══════════════════════════════')
