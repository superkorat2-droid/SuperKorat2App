<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'

const router = useRouter()

const periods = ref([])   // nt_periods, all
const schools = ref([])
const scoresByPeriod = ref({})     // { periodId: [{school_id, scores, school}] }
const benchmarksByPeriod = ref({}) // { periodId: { province:{}, national:{} } }
const loading = ref(true)

const examType   = ref('NT')
const gradeLevel = ref('')

const filterDistrict = ref('')
const filterGroup    = ref('')
const filterSchool   = ref('')

async function load() {
  loading.value = true
  const [{ data: p }, { data: sc }] = await Promise.all([
    supabase.from('nt_periods').select('*').order('academic_year'),
    supabase.from('schools').select('id, school_code, name, district, school_group'),
  ])
  periods.value = p || []
  schools.value = sc || []
  if (periods.value.length && !gradeLevel.value) {
    examType.value   = periods.value[0].exam_type
    gradeLevel.value = periods.value[0].grade_level
  }
  await loadAllScores()
  loading.value = false
}
onMounted(load)

async function loadAllScores() {
  const schoolById = new Map(schools.value.map(s => [s.id, s]))
  const scoreMap = {}
  const benchMap = {}
  for (const p of periods.value) {
    const all = []
    let from = 0
    while (true) {
      const { data, error } = await supabase.from('nt_school_scores')
        .select('school_id, scores').eq('period_id', p.id).range(from, from + 999)
      if (error || !data?.length) break
      all.push(...data)
      if (data.length < 1000) break
      from += 1000
    }
    scoreMap[p.id] = all.map(r => ({ ...r, school: schoolById.get(r.school_id) }))

    const { data: b } = await supabase.from('nt_benchmarks').select('scope, scores').eq('period_id', p.id)
    const bm = { province: {}, national: {} }
    ;(b || []).forEach(row => { bm[row.scope] = row.scores || {} })
    benchMap[p.id] = bm
  }
  scoresByPeriod.value = scoreMap
  benchmarksByPeriod.value = benchMap
}

const examTypeOptions = computed(() => [...new Set(periods.value.map(p => p.exam_type))])
const gradeLevelOptions = computed(() => [...new Set(periods.value.filter(p => p.exam_type === examType.value).map(p => p.grade_level))])

const matchingPeriods = computed(() =>
  periods.value
    .filter(p => p.exam_type === examType.value && p.grade_level === gradeLevel.value)
    .sort((a, b) => a.academic_year - b.academic_year)
)

const subjectKeys = computed(() => {
  const p = matchingPeriods.value[0]
  return [...(p?.subjects || []).map(s => s.key), 'overall']
})
const subjectLabels = computed(() => {
  const m = {}
  ;(matchingPeriods.value[0]?.subjects || []).forEach(s => { m[s.key] = s.label })
  m.overall = 'รวม 2 ด้าน'
  return m
})

const districtOptions = computed(() => [...new Set(schools.value.map(s => s.district).filter(Boolean))].sort())
const groupOptions = computed(() => {
  const list = schools.value.filter(s => !filterDistrict.value || s.district === filterDistrict.value)
  return [...new Set(list.map(s => s.school_group).filter(Boolean))].sort()
})
const schoolOptions = computed(() => {
  let list = schools.value
  if (filterDistrict.value) list = list.filter(s => s.district === filterDistrict.value)
  if (filterGroup.value)    list = list.filter(s => s.school_group === filterGroup.value)
  return list.sort((a, b) => a.name.localeCompare(b.name, 'th'))
})

function filteredScoresFor(periodId) {
  let list = scoresByPeriod.value[periodId] || []
  list = list.filter(r => r.school)
  if (filterSchool.value)      list = list.filter(r => r.school.id === filterSchool.value)
  else if (filterGroup.value)  list = list.filter(r => r.school.school_group === filterGroup.value)
  else if (filterDistrict.value) list = list.filter(r => r.school.district === filterDistrict.value)
  return list
}

function avgFor(periodId, key) {
  const list = filteredScoresFor(periodId)
  const vals = list.map(r => r.scores?.[key]?.pct).filter(v => typeof v === 'number')
  if (!vals.length) return null
  return vals.reduce((a, b) => a + b, 0) / vals.length
}

// ── Chart geometry ─────────────────────────────────────────────────────────────
const C = { W: 760, H: 280, PL: 44, PR: 20, PT: 20, PB: 40 }
const SUBJECT_COLOR = { math: '#3b82f6', thai: '#f97316', overall: '#8b5cf6' }

const chartPoints = computed(() => {
  const n = matchingPeriods.value.length
  if (!n) return { series: [], benchmarkSeries: [] }
  const chartW = C.W - C.PL - C.PR
  const chartH = C.H - C.PT - C.PB
  const step = n > 1 ? chartW / (n - 1) : 0
  const x = (i) => C.PL + (n > 1 ? step * i : chartW / 2)
  const y = (v) => C.PT + chartH - (Math.max(0, Math.min(100, v)) / 100) * chartH

  const series = subjectKeys.value.map(key => ({
    key, label: subjectLabels.value[key], color: SUBJECT_COLOR[key] || '#64748b',
    points: matchingPeriods.value.map((p, i) => {
      const v = avgFor(p.id, key)
      return { x: x(i), y: v === null ? null : y(v), v, year: p.academic_year }
    }),
  }))

  const benchmarkSeries = ['province', 'national'].map(scope => ({
    scope, label: scope === 'province' ? 'ค่าเฉลี่ยจังหวัด (รวม)' : 'ค่าเฉลี่ยประเทศ (รวม)',
    dash: scope === 'province' ? '6,4' : '2,3',
    points: matchingPeriods.value.map((p, i) => {
      const v = benchmarksByPeriod.value[p.id]?.[scope]?.overall?.pct
      return { x: x(i), y: typeof v === 'number' ? y(v) : null, v }
    }),
  })).filter(s => s.points.some(pt => pt.v != null))

  return { series, benchmarkSeries, xAt: x, yAt: y }
})

function linePath(points) {
  const valid = points.filter(p => p.y !== null)
  if (valid.length < 2) return ''
  return valid.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ')
}

const yTicks = [0, 25, 50, 75, 100]

const hovered = ref(null)
</script>

<template>
  <div class="font-sarabun space-y-6">
    <button @click="router.push('/dashboard/nt-scores')" class="text-sm text-slate-500 hover:text-primary">← กลับไปรายการรอบ</button>

    <h1 class="text-2xl font-extrabold text-slate-800">แนวโน้มผลคะแนนข้ามปี</h1>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else-if="periods.length === 0">
      <div class="text-center py-12 glass-card text-slate-400">
        <p class="font-medium">ยังไม่มีรอบผลคะแนน</p>
        <p class="text-sm mt-1">ไปสร้างรอบและนำเข้าไฟล์ก่อนที่หน้ารายการรอบ</p>
      </div>
    </template>

    <template v-else>
      <div class="flex flex-wrap gap-3">
        <select v-model="examType" @change="gradeLevel = gradeLevelOptions[0] || ''" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option v-for="e in examTypeOptions" :key="e" :value="e">{{ e }}</option>
        </select>
        <select v-model="gradeLevel" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option v-for="g in gradeLevelOptions" :key="g" :value="g">{{ g }}</option>
        </select>
        <span class="w-px bg-slate-200 mx-1"/>
        <select v-model="filterDistrict" @change="filterGroup=''; filterSchool=''" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option value="">ทุกอำเภอ</option>
          <option v-for="d in districtOptions" :key="d" :value="d">{{ d }}</option>
        </select>
        <select v-model="filterGroup" @change="filterSchool=''" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option value="">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groupOptions" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="filterSchool" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option value="">ทุกโรงเรียน</option>
          <option v-for="s in schoolOptions" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
        <button v-if="filterDistrict || filterGroup || filterSchool" @click="filterDistrict=''; filterGroup=''; filterSchool=''"
          class="text-xs font-bold text-slate-500 hover:text-red-500">ล้างตัวกรอง</button>
      </div>

      <div v-if="matchingPeriods.length === 0" class="text-center py-12 glass-card text-slate-400">
        ไม่พบรอบของ {{ examType }} {{ gradeLevel }}
      </div>

      <div v-else class="glass-card p-5">
        <div class="flex flex-wrap gap-4 mb-3">
          <div v-for="s in chartPoints.series" :key="s.key" class="flex items-center gap-1.5 text-xs">
            <span class="w-3 h-3 rounded-full" :style="`background:${s.color}`"/>{{ s.label }}
          </div>
          <div v-for="s in chartPoints.benchmarkSeries" :key="s.scope" class="flex items-center gap-1.5 text-xs text-slate-500">
            <span class="w-4 h-0.5 bg-slate-400"/>{{ s.label }}
          </div>
        </div>

        <svg :viewBox="`0 0 ${C.W} ${C.H}`" class="w-full" style="max-height:300px">
          <line v-for="t in yTicks" :key="t" :x1="C.PL" :x2="C.W - C.PR" :y1="chartPoints.yAt(t)" :y2="chartPoints.yAt(t)" stroke="#e5e7eb" stroke-width="1"/>
          <text v-for="t in yTicks" :key="'y'+t" :x="C.PL - 8" :y="chartPoints.yAt(t) + 4" text-anchor="end" font-size="11" fill="#9ca3af">{{ t }}</text>

          <text v-for="(p, i) in matchingPeriods" :key="'x'+p.id" :x="chartPoints.xAt(i)" :y="C.H - C.PB + 20" text-anchor="middle" font-size="11" fill="#6b7280">
            {{ p.academic_year }}
          </text>

          <path v-for="s in chartPoints.benchmarkSeries" :key="'bm'+s.scope" :d="linePath(s.points)" fill="none" stroke="#94a3b8" stroke-width="1.5" :stroke-dasharray="s.dash"/>

          <g v-for="s in chartPoints.series" :key="s.key">
            <path :d="linePath(s.points)" fill="none" :stroke="s.color" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>
            <circle v-for="(pt, i) in s.points.filter(p => p.y !== null)" :key="i" :cx="pt.x" :cy="pt.y" r="4"
              :fill="s.color" stroke="white" stroke-width="1.5"
              class="cursor-pointer" @mouseenter="hovered = { ...pt, label: s.label, color: s.color }" @mouseleave="hovered = null"/>
          </g>

          <g v-if="hovered">
            <rect :x="hovered.x - 55" :y="hovered.y - 42" width="110" height="34" rx="6" fill="#1e1b4b" opacity="0.92"/>
            <text :x="hovered.x" :y="hovered.y - 27" text-anchor="middle" font-size="10" fill="white">{{ hovered.label }} · {{ hovered.year }}</text>
            <text :x="hovered.x" :y="hovered.y - 13" text-anchor="middle" font-size="13" fill="#a5b4fc" font-weight="700">{{ hovered.v?.toFixed(2) }}%</text>
          </g>
        </svg>

        <p v-if="matchingPeriods.length < 2" class="text-xs text-slate-400 text-center mt-2">
          มีข้อมูลรอบเดียว — เพิ่มรอบปีอื่นเพื่อดูเส้นแนวโน้ม
        </p>
      </div>

      <!-- Table -->
      <div class="glass-card overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs text-slate-500 uppercase tracking-wider border-b border-slate-100">
              <th class="px-4 py-3">ปีการศึกษา</th>
              <th v-for="key in subjectKeys" :key="key" class="px-4 py-3 text-right">{{ subjectLabels[key] }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in [...matchingPeriods].reverse()" :key="p.id" class="border-b border-slate-50">
              <td class="px-4 py-2.5 font-medium text-slate-700">{{ p.academic_year }}</td>
              <td v-for="key in subjectKeys" :key="key" class="px-4 py-2.5 text-right font-bold text-slate-700">
                {{ avgFor(p.id, key) !== null ? avgFor(p.id, key).toFixed(2) + '%' : '—' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
