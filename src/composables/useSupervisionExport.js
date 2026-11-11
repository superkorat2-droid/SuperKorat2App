// ส่งออกผลแบบนิเทศเป็น Excel หลายชีต: สรุป / คำตอบ / สรุปรายข้อ / ยังไม่ส่ง (เฉพาะโหมดโรงเรียน)
// ทุกชีตคิดจาก responses ที่หน้าเว็บกรองแล้ว (ตัวกรองอำเภอ/ศูนย์)
// xlsx รุ่นฟรีใส่สี/ตัวหนาไม่ได้ — ตั้งได้แค่ความกว้างคอลัมน์ (!cols) และปุ่มกรอง (!autofilter)
import { utils, writeFile } from 'xlsx'
import { buildSections, responseScore, groupPct, isScoredQuestion, answerScore, summarizeByGroup } from './useSupervisionScore'

const TYPE_LABEL = {
  text: 'ข้อความสั้น', textarea: 'ข้อความยาว', choice: 'เลือกคำตอบเดียว', multi_choice: 'เลือกได้หลายข้อ',
  rating: 'ระดับคะแนน', yes_no: 'ใช่/ไม่ใช่', number: 'ตัวเลข',
}

function labelFor(q, v) {
  if (v === null || v === undefined) return ''
  return q.options?.find(o => o.value === v)?.label ?? String(v)
}

function answerText(q, a) {
  if (a === null || a === undefined || a === '') return ''
  if (q.type === 'rating' || q.type === 'number') return isNaN(Number(a)) ? String(a) : Number(a)
  if (Array.isArray(a)) return a.map(v => labelFor(q, v)).join(', ')
  if (q.type === 'yes_no') return a === 'yes' ? 'ใช่' : a === 'no' ? 'ไม่ใช่' : String(a)
  if (q.type === 'choice') return labelFor(q, a)
  return String(a)
}

const dateTh = d => (d ? new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' }) : '')
const pctCell = v => (v === null || v === undefined ? '' : v)

// ความกว้างคอลัมน์จากข้อความยาวสุด (จำกัด 8-60 ตัวอักษร)
function sheet(aoa, { filterRow } = {}) {
  const ws = utils.aoa_to_sheet(aoa)
  const widths = []
  for (const row of aoa) row.forEach((c, i) => {
    const len = String(c ?? '').length
    widths[i] = Math.max(widths[i] || 8, Math.min(60, len + 2))
  })
  ws['!cols'] = widths.map(wch => ({ wch }))
  if (filterRow !== undefined && aoa[filterRow]?.length) {
    ws['!autofilter'] = { ref: utils.encode_range({ s: { r: filterRow, c: 0 }, e: { r: aoa.length - 1, c: aoa[filterRow].length - 1 } }) }
  }
  return ws
}

export function exportSupervisionWorkbook({ form, questions, responses, schools, targets, pending, filterLabel, editorNames = {} }) {
  const isIndividual = form.respondent_type === 'individual'
  const schoolsById  = Object.fromEntries(schools.map(s => [s.id, s]))
  const sections     = buildSections(questions)
  const answerable   = sections.flatMap(s => s.questions)
  const scored       = answerable.some(isScoredQuestion)
  const scoredSecs   = sections.filter(s => s.questions.some(isScoredQuestion))
  const secTitle     = s => s.title || '(ไม่มีหัวข้อ)'
  const wb = utils.book_new()

  // ── 1) สรุป ────────────────────────────────────────────────────────────
  const sum = [
    ['รายงานผลแบบนิเทศ'],
    ['ชื่อแบบ', form.title],
    ['ส่งออกเมื่อ', new Date().toLocaleString('th-TH')],
    ['ตัวกรอง', filterLabel || 'ทั้งหมด'],
    ['ประเภทผู้ตอบ', isIndividual ? 'บุคคล' : 'โรงเรียน (1 ต่อโรง)'],
    [],
  ]
  if (isIndividual) {
    sum.push(['จำนวนผู้ตอบ', responses.length])
  } else {
    sum.push(['เป้าหมาย (โรง)', targets.length], ['ส่งแล้ว (โรง)', responses.length],
      ['ร้อยละที่ส่ง', targets.length ? Math.round((responses.length / targets.length) * 100) : 0],
      ['ยังไม่ส่ง (โรง)', pending.length])
  }
  if (scored) {
    sum.push(['คะแนนรวม (%)', pctCell(groupPct(answerable, responses))], [], ['คะแนนรายหมวด'], ['หมวด', 'คะแนน (%)'])
    for (const s of scoredSecs) sum.push([secTitle(s), pctCell(groupPct(s.questions, responses))])
  }
  if (!isIndividual) {
    sum.push([], ['สรุปรายศูนย์เครือข่าย'], ['ศูนย์เครือข่าย', 'เป้าหมาย', 'ส่งแล้ว', 'ร้อยละที่ส่ง', ...(scored ? ['คะแนนเฉลี่ย (%)'] : [])])
    for (const g of summarizeByGroup(targets, responses, sections, schoolsById)) {
      sum.push([g.group, g.targets, g.responded, pctCell(g.pct), ...(scored ? [pctCell(g.avgScore)] : [])])
    }
  }
  utils.book_append_sheet(wb, sheet(sum), 'สรุป')

  // ── 2) คำตอบ ───────────────────────────────────────────────────────────
  // ช่อง "โรงเรียน" ของผู้ตอบไม่แยกคอลัมน์ — ใช้คอลัมน์โรงเรียนกลาง (fallback เป็น respondent_info.school)
  const respFields = isIndividual ? (form.respondent_fields || []).filter(f => f.show && f.key !== 'school') : []
  // % รายหมวดแยกคอลัมน์เฉพาะเมื่อมีหมวดนับคะแนน ≥ 2 (หมวดเดียว = เท่าคะแนนรวม)
  const secCols = scoredSecs.length > 1 ? scoredSecs : []
  const head = ['ลำดับ']
  if (isIndividual) respFields.forEach(f => head.push(f.label))
  head.push('โรงเรียน', 'อำเภอ', 'ศูนย์เครือข่าย', 'วันที่ส่ง')
  if (scored) { head.push('คะแนนรวม (%)'); secCols.forEach(s => head.push(`${secTitle(s)} (%)`)) }

  const qTitle = q => {
    const sec = sections.find(s => s.questions.includes(q))
    return sec?.title ? `[${sec.title}] ${q.question_text}` : q.question_text
  }
  const plan = answerable.map(q => {
    const p = {
      q,
      score: q.type === 'yes_no' || (q.type === 'choice' && isScoredQuestion(q)),
      items: q.settings?.evidence_items?.length > 0 || !!q.settings?.evidence_allow_custom,
      file:  ['upload', 'both'].includes(q.evidence_type),
      link:  ['url', 'both'].includes(q.evidence_type),
    }
    const t = qTitle(q)
    head.push(t)
    if (p.score) head.push(`${t} (คะแนน)`)
    if (p.items) head.push(`${t} (เอกสารหลักฐาน)`)
    if (p.file)  head.push(`${t} (ไฟล์หลักฐาน)`)
    if (p.link)  head.push(`${t} (ลิงก์หลักฐาน)`)
    return p
  })
  head.push('แก้ไขโดยผู้ดูแล')

  const rows = responses.map((r, i) => {
    const sch = schoolsById[r.school_id]
    const row = [i + 1]
    if (isIndividual) respFields.forEach(f => row.push(r.respondent_info?.[f.key] ?? ''))
    row.push(sch?.name || r.school_name || r.respondent_info?.school || '', sch?.district || '', sch?.school_group || '', dateTh(r.submitted_at))
    if (scored) {
      const sc = responseScore(r, sections)
      row.push(pctCell(sc.pct))
      secCols.forEach(s => row.push(pctCell(sc.sections[s.id ?? '_'])))
    }
    for (const p of plan) {
      const ans = (r.supervision_answers || []).find(a => a.question_id === p.q.id)
      row.push(answerText(p.q, ans?.answer))
      if (p.score) { const s = answerScore(p.q, ans?.answer); row.push(s ? s.score : '') }
      if (p.items) row.push((ans?.evidence_items || []).join(', '))
      if (p.file)  row.push(ans?.evidence_file_url || '')
      if (p.link)  row.push(ans?.evidence_link_url || '')
    }
    row.push(r.edited_at ? `${editorNames[r.edited_by] || 'ผู้ดูแล'} (${dateTh(r.edited_at)})` : '')
    return row
  })
  utils.book_append_sheet(wb, sheet([head, ...rows], { filterRow: 0 }), 'คำตอบ')

  // ── 3) สรุปรายข้อ ───────────────────────────────────────────────────────
  const n = responses.length
  const pctOf = c => (n ? Math.round((c / n) * 1000) / 10 : 0)
  const per = [['หมวด', 'ข้อ', 'ประเภท', 'ตัวเลือก / ค่า', 'จำนวน', 'ร้อยละของผู้ตอบ']]
  for (const sec of sections) {
    for (const q of sec.questions) {
      const ans = responses.map(r => (r.supervision_answers || []).find(a => a.question_id === q.id))
      const vals = ans.map(a => a?.answer)
      const base = [secTitle(sec), q.question_text, TYPE_LABEL[q.type] || q.type]
      if (q.type === 'choice' || q.type === 'multi_choice') {
        for (const o of q.options || []) {
          const c = vals.filter(v => (Array.isArray(v) ? v.includes(o.value) : v === o.value)).length
          per.push([...base, o.label, c, pctOf(c)])
        }
        const other = vals.flatMap(v => (Array.isArray(v) ? v : [v])).filter(v => typeof v === 'string' && v.startsWith('อื่นๆ')).length
        if (other) per.push([...base, 'อื่นๆ (พิมพ์เอง)', other, pctOf(other)])
      } else if (q.type === 'yes_no') {
        for (const [v, l] of [['yes', 'ใช่'], ['no', 'ไม่ใช่']]) {
          const c = vals.filter(x => x === v).length
          per.push([...base, l, c, pctOf(c)])
        }
      } else if (q.type === 'rating') {
        const max = q.settings?.max || 5
        const nums = vals.map(Number).filter(x => x >= 1 && x <= max)
        for (let lv = 1; lv <= max; lv++) {
          const c = nums.filter(x => x === lv).length
          per.push([...base, `ระดับ ${lv}`, c, pctOf(c)])
        }
        per.push([...base, 'ค่าเฉลี่ย', nums.length ? Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 100) / 100 : '', ''])
      } else if (q.type === 'number') {
        const nums = vals.filter(v => v !== '' && v !== null && v !== undefined).map(Number).filter(x => !isNaN(x))
        per.push([...base, 'จำนวนที่ตอบ', nums.length, pctOf(nums.length)])
        if (nums.length) {
          per.push([...base, 'ค่าเฉลี่ย', Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 100) / 100, ''])
          per.push([...base, 'ต่ำสุด', Math.min(...nums), ''], [...base, 'สูงสุด', Math.max(...nums), ''])
        }
      } else {
        const c = vals.filter(v => typeof v === 'string' && v.trim()).length
        per.push([...base, 'จำนวนที่ตอบ', c, pctOf(c)])
      }
      // รายการเอกสารหลักฐาน
      if (q.settings?.evidence_items?.length || q.settings?.evidence_allow_custom) {
        const counts = {}
        ans.forEach(a => (a?.evidence_items || []).forEach(v => { counts[v] = (counts[v] || 0) + 1 }))
        const defined = q.settings?.evidence_items || []
        const keys = [...defined, ...Object.keys(counts).filter(k => !defined.includes(k))]
        keys.forEach(k => per.push([...base, `เอกสาร: ${k}${defined.includes(k) ? '' : ' (พิมพ์เอง)'}`, counts[k] || 0, pctOf(counts[k] || 0)]))
      }
    }
  }
  utils.book_append_sheet(wb, sheet(per, { filterRow: 0 }), 'สรุปรายข้อ')

  // ── 4) ยังไม่ส่ง (โหมดโรงเรียน) ────────────────────────────────────────────
  if (!isIndividual) {
    const pend = [['ลำดับ', 'โรงเรียน', 'อำเภอ', 'ศูนย์เครือข่าย'],
      ...pending.map((s, i) => [i + 1, s.name, s.district || '', s.school_group || ''])]
    utils.book_append_sheet(wb, sheet(pend, { filterRow: 0 }), 'ยังไม่ส่ง')
  }

  const safe = s => String(s || '').replace(/[\\/:*?"<>|]/g, '').slice(0, 60)
  const suffix = filterLabel ? `_${safe(filterLabel)}` : ''
  writeFile(wb, `แบบนิเทศ_${safe(form.title) || 'ผลลัพธ์'}${suffix}_${new Date().toISOString().slice(0, 10)}.xlsx`)
}
