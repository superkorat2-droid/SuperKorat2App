import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ADMIN_SECRET_KEY = Deno.env.get('ADMIN_SECRET_KEY')!

const admin = createClient(SUPABASE_URL, ADMIN_SECRET_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS })
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  try {
    const token = (req.headers.get('Authorization') || '').replace('Bearer ', '')
    if (!token) return json({ error: 'unauthorized' }, 401)

    const { data: { user }, error: userErr } = await admin.auth.getUser(token)
    if (userErr || !user) return json({ error: 'unauthorized' }, 401)

    const { data: callerProfile } = await admin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    const isAdmin = callerProfile && ['super_admin', 'admin'].includes(callerProfile.role)
    if (!isAdmin) return json({ error: 'forbidden' }, 403)

    const body = await req.json()

    switch (body.action) {
      // รีเซ็ตรหัสผ่านผู้ใช้ที่มีอยู่แล้ว (ทุก role: school/supervisor/staff/admin/teacher)
      case 'reset_password': {
        const { user_id, new_password } = body
        if (!user_id || !new_password) return json({ error: 'missing user_id or new_password' }, 400)
        const { error } = await admin.auth.admin.updateUserById(user_id, { password: new_password })
        if (error) return json({ error: error.message }, 400)
        return json({ ok: true })
      }

      // สร้างบัญชี auth ให้โรงเรียน (ถ้ายังไม่มี) แล้วตั้ง/รีเซ็ตรหัสผ่าน
      case 'create_school_account': {
        const { email, password, school_id, school_name } = body
        if (!email || !password || !school_id) return json({ error: 'missing fields' }, 400)

        const { data: { users } } = await admin.auth.admin.listUsers({ perPage: 1000 })
        let existing = users?.find(u => u.email?.toLowerCase() === email.toLowerCase())

        if (existing) {
          const { error } = await admin.auth.admin.updateUserById(existing.id, { password })
          if (error) return json({ error: error.message }, 400)
          return json({ ok: true, created: false })
        }

        const { data: created, error: createErr } = await admin.auth.admin.createUser({
          email, password, email_confirm: true, user_metadata: { full_name: school_name },
        })
        if (createErr) return json({ error: createErr.message }, 400)

        await admin.from('profiles').upsert({
          id: created.user.id, email, full_name: school_name, role: 'school',
          school_id, is_approved: true, is_active: true,
        }, { onConflict: 'id' })

        return json({ ok: true, created: true })
      }

      // สร้างบัญชีบุคลากร (supervisor/staff/admin)
      case 'create_personnel': {
        const { email, password, full_name, role, org_role } = body
        if (!email || !password || !full_name) return json({ error: 'missing fields' }, 400)
        if (password.length < 8) return json({ error: 'password too short' }, 400)

        const { data: authData, error: authErr } = await admin.auth.admin.createUser({
          email, password, email_confirm: true, user_metadata: { full_name },
        })
        if (authErr) return json({ error: authErr.message }, 400)

        await admin.from('profiles').update({
          full_name, role, org_role, is_approved: true, is_active: true,
        }).eq('id', authData.user.id)

        return json({ ok: true, user_id: authData.user.id })
      }

      default:
        return json({ error: 'unknown action' }, 400)
    }
  } catch (e) {
    return json({ error: String(e) }, 500)
  }
})
