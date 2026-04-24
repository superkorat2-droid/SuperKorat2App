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

// ── Default theme ──────────────────────────────────────────────
const DEFAULTS = {
  primary_color:   '#2563eb',
  secondary_color: '#4f46e5',
  area_name:       'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
  area_name_short: 'กลุ่มนิเทศฯ',
  area_type:       'สพป.',
  province:        '',
  area_number:     '',
  contact_phone:   '',
  contact_email:   '',
  facebook_url:    '',
  line_url:        '',
  youtube_url:     '',
  website_url:     '',
  logo_url:        '',
}

// ── Apply CSS variables to :root ───────────────────────────────
function applyTheme(cfg) {
  if (!cfg) return
  const root = document.documentElement

  const primary   = cfg.primary_color   || DEFAULTS.primary_color
  const secondary = cfg.secondary_color || DEFAULTS.secondary_color

  root.style.setProperty('--color-primary',   primary)
  root.style.setProperty('--color-secondary', secondary)

  // Generate shade variants (darken/lighten by mixing with black/white)
  root.style.setProperty('--color-primary-dark',  darken(primary,  20))
  root.style.setProperty('--color-primary-light', lighten(primary, 90))
  root.style.setProperty('--color-primary-ring',  lighten(primary, 70))
}

// ── Helper: hex → RGB ──────────────────────────────────────────
function hexToRgb(hex) {
  const r = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  return r ? [parseInt(r[1],16), parseInt(r[2],16), parseInt(r[3],16)] : [37,99,235]
}

function darken(hex, pct) {
  const [r,g,b] = hexToRgb(hex)
  const f = 1 - pct/100
  return `rgb(${Math.round(r*f)},${Math.round(g*f)},${Math.round(b*f)})`
}

function lighten(hex, pct) {
  const [r,g,b] = hexToRgb(hex)
  const f = pct/100
  return `rgba(${r},${g},${b},${1 - f})`
}

// ── Composable ─────────────────────────────────────────────────
export function useAreaConfig() {

  const fetchConfig = async (force = false) => {
    if (loaded.value && !force) return   // cache hit
    loading.value = true
    try {
      const { data, error } = await supabase.rpc('get_area_config')
      if (error) throw error
      config.value = { ...DEFAULTS, ...data }
    } catch {
      config.value = { ...DEFAULTS }    // fallback to defaults
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
      applyTheme(config.value)           // preview ทันทีหลัง save
    }
    return { data, error }
  }

  // preview สีโดยยังไม่ save (สำหรับ color picker)
  const previewTheme = (primary, secondary) => {
    applyTheme({ primary_color: primary, secondary_color: secondary })
  }

  // reset กลับค่าใน DB
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
