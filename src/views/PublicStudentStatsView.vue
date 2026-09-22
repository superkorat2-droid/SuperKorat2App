<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import {
  sortedGrades, KEY_STAGES, EXAM_ELIGIBILITY, matchesKeyStage, matchesExam,
  BROAD_LEVEL_GRADES, BROAD_LEVEL_LABEL, matchesGrades,
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

// ApexCharts บางทีไม่วาด point annotation ตอน mount รอบแรก (ต้องมี re-render อีกรอบ
// annotation ถึงจะขึ้น) — บังคับ re-render กราฟรายชั้นอีกครั้งอัตโนมัติหลังข้อมูลมาครบ
// โดยผู้ใช้ไม่ต้องกดตัวกรองก่อน (ดู :key ของ apexchart รายชั้นด้านล่าง)
const chartRenderTick = ref(0)

onMounted(async () => {
  const { data: d, error: e } = await supabase.rpc('get_dmc_public_stats')
  if (e || d?.error) { error.value = 'ยังไม่มีข้อมูลสถิตินักเรียนสาธารณะ'; loading.value = false; return }
  data.value    = d
  loading.value = false
  await nextTick()
  chartRenderTick.value++

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
// ศูนย์เครือข่ายต้องสัมพันธ์กับอำเภอที่เลือกไว้ — ไม่งั้นเลือกอำเภอแล้วยังเห็นศูนย์
// จากอำเภออื่นปนอยู่ ดูไม่สัมพันธ์กัน
const clusters = computed(() => {
  const scoped = filterDistrict.value === 'all'
    ? allUploads.value
    : allUploads.value.filter(u => u.district === filterDistrict.value)
  const set = new Set()
  scoped.forEach(u => { if (u.school_group) set.add(u.school_group) })
  return [...set].sort()
})

const filterDistrict  = ref('all')
const filterCluster   = ref('all')
const filterLevel     = ref('all')
const filterSchool    = ref('all')
const searchQ         = ref('')
const filterKeyStage  = ref(null) // 1-4 หรือ null
const filterExam      = ref(null) // key ใน EXAM_ELIGIBILITY หรือ null

// ปุ่ม/ตัวเลือกไหนไม่มีโรงเรียนเข้าเงื่อนไขเลยในรอบนี้ (เช็คจากข้อมูลทั้งหมด ไม่ใช่ที่กรองแล้ว) ไม่ต้องแสดง
const availableKeyStages = computed(() =>
  KEY_STAGES.filter(s => allUploads.value.some(u => matchesKeyStage(u.summary?.by_grade, s.key)))
)
const availableExams = computed(() =>
  EXAM_ELIGIBILITY.filter(e => allUploads.value.some(u => matchesExam(u.summary?.by_grade, e.key)))
)
const availableLevels = computed(() =>
  Object.keys(BROAD_LEVEL_LABEL).filter(k =>
    allUploads.value.some(u => matchesGrades(u.summary?.by_grade, BROAD_LEVEL_GRADES[k]))
  )
)

// โรงเรียนในตัวเลือก dropdown ต้องสัมพันธ์กับทั้งอำเภอ + ศูนย์เครือข่ายที่เลือกไว้
const schoolsInDistrict = computed(() => {
  let list = allUploads.value
  if (filterDistrict.value !== 'all') list = list.filter(u => u.district === filterDistrict.value)
  if (filterCluster.value  !== 'all') list = list.filter(u => u.school_group === filterCluster.value)
  return list
})

// ตัวกรองชุดเดียวกันนี้ใช้ทั้งกับยอดรอบปัจจุบัน (filteredUploads) และกราฟแนวโน้ม
// ข้ามรอบด้านล่าง (ใช้ apply ซ้ำกับ uploads ของแต่ละรอบในอดีตได้เลย ไม่ต้องเขียนใหม่)
function applyFilters(list) {
  if (filterDistrict.value !== 'all') list = list.filter(u => u.district === filterDistrict.value)
  if (filterCluster.value  !== 'all') list = list.filter(u => u.school_group === filterCluster.value)
  if (filterLevel.value    !== 'all') list = list.filter(u => matchesGrades(u.summary?.by_grade, BROAD_LEVEL_GRADES[filterLevel.value]))
  if (filterSchool.value !== 'all')   list = list.filter(u => u.school_id === filterSchool.value)
  if (filterKeyStage.value !== null)  list = list.filter(u => matchesKeyStage(u.summary?.by_grade, filterKeyStage.value))
  if (filterExam.value !== null)      list = list.filter(u => matchesExam(u.summary?.by_grade, filterExam.value))
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(u => u.school_name?.toLowerCase().includes(q))
  }
  return list
}

const filteredUploads = computed(() => applyFilters(allUploads.value))

const isFiltered = computed(() =>
  filterDistrict.value !== 'all' || filterCluster.value !== 'all' || filterLevel.value !== 'all' ||
  filterSchool.value !== 'all' || searchQ.value.trim() || filterKeyStage.value !== null || filterExam.value !== null
)

function resetFilter() {
  filterDistrict.value = 'all'; filterCluster.value = 'all'; filterLevel.value = 'all'
  filterSchool.value = 'all'; searchQ.value = ''; filterKeyStage.value = null; filterExam.value = null
}
// เปลี่ยนอำเภอ → ศูนย์เครือข่าย/โรงเรียนที่เคยเลือกไว้อาจไม่มีอยู่ในอำเภอใหม่แล้ว รีเซ็ตกัน
// ตัวเลือกค้างที่ไม่มีอยู่จริง / เปลี่ยนศูนย์เครือข่าย → โรงเรียนที่เคยเลือกไว้ก็รีเซ็ตเช่นกัน
function onDistrictChange() { filterCluster.value = 'all'; filterSchool.value = 'all' }
function onClusterChange()  { filterSchool.value = 'all' }

// ── ขอบเขตชั้นที่กำลังดู (null = ทุกชั้น) — รวมทุกตัวกรองที่ตัดกรอบชั้นได้
// (ระดับ/ช่วงชั้น/สิทธิ์สอบ) เข้าด้วยกันแบบ intersect เผื่อเลือกพร้อมกันหลายตัว
// ปุ่มพวกนี้ไม่ได้แค่เลือกโรงเรียนที่มีชั้นนี้ แต่ต้องนับตัวเลขเฉพาะชั้นนั้นด้วย
// ไม่ใช่ยอดรวมทั้งโรงเรียน
function intersectGrades(a, b) {
  if (!a) return b
  if (!b) return a
  return a.filter(g => b.includes(g))
}
const activeGradeScope = computed(() => {
  let scope = null
  if (filterLevel.value !== 'all') scope = intersectGrades(scope, BROAD_LEVEL_GRADES[filterLevel.value])
  if (filterKeyStage.value !== null) {
    const stage = KEY_STAGES.find(s => s.key === filterKeyStage.value)
    scope = intersectGrades(scope, stage ? stage.grades : [])
  }
  if (filterExam.value !== null) {
    const exam = EXAM_ELIGIBILITY.find(e => e.key === filterExam.value)
    scope = intersectGrades(scope, exam ? [exam.grade] : [])
  }
  return scope
})

function scopedTotals(u) {
  if (!activeGradeScope.value) {
    return { total: u.total || 0, male: u.summary?.gender?.male || 0, female: u.summary?.gender?.female || 0 }
  }
  const byGrade = u.summary?.by_grade || {}
  let total = 0, male = 0, female = 0
  activeGradeScope.value.forEach(g => {
    const d = byGrade[g]
    if (d) { total += d.total || 0; male += d.male || 0; female += d.female || 0 }
  })
  return { total, male, female }
}

function scopedByGrade(u) {
  const byGrade = u.summary?.by_grade || {}
  if (!activeGradeScope.value) return byGrade
  const result = {}
  activeGradeScope.value.forEach(g => { if (byGrade[g]) result[g] = byGrade[g] })
  return result
}

// ── ยอดแยกตามศูนย์เครือข่าย ──────────────────────────────────────────────
// เรียงได้ 3 แบบ: มากไปน้อย (ค่าเริ่มต้น) / น้อยไปมาก / ตามชื่อศูนย์
const clusterSort = ref('value_desc')
const CLUSTER_SORT_OPTIONS = [
  { value: 'value_desc', label: 'มากไปน้อย' },
  { value: 'value_asc',  label: 'น้อยไปมาก' },
  { value: 'name',       label: 'ชื่อศูนย์' },
]
const clusterAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const key = u.school_group || 'ไม่ระบุศูนย์'
    map[key] = (map[key] || 0) + scopedTotals(u).total
  })
  const entries = Object.entries(map)
  if (clusterSort.value === 'name')       entries.sort((a, b) => a[0].localeCompare(b[0], 'th'))
  else if (clusterSort.value === 'value_asc') entries.sort((a, b) => a[1] - b[1])
  else                                     entries.sort((a, b) => b[1] - a[1])
  return entries.map(([label, value]) => ({ label, value, bar: 'bg-blue-500' }))
})

const totalStudents = computed(() => filteredUploads.value.reduce((s, u) => s + scopedTotals(u).total, 0))
const genderMale    = computed(() => filteredUploads.value.reduce((s, u) => s + scopedTotals(u).male, 0))
const genderFemale  = computed(() => filteredUploads.value.reduce((s, u) => s + scopedTotals(u).female, 0))
const disadvCount   = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.disadvantaged?.count || 0), 0))
// BMI/ความด้อยโอกาส เป็นยอดทั้งโรงเสมอ (ไม่มีข้อมูลแยกรายชั้น) — หารด้วยยอดทั้งโรง
// ไม่ใช่ totalStudents ที่อาจถูกกรองเหลือแค่บางชั้นแล้ว ไม่งั้น % จะเพี้ยน
const wholeSchoolTotal = computed(() => filteredUploads.value.reduce((s, u) => s + (u.total || 0), 0))
const disadvPct     = computed(() => wholeSchoolTotal.value > 0 ? ((disadvCount.value / wholeSchoolTotal.value) * 100).toFixed(1) : '0')

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
    Object.entries(scopedByGrade(u)).forEach(([g,d]) => {
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
  // ยอดรวมตัวเล็กๆ เหนือแท่งที่สูงกว่าของแต่ละระดับชั้น (ชาย+หญิง)
  annotations: {
    points: Object.entries(gradeAgg.value).map(([grade, d]) => ({
      x: grade, y: Math.max(d.male||0, d.female||0),
      marker: { size: 0 },
      label: {
        text: ((d.male||0) + (d.female||0)).toLocaleString(),
        borderWidth: 0, offsetY: -6,
        style: { fontSize: '10px', fontFamily: 'Sarabun', color: '#64748b', background: 'transparent' },
      },
    })),
  },
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

// ── การ์ดสถิติหลัก — ทำเป็น array แทนที่จะ hardcode ทีละใบ เพื่อให้ grid เต็มคอนเทนเนอร์
// พอดีกับจำนวนใบที่โชว์จริง (บางรอบไม่เปิด BMI/ความด้อยโอกาส ก็ไม่เหลือช่องว่าง)
const USER_ICON = 'M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z'
const HEART_ICON = 'M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z'
const USERS_ICON = 'M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z'

const statCards = computed(() => {
  const cards = []
  if (vis.value.total || vis.value.gender) {
    cards.push({ key: 'total', label: 'นักเรียนทั้งหมด', value: totalStudents.value.toLocaleString(),
      icon: USERS_ICON, bg: 'class', cls: 'border-cyan-100 bg-cyan-50', chipCls: 'bg-cyan-500/15', text: 'text-cyan-600', iconText: 'text-cyan-600' })
  }
  if (vis.value.gender) {
    cards.push({ key: 'male', label: 'ชาย', value: genderMale.value.toLocaleString(),
      icon: USER_ICON, bg: 'class', cls: 'border-blue-100 bg-blue-50', chipCls: 'bg-blue-500/15', text: 'text-blue-600', iconText: 'text-blue-600' })
    cards.push({ key: 'female', label: 'หญิง', value: genderFemale.value.toLocaleString(),
      icon: USER_ICON, bg: 'class', cls: 'border-pink-100 bg-pink-50', chipCls: 'bg-pink-500/15', text: 'text-pink-500', iconText: 'text-pink-500' })
  }
  if (vis.value.disadvantaged) {
    const high = Number(disadvPct.value) > 50
    cards.push({ key: 'disadv', label: `เด็กยากจน ${disadvCount.value.toLocaleString()} คน`, value: disadvPct.value + '%',
      icon: HEART_ICON, bg: 'class', cls: high ? 'border-red-200 bg-red-50' : 'border-amber-100 bg-amber-50',
      chipCls: high ? 'bg-red-500/15' : 'bg-amber-500/15', text: high ? 'text-red-600' : 'text-amber-600', iconText: high ? 'text-red-600' : 'text-amber-600' })
  }
  return cards
})
// Tailwind ต้องเจอ class เต็มตัวอักษรถึงจะไม่ถูก purge ทิ้ง — เขียนไว้ตรงๆ ทีละจำนวนแทนการต่อ string
const STAT_GRID_COLS = { 1: 'sm:grid-cols-1', 2: 'sm:grid-cols-2', 3: 'sm:grid-cols-3', 4: 'sm:grid-cols-4' }
const statGridClass = computed(() => STAT_GRID_COLS[statCards.value.length] || 'sm:grid-cols-4')

const schoolTableData = computed(() =>
  filteredUploads.value.map(u => {
    const t = scopedTotals(u)
    return {
      id: u.school_id, name: u.school_name, total: t.total, male: t.male, female: t.female,
      // BMI/ความด้อยโอกาส เป็นยอดทั้งโรงเสมอ ไม่ได้ scope ตามช่วงชั้น/สิทธิ์สอบ — เก็บ wholeTotal
      // ไว้แยกต่างหาก เพื่อใช้เป็นตัวหารของ BMI% ในตาราง ไม่ใช่ total ที่อาจถูกกรองแล้ว
      wholeTotal: u.total || 0,
      disadv: u.summary?.disadvantaged?.count||0, disadvPct: u.summary?.disadvantaged?.pct||'0',
      bmiNormal: u.summary?.bmi?.normal||0,
    }
  }).sort((a,b)=>b.total-a.total)
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
    if (vis.value.bmi)      row.push(s.wholeTotal > 0 ? ((s.bmiNormal/s.wholeTotal)*100).toFixed(1) : '0')
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

// ── กราฟแนวโน้มข้ามภาคเรียน — แอกทีฟตามตัวกรองด้านบนด้วย ─────────────────────
// เอาตัวกรองชุดเดียวกับยอดรอบปัจจุบัน (applyFilters + scopedTotals) ไป apply ซ้ำ
// กับ uploads ของทุกรอบที่เผยแพร่ไว้ — ไม่ต้องเขียนตรรกะกรองใหม่เลย
const trendPoints = computed(() => {
  return trend.value
    .filter(p => p.visibility?.total !== false) // เคารพสวิตช์ "แสดงผล" ของแต่ละรอบเอง
    .map(p => {
      const filtered = applyFilters(p.uploads || [])
      const total = filtered.reduce((s, u) => s + scopedTotals(u).total, 0)
      return { label: p.title || `${p.academic_year}/${p.semester}`, total, schools: filtered.length }
    })
})
const trendOpts = computed(() => ({
  chart: { type: 'area', height: 280, toolbar: { show: false } },
  stroke: { curve: 'smooth', width: 3 },
  markers: { size: 5, colors: ['#fff'], strokeColors: '#2563eb', strokeWidth: 2, hover: { size: 7 } },
  fill: { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.35, opacityTo: 0.03, stops: [0, 90, 100] } },
  colors: ['#2563eb'],
  grid: { borderColor: '#f1f5f9' },
  xaxis: { categories: trendPoints.value.map(p => p.label), labels: { style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
  yaxis: { labels: { formatter: v => v.toLocaleString(), style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
  dataLabels: { enabled: true, style: { fontSize: '11px', fontFamily: 'Sarabun' }, offsetY: -8, formatter: v => v.toLocaleString() },
  tooltip: { y: { formatter: v => (v || 0).toLocaleString() + ' คน' } },
}))
const trendSeries = computed(() => [{ name: 'นักเรียนรวม', data: trendPoints.value.map(p => p.total) }])
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
          {{ period.title }} · ปีการศึกษา {{ period.academic_year }} ภาคเรียนที่ {{ period.semester }}
        </p>
        <div class="grid grid-cols-2 gap-4">
          <div class="rounded-2xl border border-indigo-100 bg-indigo-50 shadow-sm px-6 py-5 text-center">
            <div class="w-12 h-12 mx-auto mb-3 rounded-2xl bg-indigo-500/15 flex items-center justify-center">
              <svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z"/>
              </svg>
            </div>
            <p class="text-3xl font-extrabold text-indigo-600">{{ data.total_schools }}</p>
            <p class="text-sm text-slate-500 mt-1">โรงเรียน</p>
          </div>
          <div class="rounded-2xl border border-cyan-100 bg-cyan-50 shadow-sm px-6 py-5 text-center">
            <div class="w-12 h-12 mx-auto mb-3 rounded-2xl bg-cyan-500/15 flex items-center justify-center">
              <svg class="w-6 h-6 text-cyan-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"/>
              </svg>
            </div>
            <p class="text-3xl font-extrabold text-cyan-600">{{ allUploads.reduce((s,u)=>s+u.total,0).toLocaleString() }}</p>
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
          <select v-model="filterCluster" @change="onClusterChange"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกศูนย์เครือข่าย</option>
            <option v-for="c in clusters" :key="c" :value="c">{{ c }}</option>
          </select>
          <select v-model="filterLevel"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
            <option value="all">ทุกระดับ</option>
            <option v-for="lv in availableLevels" :key="lv" :value="lv">{{ BROAD_LEVEL_LABEL[lv] }}</option>
          </select>
          <select v-model="filterSchool"
            class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-[180px]">
            <option value="all">ทุกโรงเรียน</option>
            <option v-for="u in schoolsInDistrict" :key="u.school_id" :value="u.school_id">{{ u.school_name }}</option>
          </select>
          <!-- ส่งออกข้อมูลตามตัวกรอง — เห็นเฉพาะสมาชิกที่ล็อกอินแล้ว -->
          <button v-if="userSession" @click="exportFilteredCSV"
            class="flex items-center gap-1.5 px-3 py-2.5 text-sm font-bold bg-emerald-600 text-white rounded-xl hover:-translate-y-0.5 shadow-sm transition-all">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/>
            </svg>
            ส่งออกข้อมูล
          </button>
        </div>
        <div v-if="isFiltered" class="mt-2 flex items-center gap-2 flex-wrap">
          <div class="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"/>
          <p class="text-sm text-primary font-medium flex-1">กรองแล้ว: {{ filteredUploads.length }} โรงเรียน · {{ totalStudents.toLocaleString() }} นักเรียน</p>
          <button @click="resetFilter" class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 border border-red-200 rounded-full hover:bg-red-100 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            ล้างตัวกรองทั้งหมด
          </button>
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

        <p v-if="activeGradeScope" class="text-xs text-amber-600 bg-amber-50 rounded-lg px-3 py-2 mt-3">
          ⚠️ กำลังกรองเฉพาะ {{ activeGradeScope.join(', ') }} — ตัวเลขนักเรียนทั้งหมด/ชาย/หญิงด้านล่างนับเฉพาะชั้นนี้แล้ว
        </p>
      </div>

      <!-- Stats cards — จำนวนใบไม่ตายตัว ขึ้นกับหมวดที่เปิดไว้ จึงเติมเต็มความกว้างเสมอ -->
      <div :class="['grid grid-cols-1 gap-4', statGridClass]">
        <div v-for="card in statCards" :key="card.key"
          :class="['rounded-2xl border shadow-sm p-5 text-center', card.bg === 'class' ? card.cls : '']"
          :style="card.bg === 'style' ? `border-color:${card.border}; background:${card.chipBg}` : ''">
          <div :class="['w-12 h-12 mx-auto mb-3 rounded-2xl flex items-center justify-center', card.bg === 'class' ? card.chipCls : '']"
            :style="card.bg === 'style' ? `background:${card.chipBg2}` : ''">
            <svg :class="['w-6 h-6', card.iconText]" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="card.icon"/>
            </svg>
          </div>
          <p :class="['text-3xl font-extrabold', card.text]">{{ card.value }}</p>
          <p class="text-sm text-slate-500 mt-1">{{ card.label }}</p>
        </div>
      </div>

      <!-- ศูนย์เครือข่าย -->
      <div v-if="clusterAgg.length > 0" class="glass-tile p-5">
        <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
          <h3 class="font-bold text-slate-700">นักเรียนแยกตามศูนย์เครือข่าย</h3>
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

      <!-- Grade chart -->
      <div v-if="vis.by_grade && Object.keys(gradeAgg).length > 0" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 mb-4 text-center">จำนวนนักเรียนแยกตามระดับชั้น</h3>
        <apexchart type="bar" :height="240" :options="gradeOpts"
          :series="[{ name:'ชาย', data:Object.values(gradeAgg).map(g=>g.male) },{ name:'หญิง', data:Object.values(gradeAgg).map(g=>g.female) }]"
          :key="`grade-${filteredUploads.length}-${chartRenderTick}`"/>
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
        <div class="px-5 py-4 border-b border-slate-50 text-center">
          <h3 class="font-bold text-slate-700">ข้อมูลรายโรงเรียน ({{ filteredUploads.length }} โรงเรียน)</h3>
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
                <td v-if="vis.bmi" class="px-4 py-3 text-right text-emerald-600 font-bold">{{ s.wholeTotal>0?((s.bmiNormal/s.wholeTotal)*100).toFixed(1):0 }}%</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ── แนวโน้มข้ามภาคเรียน (ท้ายหน้า) — แอกทีฟตามตัวกรองด้านบนแล้ว ── -->
      <div v-if="!loadingTrend && trendPoints.length >= 2" class="glass-tile p-5">
        <h3 class="font-bold text-slate-700 text-center">แนวโน้มจำนวนนักเรียน</h3>
        <p class="text-sm text-slate-400 text-center mb-4">
          {{ isFiltered ? 'ตามตัวกรองที่เลือกไว้ด้านบน' : 'ยอดรวมทั้งเขต' }} ในแต่ละภาคเรียนที่เผยแพร่ต่อสาธารณะ
        </p>
        <apexchart type="area" :height="280" :options="trendOpts" :series="trendSeries" :key="`trend-${trendPoints.map(p=>p.total).join('-')}`"/>
      </div>

      <p class="text-center text-sm text-slate-400 pb-6">ข้อมูลจากระบบ DMC · {{ config?.area_name }}<span v-if="isFiltered"> · <button @click="resetFilter" class="text-primary hover:underline">ล้างตัวกรอง</button></span></p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
