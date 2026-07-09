// ปฏิทินนิเทศ — shared labels/colors/formatting reused by admin + public views

export const TYPE_LABEL = {
  school_visit: 'นิเทศโรงเรียน',
  meeting:      'ประชุม',
  training:     'อบรม',
  other:        'อื่นๆ',
}

export const TYPE_COLOR = {
  school_visit: { bg: 'bg-blue-100 dark:bg-blue-500/20',   text: 'text-blue-700 dark:text-blue-300',   dot: 'bg-blue-500' },
  meeting:      { bg: 'bg-amber-100 dark:bg-amber-500/20', text: 'text-amber-700 dark:text-amber-300', dot: 'bg-amber-500' },
  training:     { bg: 'bg-emerald-100 dark:bg-emerald-500/20', text: 'text-emerald-700 dark:text-emerald-300', dot: 'bg-emerald-500' },
  other:        { bg: 'bg-slate-100 dark:bg-slate-500/20', text: 'text-slate-700 dark:text-slate-300', dot: 'bg-slate-500' },
}

export const STATUS_LABEL = {
  scheduled: 'กำหนดการ',
  done:      'เสร็จสิ้น',
  cancelled: 'ยกเลิก',
}

export const STATUS_COLOR = {
  scheduled: 'bg-blue-50 text-blue-600 dark:bg-blue-500/10 dark:text-blue-300',
  done:      'bg-emerald-50 text-emerald-600 dark:bg-emerald-500/10 dark:text-emerald-300',
  cancelled: 'bg-red-50 text-red-500 dark:bg-red-500/10 dark:text-red-300',
}

// เหมือน AdminPersonnelView.vue's displayName() — ใช้ร่วมกันสำหรับ "ผู้รับผิดชอบ"
export function displayName(p) {
  if (!p) return '-'
  if (p.first_name || p.last_name) return `${p.title || ''} ${p.first_name || ''} ${p.last_name || ''}`.trim()
  return p.full_name || p.email || '-'
}

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

function fmtTime(t) {
  if (!t) return ''
  return t.slice(0, 5) // 'HH:MM:SS' -> 'HH:MM'
}

export function formatEventDateRange(event) {
  const sameDay = event.start_date === event.end_date
  const dateStr = sameDay ? fmtDate(event.start_date) : `${fmtDate(event.start_date)} - ${fmtDate(event.end_date)}`
  const timeStr = event.start_time ? `${fmtTime(event.start_time)}${event.end_time ? '-' + fmtTime(event.end_time) : ''} น.` : ''
  return timeStr ? `${dateStr} · ${timeStr}` : dateStr
}

// รวมชื่อผู้รับผิดชอบหลายคน + ชื่อกลุ่ม (ถ้ามอบทั้งกลุ่ม) เป็นสตริงเดียวสำหรับแสดงผล
export function formatResponsible(names, groupLabel) {
  const parts = []
  if (groupLabel) parts.push(groupLabel)
  if (names && names.length) parts.push(names.join(', '))
  return parts.join(' · ')
}
