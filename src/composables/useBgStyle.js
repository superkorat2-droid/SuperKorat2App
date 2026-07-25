// useBgStyle — ระบบพื้นหลังกลาง ใช้ร่วมกันทั้ง section หน้าแรกและบล็อกหน้า CMS
//
// field ที่ object ต้องมี: bg_type, bg, bg2
// เฉพาะ bg_type='image' ใช้เพิ่ม: bg_image, bg_overlay, bg_overlay_color,
//                                  bg_blur, bg_position, bg_text
//
// เดิม HomeView มีสำเนา getBgStyle ของตัวเอง (รองรับ gradient-rl ที่ตัวกลางไม่มี)
// ทำให้หน้าแรกกับหน้า CMS ทำงานไม่เหมือนกัน — รวบมาไว้ที่นี่ที่เดียวแล้ว
// (ตรวจข้อมูลจริงก่อนรวบ: ไม่มี section ไหนใช้ gradient-rl เลย จึงไม่ต้องย้ายค่ามา)

export const BG_TYPES = [
  // 'none' = ไม่ทาสีพื้นเลย ปล่อยให้พื้นหลัง aurora ของเว็บทะลุขึ้นมา
  // จำเป็นสำหรับธีมกระจก — ถ้าทุก section ทาสีทึบ จะบังพื้นหลังจนไม่เห็นกระจก
  { value: 'none',        label: '◇ โปร่งใส',     preview: ()       => 'transparent' },
  { value: 'solid',       label: 'สีเดียว',       preview: (c1)     => `${c1}` },
  { value: 'gradient-tb', label: '↓ บน→ล่าง',     preview: (c1, c2) => `linear-gradient(to bottom, ${c1}, ${c2})` },
  { value: 'gradient-bt', label: '↑ ล่าง→บน',     preview: (c1, c2) => `linear-gradient(to top, ${c1}, ${c2})` },
  { value: 'gradient-lr', label: '→ ซ้าย→ขวา',    preview: (c1, c2) => `linear-gradient(to right, ${c1}, ${c2})` },
  { value: 'radial',      label: '◎ เรืองกลาง',   preview: (c1, c2) => `radial-gradient(ellipse at center, ${c1}, ${c2})` },
  { value: 'radial-in',  label: '◉ สี2กลาง-สี1ขอบ', preview: (c1, c2) => `radial-gradient(ellipse at center, ${c2} 0%, ${c1} 100%)` },
  { value: 'image',       label: '🖼 รูปภาพ',      preview: ()       => 'transparent' },
]

export function isImageBg(obj) {
  return obj?.bg_type === 'image' && !!obj?.bg_image
}

export function getBgStyle(obj) {
  if (!obj) return {}
  if (obj.bg_type === 'none') return {}
  // ภาพวาดด้วย <BgLayers> (ต้องมีชั้นเบลอ + ชั้นม่านแยก ทำด้วย style object เดียวไม่ได้)
  if (obj.bg_type === 'image') return {}
  const c1 = obj.bg  || '#ffffff'
  const c2 = obj.bg2 || '#f1f5f9'
  const t  = BG_TYPES.find(t => t.value === (obj.bg_type || 'solid'))
  if (!t || obj.bg_type === 'solid') return { backgroundColor: c1 }
  return { background: t.preview(c1, c2) }
}

// ── พื้นหลังรูปภาพ ────────────────────────────────────────────────

export const BG_POSITIONS = [
  { value: 'left top',      label: '↖' }, { value: 'center top',    label: '↑' }, { value: 'right top',    label: '↗' },
  { value: 'left center',   label: '←' }, { value: 'center center', label: '•' }, { value: 'right center', label: '→' },
  { value: 'left bottom',   label: '↙' }, { value: 'center bottom', label: '↓' }, { value: 'right bottom', label: '↘' },
]

// สีม่าน — 'brand' ผูกกับสีแบรนด์ใน DB ผ่าน CSS var จึงเปลี่ยนตามธีมอัตโนมัติ
export const OVERLAY_COLORS = [
  { value: 'white', label: 'ขาว',      rgb: '255,255,255' },
  { value: 'black', label: 'ดำ',       rgb: '15,23,42'    },
  { value: 'brand', label: 'สีแบรนด์', rgb: null          },
]

// preset ที่การันตีว่าอ่านออก — คนใช้ทั่วไปกดปุ่มเดียวจบ ไม่ต้องปรับ 5 ค่าเอง
export const IMAGE_PRESETS = [
  { key:'soft',  label:'ภาพนุ่ม',    desc:'ปลอดภัยสุด ใช้ได้กับภาพทุกแบบ', bg_overlay:60, bg_overlay_color:'white', bg_blur:8, bg_text:'dark'  },
  { key:'sharp', label:'ภาพชัด',     desc:'เห็นรายละเอียดภาพ ใช้กับภาพสว่าง', bg_overlay:30, bg_overlay_color:'white', bg_blur:0, bg_text:'dark'  },
  { key:'dark',  label:'ภาพเข้ม',    desc:'ดูมีพลัง ใช้กับภาพกิจกรรม',      bg_overlay:55, bg_overlay_color:'black', bg_blur:4, bg_text:'light' },
  { key:'brand', label:'โทนแบรนด์',  desc:'กลืนกับธีมสีของเว็บ',            bg_overlay:65, bg_overlay_color:'brand', bg_blur:6, bg_text:'light' },
]

export const IMAGE_DEFAULTS = {
  bg_overlay: 60, bg_overlay_color: 'white', bg_blur: 8,
  bg_position: 'center center', bg_text: 'dark',
}

// style ของชั้นรูปภาพ (ชั้นล่างสุด)
export function bgImageLayerStyle(obj) {
  const blur = Number(obj.bg_blur ?? IMAGE_DEFAULTS.bg_blur) || 0
  return {
    backgroundImage:    `url("${obj.bg_image}")`,
    backgroundSize:     'cover',
    backgroundPosition: obj.bg_position || IMAGE_DEFAULTS.bg_position,
    backgroundRepeat:   'no-repeat',
    ...(blur ? {
      filter: `blur(${blur}px)`,
      // ขยายเผื่อ เพราะ blur ทำให้ขอบภาพจางจนเห็นพื้นหลังลอดตรงมุม
      transform: `scale(${1 + blur / 100 + 0.04})`,
    } : {}),
  }
}

// style ของชั้นม่าน (ทับรูป อยู่ใต้เนื้อหา)
export function bgOverlayLayerStyle(obj) {
  const pct = Number(obj.bg_overlay ?? IMAGE_DEFAULTS.bg_overlay) || 0
  if (!pct) return { display: 'none' }
  const c = OVERLAY_COLORS.find(c => c.value === (obj.bg_overlay_color || 'white'))
  const a = pct / 100
  return c?.rgb
    ? { backgroundColor: `rgba(${c.rgb},${a})` }
    : { backgroundColor: `color-mix(in srgb, var(--color-primary) ${pct}%, transparent)` }
}

// class ของสีตัวอักษรบนพื้นภาพ — รูปภาพเดาความสว่างอัตโนมัติไม่ได้เหมือนสีเดียว
// (isDarkColor ใช้กับ hex เท่านั้น) จึงให้ admin เลือกเอง
export function bgTextClass(obj) {
  if (!isImageBg(obj)) return ''
  return (obj.bg_text || IMAGE_DEFAULTS.bg_text) === 'light' ? 'bg-image-on-dark' : 'bg-image-on-light'
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
