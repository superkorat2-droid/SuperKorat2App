// useBgStyle — ระบบพื้นหลัง (สีเดียว/ไล่สี) ใช้ร่วมกันทั้ง section หน้าแรกและบล็อกหน้า CMS
// object ที่รับเข้ามาต้องมี field: bg_type, bg, bg2

export const BG_TYPES = [
  { value: 'solid',       label: 'สีเดียว',       preview: (c1)     => `${c1}` },
  { value: 'gradient-tb', label: '↓ บน→ล่าง',     preview: (c1, c2) => `linear-gradient(to bottom, ${c1}, ${c2})` },
  { value: 'gradient-bt', label: '↑ ล่าง→บน',     preview: (c1, c2) => `linear-gradient(to top, ${c1}, ${c2})` },
  { value: 'gradient-lr', label: '→ ซ้าย→ขวา',    preview: (c1, c2) => `linear-gradient(to right, ${c1}, ${c2})` },
  { value: 'radial',      label: '◎ เรืองกลาง',   preview: (c1, c2) => `radial-gradient(ellipse at center, ${c1}, ${c2})` },
  { value: 'radial-in',  label: '◉ สี2กลาง-สี1ขอบ', preview: (c1, c2) => `radial-gradient(ellipse at center, ${c2} 0%, ${c1} 100%)` },
]

export function getBgStyle(obj) {
  const c1 = obj.bg  || '#ffffff'
  const c2 = obj.bg2 || '#f1f5f9'
  const t  = BG_TYPES.find(t => t.value === (obj.bg_type || 'solid'))
  if (!t || obj.bg_type === 'solid') return { backgroundColor: c1 }
  return { background: t.preview(c1, c2) }
}

export const BG_PRESETS = [
  // Light (solid)
  { label: 'ขาว',        value: '#ffffff' },
  { label: 'Slate 50',   value: '#f8fafc' },
  { label: 'Slate 100',  value: '#f1f5f9' },
  { label: 'Blue 50',    value: '#eff6ff' },
  { label: 'Indigo 50',  value: '#eef2ff' },
  { label: 'Purple 50',  value: '#faf5ff' },
  { label: 'Emerald 50', value: '#ecfdf5' },
  { label: 'Amber 50',   value: '#fffbeb' },
  // Deep (gradient-friendly)
  { label: 'Blue 900',   value: '#1e3a8a' },
  { label: 'Blue 700',   value: '#1d4ed8' },
  { label: 'Blue 500',   value: '#3b82f6' },
  { label: 'Indigo 800', value: '#3730a3' },
  { label: 'Indigo 600', value: '#4f46e5' },
  { label: 'Purple 800', value: '#6b21a8' },
  { label: 'Purple 600', value: '#9333ea' },
  { label: 'Teal 700',   value: '#0f766e' },
  { label: 'Teal 500',   value: '#14b8a6' },
  { label: 'Emerald 700',value: '#047857' },
  { label: 'Rose 700',   value: '#be123c' },
  { label: 'Slate 800',  value: '#1e293b' },
  { label: 'Slate 900',  value: '#0f172a' },
]

export const GRADIENT_PRESETS = [
  { label: 'Ocean Blue',   bg: '#1e3a8a', bg2: '#3b82f6', bg_type: 'gradient-lr' },
  { label: 'Royal Indigo', bg: '#3730a3', bg2: '#6366f1', bg_type: 'gradient-lr' },
  { label: 'Violet Night', bg: '#4c1d95', bg2: '#7c3aed', bg_type: 'gradient-tb' },
  { label: 'Teal Ocean',   bg: '#0f766e', bg2: '#2dd4bf', bg_type: 'gradient-lr' },
  { label: 'Forest',       bg: '#14532d', bg2: '#22c55e', bg_type: 'gradient-tb' },
  { label: 'Sunset',       bg: '#9a3412', bg2: '#f97316', bg_type: 'gradient-lr' },
  { label: 'Midnight',     bg: '#0f172a', bg2: '#1e3a8a', bg_type: 'gradient-tb' },
  { label: 'Light Blue',   bg: '#eff6ff', bg2: '#dbeafe', bg_type: 'gradient-tb' },
  { label: 'Light Purple', bg: '#faf5ff', bg2: '#ede9fe', bg_type: 'gradient-tb' },
]

// ── Contrast check (ใช้ตัดสินสีตัวอักษร/ไอคอนบนพื้นหลัง) ──────────────
export function isDarkColor(hex) {
  const m = hex.match(/\w\w/g)
  if (!m) return false
  const [r, g, b] = m.map(x => parseInt(x, 16))
  return (r * 299 + g * 587 + b * 114) / 1000 < 128
}
