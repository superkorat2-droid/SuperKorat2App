/**
 * useNewsletterMeta — หมวดหมู่และเดือนของจดหมายข่าว
 *
 * แยกออกมาเพราะตอนนี้ใช้ 2 ที่แล้ว (หน้า /newsletters และเซกชันหน้าแรก)
 * ถ้าปล่อยให้ก๊อปกัน วันหนึ่งเพิ่มหมวดใหม่แล้วจะขึ้นไม่ครบทุกหน้า
 * (ปัญหาเดียวกับ extractFileId ที่เคยกระจายอยู่ 5 ไฟล์ ดู useGoogleDrive.js)
 */

export const NEWSLETTER_CATEGORIES = [
  { value: 'newsletter',   label: 'จดหมายข่าว' },
  { value: 'announcement', label: 'ประกาศ/หนังสือเวียน' },
  { value: 'circular',     label: 'คำสั่ง' },
  { value: 'policy',       label: 'นโยบาย' },
  { value: 'other',        label: 'อื่นๆ' },
]

export const MONTHS_TH = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
                          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']

export function newsletterCatLabel(c) {
  return NEWSLETTER_CATEGORIES.find(x => x.value === c)?.label || c
}

/**
 * สีป้ายหมวด
 * ⚠️ ห้ามใช้รูปแบบ `bg-primary/10` — `primary` ไม่ใช่สีใน theme ของ Tailwind
 * (เป็นคลาสที่เขียนมือใน style.css) เขียนแบบนั้นแล้วคลาสจะไม่มีอยู่จริง
 */
export function newsletterCatColor(c) {
  return {
    newsletter:   'bg-sky-100 text-sky-700',
    announcement: 'bg-indigo-100 text-indigo-700',
    circular:     'bg-amber-100 text-amber-700',
    policy:       'bg-rose-100 text-rose-700',
    other:        'bg-slate-100 text-slate-500',
  }[c] || 'bg-slate-100 text-slate-500'
}

/** ตาราง newsletters เก็บ `year` เป็น พ.ศ. อยู่แล้ว — ห้าม +543 ซ้ำ */
export function newsletterDateLabel(month, year) {
  const m = month ? MONTHS_TH[month - 1] : ''
  return [m, year].filter(Boolean).join(' ')
}
