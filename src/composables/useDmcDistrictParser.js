/**
 * useDmcDistrictParser — parse the district-wide DMC summary export (CSV)
 * ไฟล์นี้มาจาก สพป./เขต โดยตรง: 1 แถว/โรงเรียน สรุปจำนวนนักเรียนแยกตามระดับชั้น
 * (อ.1-3, ป.1-6, ม.1-6, ปวช.1-3) พร้อมเพศและจำนวนห้อง — ไม่มีข้อมูลรายบุคคล
 * (ไม่มี BMI/ความด้อยโอกาส/ครอบครัว ต่างจากไฟล์รายบุคคลที่ useDmcParser.js อ่าน)
 *
 * เข้ารหัสแบบ Windows-874 (cp874) — ต้องถอดรหัสด้วย TextDecoder ไม่ใช่ UTF-8 ปกติ
 */
import { classifyLevel } from './useDmcParser'

// ตำแหน่งคอลัมน์ (0-indexed) ตามไฟล์จริงจาก DMC ระดับเขต — ตรวจสอบด้วยการไล่บวกเลขใน
// แถวตัวอย่างแล้วตรงกันทุกแถว (เช่น รวมก่อนประถม = ผลรวม อ.1+อ.2+อ.3)
const COL = {
  DISTRICT_CODE: 0,
  DISTRICT_NAME: 1,
  SCHOOL_CODE:   2,
  SCHOOL_NAME:   3,
}

// { grade } = กลุ่มระดับชั้นที่เก็บเข้า by_grade, { subtotal: true } = ผลรวมย่อยที่ไฟล์แถมมา (ข้าม)
const GROUPS = [
  { grade: 'อ.1',    start: 4  },
  { grade: 'อ.2',    start: 8  },
  { grade: 'อ.3',    start: 12 },
  { subtotal: true,  start: 16 }, // รวมก่อนประถม
  { grade: 'ป.1',    start: 20 },
  { grade: 'ป.2',    start: 24 },
  { grade: 'ป.3',    start: 28 },
  { grade: 'ป.4',    start: 32 },
  { grade: 'ป.5',    start: 36 },
  { grade: 'ป.6',    start: 40 },
  { subtotal: true,  start: 44 }, // รวมประถม
  { grade: 'ม.1',    start: 48 },
  { grade: 'ม.2',    start: 52 },
  { grade: 'ม.3',    start: 56 },
  { subtotal: true,  start: 60 }, // รวมม.ต้น
  { grade: 'ม.4',    start: 64 },
  { grade: 'ม.5',    start: 68 },
  { grade: 'ม.6',    start: 72 },
  { grade: 'ปวช.1',  start: 76 },
  { grade: 'ปวช.2',  start: 80 },
  { grade: 'ปวช.3',  start: 84 },
  { subtotal: true,  start: 88 }, // รวมปวช.
]
const GRAND_TOTAL_START = 92 // ชาย, หญิง, รวม, ห้อง — คอลัมน์สุดท้ายของแถว
const EXPECTED_COLS = 96

function toInt(v) {
  const n = parseInt(String(v ?? '').trim(), 10)
  return isNaN(n) ? 0 : n
}

function splitCsvLine(line) {
  // ไฟล์นี้เป็น fixed-format ไม่มี quote/comma ปะปนในข้อมูล — split ตรงๆ พอ
  return line.split(',')
}

export function parseDmcDistrictFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const bytes = new Uint8Array(e.target.result)
        const text  = new TextDecoder('windows-874').decode(bytes)
        const lines = text.split(/\r\n|\r|\n/).filter(l => l.trim().length > 0)

        if (lines.length < 2) {
          reject(new Error('ไฟล์ไม่มีข้อมูล'))
          return
        }

        const dataLines = lines.slice(1) // แถวแรกเป็นหัวตาราง
        const schools = []
        let skippedRows = 0

        dataLines.forEach((line) => {
          const cols = splitCsvLine(line)
          const schoolCode = String(cols[COL.SCHOOL_CODE] ?? '').trim()
          // แถวผลรวมทั้งเขตท้ายไฟล์ไม่มีรหัสโรงเรียน — ข้าม
          if (!schoolCode) { skippedRows++; return }
          if (cols.length < EXPECTED_COLS) { skippedRows++; return }

          const schoolName = String(cols[COL.SCHOOL_NAME] ?? '').trim()

          const by_grade = {}
          GROUPS.forEach((g) => {
            if (g.subtotal) return
            const male   = toInt(cols[g.start])
            const female = toInt(cols[g.start + 1])
            const total  = toInt(cols[g.start + 2])
            const rooms  = toInt(cols[g.start + 3])
            if (total > 0 || male > 0 || female > 0) {
              by_grade[g.grade] = { total, male, female, rooms }
            }
          })

          const grandMale   = toInt(cols[GRAND_TOTAL_START])
          const grandFemale = toInt(cols[GRAND_TOTAL_START + 1])
          const grandTotal  = toInt(cols[GRAND_TOTAL_START + 2])
          const grandRooms  = toInt(cols[GRAND_TOTAL_START + 3])

          schools.push({
            dmc_code: schoolCode,
            file_school_name: schoolName,
            summary: {
              source: 'district_bulk',
              school_code: schoolCode,
              school_name: schoolName,
              level: classifyLevel(Object.keys(by_grade)),
              total: grandTotal,
              gender: { male: grandMale, female: grandFemale },
              rooms: grandRooms,
              by_grade,
            },
          })
        })

        if (schools.length === 0) {
          reject(new Error('ไม่พบข้อมูลโรงเรียนในไฟล์ — ตรวจสอบว่าเป็นไฟล์ DMC ระดับเขตที่ถูกต้อง'))
          return
        }

        resolve({ schools, skippedRows })
      } catch (err) {
        reject(new Error('อ่านไฟล์ไม่ได้: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('อ่านไฟล์ไม่ได้'))
    reader.readAsArrayBuffer(file)
  })
}
