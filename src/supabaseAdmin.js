import { createClient } from '@supabase/supabase-js'

// ⚠️ Service role key — ใช้ได้เฉพาะ admin เท่านั้น ห้าม expose สาธารณะ
// production: ย้าย logic ไป Edge Function แทน
const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_SERVICE_KEY

export const supabaseAdmin = key
  ? createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } })
  : null
