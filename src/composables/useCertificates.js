import { driveThumb } from './useGoogleDrive'

/**
 * useCertificates — ตัวช่วยเล็กๆ ของคลังเกียรติบัตร
 *
 * ตัวเลือก "กลุ่มงาน" (useGroupOptions) และรายชื่อผู้ที่เลือกเป็น "ผู้รับผิดชอบ" ได้
 * (usePublisherOptions) ใช้ของ useLibraryOptions.js ตรงๆ ไม่สร้างซ้ำ
 *
 * ผู้รับผิดชอบเก็บเป็น responsible_ids uuid[] (เลือกได้หลายคน — งานบางชิ้นทำร่วมกัน)
 * หน้าสาธารณะอ่านชื่อที่รวมมาแล้วจาก view certificates_public.responsible_names ตรงๆ
 */

/** รวมชื่อผู้รับผิดชอบหลายคน (จาก usePublisherOptions().publisherById) ให้เป็นข้อความเดียว — ใช้ฝั่งแอดมิน */
export function responsibleNames(ids, publisherById, personDisplayName) {
  return (ids || [])
    .map(id => publisherById[id] ? personDisplayName(publisherById[id]) : '')
    .filter(Boolean)
    .join(', ')
}

/** ภาพปกที่จะใช้แสดงบนการ์ด ตาม cover_source ของแถว */
export function certCoverSrc(item, size = 480) {
  if (!item) return ''
  if (item.cover_source === 'drive') return driveThumb(item.cover_drive_id, size)
  return item.cover_url || ''
}

export function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })
}
