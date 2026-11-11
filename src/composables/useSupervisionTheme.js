// ธีมสี + ขนาดการแสดงผลของหน้ากรอกแบบนิเทศ (ต่อแบบ: supervision_forms.theme / display_size)
// ใช้โดยครอบ :style ที่กรอบนอกสุดของหน้ากรอก — .bg-primary/.text-primary ใน style.css อ่าน var(--color-primary)
// จึงเปลี่ยนสีเฉพาะในหน้านั้น ไม่ลามไปทั้งเว็บ
// รายชื่อ key ต้องตรงกับ CHECK ใน migration 100
import { darken, alphaOf } from './useAreaConfig'

// site = ตามสีเว็บ (ไม่ override สีหลัก) + หัวข้อส่วน/พื้นหลังเท่าของเดิมเป๊ะ (indigo-600, slate-50 → blue-50)
export const SUPERVISION_THEMES = [
  { key: 'site',    label: 'ตามสีเว็บ',    primary: null,      section: '#4f46e5', bgFrom: '#f8fafc', bgTo: '#eff6ff' },
  { key: 'ocean',   label: 'ฟ้าทะเล',     primary: '#0369a1', section: '#0284c7', bgFrom: '#f0f9ff', bgTo: '#e0f2fe' },
  { key: 'emerald', label: 'เขียวมรกต',   primary: '#047857', section: '#059669', bgFrom: '#f0fdf4', bgTo: '#d1fae5' },
  { key: 'violet',  label: 'ม่วงลาเวนเดอร์', primary: '#6d28d9', section: '#7c3aed', bgFrom: '#faf5ff', bgTo: '#ede9fe' },
  { key: 'rose',    label: 'ชมพูกุหลาบ',  primary: '#be123c', section: '#e11d48', bgFrom: '#fff1f2', bgTo: '#ffe4e6' },
  { key: 'sunset',  label: 'ส้มอบอุ่น',    primary: '#c2410c', section: '#ea580c', bgFrom: '#fff7ed', bgTo: '#ffedd5' },
  { key: 'gold',    label: 'ทองไทย',     primary: '#92400e', section: '#b45309', bgFrom: '#fffbeb', bgTo: '#fef3c7' },
  { key: 'slate',   label: 'เทาเข้ม',     primary: '#334155', section: '#475569', bgFrom: '#f8fafc', bgTo: '#e2e8f0' },
]

// zoom ขยายทั้งตัวอักษร ปุ่ม และความกว้างพร้อมกัน → กว้างที่ตาเห็น = maxW × zoom
// ปกติ 672px · ใหญ่ 720×1.125 ≈ 810px · ใหญ่มาก 768×1.25 = 960px
export const DISPLAY_SIZES = [
  { key: 'normal', label: 'ปกติ',    maxW: 'max-w-2xl',     zoom: 1 },
  { key: 'large',  label: 'ใหญ่',    maxW: 'max-w-[45rem]', zoom: 1.125 },
  { key: 'xlarge', label: 'ใหญ่มาก', maxW: 'max-w-3xl',     zoom: 1.25 },
]

export function findTheme(key) {
  return SUPERVISION_THEMES.find(t => t.key === key) || SUPERVISION_THEMES[0]
}
export function findSize(key) {
  return DISPLAY_SIZES.find(s => s.key === key) || DISPLAY_SIZES[0]
}

// CSS variables สำหรับกรอบนอกของหน้ากรอก
export function themeStyle(key) {
  const t = findTheme(key)
  const vars = {
    '--sv-section': t.section,
    '--sv-bg-from': t.bgFrom,
    '--sv-bg-to':   t.bgTo,
  }
  if (t.primary) {
    vars['--color-primary']       = t.primary
    vars['--color-primary-dark']  = darken(t.primary, 25)
    vars['--color-primary-deep']  = darken(t.primary, 52)
    vars['--color-primary-light'] = alphaOf(t.primary, 0.08)
    vars['--color-primary-ring']  = alphaOf(t.primary, 0.22)
  }
  return vars
}
