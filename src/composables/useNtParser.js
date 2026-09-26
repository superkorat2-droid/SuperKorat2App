/**
 * useNtParser — parse the official NT "Local 03" score report (.xlsx) from สทศ./สพฐ.
 * 1 แถว/โรงเรียน: รหัสโรงเรียน(10หลัก)/ชื่อ/อำเภอ/ขนาดโรงเรียน + คะแนน+ร้อยละของแต่ละด้าน
 * + ระดับคุณภาพ (ดีมาก/ดี/พอใช้/ปรับปรุง) — เป็นไฟล์ .xlsx ปกติ (UTF-8 ภายใน) ไม่ใช่ cp874
 * เหมือนไฟล์ DMC ระดับเขต จึงอ่านด้วย SheetJS ตรงๆ ได้เลย
 */
import { read, utils } from 'xlsx'

// ตำแหน่งคอลัมน์ (0-indexed) ของฟอร์แมต Local03 ที่ สพฐ. ใช้คงที่ทุกปี:
// ลำดับ, รหัสโรงเรียน, ชื่อโรงเรียน, อำเภอ/เขต, ขนาดโรงเรียน,
// [คณิต คะแนน][คณิต ร้อยละ][ไทย คะแนน][ไทย ร้อยละ][รวม คะแนน][รวม ร้อยละ],
// [ระดับ คณิต][ระดับ ไทย][ระดับ รวม]
const COL = {
  NO: 1, CODE: 2, NAME: 3, DISTRICT: 4, SIZE: 5,
  MATH_SCORE: 6, MATH_PCT: 7, THAI_SCORE: 8, THAI_PCT: 9, OVERALL_SCORE: 10, OVERALL_PCT: 11,
  MATH_LEVEL: 12, THAI_LEVEL: 13, OVERALL_LEVEL: 14,
}

export const NT_SUBJECTS = [
  { key: 'math', label: 'ด้านคณิตศาสตร์' },
  { key: 'thai', label: 'ด้านภาษาไทย' },
]

function toNum(v) {
  const n = parseFloat(String(v ?? '').trim())
  return isNaN(n) ? null : n
}

function findHeaderRow(rows) {
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i]
    if (String(r[1] ?? '').trim() === 'ลำดับ' && String(r[2] ?? '').trim() === 'รหัสโรงเรียน') {
      return i
    }
  }
  return -1
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

export function parseNtLocal03File(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb = read(e.target.result, { type: 'array' })
        const ws = wb.Sheets[wb.SheetNames[0]]
        const rows = utils.sheet_to_json(ws, { header: 1, defval: '' })

        const headerRowIdx = findHeaderRow(rows)
        if (headerRowIdx === -1) {
          reject(new Error('ไม่พบหัวตาราง — ตรวจสอบว่าเป็นไฟล์รายงาน Local03 ของ NT ที่ถูกต้อง'))
          return
        }

        const meta = parseMeta(rows)
        const dataRows = rows.slice(headerRowIdx + 3) // หัวตาราง 3 ชั้น (ชื่อกลุ่ม/ชื่อวิชา/คะแนน-ร้อยละ)

        const schoolRows = []
        let skippedRows = 0

        for (const r of dataRows) {
          const code = String(r[COL.CODE] ?? '').trim()
          if (!code) break // หมดข้อมูลโรงเรียน (แถวถัดไปเป็นหมายเหตุ/ว่าง)
          if (!/^\d+$/.test(code)) { skippedRows++; continue }

          const mathScore = toNum(r[COL.MATH_SCORE])
          const thaiScore = toNum(r[COL.THAI_SCORE])
          const overallScore = toNum(r[COL.OVERALL_SCORE])
          if (mathScore === null && thaiScore === null) { skippedRows++; continue }

          schoolRows.push({
            school_code: code,
            school_name: String(r[COL.NAME] ?? '').trim(),
            district: String(r[COL.DISTRICT] ?? '').trim(),
            school_size: String(r[COL.SIZE] ?? '').trim(),
            scores: {
              math:    { score: mathScore,    pct: toNum(r[COL.MATH_PCT]),    level: String(r[COL.MATH_LEVEL] ?? '').trim() },
              thai:    { score: thaiScore,    pct: toNum(r[COL.THAI_PCT]),    level: String(r[COL.THAI_LEVEL] ?? '').trim() },
              overall: { score: overallScore, pct: toNum(r[COL.OVERALL_PCT]), level: String(r[COL.OVERALL_LEVEL] ?? '').trim() },
            },
          })
        }

        if (schoolRows.length === 0) {
          reject(new Error('ไม่พบข้อมูลโรงเรียนในไฟล์ — ตรวจสอบว่าเป็นไฟล์รายงาน Local03 ของ NT ที่ถูกต้อง'))
          return
        }

        resolve({ meta, subjects: NT_SUBJECTS, rows: schoolRows, skippedRows })
      } catch (err) {
        reject(new Error('อ่านไฟล์ไม่ได้: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('อ่านไฟล์ไม่ได้'))
    reader.readAsArrayBuffer(file)
  })
}

export const QUALITY_LEVELS = ['ดีมาก', 'ดี', 'พอใช้', 'ปรับปรุง']
export const QUALITY_COLOR = {
  'ดีมาก':   '#059669',
  'ดี':      '#3b82f6',
  'พอใช้':   '#f59e0b',
  'ปรับปรุง': '#ef4444',
}
