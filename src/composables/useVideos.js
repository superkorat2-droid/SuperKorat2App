// useVideos — ค่าคงที่และตัวช่วยของระบบวีดิทัศน์การศึกษา
// ใช้ร่วมกันทั้งหน้า admin คิวอนุมัติ หน้ารวมสาธารณะ และเซกชันหน้าแรก

import { youtubeId } from './useYoutubeGrid'
import { extractDriveId, drivePreviewUrl, driveViewUrl, driveThumb } from './useGoogleDrive'

// บทบาทใช้ชุดเดียวกับระบบผลงาน — import ต่อ ไม่นิยามซ้ำ ไม่งั้นวันหนึ่งจะหลุดกัน
export { AUTO_APPROVE_ROLES, REVIEWER_ROLES } from './useWorks'
export { CURRENT_BE_YEAR } from './useLibraryOptions'

/** ⚠️ ต้องตรงกับ CHECK constraint videos_category_chk ใน migration 0071 เป๊ะ */
export const VIDEO_CATEGORIES = [
  { value: 'learning',      label: 'คลิปการสอน',      icon: '📚', color: 'bg-indigo-100 text-indigo-700'   },
  { value: 'activity',      label: 'กิจกรรมโรงเรียน',  icon: '🎉', color: 'bg-emerald-100 text-emerald-700' },
  { value: 'training',      label: 'อบรม/สัมมนา',      icon: '🎓', color: 'bg-blue-100 text-blue-700'       },
  { value: 'supervision',   label: 'นิเทศติดตาม',      icon: '🔍', color: 'bg-cyan-100 text-cyan-700'       },
  { value: 'announcement',  label: 'ประชาสัมพันธ์',    icon: '📣', color: 'bg-amber-100 text-amber-700'     },
  { value: 'best_practice', label: 'Best Practice',    icon: '⭐', color: 'bg-violet-100 text-violet-700'   },
  { value: 'ceremony',      label: 'พิธีการ',          icon: '🏛️', color: 'bg-rose-100 text-rose-700'       },
  { value: 'other',         label: 'อื่นๆ',            icon: '🎬', color: 'bg-slate-100 text-slate-500'     },
]

export const VIDEO_STATUS = {
  pending:  { label: 'รออนุมัติ', bg: 'bg-amber-100',   text: 'text-amber-700'   },
  approved: { label: 'เผยแพร่',   bg: 'bg-emerald-100', text: 'text-emerald-700' },
  rejected: { label: 'ถูกตีกลับ', bg: 'bg-red-100',     text: 'text-red-600'     },
}

export const VIDEO_OWNER_TYPES = {
  area:       'สำนักงานเขต',
  supervisor: 'บุคลากรเขต',
  school:     'โรงเรียน',
  teacher:    'ครู',
  member:     'สมาชิก',
}

export function categoryMeta(v) {
  return VIDEO_CATEGORIES.find(c => c.value === v) || VIDEO_CATEGORIES[VIDEO_CATEGORIES.length - 1]
}
/** ⚠️ ห้ามคืนคลาสแบบ `bg-primary/10` — primary ไม่ใช่สีใน theme คลาสจะไม่มีอยู่จริง */
export function categoryLabel(v) { return categoryMeta(v).label }
export function categoryColor(v) { return categoryMeta(v).color }
export function videoStatusMeta(v) { return VIDEO_STATUS[v] || VIDEO_STATUS.pending }
export function ownerTypeLabel(v) { return VIDEO_OWNER_TYPES[v] || VIDEO_OWNER_TYPES.member }

/**
 * แยกแหล่งวิดีโอจากลิงก์ที่ผู้ใช้วางมา
 *
 * เช็ค YouTube ก่อนเสมอ เพราะ parseDriveUrl() มี pattern `/d/<id>` ที่กว้างพอจะ
 * ไปคว้าลิงก์อื่นมาผิด ๆ ได้ · คืน { source:'', videoId:'' } ถ้าไม่ใช่ทั้งคู่
 *
 * @returns {{ source: 'youtube'|'drive'|'', videoId: string }}
 */
export function parseVideoSource(url) {
  const yt = youtubeId(url)
  if (yt) return { source: 'youtube', videoId: yt }

  const s = String(url || '').trim()
  if (/drive\.google\.com|docs\.google\.com/.test(s)) {
    const id = extractDriveId(s)
    if (id) return { source: 'drive', videoId: id }
  }
  return { source: '', videoId: '' }
}

/**
 * ภาพปกการ์ด — ต้องเป็น <img> เท่านั้น
 * ⚠️ ห้ามใช้ iframe ทำภาพปก วัดแล้วหนักกว่า 64 เท่า (ดู useGoogleDrive.js:40-54)
 * youtube คืน hqdefault ซึ่งเป็น 4:3 → ผู้เรียกต้องใช้ object-cover บนกรอบ 16:9
 */
export function videoThumb(v, size = 600) {
  if (!v) return ''
  if (v.thumb_url) return v.thumb_url
  if (!v.video_id) return ''
  return v.source === 'drive'
    ? driveThumb(v.video_id, size)
    : `https://img.youtube.com/vi/${v.video_id}/hqdefault.jpg`
}

/**
 * URL สำหรับ iframe ในโมดัล
 *
 * ไม่ใช้ toEmbedUrl() จาก useEmbed.js เพราะตัวนั้นรับ "URL" แล้ว regex ใหม่ทุกครั้ง
 * และไม่รองรับ shorts/live — ส่วนเราเก็บ video_id ที่สกัดไว้แล้วตั้งแต่ตอนบันทึก
 */
export function videoEmbedUrl(v) {
  if (!v?.video_id) return ''
  return v.source === 'drive'
    ? drivePreviewUrl(v.video_id)
    : `https://www.youtube.com/embed/${v.video_id}?rel=0&autoplay=1`
}

/** ลิงก์เปิดที่ต้นทาง — ต้องมีเสมอ เผื่อคลิปที่เจ้าของปิดการฝัง */
export function videoWatchUrl(v) {
  if (!v) return ''
  if (v.video_url) return v.video_url
  if (!v.video_id) return ''
  return v.source === 'drive' ? driveViewUrl(v.video_id) : `https://www.youtube.com/watch?v=${v.video_id}`
}

export function fmtDateTime(d) {
  if (!d) return ''
  return new Date(d).toLocaleString('th-TH', {
    day: 'numeric', month: 'short', year: '2-digit', hour: '2-digit', minute: '2-digit',
  })
}

export function fmtViews(n) {
  const v = Number(n) || 0
  if (v >= 1000000) return (v / 1000000).toFixed(1).replace(/\.0$/, '') + ' ล้าน'
  if (v >= 1000) return (v / 1000).toFixed(1).replace(/\.0$/, '') + ' พัน'
  return String(v)
}
