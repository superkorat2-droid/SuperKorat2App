/**
 * useDmcParser — parse DMC Excel file → aggregate summary (no individual data stored)
 * รองรับ ประถม (ป.1-6) และมัธยม (ม.1-6)
 */
import { read, utils } from 'xlsx'

// ── Grade order ──────────────────────────────────────────────────────────────
const GRADE_ORDER = ['ป.1','ป.2','ป.3','ป.4','ป.5','ป.6','ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']

function sortedGrades(map) {
  const result = {}
  GRADE_ORDER.forEach(g => { if (map[g]) result[g] = map[g] })
  Object.keys(map).forEach(g => { if (!result[g]) result[g] = map[g] })
  return result
}

// ── BMI classification ───────────────────────────────────────────────────────
function bmiClass(w, h) {
  if (!w || !h || h === 0) return null
  const bmi = w / ((h / 100) ** 2)
  if (bmi < 18.5) return 'underweight'
  if (bmi < 25)   return 'normal'
  if (bmi < 30)   return 'overweight'
  return 'obese'
}

// ── Count helper ─────────────────────────────────────────────────────────────
function countMap(rows, getKey) {
  const map = {}
  rows.forEach(r => {
    const k = getKey(r)
    if (k) map[k] = (map[k] || 0) + 1
  })
  return map
}

// ── Main parser ──────────────────────────────────────────────────────────────
export function parseDmcFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb   = read(e.target.result, { type: 'array' })
        const ws   = wb.Sheets[wb.SheetNames[0]]
        const all  = utils.sheet_to_json(ws, { header: 1, defval: '' })

        // Find header row — look for row containing 'รหัสโรงเรียน'
        let headerIdx = -1
        for (let i = 0; i < Math.min(6, all.length); i++) {
          if (Array.isArray(all[i]) && String(all[i][0]).includes('รหัสโรงเรียน')) {
            headerIdx = i; break
          }
        }
        if (headerIdx === -1) {
          reject(new Error('ไม่พบหัวตาราง กรุณาใช้ไฟล์ DMC จากระบบ'))
          return
        }

        const headers = all[headerIdx].map(h => String(h).trim())
        const rows    = all.slice(headerIdx + 1).filter(r => r && r[0] && String(r[0]).trim())

        if (rows.length === 0) {
          reject(new Error('ไม่พบข้อมูลนักเรียนในไฟล์'))
          return
        }

        // Map column names → indices
        const C = {}
        const KNOWN = {
          'รหัสโรงเรียน': 'SCHOOL_CODE', 'ชื่อโรงเรียน': 'SCHOOL_NAME',
          'ชั้น': 'GRADE', 'ห้อง': 'ROOM', 'เพศ': 'GENDER',
          'อายุ(ปี)': 'AGE', 'น้ำหนัก': 'WEIGHT', 'ส่วนสูง': 'HEIGHT',
          'กลุ่มเลือด': 'BLOOD', 'ศาสนา': 'RELIGION',
          'เชื้อชาติ': 'RACE', 'สัญชาติ': 'NATIONALITY',
          'ความเกี่ยวข้องของผู้ปกครองกับนักเรียน': 'GUARDIAN_REL',
          'อาชีพของผู้ปกครอง': 'PARENT_JOB',
          'ความด้อยโอกาส': 'DISADVANTAGE',
        }
        headers.forEach((h, i) => { if (KNOWN[h]) C[KNOWN[h]] = i })

        resolve(computeSummary(rows, C))
      } catch (err) {
        reject(new Error('อ่านไฟล์ไม่ได้: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('อ่านไฟล์ไม่ได้'))
    reader.readAsArrayBuffer(file)
  })
}

function computeSummary(rows, C) {
  const total = rows.length

  // ── School info ──────────────────────────────────────────────
  const schoolCode = String(rows[0]?.[C.SCHOOL_CODE] ?? '').trim()
  const schoolName = String(rows[0]?.[C.SCHOOL_NAME] ?? '').trim()

  // ── Gender ───────────────────────────────────────────────────
  const gender = { male: 0, female: 0 }
  rows.forEach(r => {
    const g = String(r[C.GENDER] ?? '').trim()
    if (g === 'ช') gender.male++
    else if (g === 'ญ') gender.female++
  })

  // ── By grade ─────────────────────────────────────────────────
  const gradeRaw = {}
  rows.forEach(r => {
    const grade = String(r[C.GRADE] ?? '').trim()
    if (!grade) return
    if (!gradeRaw[grade]) gradeRaw[grade] = { total: 0, male: 0, female: 0 }
    gradeRaw[grade].total++
    const g = String(r[C.GENDER] ?? '').trim()
    if (g === 'ช') gradeRaw[grade].male++
    else if (g === 'ญ') gradeRaw[grade].female++
  })
  const by_grade = sortedGrades(gradeRaw)

  // ── Detect level ─────────────────────────────────────────────
  const grades   = Object.keys(by_grade)
  const hasP     = grades.some(g => g.startsWith('ป.'))
  const hasM     = grades.some(g => g.startsWith('ม.'))
  const level    = hasP && hasM ? 'mixed' : hasP ? 'primary' : 'secondary'

  // ── BMI ──────────────────────────────────────────────────────
  const bmiCounts = { underweight: 0, normal: 0, overweight: 0, obese: 0 }
  let wSum = 0, hSum = 0, bmiSum = 0, bmiN = 0
  rows.forEach(r => {
    const w = parseFloat(r[C.WEIGHT])
    const h = parseFloat(r[C.HEIGHT])
    if (isNaN(w) || isNaN(h) || h === 0) return
    const cls = bmiClass(w, h)
    if (cls) {
      bmiCounts[cls]++
      wSum += w; hSum += h
      bmiSum += w / ((h / 100) ** 2)
      bmiN++
    }
  })

  // ── Disadvantaged ────────────────────────────────────────────
  const disadvDetail = countMap(rows, r => {
    const v = String(r[C.DISADVANTAGE] ?? '').trim()
    return v && v !== '-' ? v : null
  })
  const disadvCount = Object.values(disadvDetail).reduce((a, b) => a + b, 0)

  // ── Other demographics ───────────────────────────────────────
  const guardian_relation = countMap(rows, r => String(r[C.GUARDIAN_REL] ?? '').trim() || null)
  const parent_jobs       = countMap(rows, r => {
    const v = String(r[C.PARENT_JOB] ?? '').trim()
    return v && v !== 'ไม่ระบุ' ? v : null
  })
  const religion    = countMap(rows, r => String(r[C.RELIGION]    ?? '').trim() || null)
  const nationality = countMap(rows, r => String(r[C.NATIONALITY] ?? '').trim() || null)
  const race        = countMap(rows, r => String(r[C.RACE]        ?? '').trim() || null)
  const blood_type  = countMap(rows, r => {
    const v = String(r[C.BLOOD] ?? '').trim()
    return v && v !== '-' ? v : null
  })

  // ── Age ──────────────────────────────────────────────────────
  const ages = rows.map(r => parseInt(r[C.AGE])).filter(a => !isNaN(a) && a > 0)
  const age_avg = ages.length ? (ages.reduce((a, b) => a + b, 0) / ages.length).toFixed(1) : null

  return {
    school_code: schoolCode,
    school_name: schoolName,
    level,
    total,
    gender,
    by_grade,
    bmi: {
      underweight: bmiCounts.underweight,
      normal:      bmiCounts.normal,
      overweight:  bmiCounts.overweight,
      obese:       bmiCounts.obese,
      avg_weight:  bmiN ? (wSum / bmiN).toFixed(1) : null,
      avg_height:  bmiN ? (hSum / bmiN).toFixed(1) : null,
      avg_bmi:     bmiN ? (bmiSum / bmiN).toFixed(1) : null,
    },
    disadvantaged: {
      detail: disadvDetail,
      count:  disadvCount,
      pct:    total > 0 ? ((disadvCount / total) * 100).toFixed(1) : '0',
    },
    guardian_relation,
    parent_jobs,
    religion,
    nationality,
    race,
    blood_type,
    age_avg,
  }
}
