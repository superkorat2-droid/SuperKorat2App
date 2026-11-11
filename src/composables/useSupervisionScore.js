// คะแนนแบบนิเทศ — ฟังก์ชันล้วน ใช้ร่วมระหว่างหน้าผลลัพธ์และไฟล์ Excel
// ข้อที่นับคะแนน: rating (ค่า / ระดับสูงสุด), yes_no (ใช่ = 100, ไม่ใช่ = 0), choice ที่ตั้งคะแนนตัวเลือกไว้
// คำตอบว่าง (ผู้ตอบข้าม) ไม่นับ — ไม่งั้น rating ที่ว่างจะกลายเป็น 0 คะแนนแล้วดึงค่าเฉลี่ยลง

export function isEmptyAnswer(v) {
  return v === null || v === undefined || v === '' || (Array.isArray(v) && !v.length)
}

export function hasChoiceScores(q) {
  return q.type === 'choice' && q.options?.some(o => o.score !== '' && o.score !== null && o.score !== undefined)
}

export function isScoredQuestion(q) {
  return q.type === 'rating' || q.type === 'yes_no' || hasChoiceScores(q)
}

// { score, max } ของคำตอบเดียว หรือ null ถ้าข้อนี้ไม่นับคะแนน/ไม่ได้ตอบ
export function answerScore(q, answer) {
  if (isEmptyAnswer(answer)) return null
  if (q.type === 'rating') {
    const n = Number(answer)
    return isNaN(n) ? null : { score: n, max: q.settings?.max || 5 }
  }
  if (q.type === 'yes_no') {
    if (answer === 'yes') return { score: 100, max: 100 }
    if (answer === 'no')  return { score: 0,   max: 100 }
    return null
  }
  if (hasChoiceScores(q)) {
    const maxOpt = Math.max(...q.options.map(o => Number(o.score || 0)))
    if (maxOpt <= 0) return null
    const opt = q.options.find(o => o.value === answer)
    return opt ? { score: Number(opt.score || 0), max: maxOpt } : null
  }
  return null
}

// แบ่งคำถามตามหัวข้อส่วน (หมวด) — ข้อก่อนหัวข้อแรกอยู่หมวด id = null
export function buildSections(questions) {
  const sorted = [...questions].sort((a, b) => a.sort_order - b.sort_order)
  const result = []
  let current = { id: null, title: null, description: null, questions: [] }
  for (const q of sorted) {
    if (q.type === 'section') {
      if (current.questions.length > 0) result.push({ ...current })
      current = { id: q.id, title: q.question_text, description: q.description, questions: [] }
    } else {
      current.questions.push(q)
    }
  }
  if (current.questions.length > 0) result.push({ ...current })
  return result
}

function toPct(score, max) {
  return max > 0 ? Math.round((score / max) * 100) : null
}

// คะแนนของชุดคำตอบหนึ่งชุด: { pct, sections: { [sectionKey]: pct } }  (pct = null ถ้าไม่มีข้อนับคะแนนที่ตอบ)
// sectionKey = section.id หรือ '_' สำหรับหมวดที่ไม่มีหัวข้อ
export function responseScore(response, sections) {
  const answers = response.supervision_answers || []
  let total = 0, totalMax = 0
  const out = {}
  for (const sec of sections) {
    let s = 0, m = 0
    for (const q of sec.questions) {
      const r = answerScore(q, answers.find(a => a.question_id === q.id)?.answer)
      if (r) { s += r.score; m += r.max }
    }
    out[sec.id ?? '_'] = toPct(s, m)
    total += s; totalMax += m
  }
  return { pct: toPct(total, totalMax), sections: out }
}

// คะแนนเฉลี่ยของทั้งกลุ่มสำหรับคำถามข้อหนึ่ง (ใช้กับคะแนนรวม/รายหมวดของเขต)
export function questionAverage(q, responses) {
  let s = 0, m = 0, n = 0
  for (const r of responses) {
    const res = answerScore(q, (r.supervision_answers || []).find(a => a.question_id === q.id)?.answer)
    if (res) { s += res.score; m = res.max; n++ }
  }
  return n ? { score: s / n, max: m } : null
}

// รวมหลายข้อ → ร้อยละ (ผลรวมค่าเฉลี่ย / ผลรวมคะแนนเต็ม — สูตรเดิมของหน้าผลลัพธ์)
export function groupPct(questions, responses) {
  let s = 0, m = 0
  for (const q of questions) {
    const avg = questionAverage(q, responses)
    if (avg) { s += avg.score; m += avg.max }
  }
  return toPct(s, m)
}

// สรุปรายศูนย์เครือข่าย: [{ group, targets, responded, pct, avgScore }]
// avgScore = ค่าเฉลี่ยคะแนน (responseScore) ของโรงเรียนที่ส่งในศูนย์นั้น
export function summarizeByGroup(targets, responses, sections, schoolsById) {
  const map = new Map()
  const row = g => {
    if (!map.has(g)) map.set(g, { group: g, targets: 0, responded: 0, scores: [] })
    return map.get(g)
  }
  for (const s of targets) row(s.school_group || '(ไม่ระบุศูนย์)').targets++
  for (const r of responses) {
    const g = schoolsById[r.school_id]?.school_group || '(ไม่ระบุศูนย์)'
    const x = row(g)
    x.responded++
    const sc = responseScore(r, sections).pct
    if (sc !== null) x.scores.push(sc)
  }
  return [...map.values()]
    .map(x => ({
      group: x.group, targets: x.targets, responded: x.responded,
      pct: x.targets ? Math.round((x.responded / x.targets) * 100) : null,
      avgScore: x.scores.length ? Math.round(x.scores.reduce((a, b) => a + b, 0) / x.scores.length) : null,
    }))
    .sort((a, b) => a.group.localeCompare(b.group, 'th'))
}

export function scoreColor(pct) {
  if (pct === null || pct === undefined) return 'slate'
  return pct >= 80 ? 'emerald' : pct >= 60 ? 'amber' : 'red'
}
