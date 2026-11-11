<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { buildSections, groupPct, responseScore, isScoredQuestion, summarizeByGroup, scoreColor } from '../../composables/useSupervisionScore'
import { exportSupervisionWorkbook } from '../../composables/useSupervisionExport'
import SupervisionAnswerEditModal from '../../components/supervision/SupervisionAnswerEditModal.vue'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()
const formId = computed(() => route.params.id)

// ─── State ────────────────────────────────────────────────────────────────────
const loading   = ref(true)
const form      = ref(null)
const questions = ref([])
const allResponses = ref([])   // ชุดคำตอบที่ส่งครบทั้งหมด (ไม่กรอง)
const allSchools = ref([])
const schoolsById = computed(() => Object.fromEntries(allSchools.value.map(s => [s.id, s])))

// ─── ตัวกรอง อำเภอ / ศูนย์เครือข่าย ──────────────────────────────────────────
// responses = ชุดที่กรองแล้ว → การ์ด กราฟ ตาราง และ Excel คิดตามตัวกรองทั้งหมด
// แบบบุคคล: กรองด้วยโรงเรียนที่ผู้ตอบเลือก (ผู้ตอบที่ไม่เลือกโรงเรียนจะถูกซ่อนเมื่อเปิดตัวกรอง)
const filterDistrict = ref('')
const filterGroup    = ref('')
const isFiltered = computed(() => !!(filterDistrict.value || filterGroup.value))
function matchSchool(s) {
  if (!s) return !isFiltered.value
  return (!filterDistrict.value || s.district === filterDistrict.value)
      && (!filterGroup.value || s.school_group === filterGroup.value)
}
const responses = computed(() => allResponses.value.filter(r => matchSchool(schoolsById.value[r.school_id])))
const hiddenByFilter = computed(() => allResponses.value.length - responses.value.length)
const filterLabel = computed(() => [filterDistrict.value && `อ.${filterDistrict.value}`, filterGroup.value].filter(Boolean).join(' · '))
function clearFilters() { filterDistrict.value = ''; filterGroup.value = '' }
let realtimeChannel = null

// ─── แก้คำตอบ (เฉพาะแอดมิน / ผู้สร้างแบบ / ผู้รับผิดชอบรายบุคคล — RLS ตรวจซ้ำอีกชั้น) ─────
const canEditAnswers = ref(false)
const editingResponse = ref(null)
const editorNames = ref({})   // profile id → ชื่อ สำหรับป้าย "แก้ไขโดย"
function respondentLabel(r) {
  if (form.value?.respondent_type === 'individual') return r.respondent_info?.name || 'ไม่ระบุตัวตน'
  return allSchools.value.find(s => s.id === r.school_id)?.name || r.school_name || '—'
}
async function onAnswersSaved() {
  editingResponse.value = null
  await load()
}

// ─── ปลดล็อกให้ส่งใหม่ (โหมดโรงเรียน) ─────────────────────────────────────────
// ทุกจุดนับ "ส่งแล้ว" จาก is_complete = true (RPC กันส่งซ้ำ, หน้าสถานะ, หน้าหลักโรงเรียน, หน้านี้)
// ปลดล็อก = ตั้ง false → โรงเรียนกลับเป็น "ยังไม่ส่ง" และส่งใหม่ได้ · ไม่ลบคำตอบ คืนสถานะได้
// RPC insert ด้วย is_complete = true เสมอ → แถว false มีแค่ตัวที่ถูกปลดล็อก
const unlockedResponses = ref([])
async function setComplete(r, value) {
  const { data: { user } } = await supabase.auth.getUser()
  const { error } = await supabase.from('supervision_responses')
    .update({ is_complete: value, edited_by: user?.id, edited_at: new Date().toISOString() })
    .eq('id', r.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message }); return false }
  return true
}
async function unlockResponse(r) {
  const ok = await Swal.fire({
    icon: 'question',
    title: `ปลดล็อกให้ ${respondentLabel(r)} ส่งใหม่?`,
    html: 'โรงเรียนจะกลับเป็น <b>ยังไม่ส่ง</b> และกรอกแบบนี้ใหม่ได้<br>คำตอบเดิมไม่ถูกลบ เก็บไว้ในกล่อง "ปลดล็อกแล้ว" และคืนสถานะได้',
    showCancelButton: true, confirmButtonText: 'ปลดล็อก', cancelButtonText: 'ยกเลิก',
  })
  if (!ok.isConfirmed) return
  if (await setComplete(r, false)) {
    Swal.fire({ icon: 'success', title: 'ปลดล็อกแล้ว', showConfirmButton: false, timer: 1200 })
    await load()
  }
}
// โรงเรียนส่งใหม่แล้ว → ห้ามคืนสถานะแถวเก่า ไม่งั้นนับซ้ำ
function hasResubmitted(r) {
  return !!r.school_id && allResponses.value.some(x => x.school_id === r.school_id)
}
async function restoreResponse(r) {
  if (hasResubmitted(r)) return
  if (await setComplete(r, true)) await load()
}

// ─── Load data ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true

  const [
    { data: formData },
    { data: qs },
    { data: rsp },
    { data: sc },
  ] = await Promise.all([
    supabase.from('supervision_forms').select('*').eq('id', formId.value).single(),
    supabase.from('supervision_questions').select('*').eq('form_id', formId.value).order('sort_order'),
    supabase.from('supervision_responses')
      .select('*, supervision_answers(*)')
      .eq('form_id', formId.value)
      .eq('is_complete', true),
    supabase.from('schools').select('id, name, district, school_group, is_active').order('district').order('name'),
  ])

  const { data: unl } = await supabase.from('supervision_responses')
    .select('*, supervision_answers(*)')
    .eq('form_id', formId.value)
    .eq('is_complete', false)
    .order('edited_at', { ascending: false })
  unlockedResponses.value = unl || []

  form.value      = formData
  questions.value = qs || []
  allResponses.value = rsp || []
  allSchools.value = sc || []

  const editorIds = [...new Set([...allResponses.value, ...unlockedResponses.value].map(r => r.edited_by).filter(Boolean))]
  if (editorIds.length) {
    const { data: eds } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name').in('id', editorIds)
    editorNames.value = Object.fromEntries((eds || []).map(p => [p.id,
      (p.first_name || p.last_name) ? `${p.title || ''}${p.first_name || ''} ${p.last_name || ''}`.trim() : (p.full_name || '')]))
  }

  loading.value = false
}

// ─── Realtime ─────────────────────────────────────────────────────────────────
function subscribeRealtime() {
  realtimeChannel = supabase
    .channel(`supervision_results_${formId.value}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'supervision_responses',
      filter: `form_id=eq.${formId.value}`,
    }, () => load())
    .subscribe()
}

onMounted(async () => {
  await load()
  subscribeRealtime()
  const { data } = await supabase.rpc('can_manage_supervision_form', { p_form_id: formId.value })
  canEditAnswers.value = data === true
})

onUnmounted(() => {
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
})

// ─── Stats ────────────────────────────────────────────────────────────────────
// โรงที่ปิด/ยุบแล้วไม่นับเป็นเป้าหมาย ยกเว้นตอบไว้ก่อนปิด (ไม่ให้ร้อยละเกิน 100)
// ตัวเลือกในตัวกรองมาจากโรงเรียนเป้าหมายทั้งหมด (ไม่กรอง)
const allTargetSchools = computed(() => {
  if (!form.value) return []
  const list = form.value.target === 'all'
    ? allSchools.value
    : allSchools.value.filter(s => form.value.target_schools?.includes(s.id))
  const everResponded = new Set(allResponses.value.map(r => r.school_id))
  return list.filter(s => s.is_active !== false || everResponded.has(s.id))
})
const targetSchools = computed(() => allTargetSchools.value.filter(matchSchool))
const districtOptions = computed(() => [...new Set(allTargetSchools.value.map(s => s.district).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
const groupOptions = computed(() => [...new Set(allTargetSchools.value
  .filter(s => !filterDistrict.value || s.district === filterDistrict.value)
  .map(s => s.school_group).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))

const totalSchools = computed(() => targetSchools.value.length)

const responseCount = computed(() => responses.value.length)
const pct           = computed(() =>
  totalSchools.value > 0 ? Math.round((responseCount.value / totalSchools.value) * 100) : 0
)

const respondedIds = computed(() => new Set(responses.value.map(r => r.school_id)))

const pendingSchools = computed(() => targetSchools.value.filter(s => !respondedIds.value.has(s.id)))

// ─── Per-question aggregation ─────────────────────────────────────────────────
function getAnswerObjects(q) {
  return responses.value
    .flatMap(r => r.supervision_answers || [])
    .filter(a => a.question_id === q.id)
}

function getAnswers(q) {
  return getAnswerObjects(q).map(a => a.answer)
}

function fileLinkCount(q) {
  return getAnswerObjects(q).filter(a => a.evidence_file_url || a.evidence_link_url).length
}

// นับคนที่มีหลักฐานอย่างใดอย่างหนึ่ง (ไฟล์ / ลิงก์ / ติ๊กรายการเอกสาร)
function evidenceCount(q) {
  return getAnswerObjects(q).filter(a => a.evidence_file_url || a.evidence_link_url || a.evidence_items?.length).length
}

// ─── รายการเอกสารหลักฐาน (q.settings.evidence_items + ที่ผู้ตอบพิมพ์เอง) ──────────
function hasEvidenceItems(q) {
  return q.settings?.evidence_items?.length > 0 || !!q.settings?.evidence_allow_custom
}
function hasAnyEvidence(q) {
  return (q.evidence_type && q.evidence_type !== 'none') || hasEvidenceItems(q)
}
// [{ label, count, custom }] — รายการของผู้สร้างเรียงตามที่ตั้งไว้ (แสดงแม้ได้ 0) แล้วตามด้วยที่ผู้ตอบพิมพ์เอง
function evidenceItemTally(q) {
  const defined = q.settings?.evidence_items || []
  const counts = {}
  for (const a of getAnswerObjects(q)) {
    for (const v of (a.evidence_items || [])) counts[v] = (counts[v] || 0) + 1
  }
  const customs = Object.keys(counts).filter(k => !defined.includes(k)).sort((a, b) => counts[b] - counts[a])
  return [
    ...defined.map(label => ({ label, count: counts[label] || 0, custom: false })),
    ...customs.map(label => ({ label, count: counts[label], custom: true })),
  ]
}

// ─── Sections + คะแนน (สูตรอยู่ใน useSupervisionScore.js ใช้ร่วมกับ Excel) ──────────
const sectionsData = computed(() => buildSections(questions.value))
const hasScored = computed(() => questions.value.some(isScoredQuestion))

function getSectionScore(sec) {
  if (!sec.questions.some(isScoredQuestion)) return null
  const pct = groupPct(sec.questions, responses.value)
  return pct === null ? null : { pct, color: scoreColor(pct) }
}

const overallScore = computed(() => {
  if (responseCount.value === 0) return null
  const pct = groupPct(questions.value.filter(q => q.type !== 'section'), responses.value)
  return pct === null ? null : { pct, color: scoreColor(pct) }
})

// กราฟเปรียบเทียบรายหมวด (แสดงเมื่อมีหมวดนับคะแนน ≥ 2)
const sectionChart = computed(() => {
  const rows = sectionsData.value
    .map(sec => ({ title: sec.title || '(ไม่มีหัวข้อ)', s: getSectionScore(sec) }))
    .filter(x => x.s)
  if (rows.length < 2) return null
  const hex = { emerald: '#10B981', amber: '#F59E0B', red: '#EF4444' }
  return {
    series: [{ name: 'คะแนน (%)', data: rows.map(x => x.s.pct) }],
    options: {
      chart: { type: 'bar', toolbar: { show: false }, fontFamily: 'Sarabun, sans-serif' },
      plotOptions: { bar: { horizontal: true, borderRadius: 6, distributed: true, barHeight: '60%' } },
      colors: rows.map(x => hex[x.s.color]),
      xaxis: { categories: rows.map(x => x.title), max: 100, labels: { formatter: v => `${v}%` } },
      dataLabels: { enabled: true, formatter: v => `${v}%` },
      legend: { show: false },
      tooltip: { y: { formatter: v => `${v}%` } },
    },
    height: 70 + rows.length * 44,
  }
})

// ─── สรุปรายศูนย์เครือข่าย (โหมดโรงเรียน) ─────────────────────────────────────
const groupSort = ref('name')   // 'name' | 'pct'
const groupSummary = computed(() => {
  const rows = summarizeByGroup(targetSchools.value, responses.value, sectionsData.value, schoolsById.value)
  return groupSort.value === 'pct' ? [...rows].sort((a, b) => (a.pct ?? 0) - (b.pct ?? 0)) : rows
})

// ─── คะแนนรายโรงเรียน/รายผู้ตอบ ──────────────────────────────────────────────
const scoredSections = computed(() => sectionsData.value.filter(sec => sec.questions.some(isScoredQuestion)))
const scoreSort = ref({ key: 'pct', dir: -1 })   // key: 'pct' | 'name' | sectionKey
function sortScoresBy(key) {
  scoreSort.value = scoreSort.value.key === key ? { key, dir: -scoreSort.value.dir } : { key, dir: key === 'name' ? 1 : -1 }
}
const schoolScores = computed(() => {
  const rows = responses.value.map(r => ({
    r, name: respondentLabel(r),
    group: schoolsById.value[r.school_id]?.school_group || '',
    ...responseScore(r, sectionsData.value),
  }))
  const { key, dir } = scoreSort.value
  const val = x => key === 'name' ? x.name : key === 'pct' ? x.pct : x.sections[key]
  return rows.sort((a, b) => {
    const va = val(a), vb = val(b)
    if (va === null || va === undefined) return 1
    if (vb === null || vb === undefined) return -1
    return key === 'name' ? dir * va.localeCompare(vb, 'th') : dir * (va - vb)
  })
})

// ─── ข้อมูลผู้ตอบ (โหมดบุคคล) ───────────────────────────────────────────────
const isIndividual = computed(() => form.value?.respondent_type === 'individual')
const todayCount = computed(() => {
  const d = new Date().toDateString()
  return responses.value.filter(r => new Date(r.submitted_at).toDateString() === d).length
})
function tallyInfo(key, limit = 10) {
  const c = {}
  responses.value.forEach(r => { const v = r.respondent_info?.[key]; if (v) c[v] = (c[v] || 0) + 1 })
  return Object.entries(c).sort((a, b) => b[1] - a[1]).slice(0, limit)
}
const respondentCharts = computed(() => {
  if (!isIndividual.value) return []
  const shown = new Set((form.value?.respondent_fields || []).filter(f => f.show).map(f => f.key))
  const defs = [
    { key: 'gender',    label: 'เพศ',             kind: 'donut' },
    { key: 'age_range', label: 'ช่วงอายุ',         kind: 'donut' },
    { key: 'position',  label: 'ตำแหน่ง/วิทยฐานะ', kind: 'bar' },
    { key: 'school',    label: 'โรงเรียน',          kind: 'bar' },
  ]
  return defs.filter(d => shown.has(d.key)).map(d => {
    const t = tallyInfo(d.key)
    return { ...d, labels: t.map(x => x[0]), counts: t.map(x => x[1]) }
  }).filter(d => d.counts.length)
})

const hasSections = computed(() => questions.value.some(q => q.type === 'section'))

function aggChoice(q) {
  const opts = q.options || []
  const counts = {}
  opts.forEach(o => (counts[o.value] = 0))
  getAnswers(q).forEach(a => {
    if (typeof a === 'string' && counts[a] !== undefined) counts[a]++
  })
  return {
    labels: opts.map(o => o.label),
    series: opts.map(o => counts[o.value]),
  }
}

function aggMultiChoice(q) {
  const opts = q.options || []
  const counts = {}
  opts.forEach(o => (counts[o.value] = 0))
  getAnswers(q).forEach(a => {
    if (Array.isArray(a)) a.forEach(v => { if (counts[v] !== undefined) counts[v]++ })
  })
  return {
    categories: opts.map(o => o.label),
    series: [{ name: 'จำนวน', data: opts.map(o => counts[o.value]) }],
  }
}

function aggYesNo(q) {
  let yes = 0, no = 0
  getAnswers(q).forEach(a => { if (a === 'yes') yes++; else if (a === 'no') no++ })
  return { labels: ['ใช่', 'ไม่ใช่'], series: [yes, no] }
}

function aggRating(q) {
  const max = q.settings?.max || 5
  const counts = Array(max).fill(0)
  const vals = []
  getAnswers(q).forEach(a => {
    const n = Number(a)
    if (n >= 1 && n <= max) { counts[n - 1]++; vals.push(n) }
  })
  const avg = vals.length > 0 ? (vals.reduce((s, v) => s + v, 0) / vals.length).toFixed(2) : null
  return {
    avg,
    total: vals.length,
    categories: Array.from({ length: max }, (_, i) => `${i+1}`),
    series: [{ name: 'จำนวน', data: counts }],
  }
}

function aggNumber(q) {
  const vals = getAnswers(q).map(Number).filter(n => !isNaN(n))
  if (vals.length === 0) return null
  return {
    min: Math.min(...vals),
    max: Math.max(...vals),
    avg: (vals.reduce((s, v) => s + v, 0) / vals.length).toFixed(2),
    total: vals.length,
  }
}

function textAnswers(q) {
  return getAnswers(q).filter(a => typeof a === 'string' && a.trim() !== '')
}

// ─── Chart options helpers ────────────────────────────────────────────────────
const chartColors = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316']

function donutOpts(labels, series) {
  return {
    chart: { type: 'donut', height: 200, sparkline: { enabled: false } },
    labels,
    series,
    colors: chartColors,
    legend: { position: 'bottom', fontFamily: 'Sarabun, sans-serif', fontSize: '12px' },
    plotOptions: { pie: { donut: { size: '65%' } } },
    dataLabels: { enabled: true, formatter: (val) => Math.round(val) + '%', style: { fontSize: '11px' } },
    tooltip: { y: { formatter: (val) => val + ' โรง' } },
  }
}

function barOpts(categories, horizontal = false) {
  return {
    chart: { type: 'bar', height: 200, toolbar: { show: false } },
    plotOptions: { bar: { borderRadius: 6, horizontal, distributed: !horizontal } },
    colors: chartColors,
    xaxis: { categories, labels: { style: { fontFamily: 'Sarabun, sans-serif', fontSize: '11px' } } },
    yaxis: { labels: { style: { fontFamily: 'Sarabun, sans-serif', fontSize: '11px' } } },
    dataLabels: { enabled: true, style: { fontSize: '11px' } },
    legend: { show: false },
    tooltip: { y: { formatter: (val) => val + ' คำตอบ' } },
  }
}

// ─── Export Excel (.xlsx) — หลายชีต ดู useSupervisionExport.js ─────────────────
function exportExcel() {
  exportSupervisionWorkbook({
    form: form.value, questions: questions.value, responses: responses.value,
    schools: allSchools.value, targets: targetSchools.value, pending: pendingSchools.value,
    filterLabel: filterLabel.value, editorNames: editorNames.value,
  })
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <button @click="router.push('/dashboard/supervision')"
          class="flex items-center gap-1 text-sm text-slate-400 hover:text-slate-600 mb-1 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
          </svg>
          กลับรายการ
        </button>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="chart-bar" class="w-6 h-6 text-primary"/>
          ผลลัพธ์แบบนิเทศ
        </h1>
        <p v-if="form" class="text-slate-500 text-sm mt-0.5">{{ form.title }}</p>
      </div>
      <div class="flex gap-2">
        <button @click="router.push(`/dashboard/supervision/${formId}/edit`)"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
          <SvgIcon name="wrench" class="w-4 h-4"/>
          แก้ไขแบบ
        </button>
        <button @click="exportExcel" :disabled="responseCount === 0"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-emerald-600 text-white rounded-2xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
          <SvgIcon name="download" class="w-4 h-4"/>
          Export Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else>
      <!-- ตัวกรอง อำเภอ / ศูนย์เครือข่าย -->
      <div class="glass-card px-4 py-3 flex flex-wrap items-center gap-2">
        <span class="text-xs font-bold text-slate-500">กรองผล:</span>
        <select v-model="filterDistrict" @change="filterGroup = ''"
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm bg-white/70 focus:outline-none focus:border-primary">
          <option value="">ทุกอำเภอ</option>
          <option v-for="d in districtOptions" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="filterGroup"
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm bg-white/70 focus:outline-none focus:border-primary">
          <option value="">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groupOptions" :key="g" :value="g">{{ g }}</option>
        </select>
        <button v-if="isFiltered" @click="clearFilters" type="button"
          class="text-xs font-bold text-slate-400 hover:text-slate-600">✕ ล้างตัวกรอง</button>
        <span v-if="isFiltered" class="text-xs text-primary font-bold ml-auto">
          แสดงเฉพาะ {{ filterLabel }} · Excel ส่งออกตามตัวกรองนี้
        </span>
        <span v-if="isFiltered && isIndividual && hiddenByFilter" class="w-full text-[11px] text-slate-400">
          ซ่อน {{ hiddenByFilter }} ผู้ตอบที่ไม่อยู่ในตัวกรอง (รวมผู้ที่ไม่ได้ระบุโรงเรียน)
        </span>
      </div>

      <!-- Summary stats: โหมดบุคคล -->
      <div v-if="isIndividual" :class="['grid gap-4', overallScore ? 'grid-cols-3' : 'grid-cols-2']">
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ responseCount }}</p>
          <p class="text-xs text-slate-500 mt-1">ผู้ตอบทั้งหมด</p>
          <div class="flex items-center justify-center gap-1 mt-1">
            <div class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"/>
            <span class="text-[10px] text-emerald-600 font-medium">Realtime</span>
          </div>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-emerald-600">{{ todayCount }}</p>
          <p class="text-xs text-slate-500 mt-1">ผู้ตอบวันนี้</p>
        </div>
        <div v-if="overallScore"
          :class="['rounded-2xl border shadow-sm p-4 text-center',
            overallScore.color === 'emerald' ? 'bg-emerald-50 border-emerald-200' :
            overallScore.color === 'amber'   ? 'bg-amber-50 border-amber-200' : 'bg-red-50 border-red-200']">
          <p :class="['text-3xl font-extrabold',
            overallScore.color === 'emerald' ? 'text-emerald-600' :
            overallScore.color === 'amber'   ? 'text-amber-600' : 'text-red-500']">{{ overallScore.pct }}%</p>
          <p class="text-xs text-slate-500 mt-1">คะแนนรวม</p>
        </div>
      </div>

      <!-- Summary stats: โหมดโรงเรียน -->
      <div v-else :class="['grid gap-4', overallScore ? 'grid-cols-2 sm:grid-cols-5' : 'grid-cols-2 sm:grid-cols-4']">
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ responseCount }}</p>
          <p class="text-xs text-slate-500 mt-1">ส่งแล้ว</p>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-slate-700">{{ totalSchools }}</p>
          <p class="text-xs text-slate-500 mt-1">เป้าหมาย</p>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-emerald-600">{{ pct }}%</p>
          <p class="text-xs text-slate-500 mt-1">ความสำเร็จ</p>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-amber-500">{{ pendingSchools.length }}</p>
          <p class="text-xs text-slate-500 mt-1">ยังไม่ส่ง</p>
          <div class="flex items-center justify-center gap-1 mt-1">
            <div class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"/>
            <span class="text-[10px] text-emerald-600 font-medium">Realtime</span>
          </div>
        </div>
        <!-- Overall score (แสดงเฉพาะถ้ามี scoreable questions) -->
        <div v-if="overallScore"
          :class="['rounded-2xl border shadow-sm p-4 text-center',
            overallScore.color === 'emerald' ? 'bg-emerald-50 border-emerald-200' :
            overallScore.color === 'amber'   ? 'bg-amber-50 border-amber-200' :
            'bg-red-50 border-red-200']">
          <p :class="['text-3xl font-extrabold',
            overallScore.color === 'emerald' ? 'text-emerald-600' :
            overallScore.color === 'amber'   ? 'text-amber-600' : 'text-red-500']">
            {{ overallScore.pct }}%
          </p>
          <p class="text-xs text-slate-500 mt-1">คะแนนรวม</p>
        </div>
      </div>

      <!-- Progress bar (โหมดโรงเรียน) -->
      <div v-if="!isIndividual" class="glass-card p-4">
        <div class="flex justify-between text-sm font-medium text-slate-600 mb-2">
          <span>ความคืบหน้า</span>
          <span>{{ responseCount }} / {{ totalSchools }} โรงเรียน</span>
        </div>
        <div class="h-3 bg-slate-100 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-primary to-blue-400 rounded-full transition-all duration-700"
            :style="`width:${pct}%`"/>
        </div>
      </div>

      <!-- ภาพรวมรายศูนย์เครือข่าย (โหมดโรงเรียน) -->
      <div v-if="!isIndividual && !filterGroup && groupSummary.length > 1" class="glass-card p-5">
        <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
          <h3 class="font-bold text-slate-700">ภาพรวมรายศูนย์เครือข่าย</h3>
          <div class="flex gap-1 text-xs">
            <button v-for="o in [{ k: 'name', l: 'เรียงตามชื่อ' }, { k: 'pct', l: 'ค้างส่งมากก่อน' }]" :key="o.k"
              @click="groupSort = o.k" type="button"
              :class="['px-2.5 py-1 rounded-lg font-bold', groupSort === o.k ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500']">{{ o.l }}</button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="text-slate-400 text-left border-b border-slate-100">
                <th class="pb-2 font-medium pr-3">ศูนย์เครือข่าย</th>
                <th class="pb-2 font-medium pr-3 text-right">เป้าหมาย</th>
                <th class="pb-2 font-medium pr-3 text-right">ส่งแล้ว</th>
                <th class="pb-2 font-medium pr-3 w-1/3">ร้อยละที่ส่ง</th>
                <th v-if="hasScored" class="pb-2 font-medium text-right">คะแนนเฉลี่ย</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="g in groupSummary" :key="g.group" @click="filterGroup = g.group"
                class="border-b border-slate-50 hover:bg-slate-50 cursor-pointer" title="คลิกเพื่อกรองเฉพาะศูนย์นี้">
                <td class="py-2 pr-3 font-medium text-slate-700">{{ g.group }}</td>
                <td class="py-2 pr-3 text-right tabular-nums text-slate-500">{{ g.targets }}</td>
                <td class="py-2 pr-3 text-right tabular-nums text-slate-700 font-bold">{{ g.responded }}</td>
                <td class="py-2 pr-3">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                      <div :class="['h-full rounded-full', (g.pct ?? 0) >= 80 ? 'bg-emerald-500' : (g.pct ?? 0) >= 50 ? 'bg-amber-400' : 'bg-red-400']"
                        :style="{ width: `${g.pct ?? 0}%` }"/>
                    </div>
                    <span class="w-10 text-right tabular-nums text-slate-600">{{ g.pct ?? '-' }}%</span>
                  </div>
                </td>
                <td v-if="hasScored" class="py-2 text-right">
                  <span v-if="g.avgScore !== null"
                    :class="['px-2 py-0.5 rounded-full font-bold', { emerald: 'bg-emerald-100 text-emerald-700', amber: 'bg-amber-100 text-amber-700', red: 'bg-red-100 text-red-600' }[scoreColor(g.avgScore)]]">
                    {{ g.avgScore }}%
                  </span>
                  <span v-else class="text-slate-300">-</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ข้อมูลผู้ตอบ (โหมดบุคคล) -->
      <div v-if="isIndividual && respondentCharts.length && responseCount > 0" class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-3">ข้อมูลผู้ตอบ</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div v-for="c in respondentCharts" :key="c.key">
            <p class="text-xs font-bold text-slate-500 mb-1">{{ c.label }}</p>
            <apexchart v-if="c.kind === 'donut'" type="donut" :height="220"
              :options="{ ...donutOpts(c.labels, c.counts), tooltip: { y: { formatter: v => v + ' คน' } } }" :series="c.counts"/>
            <apexchart v-else type="bar" :height="60 + c.counts.length * 32"
              :options="{ ...barOpts(c.labels, true), tooltip: { y: { formatter: v => v + ' คน' } } }"
              :series="[{ name: 'จำนวน', data: c.counts }]"/>
          </div>
        </div>
      </div>

      <!-- คะแนนรายหมวด (กราฟ) + คะแนนรายโรงเรียน -->
      <template v-if="hasScored && responseCount > 0">
        <div v-if="sectionChart" class="glass-card p-5">
          <h3 class="font-bold text-slate-700 mb-1">เปรียบเทียบคะแนนรายหมวด</h3>
          <apexchart type="bar" :height="sectionChart.height" :options="sectionChart.options" :series="sectionChart.series"/>
        </div>

        <div class="glass-card p-5">
          <h3 class="font-bold text-slate-700 mb-3">
            คะแนนราย{{ isIndividual ? 'ผู้ตอบ' : 'โรงเรียน' }}
            <span class="text-xs font-normal text-slate-400 ml-1">คลิกหัวคอลัมน์เพื่อเรียง{{ canEditAnswers ? ' · คลิกแถวเพื่อดูคำตอบ' : '' }}</span>
          </h3>
          <div class="overflow-x-auto max-h-[28rem] overflow-y-auto">
            <table class="w-full text-xs">
              <thead class="sticky top-0 bg-white/95 backdrop-blur">
                <tr class="text-slate-400 text-left border-b border-slate-100">
                  <th class="pb-2 font-medium pr-3 w-10">#</th>
                  <th class="pb-2 font-medium pr-3 cursor-pointer hover:text-slate-600" @click="sortScoresBy('name')">
                    {{ isIndividual ? 'ผู้ตอบ' : 'โรงเรียน' }} {{ scoreSort.key === 'name' ? (scoreSort.dir > 0 ? '▲' : '▼') : '' }}
                  </th>
                  <th v-if="!isIndividual" class="pb-2 font-medium pr-3">ศูนย์</th>
                  <th class="pb-2 font-medium pr-3 text-right cursor-pointer hover:text-slate-600 whitespace-nowrap" @click="sortScoresBy('pct')">
                    คะแนนรวม {{ scoreSort.key === 'pct' ? (scoreSort.dir > 0 ? '▲' : '▼') : '' }}
                  </th>
                  <th v-for="sec in (scoredSections.length > 1 ? scoredSections : [])" :key="sec.id ?? '_'"
                    class="pb-2 font-medium pr-3 text-right cursor-pointer hover:text-slate-600 max-w-[9rem] truncate"
                    :title="sec.title || '(ไม่มีหัวข้อ)'" @click="sortScoresBy(sec.id ?? '_')">
                    {{ sec.title || '(ไม่มีหัวข้อ)' }} {{ scoreSort.key === (sec.id ?? '_') ? (scoreSort.dir > 0 ? '▲' : '▼') : '' }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(x, i) in schoolScores" :key="x.r.id"
                  @click="canEditAnswers && (editingResponse = x.r)"
                  :class="['border-b border-slate-50', canEditAnswers ? 'hover:bg-slate-50 cursor-pointer' : '']">
                  <td class="py-2 pr-3 text-slate-400">{{ i + 1 }}</td>
                  <td class="py-2 pr-3 font-medium text-slate-700">{{ x.name }}</td>
                  <td v-if="!isIndividual" class="py-2 pr-3 text-slate-500">{{ x.group }}</td>
                  <td class="py-2 pr-3 text-right">
                    <span v-if="x.pct !== null"
                      :class="['px-2 py-0.5 rounded-full font-bold', { emerald: 'bg-emerald-100 text-emerald-700', amber: 'bg-amber-100 text-amber-700', red: 'bg-red-100 text-red-600' }[scoreColor(x.pct)]]">
                      {{ x.pct }}%
                    </span>
                    <span v-else class="text-slate-300">-</span>
                  </td>
                  <td v-for="sec in (scoredSections.length > 1 ? scoredSections : [])" :key="sec.id ?? '_'"
                    :class="['py-2 pr-3 text-right tabular-nums font-bold',
                      { emerald: 'text-emerald-600', amber: 'text-amber-600', red: 'text-red-500', slate: 'text-slate-300' }[scoreColor(x.sections[sec.id ?? '_'])]]">
                    {{ x.sections[sec.id ?? '_'] ?? '-' }}{{ x.sections[sec.id ?? '_'] !== null ? '%' : '' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <!-- No responses yet -->
      <div v-if="responseCount === 0"
        class="text-center py-16 glass-card text-slate-400">
        <SvgIcon name="chart-bar" class="w-12 h-12 mx-auto mb-3 opacity-30"/>
        <p class="font-medium">ยังไม่มีคำตอบ</p>
        <p class="text-sm mt-1">รอโรงเรียนส่งแบบนิเทศ ผลลัพธ์จะแสดงอัตโนมัติ</p>
      </div>

      <!-- Question charts (grouped by section) -->
      <template v-else>
        <template v-for="(sec, si) in sectionsData" :key="si">

          <!-- Section header card -->
          <div v-if="sec.title"
            class="bg-indigo-600 rounded-2xl px-5 py-4 text-white flex items-center justify-between">
            <div>
              <div class="flex items-center gap-2">
                <svg class="w-5 h-5 text-indigo-200" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z"/>
                </svg>
                <h3 class="font-extrabold text-base">{{ sec.title }}</h3>
              </div>
              <p v-if="sec.description" class="text-indigo-200 text-xs mt-0.5 ml-7">{{ sec.description }}</p>
            </div>
            <!-- Section score badge -->
            <div v-if="getSectionScore(sec)" class="flex-shrink-0 ml-4">
              <div :class="['text-center px-4 py-2 rounded-xl font-extrabold text-lg',
                getSectionScore(sec).color === 'emerald' ? 'bg-emerald-500 text-white' :
                getSectionScore(sec).color === 'amber'   ? 'bg-amber-400 text-white' :
                'bg-red-400 text-white']">
                {{ getSectionScore(sec).pct }}%
              </div>
              <p class="text-indigo-200 text-[10px] text-center mt-0.5">คะแนนหมวด</p>
            </div>
          </div>

          <!-- Questions in this section -->
          <div v-for="q in sec.questions" :key="q.id"
            class="glass-card p-5">

          <div class="mb-4">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span class="text-xs font-bold text-primary/70 uppercase tracking-wider">
                {{ { text:'ข้อความสั้น', textarea:'ข้อความยาว', choice:'เลือกคำตอบเดียว',
                     multi_choice:'เลือกได้หลายข้อ', rating:'ระดับคะแนน', yes_no:'ใช่/ไม่ใช่', number:'ตัวเลข' }[q.type] }}
              </span>
              <span v-if="hasAnyEvidence(q)"
                class="text-xs bg-amber-100 text-amber-700 font-bold px-2 py-0.5 rounded-full">
                {{ { none:'📋 รายการเอกสาร', upload:'📎 อัปโหลด', url:'🔗 ลิงก์', both:'📎🔗 ทั้งสอง' }[q.evidence_type || 'none'] }}
                {{ evidenceCount(q) > 0 ? `(${evidenceCount(q)})` : '' }}
              </span>
            </div>
            <h3 class="font-bold text-slate-800">{{ q.question_text }}</h3>
            <p v-if="q.description" class="text-xs text-slate-400 mt-0.5">{{ q.description }}</p>
          </div>

          <!-- choice → donut -->
          <template v-if="q.type === 'choice'">
            <div v-if="getAnswers(q).length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <div v-else class="flex flex-col sm:flex-row items-center gap-6">
              <apexchart type="donut" :height="220" :width="280"
                :options="donutOpts(aggChoice(q).labels, aggChoice(q).series)"
                :series="aggChoice(q).series"/>
              <div class="flex-1 space-y-1 w-full">
                <div v-for="(opt, oi) in q.options" :key="oi" class="flex items-center gap-2 text-sm">
                  <div class="w-3 h-3 rounded-full flex-shrink-0" :style="`background:${chartColors[oi % chartColors.length]}`"/>
                  <span class="flex-1 text-slate-600">{{ opt.label }}</span>
                  <span class="font-bold text-slate-800">{{ aggChoice(q).series[oi] }}</span>
                </div>
              </div>
            </div>
          </template>

          <!-- multi_choice → bar -->
          <template v-else-if="q.type === 'multi_choice'">
            <div v-if="getAnswers(q).length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <apexchart v-else type="bar" :height="200"
              :options="barOpts(aggMultiChoice(q).categories, true)"
              :series="aggMultiChoice(q).series"/>
          </template>

          <!-- yes_no → donut -->
          <template v-else-if="q.type === 'yes_no'">
            <div v-if="getAnswers(q).length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <div v-else class="flex flex-col sm:flex-row items-center gap-6">
              <apexchart type="donut" :height="200" :width="260"
                :options="{ ...donutOpts(['ใช่','ไม่ใช่'], aggYesNo(q).series), colors: ['#10B981','#EF4444'] }"
                :series="aggYesNo(q).series"/>
              <div class="space-y-2 w-full sm:max-w-xs">
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full bg-emerald-500"/>
                  <span class="text-sm text-slate-600 flex-1">ใช่</span>
                  <span class="font-bold text-slate-800">{{ aggYesNo(q).series[0] }} ({{ aggYesNo(q).series[0]+aggYesNo(q).series[1]>0 ? Math.round(aggYesNo(q).series[0]/(aggYesNo(q).series[0]+aggYesNo(q).series[1])*100) : 0 }}%)</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full bg-red-500"/>
                  <span class="text-sm text-slate-600 flex-1">ไม่ใช่</span>
                  <span class="font-bold text-slate-800">{{ aggYesNo(q).series[1] }}</span>
                </div>
              </div>
            </div>
          </template>

          <!-- rating → bar + avg -->
          <template v-else-if="q.type === 'rating'">
            <div v-if="getAnswers(q).length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <template v-else>
              <div class="flex items-center gap-6 mb-3">
                <div class="text-center">
                  <p class="text-3xl font-extrabold text-primary">{{ aggRating(q).avg }}</p>
                  <p class="text-xs text-slate-400">เฉลี่ย / {{ q.settings?.max || 5 }}</p>
                </div>
                <div class="text-center">
                  <p class="text-xl font-bold text-slate-700">{{ aggRating(q).total }}</p>
                  <p class="text-xs text-slate-400">คำตอบ</p>
                </div>
              </div>
              <apexchart type="bar" :height="160"
                :options="barOpts(aggRating(q).categories)"
                :series="aggRating(q).series"/>
            </template>
          </template>

          <!-- number → stats -->
          <template v-else-if="q.type === 'number'">
            <div v-if="!aggNumber(q)" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <div v-else class="grid grid-cols-4 gap-3 text-center">
              <div class="bg-blue-50 rounded-xl p-3">
                <p class="text-xl font-bold text-blue-700">{{ aggNumber(q).avg }}</p>
                <p class="text-xs text-blue-400">เฉลี่ย</p>
              </div>
              <div class="bg-emerald-50 rounded-xl p-3">
                <p class="text-xl font-bold text-emerald-700">{{ aggNumber(q).max }}</p>
                <p class="text-xs text-emerald-400">สูงสุด</p>
              </div>
              <div class="bg-amber-50 rounded-xl p-3">
                <p class="text-xl font-bold text-amber-700">{{ aggNumber(q).min }}</p>
                <p class="text-xs text-amber-400">ต่ำสุด</p>
              </div>
              <div class="bg-slate-50 rounded-xl p-3">
                <p class="text-xl font-bold text-slate-700">{{ aggNumber(q).total }}</p>
                <p class="text-xs text-slate-400">คำตอบ</p>
              </div>
            </div>
          </template>

          <!-- text/textarea → list -->
          <template v-else>
            <div v-if="textAnswers(q).length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีคำตอบ</div>
            <div v-else class="space-y-2 max-h-64 overflow-y-auto">
              <div v-for="(ansObj, ai) in getAnswerObjects(q).filter(a => a.answer)" :key="ai"
                class="flex gap-2 text-sm">
                <span class="w-5 h-5 rounded-full bg-slate-100 text-slate-500 text-xs flex items-center justify-center flex-shrink-0 mt-0.5">
                  {{ ai+1 }}
                </span>
                <div class="flex-1">
                  <p class="text-slate-700 leading-relaxed">{{ ansObj.answer }}</p>
                  <div v-if="ansObj.evidence_file_url || ansObj.evidence_link_url" class="flex flex-wrap gap-2 mt-1">
                    <a v-if="ansObj.evidence_file_url" :href="ansObj.evidence_file_url" target="_blank"
                      class="inline-flex items-center gap-1 text-xs text-blue-600 hover:underline">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/>
                      </svg>
                      📎 ไฟล์แนบ
                    </a>
                    <a v-if="ansObj.evidence_link_url" :href="ansObj.evidence_link_url" target="_blank"
                      class="inline-flex items-center gap-1 text-xs text-purple-600 hover:underline">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/>
                      </svg>
                      🔗 ลิงก์อ้างอิง
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- หลักฐานอ้างอิง (สำหรับทุกประเภทคำถาม ยกเว้น text/textarea ที่แสดงแล้ว) -->
          <div v-if="q.evidence_type && q.evidence_type !== 'none' && !['text','textarea'].includes(q.type) && fileLinkCount(q) > 0"
            class="mt-4 pt-3 border-t border-slate-100">
            <p class="text-xs font-bold text-slate-500 mb-2">หลักฐานอ้างอิง ({{ fileLinkCount(q) }} รายการ)</p>
            <div class="space-y-2 max-h-48 overflow-y-auto">
              <div v-for="(r, ri) in responses" :key="r.id">
                <template v-for="ansObj in (r.supervision_answers||[]).filter(a => a.question_id === q.id && (a.evidence_file_url || a.evidence_link_url))" :key="ansObj.id">
                  <div class="flex items-start gap-2 text-xs p-2 bg-slate-50 rounded-xl">
                    <span class="text-slate-400 flex-shrink-0 mt-0.5">
                      {{ allSchools.find(s => s.id === r.school_id)?.name || r.school_name || `#${ri+1}` }}
                    </span>
                    <div class="flex flex-wrap gap-2 ml-auto">
                      <a v-if="ansObj.evidence_file_url" :href="ansObj.evidence_file_url" target="_blank"
                        class="text-blue-600 hover:underline">📎 ดูไฟล์</a>
                      <a v-if="ansObj.evidence_link_url" :href="ansObj.evidence_link_url" target="_blank"
                        class="text-purple-600 hover:underline">🔗 ลิงก์</a>
                    </div>
                  </div>
                </template>
              </div>
            </div>
          </div>

          <!-- รายการเอกสารหลักฐานที่ผู้ตอบติ๊ก -->
          <div v-if="hasEvidenceItems(q) && responseCount > 0" class="mt-4 pt-3 border-t border-slate-100">
            <p class="text-xs font-bold text-slate-500 mb-2">เอกสารหลักฐานที่ผู้ตอบมี (จาก {{ responseCount }} ผู้ตอบ)</p>
            <div class="space-y-1.5">
              <div v-for="t in evidenceItemTally(q)" :key="t.label" class="flex items-center gap-2 text-xs">
                <span class="w-40 sm:w-56 truncate text-slate-600" :title="t.label">
                  {{ t.label }}<span v-if="t.custom" class="text-[10px] text-slate-400"> (พิมพ์เอง)</span>
                </span>
                <div class="flex-1 h-2.5 bg-slate-100 rounded-full overflow-hidden">
                  <div class="h-full rounded-full bg-amber-400" :style="{ width: `${Math.round(t.count / responseCount * 100)}%` }"/>
                </div>
                <span class="w-16 text-right text-slate-500 tabular-nums">{{ t.count }} ({{ Math.round(t.count / responseCount * 100) }}%)</span>
              </div>
            </div>
          </div>

          </div>
        </template>
      </template>

      <!-- Pending schools table (โหมดโรงเรียน) -->
      <div v-if="!isIndividual && pendingSchools.length > 0" class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-3 flex items-center gap-2">
          <SvgIcon name="school" class="w-4 h-4 text-amber-500"/>
          โรงเรียนที่ยังไม่ส่ง ({{ pendingSchools.length }})
        </h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
          <div v-for="s in pendingSchools" :key="s.id"
            class="flex items-center gap-2 text-xs px-3 py-2 bg-amber-50 rounded-xl text-amber-700">
            <div class="w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0"/>
            <span class="truncate">{{ s.name }}</span>
          </div>
        </div>
      </div>

      <!-- Responded list -->
      <div v-if="responseCount > 0" class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-3 flex items-center gap-2">
          <SvgIcon name="school" class="w-4 h-4 text-emerald-500"/>
          {{ form?.respondent_type === 'individual' ? 'ผู้ตอบ' : 'โรงเรียน' }}ที่ส่งแล้ว ({{ responseCount }})
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="text-slate-400 text-left border-b border-slate-100">
                <th class="pb-2 font-medium pr-4">#</th>
                <th class="pb-2 font-medium pr-4">
                  {{ form?.respondent_type === 'individual' ? 'ผู้ตอบ' : 'โรงเรียน' }}
                </th>
                <th v-if="form?.respondent_type === 'individual'" class="pb-2 font-medium pr-4">ข้อมูลเพิ่มเติม</th>
                <th class="pb-2 font-medium">วันที่ส่ง</th>
                <th v-if="canEditAnswers" class="pb-2 font-medium text-right">คำตอบ</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in responses" :key="r.id" class="border-b border-slate-50 hover:bg-slate-50">
                <td class="py-2 pr-4 text-slate-400">{{ i+1 }}</td>
                <td class="py-2 pr-4 font-medium text-slate-700">
                  <template v-if="form?.respondent_type === 'individual'">
                    <span v-if="r.respondent_info?.name" class="font-bold">{{ r.respondent_info.name }}</span>
                    <span v-else class="text-slate-400 italic">ไม่ระบุตัวตน</span>
                  </template>
                  <template v-else>
                    {{ allSchools.find(s => s.id === r.school_id)?.name || r.school_name || '—' }}
                  </template>
                </td>
                <td v-if="form?.respondent_type === 'individual'" class="py-2 pr-4 text-slate-500">
                  <div class="flex flex-wrap gap-1">
                    <span v-if="r.respondent_info?.position" class="bg-slate-100 px-1.5 py-0.5 rounded text-[10px]">{{ r.respondent_info.position }}</span>
                    <span v-if="r.respondent_info?.school" class="bg-blue-50 text-blue-600 px-1.5 py-0.5 rounded text-[10px]">{{ r.respondent_info.school }}</span>
                    <span v-if="r.respondent_info?.gender" class="bg-purple-50 text-purple-600 px-1.5 py-0.5 rounded text-[10px]">{{ r.respondent_info.gender }}</span>
                    <span v-if="r.respondent_info?.age_range" class="bg-amber-50 text-amber-600 px-1.5 py-0.5 rounded text-[10px]">{{ r.respondent_info.age_range }}</span>
                  </div>
                </td>
                <td class="py-2 text-slate-500">
                  {{ formatDate(r.submitted_at) }}
                  <span v-if="r.edited_at" class="block text-[10px] text-amber-600"
                    :title="`แก้ไขล่าสุด ${formatDate(r.edited_at)}`">
                    ✎ แก้ไขโดยผู้ดูแล{{ editorNames[r.edited_by] ? ` (${editorNames[r.edited_by]})` : '' }}
                  </span>
                </td>
                <td v-if="canEditAnswers" class="py-2 text-right">
                  <div class="flex justify-end gap-1.5">
                    <button @click="editingResponse = r" type="button"
                      class="px-2.5 py-1 text-[11px] font-bold bg-primary/10 text-primary rounded-lg hover:bg-primary/20 whitespace-nowrap">
                      ดู / แก้คำตอบ
                    </button>
                    <button v-if="form?.respondent_type !== 'individual'" @click="unlockResponse(r)" type="button"
                      class="px-2.5 py-1 text-[11px] font-bold bg-amber-50 text-amber-700 rounded-lg hover:bg-amber-100 whitespace-nowrap">
                      ปลดล็อกให้ส่งใหม่
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ปลดล็อกแล้ว รอส่งใหม่ (ไม่นับในสถิติ/Excel) -->
      <div v-if="unlockedResponses.length" class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-1 flex items-center gap-2">
          <svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 10.5V6.75a4.5 4.5 0 119 0v3.75M3.75 21.75h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H3.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
          </svg>
          ปลดล็อกแล้ว รอส่งใหม่ ({{ unlockedResponses.length }})
        </h3>
        <p class="text-xs text-slate-400 mb-3">คำตอบชุดเดิมเก็บไว้เป็นประวัติ ไม่นับในสถิติและ Excel</p>
        <div class="divide-y divide-slate-100">
          <div v-for="r in unlockedResponses" :key="r.id" class="flex flex-wrap items-center gap-2 py-2 text-xs">
            <span class="font-medium text-slate-700 flex-1 min-w-[140px]">{{ respondentLabel(r) }}</span>
            <span class="text-slate-400">
              ส่งเดิม {{ formatDate(r.submitted_at) }}
              <template v-if="r.edited_at"> · ปลดล็อก {{ formatDate(r.edited_at) }}{{ editorNames[r.edited_by] ? ` โดย ${editorNames[r.edited_by]}` : '' }}</template>
            </span>
            <button @click="editingResponse = r" type="button"
              class="px-2.5 py-1 text-[11px] font-bold bg-slate-100 text-slate-600 rounded-lg hover:bg-slate-200">ดูคำตอบเดิม</button>
            <span v-if="hasResubmitted(r)" class="px-2.5 py-1 text-[11px] font-bold bg-emerald-50 text-emerald-700 rounded-lg">✓ ส่งใหม่แล้ว</span>
            <button v-else-if="canEditAnswers" @click="restoreResponse(r)" type="button"
              class="px-2.5 py-1 text-[11px] font-bold bg-primary/10 text-primary rounded-lg hover:bg-primary/20">คืนสถานะส่งแล้ว</button>
          </div>
        </div>
      </div>
    </template>

    <SupervisionAnswerEditModal :response="editingResponse" :questions="questions"
      :title="editingResponse ? respondentLabel(editingResponse) : ''"
      @close="editingResponse = null" @saved="onAnswersSaved"/>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
