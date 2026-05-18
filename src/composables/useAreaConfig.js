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
  { key: 'news',     label: 'ข่าวสาร',      title: 'ข่าวสารและประชาสัมพันธ์',             visible: true, bg: '#ffffff', order: 1 },
  { key: 'services', label: 'บริการออนไลน์', title: 'บริการออนไลน์',                       visible: true, bg: '#f8fafc', order: 2 },
  { key: 'cta',      label: 'CTA Banner',    title: 'ระบบกลุ่มนิเทศ ติดตามและประเมินผล',  visible: true, bg: '#ffffff', order: 3 },
]

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
  logo_url:        '',
  home_sections:   DEFAULT_HOME_SECTIONS,
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
