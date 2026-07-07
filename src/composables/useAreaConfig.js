/**
 * useAreaConfig — Singleton composable สำหรับข้อมูลเขตพื้นที่
 * - ดึงข้อมูลจาก Supabase area_config (id=1)
 * - apply CSS variables ลง :root อัตโนมัติ
 * - cache ใน module-level ref (ไม่โหลดซ้ำ)
 */
import { ref, readonly } from 'vue'
import { supabase } from '../supabase'

// ── Module-level state (shared across all usages) ──────────────
const config  = ref(null)
const loading = ref(false)
const loaded  = ref(false)

// ── Preset themes ──────────────────────────────────────────────
export const THEME_PRESETS = [
  {
    id:        'navy',
    name:      'Executive Navy',
    desc:      'น้ำเงินเข้ม + ทอง — ราชการ น่าเชื่อถือ',
    primary:   '#1e3a5f',
    secondary: '#b8922a',
  },
  {
    id:        'slate',
    name:      'Slate & Sky',
    desc:      'เทาเข้ม + ฟ้า — โมเดิร์น สะอาด',
    primary:   '#1e293b',
    secondary: '#0369a1',
  },
  {
    id:        'indigo',
    name:      'Royal Indigo',
    desc:      'คราม + ม่วง — สง่างาม โดดเด่น',
    primary:   '#312e81',
    secondary: '#7c3aed',
  },
]

// ── Default sections config ────────────────────────────────────
export const DEFAULT_HOME_SECTIONS = [
  { key: 'news',            label: 'ข่าวสาร',        subtitle: 'Latest News',      title: 'ข่าวสารและประชาสัมพันธ์',            visible: true,  bg: '#ffffff', bg2: '#f1f5f9', bg_type: 'solid', order: 1 },
  { key: 'education_news',  label: 'ข่าวการศึกษา',   subtitle: 'Education News',   title: 'ข่าวการศึกษาจาก Google News',        visible: true,  bg: '#f8fafc', bg2: '#e0e7ff', bg_type: 'solid', order: 2 },
  { key: 'supervision_list',label: 'แบบนิเทศ',       subtitle: 'Supervision',      title: 'แบบนิเทศและแบบสอบถาม',               visible: false, bg: '#f8fafc', bg2: '#e0e7ff', bg_type: 'solid', order: 3 },
  { key: 'services',        label: 'บริการออนไลน์',  subtitle: 'E-Service Center', title: 'บริการออนไลน์',                      visible: true,  bg: '#f8fafc', bg2: '#e2e8f0', bg_type: 'solid', order: 4 },
  { key: 'cta',             label: 'CTA Banner',      subtitle: '',                 title: 'ระบบกลุ่มนิเทศ ติดตามและประเมินผล', visible: true,  bg: '#ffffff', bg2: '#f1f5f9', bg_type: 'solid', order: 5 },
]

// ── Default page headers (ว่างเปล่า = ทุกหน้าใช้ icon/title default ของไฟล์ตัวเอง) ──
// entry: { key: routeName, mode: 'icon'|'media', icon, title, subtitle, media_url, media_type }
export const DEFAULT_PAGE_HEADERS = []

// ── Default theme ──────────────────────────────────────────────
const DEFAULTS = {
  primary_color:   '#1e3a5f',
  secondary_color: '#b8922a',
  area_name:       'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
  area_name_short: 'กลุ่มนิเทศฯ',
  area_type:       'สพป.',
  province:        '',
  area_number:     '',
  tagline:         '',
  contact_phone:   '',
  contact_email:   '',
  facebook_url:    '',
  line_url:        '',
  youtube_url:     '',
  website_url:     '',
  logo_url:                '',
  default_school_password: 'Korat2@2569',
  banner_aspect_ratio:     '21:9',
  schools_page_title:      'ทำเนียบสถานศึกษา',
  schools_page_subtitle:   '',
  home_sections:           DEFAULT_HOME_SECTIONS,
  services: [
    { key:'nitet',    label:'กลุ่มนิเทศติดตามฯ',   icon:'eye',       type:'internal', url:'/nithet',    visible:true, order:1 },
    { key:'download', label:'ดาวน์โหลดเอกสาร',     icon:'download',  type:'internal', url:'/download',  visible:true, order:2 },
    { key:'qrcode',   label:'สร้าง QR Code',        icon:'qrcode',    type:'internal', url:'/qrcode',    visible:true, order:3 },
    { key:'urlshort', label:'ย่อลิงค์',             icon:'link',      type:'internal', url:'/url-short', visible:true, order:4 },
    { key:'sar',      label:'ระบบ SAR Online',       icon:'chart-bar', type:'external', url:'',           visible:true, order:5 },
    { key:'media',    label:'คลังสื่อนวัตกรรม',     icon:'beaker',    type:'external', url:'',           visible:true, order:6 },
    { key:'training', label:'ลงทะเบียนอบรม',        icon:'clipboard', type:'external', url:'',           visible:true, order:7 },
    { key:'contact',  label:'ติดต่อเรา',             icon:'phone',     type:'internal', url:'/contact',   visible:true, order:8 },
  ],
  personnel_groups: [
    { key: 'nitet',     label: 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา', visible: true, order: 1 },
    { key: 'promote',   label: 'กลุ่มส่งเสริมการจัดการศึกษา',                 visible: true, order: 2 },
    { key: 'personnel', label: 'กลุ่มบริหารงานบุคคล',                         visible: true, order: 3 },
    { key: 'budget',    label: 'กลุ่มบริหารงบประมาณ',                         visible: true, order: 4 },
    { key: 'general',   label: 'กลุ่มอำนวยการ',                               visible: true, order: 5 },
  ],
  nav_groups: [
    { key: 'general', label: 'ข้อมูลทั่วไป',   visible: true,  order: 1 },
    { key: 'work',    label: 'งานนิเทศติดตาม', visible: true,  order: 2 },
    { key: 'service', label: 'บริการ',          visible: true,  order: 3 },
    { key: 'other',   label: 'อื่นๆ',           visible: false, order: 4 },
  ],
  page_headers: DEFAULT_PAGE_HEADERS,
}

// ── Helper: hex → RGB ──────────────────────────────────────────
function hexToRgb(hex) {
  const r = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  return r ? [parseInt(r[1],16), parseInt(r[2],16), parseInt(r[3],16)] : [30,58,95]
}

function darken(hex, pct) {
  const [r,g,b] = hexToRgb(hex)
  const f = 1 - pct/100
  return `rgb(${Math.round(r*f)},${Math.round(g*f)},${Math.round(b*f)})`
}

function alphaOf(hex, alpha) {
  const [r,g,b] = hexToRgb(hex)
  return `rgba(${r},${g},${b},${alpha})`
}

// ── Apply CSS variables to :root ───────────────────────────────
export function applyTheme(cfg) {
  if (!cfg) return
  const root = document.documentElement

  const primary   = cfg.primary_color   || DEFAULTS.primary_color
  const secondary = cfg.secondary_color || DEFAULTS.secondary_color

  root.style.setProperty('--color-primary',          primary)
  root.style.setProperty('--color-primary-dark',     darken(primary, 25))
  root.style.setProperty('--color-primary-light',    alphaOf(primary, 0.08))
  root.style.setProperty('--color-primary-ring',     alphaOf(primary, 0.22))
  root.style.setProperty('--color-secondary',        secondary)
  root.style.setProperty('--color-secondary-light',  alphaOf(secondary, 0.12))
}

// ── Composable ─────────────────────────────────────────────────
export function useAreaConfig() {

  const fetchConfig = async (force = false) => {
    if (loaded.value && !force) return
    loading.value = true
    try {
      const { data, error } = await supabase.rpc('get_area_config')
      if (error) throw error
      config.value = { ...DEFAULTS, ...data }
    } catch {
      config.value = { ...DEFAULTS }
    } finally {
      applyTheme(config.value)
      loading.value = false
      loaded.value  = true
    }
  }

  const updateConfig = async (patch) => {
    const { data, error } = await supabase
      .from('area_config')
      .update({ ...patch, updated_at: new Date().toISOString() })
      .eq('id', 1)
      .select()
      .single()
    if (!error) {
      config.value = { ...config.value, ...patch }
      applyTheme(config.value)
    }
    return { data, error }
  }

  const previewTheme = (primary, secondary) => {
    applyTheme({ primary_color: primary, secondary_color: secondary })
  }

  const resetTheme = () => applyTheme(config.value)

  return {
    config:       readonly(config),
    loading:      readonly(loading),
    loaded:       readonly(loaded),
    fetchConfig,
    updateConfig,
    previewTheme,
    resetTheme,
    applyTheme,
  }
}
