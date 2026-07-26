// useWorks — ค่าคงที่และตัวช่วยของระบบเผยแพร่ผลงาน (ใช้ร่วมกันทั้ง admin และหน้าสาธารณะ)

export const WORK_TYPES = [
  { value: 'research',      label: 'งานวิจัย',        icon: '🔬', bg: 'bg-blue-100',    text: 'text-blue-700'    },
  { value: 'innovation',    label: 'นวัตกรรม',        icon: '💡', bg: 'bg-amber-100',   text: 'text-amber-700'   },
  { value: 'best_practice', label: 'Best Practice',   icon: '⭐', bg: 'bg-emerald-100', text: 'text-emerald-700' },
  { value: 'lesson_plan',   label: 'แผนการสอน',       icon: '📘', bg: 'bg-violet-100',  text: 'text-violet-700'  },
  { value: 'other',         label: 'อื่นๆ',           icon: '📄', bg: 'bg-slate-100',   text: 'text-slate-600'   },
]

export const WORK_STATUS = {
  pending:  { label: 'รออนุมัติ', bg: 'bg-amber-100',   text: 'text-amber-700'   },
  approved: { label: 'เผยแพร่',   bg: 'bg-emerald-100', text: 'text-emerald-700' },
  rejected: { label: 'ถูกตีกลับ', bg: 'bg-red-100',     text: 'text-red-600'     },
}

export const OWNER_TYPES = [
  { value: 'supervisor', label: 'บุคลากรเขต' },
  { value: 'teacher',    label: 'ครู' },
  { value: 'school',     label: 'โรงเรียน' },
]

export function workTypeMeta(v) { return WORK_TYPES.find(t => t.value === v) || WORK_TYPES[WORK_TYPES.length - 1] }
export function workStatusMeta(v) { return WORK_STATUS[v] || WORK_STATUS.pending }

/** บทบาทที่เผยแพร่ได้ทันทีโดยไม่ต้องรออนุมัติ — ต้องตรงกับ trigger works_before_insert */
export const AUTO_APPROVE_ROLES = ['super_admin', 'admin', 'supervisor', 'staff']
/** บทบาทที่อนุมัติผลงานคนอื่นได้ — ต้องตรงกับ RPC review_work */
export const REVIEWER_ROLES = ['super_admin', 'admin', 'supervisor']

/** เดา owner_type จาก role ของผู้ใช้ (ตอนสร้างผลงานใหม่) */
export function ownerTypeFromRole(role) {
  if (role === 'school') return 'school'
  if (role === 'teacher') return 'teacher'
  return 'supervisor'
}

export function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: '2-digit' })
}
