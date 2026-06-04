<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'

const router = useRouter()
const route  = useRoute()
const formId = computed(() => route.params.id)

// ─── State ────────────────────────────────────────────────────────────────────
const loading   = ref(true)
const form      = ref(null)
const questions = ref([])
const responses = ref([])
const allSchools = ref([])
let realtimeChannel = null

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
    supabase.from('schools').select('id, name, district').order('district').order('name'),
  ])

  form.value      = formData
  questions.value = qs || []
  responses.value = rsp || []
  allSchools.value = sc || []

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
})

onUnmounted(() => {
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
})

// ─── Stats ────────────────────────────────────────────────────────────────────
const totalSchools = computed(() => {
  if (!form.value) return 0
  if (form.value.target === 'all') return allSchools.value.length
  return form.value.target_schools?.length || 0
})

const responseCount = computed(() => responses.value.length)
const pct           = computed(() =>
  totalSchools.value > 0 ? Math.round((responseCount.value / totalSchools.value) * 100) : 0
)

const respondedIds = computed(() => new Set(responses.value.map(r => r.school_id)))

const pendingSchools = computed(() => {
  const targets = form.value?.target === 'all'
    ? allSchools.value
    : allSchools.value.filter(s => form.value?.target_schools?.includes(s.id))
  return targets.filter(s => !respondedIds.value.has(s.id))
})

// ─── Per-question aggregation ─────────────────────────────────────────────────
function getAnswerObjects(q) {
  return responses.value
    .flatMap(r => r.supervision_answers || [])
    .filter(a => a.question_id === q.id)
}

function getAnswers(q) {
  return getAnswerObjects(q).map(a => a.answer)
}

function evidenceCount(q) {
  return getAnswerObjects(q).filter(a => a.evidence_file_url || a.evidence_link_url).length
}

// ─── Section grouping ─────────────────────────────────────────────────────────
const sectionsData = computed(() => {
  const sorted = [...questions.value].sort((a, b) => a.sort_order - b.sort_order)
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
})

// ─── Scoring ──────────────────────────────────────────────────────────────────
function scoreQuestion(q) {
  const vals = getAnswers(q)
  if (vals.length === 0) return null

  if (q.type === 'rating') {
    const max = q.settings?.max || 5
    const avg = vals.reduce((s, a) => s + Number(a), 0) / vals.length
    return { score: avg, max }
  }
  if (q.type === 'yes_no') {
    const yes = vals.filter(a => a === 'yes').length
    return { score: (yes / vals.length) * 100, max: 100 }
  }
  if (q.type === 'choice') {
    const hasScores = q.options?.some(o => o.score !== '' && o.score !== null && o.score !== undefined)
    if (!hasScores) return null
    const maxOpt = Math.max(...q.options.map(o => Number(o.score || 0)))
    if (maxOpt <= 0) return null
    const map = Object.fromEntries(q.options.map(o => [o.value, Number(o.score || 0)]))
    const avg = vals.reduce((s, a) => s + (map[a] || 0), 0) / vals.length
    return { score: avg, max: maxOpt }
  }
  return null
}

function getSectionScore(sec) {
  let totalScore = 0, totalMax = 0
  for (const q of sec.questions) {
    const s = scoreQuestion(q)
    if (s) { totalScore += s.score; totalMax += s.max }
  }
  if (totalMax === 0) return null
  const pct = Math.round((totalScore / totalMax) * 100)
  return { pct, color: pct >= 80 ? 'emerald' : pct >= 60 ? 'amber' : 'red' }
}

const overallScore = computed(() => {
  if (responseCount.value === 0) return null
  let totalScore = 0, totalMax = 0
  for (const q of questions.value.filter(q => q.type !== 'section')) {
    const s = scoreQuestion(q)
    if (s) { totalScore += s.score; totalMax += s.max }
  }
  if (totalMax === 0) return null
  const pct = Math.round((totalScore / totalMax) * 100)
  return { pct, color: pct >= 80 ? 'emerald' : pct >= 60 ? 'amber' : 'red' }
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

// ─── Export CSV ───────────────────────────────────────────────────────────────
function exportCSV() {
  // map question_id → section title
  const qSectionMap = {}
  for (const sec of sectionsData.value) {
    sec.questions.forEach(q => { qSectionMap[q.id] = sec.title || '' })
  }

  const nonSectionQs = questions.value
    .filter(q => q.type !== 'section')
    .sort((a, b) => a.sort_order - b.sort_order)

  const headers = [
    'โรงเรียน', 'วันที่ส่ง',
    ...nonSectionQs.map(q => qSectionMap[q.id] ? `[${qSectionMap[q.id]}] ${q.question_text}` : q.question_text)
  ]

  const rows = responses.value.map(r => {
    const school = allSchools.value.find(s => s.id === r.school_id)
    const date = new Date(r.submitted_at).toLocaleDateString('th-TH')
    const ans = nonSectionQs.map(q => {
      const a = (r.supervision_answers || []).find(x => x.question_id === q.id)?.answer
      if (a === null || a === undefined) return ''
      if (Array.isArray(a)) return a.join(', ')
      return String(a)
    })
    return [school?.name || r.school_name || '—', date, ...ans]
  })

  const csv = [headers, ...rows]
    .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
    .join('\n')

  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `supervision_${form.value?.title || 'results'}_${new Date().toISOString().slice(0,10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
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
        <button @click="exportCSV" :disabled="responseCount === 0"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-emerald-600 text-white rounded-2xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
          <SvgIcon name="download" class="w-4 h-4"/>
          Export CSV
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else>
      <!-- Summary stats -->
      <div :class="['grid gap-4', overallScore ? 'grid-cols-2 sm:grid-cols-5' : 'grid-cols-2 sm:grid-cols-4']">
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ responseCount }}</p>
          <p class="text-xs text-slate-500 mt-1">ส่งแล้ว</p>
        </div>
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-slate-700">{{ totalSchools }}</p>
          <p class="text-xs text-slate-500 mt-1">เป้าหมาย</p>
        </div>
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-emerald-600">{{ pct }}%</p>
          <p class="text-xs text-slate-500 mt-1">ความสำเร็จ</p>
        </div>
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
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

      <!-- Progress bar -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
        <div class="flex justify-between text-sm font-medium text-slate-600 mb-2">
          <span>ความคืบหน้า</span>
          <span>{{ responseCount }} / {{ totalSchools }} โรงเรียน</span>
        </div>
        <div class="h-3 bg-slate-100 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-primary to-blue-400 rounded-full transition-all duration-700"
            :style="`width:${pct}%`"/>
        </div>
      </div>

      <!-- No responses yet -->
      <div v-if="responseCount === 0"
        class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
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
            class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">

          <div class="mb-4">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span class="text-xs font-bold text-primary/70 uppercase tracking-wider">
                {{ { text:'ข้อความสั้น', textarea:'ข้อความยาว', choice:'เลือกคำตอบเดียว',
                     multi_choice:'เลือกได้หลายข้อ', rating:'ระดับคะแนน', yes_no:'ใช่/ไม่ใช่', number:'ตัวเลข' }[q.type] }}
              </span>
              <span v-if="q.evidence_type && q.evidence_type !== 'none'"
                class="text-xs bg-amber-100 text-amber-700 font-bold px-2 py-0.5 rounded-full">
                {{ { upload:'📎 อัปโหลด', url:'🔗 ลิงค์', both:'📎🔗 ทั้งสอง' }[q.evidence_type] }}
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
                      🔗 ลิงค์อ้างอิง
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- หลักฐานอ้างอิง (สำหรับทุกประเภทคำถาม ยกเว้น text/textarea ที่แสดงแล้ว) -->
          <div v-if="q.evidence_type && q.evidence_type !== 'none' && !['text','textarea'].includes(q.type) && evidenceCount(q) > 0"
            class="mt-4 pt-3 border-t border-slate-100">
            <p class="text-xs font-bold text-slate-500 mb-2">หลักฐานอ้างอิง ({{ evidenceCount(q) }} รายการ)</p>
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
                        class="text-purple-600 hover:underline">🔗 ลิงค์</a>
                    </div>
                  </div>
                </template>
              </div>
            </div>
          </div>

          </div>
        </template>
      </template>

      <!-- Pending schools table -->
      <div v-if="pendingSchools.length > 0" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
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
      <div v-if="responseCount > 0" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
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
                <td class="py-2 text-slate-500">{{ formatDate(r.submitted_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
