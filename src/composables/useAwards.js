// useAwards — ค่าคงที่และตัวช่วยของระบบผลงานและรางวัล
//
// ⚠️ คลาสสีต้องเขียนเป็นสตริงเต็มเสมอ ห้ามประกอบจากตัวแปร (`bg-${c}-100`)
//    ไม่งั้น Tailwind JIT purge ทิ้ง — บทเรียนที่เจอซ้ำหลายรอบในโปรเจคนี้

/** ประเภทเจ้าของรางวัล — ต้องตรงกับ CHECK constraint ในตาราง awards */
export const OWNER_KINDS = [
  { value: 'area',       label: 'สพป.นม.2',             icon: '🏛️', bg: 'bg-indigo-100', text: 'text-indigo-700', dot: 'bg-indigo-500' },
  { value: 'school',     label: 'โรงเรียน',              icon: '🏫', bg: 'bg-blue-100',   text: 'text-blue-700',   dot: 'bg-blue-500'   },
  { value: 'teacher',    label: 'ครู',                   icon: '👩‍🏫', bg: 'bg-emerald-100', text: 'text-emerald-700', dot: 'bg-emerald-500' },
  { value: 'supervisor', label: 'ศึกษานิเทศก์',          icon: '🎓', bg: 'bg-violet-100', text: 'text-violet-700', dot: 'bg-violet-500' },
  { value: 'staff',      label: 'บุคลากรทางการศึกษา',   icon: '🧑‍💼', bg: 'bg-cyan-100',   text: 'text-cyan-700',   dot: 'bg-cyan-500'   },
  { value: 'other',      label: 'อื่นๆ (ระบุเอง)',       icon: '✳️', bg: 'bg-slate-100',  text: 'text-slate-600',  dot: 'bg-slate-400'  },
]

/**
 * ระดับรางวัล — weight ใช้เรียงความสำคัญและใช้กรอง "ระดับชาติขึ้นไป" ในแดชบอร์ด
 */
export const AWARD_LEVELS = [
  { value: 'area',          label: 'ระดับเขตพื้นที่',  short: 'เขต',      weight: 1, bg: 'bg-slate-100',  text: 'text-slate-600',  bar: 'bg-slate-400'  },
  { value: 'province',      label: 'ระดับจังหวัด',     short: 'จังหวัด',  weight: 2, bg: 'bg-sky-100',    text: 'text-sky-700',    bar: 'bg-sky-500'    },
  { value: 'region',        label: 'ระดับภาค',         short: 'ภาค',      weight: 3, bg: 'bg-violet-100', text: 'text-violet-700', bar: 'bg-violet-500' },
  { value: 'national',      label: 'ระดับชาติ',        short: 'ชาติ',     weight: 4, bg: 'bg-amber-100',  text: 'text-amber-800',  bar: 'bg-amber-500'  },
  { value: 'international', label: 'ระดับนานาชาติ',    short: 'นานาชาติ', weight: 5, bg: 'bg-rose-100',   text: 'text-rose-700',   bar: 'bg-rose-500'   },
]

/**
 * ชื่อรางวัล — จัดกลุ่มเรียงจากน้อยไปมาก ใช้กับ <optgroup>
 * เก็บลง DB เป็น value ส่วน label ใช้แสดง (แก้ label ทีหลังไม่กระทบข้อมูลเดิม)
 */
export const AWARD_RANK_GROUPS = [
  {
    label: 'เกียรติบัตร',
    items: [
      { value: 'cert_join',   label: 'เกียรติบัตรเข้าร่วม' },
      { value: 'cert_train',  label: 'เกียรติบัตรผ่านการอบรม' },
      { value: 'cert_praise', label: 'เกียรติบัตรชมเชย' },
      { value: 'cert_honor',  label: 'เกียรติบัตรเชิดชูเกียรติ' },
    ],
  },
  {
    label: 'ระดับเหรียญ',
    items: [
      { value: 'bronze',      label: 'เหรียญทองแดง' },
      { value: 'silver',      label: 'เหรียญเงิน' },
      { value: 'gold',        label: 'เหรียญทอง' },
      { value: 'gold_winner', label: 'เหรียญทอง ชนะเลิศ' },
    ],
  },
  {
    label: 'อันดับ',
    items: [
      { value: 'runner_up_2', label: 'รองชนะเลิศ อันดับ 2' },
      { value: 'runner_up_1', label: 'รองชนะเลิศ อันดับ 1' },
      { value: 'winner',      label: 'ชนะเลิศ' },
    ],
  },
  {
    label: 'โล่ / ถ้วยรางวัล',
    items: [
      { value: 'plaque',       label: 'โล่รางวัล' },
      { value: 'cup',          label: 'ถ้วยรางวัล' },
      { value: 'royal_plaque', label: 'โล่พระราชทาน' },
      { value: 'royal_cup',    label: 'ถ้วยพระราชทาน' },
    ],
  },
  {
    label: 'อื่นๆ',
    items: [{ value: 'other', label: 'อื่นๆ (ระบุเอง)' }],
  },
]

/** แบนราบไว้ใช้ค้นหา label เร็วๆ */
export const AWARD_RANKS = AWARD_RANK_GROUPS.flatMap(g => g.items)

/** สีของชื่อรางวัล — เขียนเต็มทุกคลาส (ดูหมายเหตุ JIT ด้านบน) */
const RANK_STYLE = {
  cert_join:   { bg: 'bg-slate-100',  text: 'text-slate-600'  },
  cert_train:  { bg: 'bg-slate-100',  text: 'text-slate-600'  },
  cert_praise: { bg: 'bg-teal-100',   text: 'text-teal-700'   },
  cert_honor:  { bg: 'bg-teal-100',   text: 'text-teal-700'   },
  bronze:      { bg: 'bg-orange-100', text: 'text-orange-800' },
  silver:      { bg: 'bg-zinc-200',   text: 'text-zinc-700'   },
  gold:        { bg: 'bg-amber-100',  text: 'text-amber-800'  },
  gold_winner: { bg: 'bg-amber-200',  text: 'text-amber-900'  },
  runner_up_2: { bg: 'bg-sky-100',    text: 'text-sky-700'    },
  runner_up_1: { bg: 'bg-sky-100',    text: 'text-sky-800'    },
  winner:      { bg: 'bg-emerald-100', text: 'text-emerald-800' },
  plaque:      { bg: 'bg-violet-100', text: 'text-violet-700' },
  cup:         { bg: 'bg-violet-100', text: 'text-violet-800' },
  royal_plaque:{ bg: 'bg-rose-100',   text: 'text-rose-700'   },
  royal_cup:   { bg: 'bg-rose-100',   text: 'text-rose-800'   },
  other:       { bg: 'bg-slate-100',  text: 'text-slate-600'  },
}

/**
 * ไอคอนรางวัล — เก็บแยกจาก useIcons.js เพราะ IconPicker ของเมนูจะโชว์ปนกัน
 * เป็น path ของ heroicons outline (stroke) ใช้กับ viewBox 0 0 24 24
 */
export const AWARD_ICONS = [
  { value: 'trophy', label: 'ถ้วยรางวัล', path: 'M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 002.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 012.916.52 6.003 6.003 0 01-5.395 4.972m0 0a6.726 6.726 0 01-2.749 1.35m0 0a6.772 6.772 0 01-3.044 0' },
  { value: 'medal',  label: 'เหรียญรางวัล', path: 'M8.25 2.25L12 6l3.75-3.75M12 6v3m0 0a6 6 0 100 12 6 6 0 000-12zm1.5 6a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0z' },
  { value: 'shield', label: 'โล่รางวัล', path: 'M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z' },
  { value: 'cert',   label: 'เกียรติบัตร', path: 'M10.125 2.25h-4.5c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125v-9M10.125 2.25h.375a9 9 0 019 9v.375M10.125 2.25A3.375 3.375 0 0113.5 5.625v1.5c0 .621.504 1.125 1.125 1.125h1.5a3.375 3.375 0 013.375 3.375M9 15l2.25 2.25L15 12' },
  { value: 'star',   label: 'ดาวเด่น', path: 'M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z' },
  { value: 'honor',  label: 'เชิดชูเกียรติ', path: 'M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z' },
  { value: 'academy', label: 'อบรม/พัฒนา', path: 'M4.26 10.147a60.438 60.438 0 00-.491 6.347A48.62 48.62 0 0112 20.904a48.62 48.62 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.636 50.636 0 00-2.658-.813A59.906 59.906 0 0112 3.493a59.903 59.903 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5' },
  { value: 'book',   label: 'ผลงานวิชาการ', path: 'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25' },
]

/** ตัวเลือก "จัดกลุ่มตาม" ของรายงาน A4 */
export const REPORT_GROUP_BY = [
  { value: 'school_group', label: 'ศูนย์เครือข่าย' },
  { value: 'district',     label: 'อำเภอ' },
  { value: 'school',       label: 'โรงเรียน' },
  { value: 'owner_kind',   label: 'ประเภทผู้รับรางวัล' },
  { value: 'level',        label: 'ระดับรางวัล' },
  { value: 'academic_year',label: 'ปีการศึกษา' },
]

// ── ตัวช่วย ───────────────────────────────────────────────────────────
export function ownerKindMeta(v) { return OWNER_KINDS.find(o => o.value === v) || OWNER_KINDS[OWNER_KINDS.length - 1] }
export function levelMeta(v)     { return AWARD_LEVELS.find(l => l.value === v) || AWARD_LEVELS[0] }
export function rankMeta(v)      { return RANK_STYLE[v] || RANK_STYLE.other }
export function iconMeta(v)      { return AWARD_ICONS.find(i => i.value === v) || AWARD_ICONS[0] }

/** ชื่อรางวัลที่จะแสดง — ถ้าเลือก "อื่นๆ" ให้ใช้ข้อความที่ผู้ใช้พิมพ์เอง */
export function rankLabel(a) {
  if (a?.award_rank === 'other') return a.award_rank_other || 'อื่นๆ'
  return AWARD_RANKS.find(r => r.value === a?.award_rank)?.label || a?.award_rank || '—'
}

/** บทบาทที่บันทึกแล้วขึ้นทันที — ต้องตรงกับ trigger awards_before_insert */
export const AWARD_AUTO_APPROVE_ROLES = ['super_admin', 'admin', 'supervisor', 'staff']
/** บทบาทที่อนุมัติของคนอื่นได้ — ต้องตรงกับ RPC review_award */
export const AWARD_REVIEWER_ROLES = ['super_admin', 'admin', 'supervisor']

/** ปีการศึกษาไทยของวันนี้ (เปลี่ยนปีการศึกษาเดือน พ.ค.) */
export function currentAcademicYear() {
  const now = new Date()
  const be = now.getFullYear() + 543
  return String(now.getMonth() + 1 >= 5 ? be : be - 1)
}

export function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })
}
