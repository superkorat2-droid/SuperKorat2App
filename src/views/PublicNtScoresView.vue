<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import { QUALITY_LEVELS, QUALITY_COLOR, hasNoEligible, NO_ELIGIBLE_TEXT } from '../composables/useNtParser'
import PageHero from '../components/PageHero.vue'
import BarChart from '../components/awards/BarChart.vue'

const { config } = useAreaConfig()
const header = usePageHeader('ntScores', { icon: 'students', title: 'ผลคะแนน NT', align: 'center' })

const loading = ref(true)
const notStaff = ref(false)   // ล็อกอินแล้วแต่ไม่ใช่ ศน./เจ้าหน้าที่ (เช่น บัญชีโรงเรียน) — ฐานข้อมูลก็ไม่ส่งข้อมูลให้
const periods = ref([]) // ทุกรอบที่ show_public=true จาก get_nt_public_trend() — [{id, exam_type, grade_level, academic_year, title, subjects, scores:[...]}]

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    const { data: me } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    notStaff.value = !['super_admin', 'admin', 'supervisor', 'staff'].includes(me?.role)
  }
  if (notStaff.value) { loading.value = false; return }
  const { data, error } = await supabase.rpc('get_nt_public_trend')
  periods.value = error ? [] : (data || [])
  // เลือกแท็บแรกที่มีข้อมูลจริงตามลำดับ RT→NT→O-NET ไว้ก่อน ถ้าไม่มีเลยค่อย fallback ไปแท็บแรกสุด
  const withData = examGroups.value.find(g => g.periods.length > 0)
  selectedGroup.value = (withData || examGroups.value[0])?.key || ''
  loading.value = false
})

// ── แท็บประเภทสอบ+ชั้น — โชว์ครบทุกประเภทเสมอตามลำดับ RT→NT→O-NET แม้ยังไม่มีข้อมูล
// (เช่น O-NET ที่ยังไม่เปิดใช้) เพื่อให้เห็นว่ามีฟีเจอร์นี้รออยู่ ไม่ใช่ซ่อนไปเฉยๆ
const EXAM_TYPE_ORDER = ['RT', 'NT', 'ONET']
const EXAM_TYPE_LABEL = { RT: 'RT', NT: 'NT', ONET: 'O-NET' }
const examGroups = computed(() => {
  const map = {}
  periods.value.forEach(p => {
    const key = `${p.exam_type}__${p.grade_level}`
    ;(map[key] ||= { key, exam_type: p.exam_type, grade_level: p.grade_level, periods: [] }).periods.push(p)
  })
  const groups = Object.values(map)
  EXAM_TYPE_ORDER.forEach(et => {
    if (!groups.some(g => g.exam_type === et)) {
      groups.push({ key: `${et}__none`, exam_type: et, grade_level: '', periods: [] })
    }
  })
  return groups.sort((a, b) => EXAM_TYPE_ORDER.indexOf(a.exam_type) - EXAM_TYPE_ORDER.indexOf(b.exam_type))
})
const selectedGroup = ref('')
const currentGroup = computed(() => examGroups.value.find(g => g.key === selectedGroup.value) || examGroups.value[0])
function selectGroup(key) { selectedGroup.value = key; resetFilter() }
const groupPeriods = computed(() => [...(currentGroup.value?.periods || [])].sort((a, b) => a.academic_year - b.academic_year))
const currentPeriod = computed(() => groupPeriods.value[groupPeriods.value.length - 1] || null)

const subjectKeys = computed(() => [...(currentPeriod.value?.subjects || []).map(s => s.key), 'overall'])
const subjectLabels = computed(() => {
  const m = {}
  ;(currentPeriod.value?.subjects || []).forEach(s => { m[s.key] = s.label })
  m.overall = 'รวม'
  return m
})

const allScores = computed(() => currentPeriod.value?.scores || [])

// ── ตัวกรอง (เหมือนหน้า /student-stats) ────────────────────────────────────────
const filterDistrict = ref('all')
const filterCluster  = ref('all')
const filterSchool   = ref('all')
const searchQ        = ref('')

const districts = computed(() => [...new Set(allScores.value.map(s => s.district).filter(Boolean))].sort())
const clusters = computed(() => {
  const scoped = filterDistrict.value === 'all' ? allScores.value : allScores.value.filter(s => s.district === filterDistrict.value)
  return [...new Set(scoped.map(s => s.school_group).filter(Boolean))].sort()
})
const schoolsInDistrict = computed(() => {
  let list = allScores.value
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterCluster.value  !== 'all') list = list.filter(s => s.school_group === filterCluster.value)
  return list
})

function applyFilters(list) {
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterCluster.value  !== 'all') list = list.filter(s => s.school_group === filterCluster.value)
  if (filterSchool.value   !== 'all') list = list.filter(s => s.school_id === filterSchool.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(s => s.school_name?.toLowerCase().includes(q))
  }
  return list
}
const filteredScores = computed(() => applyFilters(allScores.value))

const isFiltered = computed(() =>
  filterDistrict.value !== 'all' || filterCluster.value !== 'all' || filterSchool.value !== 'all' || searchQ.value.trim()
)
function resetFilter() {
  filterDistrict.value = 'all'; filterCluster.value = 'all'; filterSchool.value = 'all'; searchQ.value = ''
}
function onDistrictChange() { filterCluster.value = 'all'; filterSchool.value = 'all' }
function onClusterChange()  { filterSchool.value = 'all' }

// ── สรุปผล (การ์ด + กระจายระดับคุณภาพ) ─────────────────────────────────────────
function avgOf(list, key) {
  const vals = list.filter(s => !hasNoEligible(s.scores)).map(s => s.scores?.[key]?.pct).filter(v => typeof v === 'number')
  if (!vals.length) return null
  return vals.reduce((a, b) => a + b, 0) / vals.length
}
function levelDistribution(list, key) {
  const counts = Object.fromEntries(QUALITY_LEVELS.map(l => [l, 0]))
  const eligible = list.filter(s => !hasNoEligible(s.scores))
  eligible.forEach(s => { const lvl = s.scores?.[key]?.level; if (lvl && counts[lvl] !== undefined) counts[lvl]++ })
  const total = eligible.length || 1
  return QUALITY_LEVELS.map(l => ({ level: l, count: counts[l], pct: Math.round((counts[l] / total) * 100) }))
}

// ── ค่าเฉลี่ยแยกตามศูนย์เครือข่าย (รวม) ────────────────────────────────────────
const clusterSort = ref('value_desc')
const CLUSTER_SORT_OPTIONS = [
  { value: 'value_desc', label: 'มากไปน้อย' },
  { value: 'value_asc',  label: 'น้อยไปมาก' },
  { value: 'name',       label: 'ชื่อศูนย์' },
]
const clusterAgg = computed(() => {
  const map = {}
  filteredScores.value.forEach(s => {
    const key = s.school_group || 'ไม่ระบุศูนย์'
    ;(map[key] ||= []).push(s)
  })
  // ศูนย์ที่ไม่มีโรงใดมีคะแนนเลย (ทุกโรงไม่มี นร. ในเกณฑ์) ไม่ใส่ในกราฟ แทนที่จะโชว์เป็น 0
  let entries = Object.entries(map)
    .map(([label, list]) => ({ label, avg: avgOf(list, 'overall') }))
    .filter(e => e.avg !== null)
    .map(e => ({ label: e.label, value: Math.round(e.avg * 10) / 10, bar: 'bg-indigo-500' }))
  if (clusterSort.value === 'name')       entries.sort((a, b) => a.label.localeCompare(b.label, 'th'))
  else if (clusterSort.value === 'value_asc') entries.sort((a, b) => a.value - b.value)
  else                                     entries.sort((a, b) => b.value - a.value)
  return entries
})

// ── ตารางรายโรงเรียน: เรียงได้แบบเดียวกับตารางศูนย์เครือข่าย + เลือกได้ว่าเรียงตามคะแนนวิชาไหน ──
const noEligibleCount = computed(() => filteredScores.value.filter(s => hasNoEligible(s.scores)).length)
const schoolSort = ref('value_desc')
const SCHOOL_SORT_OPTIONS = [
  { value: 'value_desc', label: 'มากไปน้อย' },
  { value: 'value_asc',  label: 'น้อยไปมาก' },
  { value: 'name',       label: 'ชื่อโรงเรียน' },
  { value: 'cluster',    label: 'ศูนย์เครือข่าย' },
]
const schoolSortKeyRaw = ref('overall')
// เปลี่ยนแท็บ/รอบแล้ววิชาที่เลือกไว้อาจไม่มีในรอบใหม่ → กลับไปใช้ "รวม"
const schoolSortKey = computed(() => subjectKeys.value.includes(schoolSortKeyRaw.value) ? schoolSortKeyRaw.value : 'overall')
const byThai = (a, b) => String(a || '').localeCompare(String(b || ''), 'th')
const schoolTableData = computed(() => {
  const key = schoolSortKey.value
  const val = s => (!hasNoEligible(s.scores) && typeof s.scores?.[key]?.pct === 'number' ? s.scores[key].pct : null)
  const list = [...filteredScores.value]
  if (schoolSort.value === 'name')    return list.sort((a, b) => byThai(a.school_name, b.school_name))
  if (schoolSort.value === 'cluster') return list.sort((a, b) => byThai(a.school_group, b.school_group) || byThai(a.school_name, b.school_name))
  const dir = schoolSort.value === 'value_asc' ? 1 : -1
  // โรงที่ไม่มีคะแนนวิชานั้นไปท้ายเสมอ ไม่ว่าเรียงขึ้นหรือลง
  return list.sort((a, b) => {
    const va = val(a), vb = val(b)
    if (va === null && vb === null) return byThai(a.school_name, b.school_name)
    if (va === null) return 1
    if (vb === null) return -1
    return (va - vb) * dir || byThai(a.school_name, b.school_name)
  })
})

// ── กราฟแนวโน้มข้ามปี — แอกทีฟตามตัวกรองด้านบน ─────────────────────────────────
const C = { W: 720, H: 260, PL: 44, PR: 20, PT: 20, PB: 40 }
const SUBJECT_COLOR = { math: '#3b82f6', thai: '#f97316', overall: '#8b5cf6' }
const trendPoints = computed(() => groupPeriods.value.map(p => ({ period: p, list: applyFilters(p.scores || []) })))
function yAt(v) { const h = C.H - C.PT - C.PB; return C.PT + h - (Math.max(0, Math.min(100, v)) / 100) * h }
function xAt(i) { const n = trendPoints.value.length; const w = C.W - C.PL - C.PR; const step = n > 1 ? w / (n - 1) : 0; return C.PL + (n > 1 ? step * i : w / 2) }
const chartLines = computed(() =>
  subjectKeys.value.map(key => ({
    key, label: subjectLabels.value[key], color: SUBJECT_COLOR[key] || '#64748b',
    points: trendPoints.value.map((tp, i) => {
      const v = avgOf(tp.list, key)
      return { x: xAt(i), y: v === null ? null : yAt(v), v, year: tp.period.academic_year }
    }),
  }))
)
function linePath(points) {
  const valid = points.filter(p => p.y !== null)
  if (valid.length < 2) return ''
  return valid.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ')
}
const yTicks = [0, 25, 50, 75, 100]
const hoveredPoint = ref(null)
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title" :subtitle="header.subtitle || config?.area_name"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="5xl"/>

    <div v-if="loading" class="flex justify-center py-24"><div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/></div>

    <div v-else-if="notStaff" class="max-w-xl mx-auto px-4 py-20 text-center">
      <span class="block text-5xl mb-4">🔒</span>
      <p class="font-extrabold text-slate-700 text-lg">ผลคะแนนนี้ดูได้เฉพาะศึกษานิเทศก์และเจ้าหน้าที่</p>
      <p class="text-sm text-slate-400 mt-2">บัญชีนี้ไม่มีสิทธิ์เข้าถึงข้อมูลผลคะแนน RT / NT / O-NET</p>
    </div>

    <div v-else class="max-w-5xl mx-auto px-4 py-8 space-y-8">
      <!-- แท็บประเภทสอบ+ชั้น — การ์ดเต็มความกว้าง 3 คอลัมน์ (มือถือคอลัมน์เดียว) -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <button v-for="g in examGroups" :key="g.key" @click="selectGroup(g.key)"
          :class="['rounded-2xl border-2 px-5 py-4 text-center transition-all',
            selectedGroup === g.key
              ? 'border-indigo-600 bg-indigo-50 shadow-md'
              : 'border-slate-200 bg-white/70 hover:border-indigo-300']">
          <p :class="['text-lg font-extrabold', selectedGroup === g.key ? 'text-indigo-700' : 'text-slate-700']">
            {{ EXAM_TYPE_LABEL[g.exam_type] }}<span v-if="g.grade_level"> {{ g.grade_level }}</span>
          </p>
          <p :class="['text-xs mt-1 font-bold', g.periods.length ? 'text-slate-400 font-medium' : 'text-amber-500']">
            {{ g.periods.length ? `${g.periods.length} ปีการศึกษา` : 'ยังไม่มีข้อมูล' }}
          </p>
        </button>
      </div>

      <div v-if="!currentPeriod" class="text-center py-16 text-slate-400">
        <p class="font-bold text-lg">ยังไม่มีข้อมูล {{ EXAM_TYPE_LABEL[currentGroup?.exam_type] }} ที่เผยแพร่ต่อสาธารณะ</p>
      </div>
      <template v-else>
      <p class="text-sm text-slate-500 text-center">
        {{ currentPeriod.title }} · ปีการศึกษา {{ currentPeriod.academic_year }}
      </p>

      <!-- Filter -->
      <div class="glass-tile p-4">
        <div class="flex flex-wrap items-center gap-3">
          <div class="relative flex-1 min-w-[200px]">
            <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/></svg>
            <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน..."
              class="w-full pl-9 pr-4 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
          <select v-model="filterDistrict" @change="onDistrictChange"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกอำเภอ</option>
            <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
          </select>
          <select v-model="filterCluster" @change="onClusterChange"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกศูนย์เครือข่าย</option>
            <option v-for="c in clusters" :key="c" :value="c">{{ c }}</option>
          </select>
          <select v-model="filterSchool"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-[180px]">
            <option value="all">ทุกโรงเรียน</option>
            <option v-for="s in schoolsInDistrict" :key="s.school_id" :value="s.school_id">{{ s.school_name }}</option>
          </select>
        </div>
        <div v-if="isFiltered" class="mt-2 flex items-center gap-2 flex-wrap">
          <div class="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"/>
          <p class="text-sm text-primary font-medium flex-1">กรองแล้ว: {{ filteredScores.length }} โรงเรียน</p>
          <button @click="resetFilter" class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 border border-red-200 rounded-full hover:bg-red-100 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            ล้างตัวกรองทั้งหมด
          </button>
        </div>
      </div>

      <!-- Stat cards -->
      <div class="grid gap-4" :class="subjectKeys.length === 3 ? 'md:grid-cols-3' : 'md:grid-cols-2'">
        <div v-for="key in subjectKeys" :key="key" class="rounded-2xl border border-indigo-100 bg-white/70 shadow-sm p-5">
          <p class="text-xs font-bold text-slate-500 uppercase tracking-wider text-center">{{ subjectLabels[key] }}</p>
          <p class="text-3xl font-extrabold text-indigo-600 text-center mt-1">{{ avgOf(filteredScores, key) !== null ? avgOf(filteredScores, key).toFixed(2) : '—' }}<span class="text-sm text-slate-400 font-medium"> %</span></p>
          <div class="mt-3 space-y-1.5">
            <div v-for="d in levelDistribution(filteredScores, key)" :key="d.level" class="flex items-center gap-2 text-xs">
              <span class="w-16 flex-shrink-0 text-slate-500">{{ d.level }}</span>
              <div class="flex-1 h-2.5 bg-slate-100 rounded-full overflow-hidden">
                <div class="h-full rounded-full" :style="`width:${d.pct}%; background:${QUALITY_COLOR[d.level]}`"/>
              </div>
              <span class="w-14 flex-shrink-0 text-right font-bold text-slate-600">{{ d.count }} ({{ d.pct }}%)</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ศูนย์เครือข่าย -->
      <div v-if="clusterAgg.length > 0" class="glass-tile p-5">
        <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
          <h3 class="font-bold text-slate-700">ค่าเฉลี่ยรวมแยกตามศูนย์เครือข่าย</h3>
          <div class="flex gap-1 bg-slate-100 p-1 rounded-lg">
            <button v-for="opt in CLUSTER_SORT_OPTIONS" :key="opt.value" @click="clusterSort = opt.value"
              :class="['px-2.5 py-1 text-xs font-bold rounded-md transition-colors',
                clusterSort === opt.value ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700']">
              {{ opt.label }}
            </button>
          </div>
        </div>
        <BarChart :items="clusterAgg"/>
      </div>

      <!-- School table -->
      <div class="glass-tile overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50 flex flex-wrap items-center justify-between gap-2">
          <div>
            <h3 class="font-bold text-slate-700">ข้อมูลรายโรงเรียน ({{ filteredScores.length }} โรงเรียน)</h3>
            <p v-if="noEligibleCount" class="text-[11px] text-amber-600 mt-0.5">
              มี {{ noEligibleCount }} โรงที่{{ NO_ELIGIBLE_TEXT }} — ไม่นับในค่าเฉลี่ยและการจัดอันดับ
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <!-- เลือกวิชาที่ใช้เรียง (เฉพาะโหมดเรียงตามคะแนน) -->
            <select v-if="schoolSort === 'value_desc' || schoolSort === 'value_asc'" v-model="schoolSortKeyRaw"
              aria-label="เรียงตามคะแนนวิชา"
              class="px-2.5 py-1.5 text-xs font-bold rounded-lg border border-slate-200 bg-white text-slate-600 focus:outline-none focus:border-primary">
              <option v-for="key in subjectKeys" :key="key" :value="key">เรียงตาม: {{ subjectLabels[key] }}</option>
            </select>
            <div class="flex gap-1 bg-slate-100 p-1 rounded-lg">
              <button v-for="opt in SCHOOL_SORT_OPTIONS" :key="opt.value" @click="schoolSort = opt.value" type="button"
                :class="['px-2.5 py-1 text-xs font-bold rounded-md transition-colors',
                  schoolSort === opt.value ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700']">
                {{ opt.label }}
              </button>
            </div>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead><tr class="bg-slate-50 text-slate-500 text-left">
              <th class="px-4 py-3 font-bold">#</th>
              <th class="px-4 py-3 font-bold">โรงเรียน</th>
              <th class="px-4 py-3 font-bold">ศูนย์เครือข่าย</th>
              <th v-for="key in subjectKeys" :key="key" class="px-4 py-3 font-bold text-right">{{ subjectLabels[key] }}</th>
            </tr></thead>
            <tbody class="divide-y divide-slate-50">
              <tr v-for="(s, i) in schoolTableData" :key="s.school_id" class="hover:bg-slate-50 transition-colors cursor-pointer" @click="filterSchool = s.school_id; filterDistrict = 'all'">
                <td class="px-4 py-3 text-slate-400">{{ i + 1 }}</td>
                <td class="px-4 py-3 font-medium text-slate-700">{{ s.school_name }}</td>
                <td class="px-4 py-3 text-slate-500">{{ s.school_group }}</td>
                <td v-if="hasNoEligible(s.scores)" :colspan="subjectKeys.length" class="px-4 py-3 text-right text-amber-600 text-[11px] font-bold">
                  — {{ NO_ELIGIBLE_TEXT }}
                </td>
                <template v-else>
                  <td v-for="key in subjectKeys" :key="key" class="px-4 py-3 text-right">
                    <span class="font-bold text-slate-700">{{ s.scores?.[key]?.pct ?? '—' }}</span>
                    <span v-if="s.scores?.[key]?.level" class="ml-1.5 text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                      :style="`background:${QUALITY_COLOR[s.scores[key].level]}22; color:${QUALITY_COLOR[s.scores[key].level]}`">
                      {{ s.scores[key].level }}
                    </span>
                  </td>
                </template>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- แนวโน้มข้ามปี -->
      <div v-if="groupPeriods.length >= 2" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 text-center">แนวโน้มผลคะแนนข้ามปี</h3>
        <p class="text-sm text-slate-400 text-center mb-4">{{ isFiltered ? 'ตามตัวกรองที่เลือกไว้ด้านบน' : 'ค่าเฉลี่ยรวมทั้งเขต' }}</p>
        <div class="flex flex-wrap justify-center gap-4 mb-3">
          <div v-for="l in chartLines" :key="l.key" class="flex items-center gap-1.5 text-xs">
            <span class="w-3 h-3 rounded-full" :style="`background:${l.color}`"/>{{ l.label }}
          </div>
        </div>
        <svg :viewBox="`0 0 ${C.W} ${C.H}`" class="w-full" style="max-height:300px">
          <line v-for="t in yTicks" :key="t" :x1="C.PL" :x2="C.W - C.PR" :y1="yAt(t)" :y2="yAt(t)" stroke="#e5e7eb" stroke-width="1"/>
          <text v-for="t in yTicks" :key="'y'+t" :x="C.PL - 8" :y="yAt(t) + 4" text-anchor="end" font-size="11" fill="#9ca3af">{{ t }}</text>
          <text v-for="(tp, i) in trendPoints" :key="'x'+tp.period.id" :x="xAt(i)" :y="C.H - C.PB + 20" text-anchor="middle" font-size="11" fill="#6b7280">{{ tp.period.academic_year }}</text>
          <g v-for="l in chartLines" :key="l.key">
            <path :d="linePath(l.points)" fill="none" :stroke="l.color" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>
            <circle v-for="(pt, i) in l.points.filter(p => p.y !== null)" :key="i" :cx="pt.x" :cy="pt.y" r="4"
              :fill="l.color" stroke="white" stroke-width="1.5" class="cursor-pointer"
              @mouseenter="hoveredPoint = { ...pt, label: l.label, color: l.color }" @mouseleave="hoveredPoint = null"/>
          </g>
          <g v-if="hoveredPoint">
            <rect :x="hoveredPoint.x - 55" :y="hoveredPoint.y - 42" width="110" height="34" rx="6" fill="#1e1b4b" opacity="0.92"/>
            <text :x="hoveredPoint.x" :y="hoveredPoint.y - 27" text-anchor="middle" font-size="10" fill="white">{{ hoveredPoint.label }} · {{ hoveredPoint.year }}</text>
            <text :x="hoveredPoint.x" :y="hoveredPoint.y - 13" text-anchor="middle" font-size="13" fill="#a5b4fc" font-weight="700">{{ hoveredPoint.v?.toFixed(2) }}%</text>
          </g>
        </svg>
      </div>

      <p class="text-center text-sm text-slate-400 pb-6">ข้อมูลจากรายงาน NT/O-NET สทศ. · {{ config?.area_name }}<span v-if="isFiltered"> · <button @click="resetFilter" class="text-primary hover:underline">ล้างตัวกรอง</button></span></p>
      </template>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
