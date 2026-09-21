import { driveThumb } from './useGoogleDrive'

/**
 * useCertificates — ตัวช่วยเล็กๆ ของคลังเกียรติบัตร
 *
 * ตัวเลือก "กลุ่มงาน" (useGroupOptions) และ "ผู้รับผิดชอบ" (usePublisherOptions)
 * ใช้ของ useLibraryOptions.js ตรงๆ ไม่สร้างซ้ำ — โครงสร้างข้อมูลเหมือนกันเป๊ะ
 */

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
