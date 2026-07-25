import { ref } from 'vue'
import { supabase } from '../supabase'

export const HOLIDAY_TYPES = [
  { value: 'public',  label: 'วันหยุดราชการ', dot: 'bg-rose-500',   bg: 'bg-rose-100',   text: 'text-rose-700'   },
  { value: 'school',  label: 'ปิดภาคเรียน',   dot: 'bg-violet-500', bg: 'bg-violet-100', text: 'text-violet-700' },
  { value: 'special', label: 'หยุดกรณีพิเศษ', dot: 'bg-orange-500', bg: 'bg-orange-100', text: 'text-orange-700' },
]

export function holidayMeta(type) {
  return HOLIDAY_TYPES.find(t => t.value === type) || HOLIDAY_TYPES[0]
}

/** map วันที่ (YYYY-MM-DD) → วันหยุดที่ครอบวันนั้น ใช้ระบายสีช่องปฏิทินเร็วๆ */
export function buildHolidayIndex(holidays) {
  const idx = {}
  for (const h of holidays) {
    const d = new Date(h.start_date + 'T00:00:00')
    const end = new Date(h.end_date + 'T00:00:00')
    while (d <= end) {
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
      if (!idx[key]) idx[key] = h
      d.setDate(d.getDate() + 1)
    }
  }
  return idx
}

/** โหลดวันหยุดผ่าน RPC สาธารณะ (ใช้ได้ทั้งหน้าสาธารณะและหลังบ้าน) */
export function useHolidays() {
  const holidays = ref([])
  const loading  = ref(false)

  async function fetchHolidays() {
    loading.value = true
    const { data } = await supabase.rpc('get_nithet_holidays_public')
    holidays.value = Array.isArray(data) ? data : []
    loading.value = false
    return holidays.value
  }

  return { holidays, loading, fetchHolidays }
}

// ── Excel import ────────────────────────────────────────────────────
// รับได้ทั้งวันที่แบบ Excel serial, Date object และข้อความ d/m/yyyy (รองรับ พ.ศ.)

export const HOLIDAY_IMPORT_COLUMNS = ['ชื่อวันหยุด', 'วันที่เริ่ม', 'วันที่สิ้นสุด', 'ประเภท', 'หมายเหตุ']

const TYPE_BY_LABEL = {
  'วันหยุดราชการ': 'public',  'ราชการ': 'public',  'public': 'public',
  'ปิดภาคเรียน':   'school',  'ภาคเรียน': 'school', 'school': 'school',
  'หยุดกรณีพิเศษ': 'special', 'พิเศษ': 'special',   'special': 'special',
}

/** แปลงค่าวันที่จาก Excel เป็น YYYY-MM-DD — คืน null ถ้าแปลงไม่ได้ */
export function parseHolidayDate(v) {
  if (v === null || v === undefined || v === '') return null

  // Excel serial number (นับจาก 1899-12-30)
  if (typeof v === 'number') {
    const d = new Date(Math.round((v - 25569) * 86400000))
    return isNaN(d) ? null : d.toISOString().slice(0, 10)
  }
  if (v instanceof Date) {
    return isNaN(v) ? null : new Date(v.getTime() - v.getTimezoneOffset() * 60000).toISOString().slice(0, 10)
  }

  const s = String(v).trim()
  if (!s) return null

  // ISO อยู่แล้ว
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s

  // d/m/yyyy หรือ d-m-yyyy (ปีเป็น พ.ศ. ได้)
  const m = s.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/)
  if (m) {
    let y = parseInt(m[3], 10)
    if (y > 2400) y -= 543          // พ.ศ. → ค.ศ.
    return `${y}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`
  }
  return null
}

/**
 * แปลงแถวจากไฟล์ Excel เป็นข้อมูลพร้อม insert
 * @returns {{ rows: object[], errors: string[] }}
 */
export function parseHolidayRows(raw) {
  const rows = []
  const errors = []

  raw.forEach((r, i) => {
    const lineNo = i + 2   // +1 ข้ามหัวตาราง, +1 ให้เลขตรงกับที่เห็นใน Excel
    const title = String(r['ชื่อวันหยุด'] ?? '').trim()
    if (!title) {
      // แถวว่างท้ายไฟล์เป็นเรื่องปกติ ไม่นับเป็น error
      if (Object.values(r).some(v => String(v ?? '').trim())) {
        errors.push(`แถว ${lineNo}: ไม่มีชื่อวันหยุด`)
      }
      return
    }

    const start = parseHolidayDate(r['วันที่เริ่ม'])
    if (!start) { errors.push(`แถว ${lineNo}: "${title}" — วันที่เริ่มไม่ถูกต้อง`); return }

    // ไม่ระบุวันสิ้นสุด = วันเดียว
    const end = parseHolidayDate(r['วันที่สิ้นสุด']) || start
    if (end < start) { errors.push(`แถว ${lineNo}: "${title}" — วันสิ้นสุดอยู่ก่อนวันเริ่ม`); return }

    const typeRaw = String(r['ประเภท'] ?? '').trim()
    rows.push({
      title,
      start_date: start,
      end_date:   end,
      type:       TYPE_BY_LABEL[typeRaw] || 'public',
      note:       String(r['หมายเหตุ'] ?? '').trim(),
    })
  })

  return { rows, errors }
}
