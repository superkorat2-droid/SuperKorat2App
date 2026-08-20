// usePersonnel — ดึงข้อมูลบุคลากรสาธารณะ ใช้ร่วมกันระหว่างหน้า /personnel และโค้ดฝัง /embed/personnel
//
// อ่านจาก view personnel_public ไม่ใช่ตาราง profiles โดยตรง เพราะ:
//   1. view กรองช่องทางติดต่อตาม contact_visibility ให้แล้วที่ระดับ DB
//   2. anon ไม่มีสิทธิ์อ่าน phone/email/line_id/social จากตาราง profiles อีกแล้ว
//      (migration 20240101000060_personnel_public.sql)
import { supabase } from '../supabase'

export const ORG_ORDER = ['director','deputy','group_director','supervisor','staff','other']

/**
 * หัวข้อบล็อกผู้บริหาร 3 ชั้นบนสุดของหน้าทำเนียบ
 *
 * แอดมินแก้ทับได้ที่ area_config.personnel_section_titles (migration 0074)
 * ค่าที่นี่คือค่าเริ่มต้นเวลายังไม่ได้ตั้ง หรือตั้งเป็นค่าว่าง
 * ใช้ร่วมกันระหว่าง PersonnelDirectory.vue (ตอนแสดงผล) กับ
 * AdminPersonnelView.vue (ใช้เป็น placeholder ในช่องกรอก) เพื่อไม่ให้สองที่หลุดจากกัน
 *
 * ลำดับของ 3 ชั้นนี้ตายตัวในเทมเพลตโดยตั้งใจ — เป็นลำดับชั้นการบังคับบัญชา ไม่ใช่ค่าที่ควรสลับ
 */
export const SECTION_TITLE_DEFAULTS = {
  director:       'ผู้อำนวยการเขตพื้นที่การศึกษา',
  deputy:         'รองผู้อำนวยการเขตพื้นที่การศึกษา',
  group_director: 'ผู้อำนวยการกลุ่ม',
}

/** คอลัมน์ที่การ์ด + โมดัลของ PersonnelDirectory ต้องใช้ */
export const PERSONNEL_COLUMNS =
  'id,full_name,first_name,last_name,title,position,position_level,org_role,department,' +
  'subjects,expertise,bio,avatar_url,sort_order,phone,line_id,email,' +
  'facebook_url,youtube_url,tiktok_url,twitter_url,instagram_url,linkedin_url,' +
  'personal_website,portfolio_url,contact_visibility'

/** เรียงตามลำดับผู้บริหาร → sort_order ที่ admin ตั้งไว้ */
export function sortPersonnel(rows) {
  return [...rows].sort((a, b) => {
    const ra = ORG_ORDER.indexOf(a.org_role), rb = ORG_ORDER.indexOf(b.org_role)
    return ra !== rb ? ra - rb : (a.sort_order || 99) - (b.sort_order || 99)
  })
}

export async function fetchPersonnel() {
  const { data, error } = await supabase
    .from('personnel_public')
    .select(PERSONNEL_COLUMNS)
    .in('role', ['supervisor', 'staff'])
    .eq('is_active', true).eq('is_approved', true)
    .order('sort_order', { ascending: true })
  if (error) return { rows: [], error }
  return { rows: sortPersonnel(data || []), error: null }
}
