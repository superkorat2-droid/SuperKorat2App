// แบบสำรวจเครือข่ายวิชาชีพครู + ทำเนียบครู — ตัวช่วยที่ทุกหน้าใช้ร่วมกัน
//
// ฐานข้อมูลเก็บตัวเลือกเป็น KEY เสมอ (migration 0104) — label อยู่ใน teacher_survey_config.options
// แอดมินแก้ชื่อตัวเลือกได้โดยข้อมูลครูเดิมไม่เพี้ยน ทุกหน้าต้องแปลง key → label ผ่าน labelOf()
import { ref } from 'vue'
import { supabase } from '../supabase'

/** คำถามตัวเลือกหลักของแบบสำรวจ (ลำดับ = ลำดับในหน้าตั้งค่า) */
export const OPTION_FIELDS = [
  { key: 'grades',      label: 'ระดับชั้นที่รับผิดชอบการสอน',          multi: true  },
  { key: 'ranks',       label: 'วิทยฐานะปัจจุบัน',                     multi: false, column: 'academic_rank' },
  { key: 'major_match', label: 'ลักษณะการจัดการเรียนการสอนในปัจจุบัน', multi: false, column: 'major_match' },
  { key: 'networks',    label: 'เครือข่ายวิชาชีพครูที่สนใจเข้าร่วม',    multi: true  },
  { key: 'constraints', label: 'สภาพความพร้อมและข้อจำกัดของสถานศึกษา', multi: true  },
  { key: 'topics',      label: 'ประเด็นที่ต้องการพัฒนา/แลกเปลี่ยนเรียนรู้', multi: true },
]

export const PREFIXES = ['นาย', 'นาง', 'นางสาว', 'ว่าที่ร้อยตรี', 'ว่าที่ร้อยตรีหญิง', 'ดร.']

/** ตัวเลือกที่ "เลือกได้จริง" (หัวกลุ่มที่มี children เลือกตรงไม่ได้) */
export function leafOptions(opts) {
  const out = []
  for (const o of opts || []) {
    if (Array.isArray(o.children) && o.children.length) out.push(...o.children)
    else out.push(o)
  }
  return out
}

/** key → label (ไม่พบ = คืน key เดิม เผื่อแอดมินลบตัวเลือกไปแล้วแต่ข้อมูลเก่ายังมี) */
export function labelOf(config, field, key) {
  const hit = leafOptions(config?.options?.[field]).find(o => o.key === key)
  return hit?.label || key
}

export function labelsOf(config, field, keys) {
  return (keys || []).map(k => labelOf(config, field, k))
}

/** ชื่อเต็ม "นายสมชาย ใจดี" */
export function fullName(t) {
  if (!t) return ''
  return `${t.prefix || ''}${t.first_name || ''} ${t.last_name || ''}`.trim()
}

export function initialsOf(t) {
  return ((t?.first_name || '?')[0] + (t?.last_name || '')[0]).trim() || '?'
}

/** ตอนนี้เปิดรับแบบสำรวจใหม่หรือไม่ (server ตรวจซ้ำอีกชั้นใน teacher_survey_submit) */
export function isSurveyOpen(cfg, now = new Date()) {
  if (!cfg?.is_open) return false
  if (cfg.open_at && now < new Date(cfg.open_at)) return false
  if (cfg.deadline && now > new Date(cfg.deadline)) return false
  return true
}

const config = ref(null)
let loading = null

/** โหลดตั้งค่าแบบสำรวจ (แคชไว้ทั้งแอป · force = โหลดใหม่หลังแอดมินแก้) */
export function useTeacherSurveyConfig() {
  async function fetchConfig(force = false) {
    if (config.value && !force) return config.value
    if (!loading || force) {
      loading = supabase.from('teacher_survey_config').select('*').eq('id', 1).maybeSingle()
        .then(({ data, error }) => {
          if (error) throw error
          config.value = data
          return data
        })
        .finally(() => { loading = null })
    }
    return loading
  }
  return { config, fetchConfig }
}

// ── ลิงก์แก้ไขส่วนตัวที่จำไว้ในเครื่อง (ครูกลับมาเปิดเครื่องเดิมแล้วแก้ต่อได้ทันที) ──
const TOKEN_KEY = 'teacherSurveyToken'

export function rememberToken(token) {
  try { localStorage.setItem(TOKEN_KEY, token) } catch { /* private mode */ }
}
export function recallToken() {
  try { return localStorage.getItem(TOKEN_KEY) || '' } catch { return '' }
}
export function forgetToken() {
  try { localStorage.removeItem(TOKEN_KEY) } catch { /* ignore */ }
}

/** ลิงก์แก้ไขแบบเต็ม (hash router) */
export function editLinkOf(token) {
  return `${window.location.origin}${window.location.pathname}#/teacher-survey/edit/${token}`
}
