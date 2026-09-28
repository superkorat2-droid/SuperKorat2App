/**
 * useNtParser — parse the official "Local 03" score reports (.xlsx) from สทศ./สพฐ.
 * ใช้ได้ทั้ง NT (คณิต/ไทย) และ RT (การอ่านออกเสียง/การอ่านรู้เรื่อง) — โครงตารางเหมือนกัน
 * ทุกอย่าง (1 แถว/โรงเรียน: รหัส/ชื่อ/อำเภอ/ขนาดโรงเรียน + คะแนน+ร้อยละ 2 ด้าน+รวม +
 * ระดับคุณภาพ 2 ด้าน+รวม) ต่างกันแค่ชื่อวิชา — เป็นไฟล์ .xlsx ปกติ (UTF-8 ภายใน) ไม่ใช่ cp874
 * เหมือนไฟล์ DMC ระดับเขต จึงอ่านด้วย SheetJS ตรงๆ ได้เลย
 *
 * สำคัญ: ตำแหน่งคอลัมน์ "ลำดับ" ไม่ได้อยู่คอลัมน์เดียวกันเสมอ — ไฟล์ NT มีคอลัมน์ A ว่าง
 * (ลำดับอยู่ index 1) แต่ไฟล์ RT ไม่มีคอลัมน์ว่างนำหน้า (ลำดับอยู่ index 0) จึงต้องหา
 * ตำแหน่งคอลัมน์ "ลำดับ" ก่อนแล้วคำนวณคอลัมน์อื่นๆ แบบ offset สัมพัทธ์ ห้าม hardcode ตายตัว
 */
import { read, utils } from 'xlsx'

export const NT_SUBJECTS = [
  { key: 'math', label: 'ด้านคณิตศาสตร์' },
  { key: 'thai', label: 'ด้านภาษาไทย' },
]
export const RT_SUBJECTS = [
  { key: 'aloud',         label: 'การอ่านออกเสียง' },
  { key: 'comprehension', label: 'การอ่านรู้เรื่อง' },
]

function toNum(v) {
  const n = parseFloat(String(v ?? '').trim())
  return isNaN(n) ? null : n
}

// หาแถว+คอลัมน์ที่ "ลำดับ" ตามด้วย "รหัสโรงเรียน" ทันที คืน { row, base } (base = index ของ "ลำดับ")
function findHeader(rows) {
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    for (let j = 0; j < r.length; j++) {
      if (String(r[j] ?? '').trim() === 'ลำดับ' && String(r[j + 1] ?? '').trim() === 'รหัสโรงเรียน') {
        return { row: i, base: j }
      }
    }
  }
  return null
}

function parseMeta(rows) {
  const meta = { academicYear: null, gradeLevel: null, districtName: null }
  for (const r of rows.slice(0, 10)) {
    const line = r.filter(Boolean).join(' ')
    const yearM = line.match(/ปีการศึกษา\s*(\d{4})/)
    if (yearM) meta.academicYear = parseInt(yearM[1], 10)
    const gradeM = line.match(/ชั้นประถมศึกษาปีที่\s*(\d)/)
    if (gradeM) meta.gradeLevel = `ป.${gradeM[1]}`
    const distM = line.match(/สพป\.?\s*\S+\s*เขต\s*\d+/)
    if (distM) meta.districtName = distM[0].trim()
  }
  return meta
}

// Local03/R-Local03 มีโครงคอลัมน์เดียวกันเสมอ นับ offset จาก "ลำดับ" (base):
// base+0 ลำดับ, +1 รหัสโรงเรียน, +2 ชื่อโรงเรียน, +3 อำเภอ/เขต, +4 ขนาดโรงเรียน,
// +5 วิชา1 คะแนน, +6 วิชา1 ร้อยละ, +7 วิชา2 คะแนน, +8 วิชา2 ร้อยละ, +9 รวม คะแนน, +10 รวม ร้อยละ,
// +11 ระดับ วิชา1, +12 ระดับ วิชา2, +13 ระดับ รวม
function parseLocal03Generic(file, subjects, fileLabel) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb = read(e.target.result, { type: 'array' })
        const ws = wb.Sheets[wb.SheetNames[0]]
        const rows = utils.sheet_to_json(ws, { header: 1, defval: '' })

        const header = findHeader(rows)
        if (!header) {
          reject(new Error(`ไม่พบหัวตาราง — ตรวจสอบว่าเป็นไฟล์รายงาน Local03 ของ ${fileLabel} ที่ถูกต้อง`))
          return
        }
        const b = header.base
        const COL = {
          CODE: b + 1, NAME: b + 2, DISTRICT: b + 3, SIZE: b + 4,
          S1_SCORE: b + 5, S1_PCT: b + 6, S2_SCORE: b + 7, S2_PCT: b + 8,
          OVERALL_SCORE: b + 9, OVERALL_PCT: b + 10,
          S1_LEVEL: b + 11, S2_LEVEL: b + 12, OVERALL_LEVEL: b + 13,
        }

        const meta = parseMeta(rows)
        const dataRows = rows.slice(header.row + 3) // หัวตาราง 3 ชั้น (ชื่อกลุ่ม/ชื่อวิชา/คะแนน-ร้อยละ)

        const schoolRows = []
        let skippedRows = 0

        for (const r of dataRows) {
          const code = String(r[COL.CODE] ?? '').trim()
          if (!code) break // หมดข้อมูลโรงเรียน (แถวถัดไปเป็นหมายเหตุ/ว่าง)
          if (!/^\d+$/.test(code)) { skippedRows++; continue }

          const s1Score = toNum(r[COL.S1_SCORE])
          const s2Score = toNum(r[COL.S2_SCORE])
          const overallScore = toNum(r[COL.OVERALL_SCORE])
          if (s1Score === null && s2Score === null) { skippedRows++; continue }

          schoolRows.push({
            school_code: code,
            school_name: String(r[COL.NAME] ?? '').trim(),
            district: String(r[COL.DISTRICT] ?? '').trim(),
            school_size: String(r[COL.SIZE] ?? '').trim(),
            scores: {
              [subjects[0].key]: { score: s1Score, pct: toNum(r[COL.S1_PCT]), level: String(r[COL.S1_LEVEL] ?? '').trim() },
              [subjects[1].key]: { score: s2Score, pct: toNum(r[COL.S2_PCT]), level: String(r[COL.S2_LEVEL] ?? '').trim() },
              overall: { score: overallScore, pct: toNum(r[COL.OVERALL_PCT]), level: String(r[COL.OVERALL_LEVEL] ?? '').trim() },
            },
          })
        }

        if (schoolRows.length === 0) {
          reject(new Error(`ไม่พบข้อมูลโรงเรียนในไฟล์ — ตรวจสอบว่าเป็นไฟล์รายงาน Local03 ของ ${fileLabel} ที่ถูกต้อง`))
          return
        }

        resolve({ meta, subjects, rows: schoolRows, skippedRows })
      } catch (err) {
        reject(new Error('อ่านไฟล์ไม่ได้: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('อ่านไฟล์ไม่ได้'))
    reader.readAsArrayBuffer(file)
  })
}

export function parseNtLocal03File(file) {
  return parseLocal03Generic(file, NT_SUBJECTS, 'NT')
}
export function parseRtLocal03File(file) {
  return parseLocal03Generic(file, RT_SUBJECTS, 'RT')
}

export const QUALITY_LEVELS = ['ดีมาก', 'ดี', 'พอใช้', 'ปรับปรุง']
export const QUALITY_COLOR = {
  'ดีมาก':   '#059669',
  'ดี':      '#3b82f6',
  'พอใช้':   '#f59e0b',
  'ปรับปรุง': '#ef4444',
}
