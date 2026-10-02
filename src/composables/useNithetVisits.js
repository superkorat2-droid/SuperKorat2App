// บันทึกการนิเทศติดตาม — ค่าคงที่และตัวช่วยที่ใช้ร่วมกันทั้งหลังบ้าน รายงาน และหน้าสาธารณะ

export const VISIT_TYPES = [
  { value: 'school_visit', label: 'นิเทศโรงเรียน', icon: '🏫', color: 'bg-blue-100 text-blue-700' },
  { value: 'follow_up',    label: 'ติดตามผล',      icon: '🔁', color: 'bg-violet-100 text-violet-700' },
  { value: 'meeting',      label: 'ประชุม',         icon: '👥', color: 'bg-amber-100 text-amber-700' },
  { value: 'training',     label: 'อบรม/สัมมนา',    icon: '🎓', color: 'bg-cyan-100 text-cyan-700' },
  { value: 'speaker',      label: 'เป็นวิทยากร',    icon: '🎤', color: 'bg-emerald-100 text-emerald-700' },
  { value: 'other',        label: 'อื่นๆ',          icon: '📌', color: 'bg-slate-100 text-slate-600' },
]

export const VISIT_STATUS = {
  draft: { label: 'ร่าง',     bg: 'bg-amber-100',   text: 'text-amber-700' },
  final: { label: 'สมบูรณ์', bg: 'bg-emerald-100', text: 'text-emerald-700' },
}

export const FOLLOWUP_STATUS = {
  none:      { label: '—',            bg: 'bg-slate-100', text: 'text-slate-500' },
  open:      { label: 'รอติดตาม',     bg: 'bg-amber-100', text: 'text-amber-700' },
  done:      { label: 'ติดตามแล้ว',   bg: 'bg-emerald-100', text: 'text-emerald-700' },
  cancelled: { label: 'ยกเลิก',       bg: 'bg-slate-100', text: 'text-slate-500' },
}

/** บทบาทที่บันทึกได้ — ต้องตรงกับ is_area_staff() ใน migration 0075 */
export const VISIT_WRITER_ROLES = ['super_admin', 'admin', 'supervisor', 'staff']

export function typeMeta(v) {
  return VISIT_TYPES.find(t => t.value === v) || VISIT_TYPES[VISIT_TYPES.length - 1]
}
export function typeLabel(v) { return typeMeta(v).label }
export function typeColor(v) { return typeMeta(v).color }

/** ป้ายประเภทของบันทึกจริง — รับ object ทั้งใบ เพราะ "อื่นๆ" ต้องโชว์ visit_type_other ที่พิมพ์เองแทน */
export function visitTypeLabel(visit) {
  if (visit?.visit_type === 'other' && visit?.visit_type_other?.trim()) return visit.visit_type_other.trim()
  return typeLabel(visit?.visit_type)
}
/**
 * หัวข้อส่วน "ผล" ของบันทึก เปลี่ยนตามประเภทกิจกรรม — ใช้ 4 คอลัมน์เดิม (summary/strengths/issues/suggestions)
 * ไม่ได้เปลี่ยนสคีมา บันทึกเก่าประเภทนิเทศโรงเรียน/ติดตามผลได้หัวข้อเดิมทุกตัว
 * ใช้ที่เดียวกันทั้งฟอร์ม รายงาน A4 และหน้าสาธารณะ ห้ามเขียนหัวข้อซ้ำเองในแต่ละหน้า
 */
const RESULT_LABELS = {
  school_visit: {
    section: 'ผลการนิเทศ',
    topic: 'เรื่องที่นิเทศ',     topicPlaceholder: 'เช่น นิเทศการจัดการเรียนรู้เชิงรุก',
    actor: 'ผู้นิเทศ',           co: 'ผู้ร่วมนิเทศ',
    receiver: 'ผู้รับการนิเทศ',   date: 'วันที่นิเทศ',
    photos: 'ภาพประกอบการนิเทศ', reportTitle: 'บันทึกผลการนิเทศ ติดตาม และประเมินผล',
    summary:     { label: 'สภาพที่พบ',      placeholder: 'บรรยายสิ่งที่พบจากการนิเทศ' },
    strengths:   { label: 'จุดเด่น',         placeholder: 'สิ่งที่โรงเรียนทำได้ดี' },
    issues:      { label: 'จุดที่ควรพัฒนา',  placeholder: 'สิ่งที่ควรปรับปรุง' },
    suggestions: { label: 'ข้อเสนอแนะ',     placeholder: 'ข้อเสนอแนะต่อโรงเรียน' },
  },
  meeting: {
    section: 'ผลการประชุม',
    topic: 'เรื่องที่ประชุม',      topicPlaceholder: 'เช่น ประชุมชี้แจงแนวทางการประเมิน',
    actor: 'ผู้เข้าประชุม',        co: 'ผู้เข้าประชุมร่วม',
    receiver: 'ผู้จัด/ผู้เข้าร่วมประชุม', date: 'วันที่ประชุม',
    photos: 'ภาพประกอบการประชุม', reportTitle: 'บันทึกการเข้าร่วมประชุม',
    summary:     { label: 'สาระสำคัญ',                placeholder: 'เรื่องที่ประชุม / ประเด็นหลักที่พูดคุย' },
    strengths:   { label: 'มติ/ข้อสั่งการ',           placeholder: 'มติที่ประชุม หรือข้อสั่งการที่ได้รับ' },
    issues:      { label: 'สิ่งที่ต้องดำเนินการต่อ',   placeholder: 'งานที่ต้องทำต่อ / ผู้รับผิดชอบ / กำหนดเวลา' },
    suggestions: { label: 'ข้อเสนอแนะ',              placeholder: 'ข้อเสนอแนะเพิ่มเติม' },
  },
  training: {
    section: 'ผลการอบรม',
    topic: 'เรื่องที่อบรม',        topicPlaceholder: 'เช่น อบรมการออกแบบการเรียนรู้ Active Learning',
    actor: 'ผู้บันทึก',           co: 'ผู้ร่วมอบรม/วิทยากรร่วม',
    receiver: 'ผู้เข้ารับการอบรม', date: 'วันที่อบรม',
    photos: 'ภาพประกอบการอบรม',  reportTitle: 'บันทึกการอบรม/สัมมนา',
    summary:     { label: 'เนื้อหา/กิจกรรม',          placeholder: 'หัวข้อ เนื้อหา และกิจกรรมของการอบรม' },
    strengths:   { label: 'ผลที่ได้รับ',               placeholder: 'ความรู้/ทักษะ/ผลผลิตที่ได้' },
    issues:      { label: 'ปัญหา/อุปสรรค',            placeholder: 'ปัญหาหรืออุปสรรคที่พบ' },
    suggestions: { label: 'การนำไปใช้/ข้อเสนอแนะ',    placeholder: 'แนวทางนำไปใช้ในงาน / ข้อเสนอแนะ' },
  },
  other: {
    section: 'รายละเอียดกิจกรรม',   // ศน. ขอ (2 ต.ค. 69) — แทน "ผลการดำเนินงาน"
    topic: 'เรื่อง/กิจกรรม',       topicPlaceholder: 'เช่น ร่วมกิจกรรมวันวิชาการของโรงเรียน',
    actor: 'ผู้ปฏิบัติงาน',        co: 'ผู้ร่วมปฏิบัติงาน',
    receiver: 'ผู้เกี่ยวข้อง',       date: 'วันที่ปฏิบัติงาน',
    photos: 'ภาพประกอบ',         reportTitle: 'บันทึกการปฏิบัติงาน',
    summary:     { label: 'สิ่งที่ดำเนินการ', placeholder: 'บรรยายสิ่งที่ดำเนินการ' },
    strengths:   { label: 'ผลที่ได้รับ',      placeholder: 'ผลที่เกิดขึ้น' },
    issues:      { label: 'ปัญหา/อุปสรรค',   placeholder: 'ปัญหาหรืออุปสรรคที่พบ' },
    suggestions: { label: 'ข้อเสนอแนะ',      placeholder: 'ข้อเสนอแนะ' },
  },
}
const RESULT_LABEL_GROUP = {
  school_visit: 'school_visit', follow_up: 'school_visit',
  meeting: 'meeting', training: 'training', speaker: 'training', other: 'other',
}
/** ตัวอย่าง: resultLabels('meeting').summary.label → 'สาระสำคัญ' */
export function resultLabels(visitType) {
  return RESULT_LABELS[RESULT_LABEL_GROUP[visitType] || 'school_visit']
}

/**
 * ประเภทเอกสารอ้างอิงของแผน (ref_kind, migration 91) — ใช้คู่กับ order_number/order_date/order_link
 * ค่าเริ่มต้น 'order' ข้อมูลเดิมจึงยังเป็น "คำสั่ง" เหมือนเดิมทุกแถว
 */
export const REF_KINDS = [
  { value: 'order',  label: 'คำสั่ง',        numberLabel: 'เลขที่คำสั่ง',       dateLabel: 'ลงวันที่คำสั่ง', linkLabel: 'ลิงก์คำสั่ง',  ref: 'ตามคำสั่งเลขที่',      placeholder: 'เช่น 123/2569' },
  { value: 'letter', label: 'หนังสือราชการ', numberLabel: 'เลขที่หนังสือ',      dateLabel: 'ลงวันที่หนังสือ', linkLabel: 'ลิงก์หนังสือ', ref: 'ตามหนังสือที่',        placeholder: 'เช่น ศธ 04xxx/ว123' },
  { value: 'memo',   label: 'บันทึกข้อความ', numberLabel: 'เลขที่บันทึกข้อความ', dateLabel: 'ลงวันที่',       linkLabel: 'ลิงก์บันทึกข้อความ', ref: 'ตามบันทึกข้อความที่', placeholder: 'เช่น กนต 45/2569' },
]
export function refKindMeta(v) { return REF_KINDS.find(k => k.value === v) || REF_KINDS[0] }

/**
 * ประเภทนัดในปฏิทิน (nithet_events.type) → ประเภทบันทึก (nithet_visits.visit_type)
 * ปฏิทินมี school_visit/meeting/training/other ซึ่งตรงกับบันทึกทุกตัวแล้วตั้งแต่ migration 90
 */
export function visitTypeFromEvent(eventType) {
  return ['school_visit', 'meeting', 'training', 'other'].includes(eventType) ? eventType : 'other'
}

export function statusMeta(v) { return VISIT_STATUS[v] || VISIT_STATUS.draft }
export function followupMeta(v) { return FOLLOWUP_STATUS[v] || FOLLOWUP_STATUS.none }

/** ไปที่ไหน — โรงเรียนก่อน ไม่มีค่อยใช้สถานที่ที่พิมพ์เอง */
export function placeOf(v) {
  return v?.school_name || v?.schools?.name || v?.place_name || '—'
}

/** ภาพปก = รูปแรก ไม่ต้องอัปปกแยก */
export function coverOf(v) {
  const p = Array.isArray(v?.photos) ? v.photos : []
  return p[0]?.url || ''
}

export function photoCount(v) {
  return Array.isArray(v?.photos) ? v.photos.length : 0
}

/** รูปแนวตั้งจัด 3 ใบต่อแถวได้ แนวนอนเอา 2 — ใช้ w/h ที่เก็บไว้ตอนอัป */
export function isPortrait(photo) {
  return !!photo && Number(photo.h) > Number(photo.w)
}

/**
 * ปีการศึกษาไทย — เดือน พ.ค. ขึ้นปีใหม่
 * th-TH ให้ปี พ.ศ. มาเองอยู่แล้ว ห้าม +543 ซ้ำ
 */
export function currentAcademicYear(d = new Date()) {
  const be = d.getFullYear() + 543
  return d.getMonth() + 1 >= 5 ? be : be - 1
}

/** ภาคเรียน — พ.ค.-ต.ค. = 1, พ.ย.-เม.ย. = 2 */
export function currentTerm(d = new Date()) {
  const m = d.getMonth() + 1
  return m >= 5 && m <= 10 ? 1 : 2
}

export function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })
}

export function fmtDateLong(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'long', year: 'numeric' })
}

/** เกินกำหนดติดตามแล้วหรือยัง */
export function isOverdue(v) {
  if (v?.followup_status !== 'open' || !v?.followup_due) return false
  return new Date(v.followup_due) < new Date(new Date().toDateString())
}

/** เดาชนิดลิงก์เพื่อเลือกไอคอน — ไม่ต้องให้ผู้ใช้เลือกเอง */
export function linkKind(url) {
  const s = String(url || '').toLowerCase()
  if (/drive\.google\.com|docs\.google\.com/.test(s)) return 'drive'
  if (/youtube\.com|youtu\.be/.test(s)) return 'youtube'
  if (/facebook\.com|fb\.watch/.test(s)) return 'facebook'
  return 'other'
}

export const LINK_ICON = {
  drive:    '📁',
  youtube:  '▶️',
  facebook: '📘',
  other:    '🔗',
}
