<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import {
  LEVEL_LABEL, sortedGrades, KEY_STAGES, EXAM_ELIGIBILITY, matchesKeyStage, matchesExam,
} from '../composables/useDmcParser'
import PageHero from '../components/PageHero.vue'
import BarChart from '../components/awards/BarChart.vue'

const { config } = useAreaConfig()
const header = usePageHeader('studentStats', { icon: 'students', title: 'สารสนเทศนักเรียน', align: 'center' })
const loading = ref(true)
const data    = ref(null)
const error   = ref(null)

// ── สมาชิกที่ล็อกอินแล้ว — เห็นปุ่มส่งออกข้อมูลตามที่กรองไว้ ─────────────────
const userSession = ref(null)

// ── แนวโน้มข้ามภาคเรียน (ท้ายหน้า) — ข้อมูลนิ่ง ไม่ผูกกับตัวกรองด้านบน ──────
const trend        = ref([])
const loadingTrend = ref(true)

onMounted(async () => {
  const { data: d, error: e } = await supabase.rpc('get_dmc_public_stats')
  if (e || d?.error) { error.value = 'ยังไม่มีข้อมูลสถิตินักเรียนสาธารณะ'; loading.value = false; return }
  data.value    = d
  loading.value = false

  const { data: { session: s } } = await supabase.auth.getSession()
  userSession.value = s

  const { data: t } = await supabase.rpc('get_dmc_public_trend')
  trend.value = t || []
  loadingTrend.value = false
})

const period     = computed(() => data.value?.period)
const vis        = computed(() => data.value?.visibility || {})
const allUploads = computed(() => data.value?.uploads || [])

const districts = computed(() => {
  const set = new Set()
  allUploads.value.forEach(u => { if (u.district) set.add(u.district) })
  return [...set].sort()
})
const clusters = computed(() => {
  const set = new Set()
  allUploads.value.forEach(u => { if (u.school_group) set.add(u.school_group) })
  return [...set].sort()
})
const LEVEL_OPTIONS = [
  { value: 'primary',   label: LEVEL_LABEL.primary },
  { value: 'extended',  label: LEVEL_LABEL.extended },
  { value: 'secondary', label: LEVEL_LABEL.secondary },
]

const filterDistrict  = ref('all')
const filterCluster   = ref('all')
const filterLevel     = ref('all')
const filterSchool    = ref('all')
const searchQ         = ref('')
const filterKeyStage  = ref(null) // 1-4 หรือ null
const filterExam      = ref(null) // key ใน EXAM_ELIGIBILITY หรือ null

// ปุ่มไหนไม่มีโรงเรียนเข้าเงื่อนไขเลยในรอบนี้ (เช็คจากข้อมูลทั้งหมด ไม่ใช่ที่กรองแล้ว) ไม่ต้องแสดง
const availableKeyStages = computed(() =>
  KEY_STAGES.filter(s => allUploads.value.some(u => matchesKeyStage(u.summary?.by_grade, s.key)))
)
const availableExams = computed(() =>
  EXAM_ELIGIBILITY.filter(e => allUploads.value.some(u => matchesExam(u.summary?.by_grade, e.key)))
)

const schoolsInDistrict = computed(() => {
  if (filterDistrict.value === 'all') return allUploads.value
  return allUploads.value.filter(u => u.district === filterDistrict.value)
})

const filteredUploads = computed(() => {
  let list = allUploads.value
  if (filterDistrict.value !== 'all') list = list.filter(u => u.district === filterDistrict.value)
  if (filterCluster.value  !== 'all') list = list.filter(u => u.school_group === filterCluster.value)
  if (filterLevel.value    !== 'all') list = list.filter(u => u.level === filterLevel.value)
  if (filterSchool.value !== 'all')   list = list.filter(u => u.school_id === filterSchool.value)
  if (filterKeyStage.value !== null)  list = list.filter(u => matchesKeyStage(u.summary?.by_grade, filterKeyStage.value))
  if (filterExam.value !== null)      list = list.filter(u => matchesExam(u.summary?.by_grade, filterExam.value))
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(u => u.school_name?.toLowerCase().includes(q))
  }
  return list
})

const isFiltered = computed(() =>
  filterDistrict.value !== 'all' || filterCluster.value !== 'all' || filterLevel.value !== 'all' ||
  filterSchool.value !== 'all' || searchQ.value.trim() || filterKeyStage.value !== null || filterExam.value !== null
)

function resetFilter() {
  filterDistrict.value = 'all'; filterCluster.value = 'all'; filterLevel.value = 'all'
  filterSchool.value = 'all'; searchQ.value = ''; filterKeyStage.value = null; filterExam.value = null
}
function onDistrictChange() { filterSchool.value = 'all' }

// ── ยอดแยกตามศูนย์เครือข่าย ──────────────────────────────────────────────
const clusterAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const key = u.school_group || 'ไม่ระบุศูนย์'
    map[key] = (map[key] || 0) + (u.total || 0)
  })
  return Object.entries(map).sort((a,b) => b[1]-a[1]).map(([label, value]) => ({ label, value, bar: 'bg-primary' }))
})

const totalStudents = computed(() => filteredUploads.value.reduce((s, u) => s + u.total, 0))
const genderMale    = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.gender?.male || 0), 0))
const genderFemale  = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.gender?.female || 0), 0))
const disadvCount   = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.disadvantaged?.count || 0), 0))
const disadvPct     = computed(() => totalStudents.value > 0 ? ((disadvCount.value / totalStudents.value) * 100).toFixed(1) : '0')

const bmiAgg = computed(() => {
  let u=0,n=0,o=0,ob=0
  filteredUploads.value.forEach(up => {
    const b=up.summary?.bmi||{}; u+=b.underweight||0; n+=b.normal||0; o+=b.overweight||0; ob+=b.obese||0
  })
  return { underweight:u, normal:n, overweight:o, obese:ob, total:u+n+o+ob }
})

const gradeAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    Object.entries(u.summary?.by_grade||{}).forEach(([g,d]) => {
      if (!map[g]) map[g] = { total:0, male:0, female:0 }
      map[g].total+=d.total||0; map[g].male+=d.male||0; map[g].female+=d.female||0
    })
  })
  return sortedGrades(map)
})

const guardianAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    Object.entries(u.summary?.guardian_relation||{}).forEach(([k,v]) => { map[k]=(map[k]||0)+v })
  })
  return Object.entries(map).sort((a,b)=>b[1]-a[1]).slice(0,8)
})

const gradeOpts = computed(() => ({
  chart: { type:'bar', height:240, toolbar:{show:false} },
  plotOptions: { bar: { borderRadius:4, columnWidth:'60%' } },
  colors: ['#3b82f6','#ec4899'],
  xaxis: { categories: Object.keys(gradeAgg.value), labels:{ style:{ fontFamily:'Sarabun', fontSize:'11px' } } },
  legend: { position:'top', fontFamily:'Sarabun' }, dataLabels:{enabled:false},
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const bmiOpts = computed(() => ({
  chart: { type:'donut', height:200 },
  labels: ['ต่ำกว่าเกณฑ์','ปกติ','น้ำหนักเกิน','อ้วน'],
  colors: ['#f97316','#10b981','#f59e0b','#ef4444'],
  legend: { position:'bottom', fontFamily:'Sarabun', fontSize:'11px' },
  plotOptions: { pie:{ donut:{ size:'65%' } } },
  dataLabels: { style:{ fontSize:'11px' } },
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const guardianOpts = computed(() => ({
  chart: { type:'bar', height:220, toolbar:{show:false} },
  plotOptions: { bar: { borderRadius:4, horizontal:true } },
  colors: ['#6366f1'],
  xaxis: { categories: guardianAgg.value.map(d=>d[0]), labels:{ style:{ fontFamily:'Sarabun', fontSize:'11px' } } },
  dataLabels: { enabled:true, style:{ fontSize:'11px' } }, legend:{ show:false },
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const schoolTableData = computed(() =>
  filteredUploads.value.map(u => ({
    id: u.school_id, name: u.school_name, total: u.total,
    male: u.summary?.gender?.male||0, female: u.summary?.gender?.female||0,
    disadv: u.summary?.disadvantaged?.count||0, disadvPct: u.summary?.disadvantaged?.pct||'0',
    bmiNormal: u.summary?.bmi?.normal||0,
  })).sort((a,b)=>b.total-a.total)
)

function formatDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'long', day:'numeric' })
}

// ── ส่งออกข้อมูลตามตัวกรองปัจจุบัน (เฉพาะสมาชิกที่ล็อกอิน) ───────────────────
function exportFilteredCSV() {
  const header = ['โรงเรียน', 'ศูนย์เครือข่าย', 'อำเภอ']
  if (vis.value.total)    header.push('จำนวนทั้งหมด')
  if (vis.value.gender)   header.push('ชาย', 'หญิง')
  if (vis.value.disadvantaged) header.push('ยากจน%')
  if (vis.value.bmi)      header.push('BMI ปกติ%')

  const rows = schoolTableData.value.map(s => {
    const u = filteredUploads.value.find(x => x.school_id === s.id)
    const row = [s.name, u?.school_group || '', u?.district || '']
    if (vis.value.total)    row.push(s.total)
    if (vis.value.gender)   row.push(s.male, s.female)
    if (vis.value.disadvantaged) row.push(s.disadvPct)
    if (vis.value.bmi)      row.push(s.total > 0 ? ((s.bmiNormal/s.total)*100).toFixed(1) : '0')
    return row
  })
  const csv = [header, ...rows].map(r => r.map(c => `"${String(c).replace(/"/g,'""')}"`).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `student_stats_${period.value?.academic_year}_${period.value?.semester}_${new Date().toISOString().slice(0,10)}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

// ── กราฟแนวโน้มข้ามภาคเรียน (static) ─────────────────────────────────────────
const trendLabels = computed(() => trend.value.map(t => t.title || `${t.academic_year}/${t.semester}`))
const trendOpts = computed(() => ({
  chart: { type: 'bar', height: 260, toolbar: { show: false } },
  plotOptions: { bar: { borderRadius: 4, columnWidth: '50%' } },
  colors: ['#2563eb'],
  xaxis: { categories: trendLabels.value, labels: { style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
  dataLabels: { enabled: true, style: { fontSize: '11px' }, formatter: v => v.toLocaleString() },
  tooltip: { y: { formatter: v => (v || 0).toLocaleString() + ' คน' } },
}))
const trendSeries = computed(() => [{ name: 'นักเรียนรวม', data: trend.value.map(t => t.total) }])
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || config?.area_name"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="5xl"/>

    <div v-if="loading" class="flex justify-center py-24"><div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/></div>
    <div v-else-if="error || !data" class="text-center py-24 text-slate-400">
      <p class="font-bold text-lg">{{ error || 'ยังไม่มีข้อมูลสถิติสาธารณะ' }}</p>
    </div>

    <div v-else class="max-w-5xl mx-auto px-4 py-8 space-y-8">

      <!-- ── บทนำ: จัดกลางจอ พร้อมตัวเลขหลักของทั้งเขต ── -->
      <div class="text-center space-y-4">
        <p class="text-sm text-slate-500">
          ปีการศึกษา {{ period.academic_year }} ภาคเรียนที่ {{ period.semester }} · เผยแพร่ {{ formatDate(period.archived_at) }}
        </p>
        <div class="flex justify-center gap-4 flex-wrap">
          <div class="glass-tile px-6 py-4 text-center min-w-[140px]">
            <p class="text-3xl font-extrabold text-primary">{{ data.total_schools }}</p>
            <p class="text-sm text-slate-500 mt-1">โรงเรียน</p>
          </div>
          <div class="glass-tile px-6 py-4 text-center min-w-[140px]">
            <p class="text-3xl font-extrabold text-primary">{{ allUploads.reduce((s,u)=>s+u.total,0).toLocaleString() }}</p>
            <p class="text-sm text-slate-500 mt-1">นักเรียนทั้งเขต</p>
          </div>
        </div>
      </div>

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
          <select v-model="filterCluster"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกศูนย์เครือข่าย</option>
            <option v-for="c in clusters" :key="c" :value="c">{{ c }}</option>
          </select>
          <select v-model="filterLevel"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกระดับ</option>
            <option v-for="lv in LEVEL_OPTIONS" :key="lv.value" :value="lv.value">{{ lv.label }}</option>
          </select>
          <select v-model="filterSchool"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-[180px]">
            <option value="all">ทุกโรงเรียน</option>
            <option v-for="u in schoolsInDistrict" :key="u.school_id" :value="u.school_id">{{ u.school_name }}</option>
          </select>
          <button v-if="isFiltered" @click="resetFilter" class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-red-500 transition-colors px-2 py-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            ล้าง
          </button>
          <!-- ส่งออกข้อมูลตามตัวกรอง — เห็นเฉพาะสมาชิกที่ล็อกอินแล้ว -->
          <button v-if="userSession" @click="exportFilteredCSV"
            class="flex items-center gap-1.5 px-3 py-2.5 text-sm font-bold bg-emerald-600 text-white rounded-xl hover:-translate-y-0.5 shadow-sm transition-all">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/>
            </svg>
            ส่งออกข้อมูล
          </button>
        </div>
        <div v-if="isFiltered" class="mt-2 flex items-center gap-2">
          <div class="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"/>
          <p class="text-sm text-primary font-medium">กรองแล้ว: {{ filteredUploads.length }} โรงเรียน · {{ totalStudents.toLocaleString() }} นักเรียน</p>
        </div>

        <!-- ปุ่มช่วงชั้น -->
        <div v-if="availableKeyStages.length > 0" class="flex flex-wrap items-center gap-2 mt-3 pt-3 border-t border-slate-100">
          <span class="text-xs font-bold text-slate-400 uppercase tracking-wider">ช่วงชั้น</span>
          <button v-for="s in availableKeyStages" :key="s.key"
            @click="filterKeyStage = filterKeyStage === s.key ? null : s.key"
            :class="['px-3 py-1.5 text-xs font-bold rounded-full border transition-colors',
              filterKeyStage === s.key ? 'bg-primary text-white border-primary' : 'bg-white text-slate-600 border-slate-200 hover:border-primary']">
            {{ s.label }}
          </button>
        </div>

        <!-- ปุ่มสิทธิ์สอบ -->
        <div v-if="availableExams.length > 0" class="flex flex-wrap items-center gap-2 mt-3">
          <span class="text-xs font-bold text-slate-400 uppercase tracking-wider">สิทธิ์สอบ</span>
          <button v-for="e in availableExams" :key="e.key"
            @click="filterExam = filterExam === e.key ? null : e.key"
            :class="['px-3 py-1.5 text-xs font-bold rounded-full border transition-colors',
              filterExam === e.key ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-slate-600 border-slate-200 hover:border-indigo-400']">
            {{ e.label }}
          </button>
        </div>
      </div>

      <!-- Stats cards -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div v-if="vis.total || vis.gender" class="glass-tile p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ totalStudents.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">นักเรียนทั้งหมด</p>
        </div>
        <div v-if="vis.gender" class="bg-blue-50 rounded-2xl border border-blue-100 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-blue-600">{{ genderMale.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">ชาย</p>
        </div>
        <div v-if="vis.gender" class="bg-pink-50 rounded-2xl border border-pink-100 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-pink-500">{{ genderFemale.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">หญิง</p>
        </div>
        <div v-if="vis.disadvantaged" :class="['rounded-2xl border shadow-sm p-4 text-center', Number(disadvPct)>50?'bg-red-50 border-red-200':'bg-amber-50 border-amber-100']">
          <p :class="['text-3xl font-extrabold', Number(disadvPct)>50?'text-red-600':'text-amber-600']">{{ disadvPct }}%</p>
          <p class="text-xs text-slate-500 mt-1">เด็กยากจน {{ disadvCount.toLocaleString() }} คน</p>
        </div>
      </div>

      <!-- ศูนย์เครือข่าย -->
      <div v-if="clusterAgg.length > 0" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 mb-4 text-center">นักเรียนแยกตามศูนย์เครือข่าย</h3>
        <BarChart :items="clusterAgg"/>
      </div>

      <!-- Grade chart -->
      <div v-if="vis.by_grade && Object.keys(gradeAgg).length > 0" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 mb-4 text-center">จำนวนนักเรียนแยกตามระดับชั้น</h3>
        <apexchart type="bar" :height="240" :options="gradeOpts"
          :series="[{ name:'ชาย', data:Object.values(gradeAgg).map(g=>g.male) },{ name:'หญิง', data:Object.values(gradeAgg).map(g=>g.female) }]"
          :key="`grade-${filteredUploads.length}`"/>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <div v-if="vis.bmi && bmiAgg.total > 0" class="glass-tile p-5">
          <h3 class="font-bold text-slate-700 mb-4 text-center">ภาวะโภชนาการ (BMI)</h3>
          <apexchart type="donut" :height="200" :options="bmiOpts" :series="[bmiAgg.underweight,bmiAgg.normal,bmiAgg.overweight,bmiAgg.obese]" :key="`bmi-${filteredUploads.length}`"/>
          <div class="mt-3 space-y-1.5">
            <div v-for="(item,i) in [{ label:'ต่ำกว่าเกณฑ์',val:bmiAgg.underweight,color:'text-orange-500' },{ label:'ปกติ',val:bmiAgg.normal,color:'text-emerald-500' },{ label:'น้ำหนักเกิน',val:bmiAgg.overweight,color:'text-amber-500' },{ label:'อ้วน',val:bmiAgg.obese,color:'text-red-500' }]" :key="i" class="flex items-center gap-2 text-xs">
              <span class="flex-1 text-slate-600">{{ item.label }}</span>
              <span :class="['font-bold', item.color]">{{ item.val.toLocaleString() }}</span>
              <span class="text-slate-400 w-12 text-right">{{ bmiAgg.total>0?((item.val/bmiAgg.total)*100).toFixed(1):0 }}%</span>
            </div>
          </div>
        </div>
        <div v-if="vis.guardian_relation && guardianAgg.length > 0" class="glass-tile p-5">
          <h3 class="font-bold text-slate-700 mb-4 text-center">ผู้ปกครอง (ความสัมพันธ์)</h3>
          <apexchart type="bar" :height="220" :options="guardianOpts" :series="[{ name:'จำนวน', data:guardianAgg.map(d=>d[1]) }]" :key="`guardian-${filteredUploads.length}`"/>
        </div>
      </div>

      <!-- School table -->
      <div class="glass-tile overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50">
          <h3 class="font-bold text-slate-700">ข้อมูลรายโรงเรียน ({{ filteredUploads.length }} โรง)</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead><tr class="bg-slate-50 text-slate-500 text-left">
              <th class="px-4 py-3 font-bold">#</th>
              <th class="px-4 py-3 font-bold">โรงเรียน</th>
              <th v-if="vis.total" class="px-4 py-3 font-bold text-right">รวม</th>
              <th v-if="vis.gender" class="px-4 py-3 font-bold text-right">ชาย</th>
              <th v-if="vis.gender" class="px-4 py-3 font-bold text-right">หญิง</th>
              <th v-if="vis.disadvantaged" class="px-4 py-3 font-bold text-right">ยากจน%</th>
              <th v-if="vis.bmi" class="px-4 py-3 font-bold text-right">BMI ปกติ%</th>
            </tr></thead>
            <tbody class="divide-y divide-slate-50">
              <tr v-for="(s,i) in schoolTableData" :key="s.id" class="hover:bg-slate-50 transition-colors cursor-pointer" @click="filterSchool=s.id;filterDistrict='all'">
                <td class="px-4 py-3 text-slate-400">{{ i+1 }}</td>
                <td class="px-4 py-3 font-medium text-slate-700">
                  <div class="flex items-center gap-2">{{ s.name }}<svg v-if="filterSchool===s.id" class="w-3.5 h-3.5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg></div>
                </td>
                <td v-if="vis.total" class="px-4 py-3 text-right font-bold text-slate-700">{{ s.total.toLocaleString() }}</td>
                <td v-if="vis.gender" class="px-4 py-3 text-right text-blue-600">{{ s.male.toLocaleString() }}</td>
                <td v-if="vis.gender" class="px-4 py-3 text-right text-pink-500">{{ s.female.toLocaleString() }}</td>
                <td v-if="vis.disadvantaged" class="px-4 py-3 text-right"><span :class="['font-bold',Number(s.disadvPct)>50?'text-red-500':'text-amber-600']">{{ s.disadvPct }}%</span></td>
                <td v-if="vis.bmi" class="px-4 py-3 text-right text-emerald-600 font-bold">{{ s.total>0?((s.bmiNormal/s.total)*100).toFixed(1):0 }}%</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ── แนวโน้มข้ามภาคเรียน (ท้ายหน้า) — ข้อมูลนิ่ง ไม่ผูกกับตัวกรองด้านบน ── -->
      <div v-if="!loadingTrend && trend.length >= 2" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 text-center">แนวโน้มจำนวนนักเรียนย้อนหลัง</h3>
        <p class="text-sm text-slate-400 text-center mb-4">ยอดรวมทั้งเขตในแต่ละภาคเรียนที่เผยแพร่ต่อสาธารณะ</p>
        <apexchart type="bar" :height="260" :options="trendOpts" :series="trendSeries"/>
      </div>

      <p class="text-center text-sm text-slate-400 pb-6">ข้อมูลจากระบบ DMC · {{ config?.area_name }}<span v-if="isFiltered"> · <button @click="resetFilter" class="text-primary hover:underline">ล้างตัวกรอง</button></span></p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
