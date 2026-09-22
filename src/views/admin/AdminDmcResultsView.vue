<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { parseDmcFile, LEVEL_LABEL } from '../../composables/useDmcParser'
import { parseDmcDistrictFile } from '../../composables/useDmcDistrictParser'
import BarChart from '../../components/awards/BarChart.vue'
import Swal from 'sweetalert2'

const router  = useRouter()
const route   = useRoute()
const periodId = computed(() => route.params.id)

const period    = ref(null)
const uploads   = ref([])
const schools   = ref([])
const loading   = ref(true)
const activeTab = ref('overview')

const TABS = [
  { key: 'overview',  label: 'ภาพรวม' },
  { key: 'health',    label: 'สุขภาพ / BMI' },
  { key: 'family',    label: 'ครอบครัว' },
  { key: 'status',    label: 'สถานะโรงเรียน' },
]

// ── Filter: ศูนย์เครือข่าย / ระดับ ──────────────────────────────────────────
const filterCluster = ref('all')
const filterLevel   = ref('all')

const clusterOptions = computed(() => {
  const set = new Set(schools.value.map(s => s.school_group).filter(Boolean))
  return [...set].sort()
})
const LEVEL_OPTIONS = [
  { value: 'kindergarten', label: LEVEL_LABEL.kindergarten },
  { value: 'primary',      label: LEVEL_LABEL.primary },
  { value: 'extended',     label: LEVEL_LABEL.extended },
  { value: 'secondary',    label: LEVEL_LABEL.secondary },
]

function schoolOf(upload) { return schools.value.find(s => s.id === upload.school_id) }

const filteredUploads = computed(() => {
  let list = uploads.value
  if (filterCluster.value !== 'all') {
    list = list.filter(u => schoolOf(u)?.school_group === filterCluster.value)
  }
  if (filterLevel.value !== 'all') {
    list = list.filter(u => u.summary?.level === filterLevel.value)
  }
  return list
})

// ── Admin upload on behalf ─────────────────────────────────────────────────
const uploadModal   = ref({ open: false, school: null })
const adminFile     = ref(null)
const adminParsed   = ref(null)
const adminParsing  = ref(false)
const adminSaving   = ref(false)

function openUploadModal(school) {
  uploadModal.value = { open: true, school }
  adminFile.value   = null
  adminParsed.value = null
}
function closeUploadModal() {
  uploadModal.value = { open: false, school: null }
  adminFile.value   = null
  adminParsed.value = null
}

async function onAdminFileChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  e.target.value = ''
  adminFile.value   = file
  adminParsed.value = null
  adminParsing.value = true
  try {
    adminParsed.value = await parseDmcFile(file)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่ได้', text: err.message })
    adminFile.value = null
  }
  adminParsing.value = false
}

async function saveAdminUpload() {
  if (!adminParsed.value || !uploadModal.value.school) return
  adminSaving.value = true
  const { error } = await supabase.from('dmc_school_uploads').upsert({
    period_id:   periodId.value,
    school_id:   uploadModal.value.school.id,
    total:       adminParsed.value.total,
    summary:     adminParsed.value,
    uploaded_at: new Date().toISOString(),
  }, { onConflict: 'period_id,school_id' })
  adminSaving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  closeUploadModal()
  await load()
  Swal.fire({ icon: 'success', title: 'อัปโหลดแทนสำเร็จ', showConfirmButton: false, timer: 1500 })
}

async function deleteUpload(school) {
  const r = await Swal.fire({
    title: 'ลบข้อมูลนี้?',
    html: `<span class="text-sm">โรงเรียน: <b>${school.name}</b><br>ข้อมูลจะถูกลบและโรงเรียนต้องอัปโหลดใหม่</span>`,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  const upload = uploads.value.find(u => u.school_id === school.id)
  if (!upload) return
  const { error } = await supabase.from('dmc_school_uploads').delete().eq('id', upload.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  await load()
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 1200 })
}

function viewUploadDetail(school) {
  const upload = uploads.value.find(u => u.school_id === school.id)
  if (!upload) return
  const s = upload.summary
  Swal.fire({
    title: school.name,
    html: `
      <div class="text-left text-sm space-y-1">
        <p>📅 อัปโหลด: <b>${formatDate(upload.uploaded_at)}</b></p>
        <p>👥 นักเรียน: <b>${upload.total.toLocaleString()} คน</b> (ชาย ${s.gender?.male||0} หญิง ${s.gender?.female||0})</p>
        <p>🍎 ยากจน: <b>${s.disadvantaged?.count||0} คน (${s.disadvantaged?.pct||0}%)</b></p>
        <p>📏 BMI ต่ำกว่าเกณฑ์: <b>${s.bmi?.underweight||0} คน</b></p>
        <p>🏫 ระดับ: <b>${LEVEL_LABEL[s.level] || 'ไม่ระบุ'}</b></p>
        <p>📥 ที่มา: <b>${s.source === 'district_bulk' ? 'นำเข้าไฟล์เขต' : 'ไฟล์รายบุคคล'}</b></p>
      </div>`,
    confirmButtonText: 'ปิด',
    confirmButtonColor: 'var(--color-primary, #2563eb)',
  })
}

// ── นำเข้าจากไฟล์เขต (ทุกโรงเรียนในครั้งเดียว) ──────────────────────────────
const bulkModal    = ref({ open: false })
const bulkFile     = ref(null)
const bulkParsed   = ref(null)   // { schools, skippedRows }
const bulkParsing  = ref(false)
const bulkSaving   = ref(false)
const bulkOverrideConflicts = ref(new Set())

function openBulkModal() {
  bulkModal.value = { open: true }
  bulkFile.value = null
  bulkParsed.value = null
  bulkOverrideConflicts.value = new Set()
}
function closeBulkModal() {
  bulkModal.value = { open: false }
  bulkFile.value = null
  bulkParsed.value = null
  bulkOverrideConflicts.value = new Set()
}

async function onBulkFileChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  e.target.value = ''
  bulkFile.value = file
  bulkParsed.value = null
  bulkOverrideConflicts.value = new Set()
  bulkParsing.value = true
  try {
    bulkParsed.value = await parseDmcDistrictFile(file)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่ได้', text: err.message })
    bulkFile.value = null
  }
  bulkParsing.value = false
}

// จับคู่แต่ละแถวในไฟล์กับโรงเรียนในระบบ (โดย dmc_code) แล้วจัดกลุ่ม matched/unmatched/conflict
const bulkRows = computed(() => {
  if (!bulkParsed.value) return []
  return bulkParsed.value.schools.map(row => {
    const school = schools.value.find(s => s.dmc_code === row.dmc_code)
    const existing = school ? uploads.value.find(u => u.school_id === school.id) : null
    const isConflict = !!school && existing?.summary?.source === 'school_detail'
    return { ...row, school, existing, isConflict }
  })
})
const bulkMatched    = computed(() => bulkRows.value.filter(r => r.school))
const bulkUnmatched  = computed(() => bulkRows.value.filter(r => !r.school))
const bulkConflicts  = computed(() => bulkMatched.value.filter(r => r.isConflict))
const bulkClusterPreview = computed(() => {
  const map = {}
  bulkMatched.value.forEach(r => {
    const key = r.school.school_group || 'ไม่ระบุศูนย์'
    map[key] = (map[key] || 0) + (r.summary.total || 0)
  })
  return Object.entries(map).sort((a,b) => b[1]-a[1]).map(([label, value]) => ({ label, value }))
})
const bulkTotalStudents = computed(() => bulkMatched.value.reduce((s, r) => s + (r.summary.total || 0), 0))
const bulkRowsToSave = computed(() =>
  bulkMatched.value.filter(r => !r.isConflict || bulkOverrideConflicts.value.has(r.school.id)).length
)

function toggleBulkOverride(schoolId) {
  const set = new Set(bulkOverrideConflicts.value)
  if (set.has(schoolId)) set.delete(schoolId); else set.add(schoolId)
  bulkOverrideConflicts.value = set
}

async function saveBulkImport() {
  const rows = bulkMatched.value
    .filter(r => !r.isConflict || bulkOverrideConflicts.value.has(r.school.id))
    .map(r => ({
      period_id:   periodId.value,
      school_id:   r.school.id,
      total:       r.summary.total,
      summary:     r.summary,
      uploaded_at: new Date().toISOString(),
    }))
  if (rows.length === 0) {
    Swal.fire({ icon: 'warning', title: 'ไม่มีข้อมูลที่จะบันทึก' }); return
  }
  bulkSaving.value = true
  const { error } = await supabase.from('dmc_school_uploads')
    .upsert(rows, { onConflict: 'period_id,school_id' })
  bulkSaving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  closeBulkModal()
  await load()
  Swal.fire({ icon: 'success', title: `นำเข้าสำเร็จ ${rows.length} โรงเรียน`, showConfirmButton: false, timer: 2000 })
}

async function load() {
  loading.value = true
  const [{ data: p }, { data: u }, { data: sc }] = await Promise.all([
    supabase.from('dmc_periods').select('*').eq('id', periodId.value).single(),
    supabase.from('dmc_school_uploads').select('*').eq('period_id', periodId.value),
    supabase.from('schools').select('id, name, dmc_code, district, school_group').order('district').order('name'),
  ])
  period.value  = p
  uploads.value = u || []
  schools.value = sc || []
  loading.value = false
}

onMounted(load)

// ── Aggregate computeds (คิดจากข้อมูลที่กรองแล้ว) ───────────────────────────
const totalStudents = computed(() => filteredUploads.value.reduce((s, u) => s + u.total, 0))

const genderAgg = computed(() => {
  let male = 0, female = 0
  filteredUploads.value.forEach(u => {
    male   += u.summary?.gender?.male   || 0
    female += u.summary?.gender?.female || 0
  })
  return { male, female }
})

const gradeAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const bg = u.summary?.by_grade || {}
    Object.entries(bg).forEach(([g, d]) => {
      if (!map[g]) map[g] = { total: 0, male: 0, female: 0 }
      map[g].total  += d.total  || 0
      map[g].male   += d.male   || 0
      map[g].female += d.female || 0
    })
  })
  return map
})

const bmiAgg = computed(() => {
  let u=0, n=0, o=0, ob=0
  filteredUploads.value.forEach(up => {
    const b = up.summary?.bmi || {}
    u  += b.underweight || 0
    n  += b.normal      || 0
    o  += b.overweight  || 0
    ob += b.obese       || 0
  })
  const total = u + n + o + ob
  return { underweight: u, normal: n, overweight: o, obese: ob, total }
})

const disadvantagedAgg = computed(() => {
  let count = 0
  filteredUploads.value.forEach(u => { count += u.summary?.disadvantaged?.count || 0 })
  return { count, pct: totalStudents.value > 0 ? ((count/totalStudents.value)*100).toFixed(1) : '0' }
})

const guardianAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const gr = u.summary?.guardian_relation || {}
    Object.entries(gr).forEach(([k, v]) => { map[k] = (map[k]||0) + v })
  })
  return Object.entries(map).sort((a,b) => b[1]-a[1]).slice(0, 8)
})

const parentJobsAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const pj = u.summary?.parent_jobs || {}
    Object.entries(pj).forEach(([k, v]) => { map[k] = (map[k]||0) + v })
  })
  return Object.entries(map).sort((a,b) => b[1]-a[1]).slice(0, 8)
})

// ── ยอดแยกตามศูนย์เครือข่าย / ระดับ (ใช้ BarChart.vue ที่มีอยู่แล้ว) ────────
const clusterAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const key = schoolOf(u)?.school_group || 'ไม่ระบุศูนย์'
    map[key] = (map[key] || 0) + u.total
  })
  return Object.entries(map)
    .sort((a, b) => b[1] - a[1])
    .map(([label, value]) => ({ label, value }))
})

const levelAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    const key = u.summary?.level || 'unknown'
    map[key] = (map[key] || 0) + u.total
  })
  return Object.keys(LEVEL_LABEL)
    .filter(k => map[k])
    .map(k => ({ label: LEVEL_LABEL[k], value: map[k] }))
})

const respondedIds  = computed(() => new Set(uploads.value.map(u => u.school_id)))
const pendingSchools = computed(() => schools.value.filter(s => !respondedIds.value.has(s.id)))
const doneSchools    = computed(() => schools.value.filter(s => respondedIds.value.has(s.id)))
const pct = computed(() =>
  schools.value.length > 0 ? Math.round((uploads.value.length / schools.value.length) * 100) : 0
)

// ── Chart helpers ──────────────────────────────────────────────────────────
const chartColors = ['#3B82F6','#10B981','#F59E0B','#EF4444','#8B5CF6','#EC4899','#14B8A6','#F97316']

const gradeChartOpts = computed(() => ({
  chart: { type: 'bar', height: 250, toolbar: { show: false } },
  plotOptions: { bar: { borderRadius: 4, columnWidth: '60%' } },
  colors: ['#3b82f6', '#ec4899'],
  xaxis: { categories: Object.keys(gradeAgg.value), labels: { style: { fontFamily: 'Sarabun', fontSize: '12px' } } },
  legend: { position: 'top', fontFamily: 'Sarabun', labels: { colors: '#64748b' } },
  dataLabels: { enabled: false },
  tooltip: { y: { formatter: v => v.toLocaleString() + ' คน' } },
}))

const gradeChartSeries = computed(() => [
  { name: 'ชาย',  data: Object.values(gradeAgg.value).map(g => g.male) },
  { name: 'หญิง', data: Object.values(gradeAgg.value).map(g => g.female) },
])

const bmiChartOpts = computed(() => ({
  chart: { type: 'donut', height: 220 },
  labels: ['ต่ำกว่าเกณฑ์','ปกติ','น้ำหนักเกิน','อ้วน'],
  colors: ['#f97316','#10b981','#f59e0b','#ef4444'],
  legend: { position: 'bottom', fontFamily: 'Sarabun', fontSize: '11px' },
  plotOptions: { pie: { donut: { size: '65%' } } },
  dataLabels: { style: { fontSize: '11px' } },
  tooltip: { y: { formatter: v => v.toLocaleString() + ' คน' } },
}))

const bmiChartSeries = computed(() => [
  bmiAgg.value.underweight, bmiAgg.value.normal,
  bmiAgg.value.overweight,  bmiAgg.value.obese,
])

function guardianBarOpts(data) {
  return {
    chart: { type: 'bar', height: 220, toolbar: { show: false } },
    plotOptions: { bar: { borderRadius: 4, horizontal: true } },
    colors: chartColors,
    xaxis: { categories: data.map(d=>d[0]), labels: { style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
    dataLabels: { enabled: true, style: { fontSize: '11px' } },
    legend: { show: false },
    tooltip: { y: { formatter: v => v.toLocaleString() + ' คน' } },
  }
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' })
}

async function exportCSV() {
  const rows = [['โรงเรียน', 'จำนวนทั้งหมด', 'ชาย', 'หญิง', 'ยากจน', 'ยากจน%', 'BMI ต่ำ', 'BMI ปกติ', 'BMI เกิน', 'BMI อ้วน', 'วันที่อัปโหลด']]
  uploads.value.forEach(u => {
    const sc = schools.value.find(s => s.id === u.school_id)
    const s  = u.summary
    rows.push([
      sc?.name || '—', u.total,
      s?.gender?.male || 0, s?.gender?.female || 0,
      s?.disadvantaged?.count || 0, s?.disadvantaged?.pct || '0',
      s?.bmi?.underweight || 0, s?.bmi?.normal || 0, s?.bmi?.overweight || 0, s?.bmi?.obese || 0,
      new Date(u.uploaded_at).toLocaleDateString('th-TH'),
    ])
  })
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g,'""')}"`).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `dmc_${period.value?.title || 'export'}_${new Date().toISOString().slice(0,10)}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <button @click="router.push('/dashboard/dmc')"
          class="flex items-center gap-1 text-sm text-slate-400 hover:text-slate-600 mb-1">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
          </svg>
          กลับรายการรอบ
        </button>
        <h1 class="text-2xl font-extrabold text-slate-800">{{ period?.title }}</h1>
        <p class="text-sm text-slate-500 mt-0.5">ปีการศึกษา {{ period?.academic_year }} ภาคเรียน {{ period?.semester }}</p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button @click="openBulkModal" :disabled="period?.is_archived"
          class="flex items-center gap-2 px-4 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
          </svg>
          นำเข้าจากไฟล์เขต (ทุกโรงเรียน)
        </button>
        <button @click="exportCSV" :disabled="uploads.length === 0"
          class="flex items-center gap-2 px-4 py-2.5 text-sm font-bold bg-emerald-600 text-white rounded-2xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/>
          </svg>
          Export CSV
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else>
      <!-- Summary stats -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ totalStudents.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">นักเรียนทั้งหมด</p>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-slate-700">{{ uploads.length }} / {{ schools.length }}</p>
          <p class="text-xs text-slate-500 mt-1">โรงเรียนส่งแล้ว</p>
        </div>
        <div class="glass-card p-4 text-center">
          <p class="text-3xl font-extrabold text-emerald-600">{{ pct }}%</p>
          <p class="text-xs text-slate-500 mt-1">ความสำเร็จ</p>
        </div>
        <div :class="['rounded-2xl border shadow-sm p-4 text-center',
          Number(disadvantagedAgg.pct) > 50 ? 'bg-red-50 border-red-200' : 'bg-white border-slate-100']">
          <p :class="['text-3xl font-extrabold', Number(disadvantagedAgg.pct) > 50 ? 'text-red-600' : 'text-amber-600']">
            {{ disadvantagedAgg.pct }}%
          </p>
          <p class="text-xs text-slate-500 mt-1">เด็กยากจน</p>
        </div>
      </div>

      <!-- Progress bar -->
      <div class="glass-card p-4">
        <div class="flex justify-between text-sm font-medium text-slate-600 mb-2">
          <span>ความคืบหน้า</span>
          <span>{{ uploads.length }} / {{ schools.length }} โรงเรียน</span>
        </div>
        <div class="h-3 bg-slate-100 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-primary to-blue-400 rounded-full transition-all duration-700"
            :style="`width:${pct}%`"/>
        </div>
      </div>

      <!-- Tabs -->
      <div class="flex gap-1 bg-slate-100 p-1 rounded-xl w-fit">
        <button v-for="t in TABS" :key="t.key" @click="activeTab = t.key"
          :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
            activeTab === t.key ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ t.label }}
        </button>
      </div>

      <!-- Filter: ศูนย์เครือข่าย / ระดับ -->
      <div class="glass-card p-4 flex flex-wrap items-center gap-3">
        <select v-model="filterCluster" class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="c in clusterOptions" :key="c" :value="c">{{ c }}</option>
        </select>
        <select v-model="filterLevel" class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกระดับ</option>
          <option v-for="lv in LEVEL_OPTIONS" :key="lv.value" :value="lv.value">{{ lv.label }}</option>
        </select>
        <span v-if="filterCluster !== 'all' || filterLevel !== 'all'" class="text-xs text-primary font-medium">
          กรองแล้ว {{ filteredUploads.length }} โรงเรียน · {{ totalStudents.toLocaleString() }} คน
        </span>
        <button v-if="filterCluster !== 'all' || filterLevel !== 'all'"
          @click="filterCluster='all'; filterLevel='all'"
          class="text-xs text-slate-400 hover:text-red-500 ml-auto">ล้างตัวกรอง</button>
      </div>

      <!-- ── Overview ── -->
      <template v-if="activeTab === 'overview'">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <!-- ศูนย์เครือข่าย -->
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">นักเรียนแยกตามศูนย์เครือข่าย</h3>
            <BarChart :items="clusterAgg.map(c => ({ label: c.label, value: c.value, bar: 'bg-primary' }))"/>
          </div>
          <!-- ระดับ -->
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">นักเรียนแยกตามระดับ</h3>
            <BarChart :items="levelAgg.map(l => ({ label: l.label, value: l.value, bar: 'bg-indigo-500' }))"/>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <!-- Gender -->
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">จำนวนแยกตามเพศ</h3>
            <div class="flex gap-4 justify-center">
              <div class="text-center">
                <p class="text-4xl font-extrabold text-blue-600">{{ genderAgg.male.toLocaleString() }}</p>
                <p class="text-sm text-slate-500 mt-1">ชาย</p>
                <p class="text-xs text-slate-400">{{ totalStudents > 0 ? ((genderAgg.male/totalStudents)*100).toFixed(1) : 0 }}%</p>
              </div>
              <div class="w-px bg-slate-200"/>
              <div class="text-center">
                <p class="text-4xl font-extrabold text-pink-500">{{ genderAgg.female.toLocaleString() }}</p>
                <p class="text-sm text-slate-500 mt-1">หญิง</p>
                <p class="text-xs text-slate-400">{{ totalStudents > 0 ? ((genderAgg.female/totalStudents)*100).toFixed(1) : 0 }}%</p>
              </div>
            </div>
          </div>
          <!-- Disadvantaged -->
          <div :class="['rounded-2xl border shadow-sm p-5',
            Number(disadvantagedAgg.pct) > 50 ? 'bg-red-50 border-red-200' : 'bg-white border-slate-100']">
            <h3 class="font-bold text-slate-700 mb-4">ความด้อยโอกาส</h3>
            <div class="text-center">
              <p :class="['text-5xl font-extrabold', Number(disadvantagedAgg.pct) > 50 ? 'text-red-600' : 'text-amber-600']">
                {{ disadvantagedAgg.pct }}%
              </p>
              <p class="text-slate-600 mt-2">{{ disadvantagedAgg.count.toLocaleString() }} คน จาก {{ totalStudents.toLocaleString() }} คน</p>
              <p v-if="Number(disadvantagedAgg.pct) > 50" class="text-red-500 text-xs mt-2 font-bold">⚠️ สูงกว่าค่าเฉลี่ยทั่วไป</p>
            </div>
          </div>
        </div>

        <!-- Grade chart -->
        <div v-if="Object.keys(gradeAgg).length > 0" class="glass-card p-5">
          <h3 class="font-bold text-slate-700 mb-4">จำนวนแยกตามระดับชั้น</h3>
          <apexchart type="bar" :height="250" :options="gradeChartOpts" :series="gradeChartSeries"/>
        </div>
      </template>

      <!-- ── Health ── -->
      <template v-else-if="activeTab === 'health'">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">ภาวะโภชนาการ (BMI)</h3>
            <apexchart v-if="bmiAgg.total > 0" type="donut" :height="220" :options="bmiChartOpts" :series="bmiChartSeries"/>
            <p v-else class="text-center py-8 text-slate-400 text-sm">ยังไม่มีข้อมูล</p>
          </div>
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">สรุป BMI</h3>
            <div class="space-y-3">
              <div v-for="(item, idx) in [
                { label:'ต่ำกว่าเกณฑ์', val: bmiAgg.underweight, color:'bg-orange-500' },
                { label:'ปกติ',          val: bmiAgg.normal,      color:'bg-emerald-500' },
                { label:'น้ำหนักเกิน',  val: bmiAgg.overweight,  color:'bg-amber-500' },
                { label:'อ้วน',          val: bmiAgg.obese,       color:'bg-red-500' },
              ]" :key="idx">
                <div class="flex items-center gap-3 text-sm">
                  <div :class="['w-3 h-3 rounded-full flex-shrink-0', item.color]"/>
                  <span class="flex-1 text-slate-600">{{ item.label }}</span>
                  <span class="font-bold text-slate-800">{{ item.val.toLocaleString() }} คน</span>
                  <span class="text-slate-400 text-xs w-10 text-right">
                    {{ bmiAgg.total > 0 ? ((item.val/bmiAgg.total)*100).toFixed(1) : 0 }}%
                  </span>
                </div>
                <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div :class="['h-full rounded-full', item.color]"
                    :style="`width:${bmiAgg.total > 0 ? (item.val/bmiAgg.total*100) : 0}%`"/>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>

      <!-- ── Family ── -->
      <template v-else-if="activeTab === 'family'">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
          <!-- Guardian relation -->
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">ผู้ปกครอง (ความสัมพันธ์)</h3>
            <apexchart v-if="guardianAgg.length > 0" type="bar" :height="220"
              :options="guardianBarOpts(guardianAgg)"
              :series="[{ name: 'จำนวน', data: guardianAgg.map(d=>d[1]) }]"/>
          </div>
          <!-- Parent jobs -->
          <div class="glass-card p-5">
            <h3 class="font-bold text-slate-700 mb-4">อาชีพผู้ปกครอง (Top 8)</h3>
            <apexchart v-if="parentJobsAgg.length > 0" type="bar" :height="220"
              :options="guardianBarOpts(parentJobsAgg)"
              :series="[{ name: 'จำนวน', data: parentJobsAgg.map(d=>d[1]) }]"/>
          </div>
        </div>
      </template>

      <!-- ── Status ── -->
      <template v-else-if="activeTab === 'status'">
        <div class="space-y-5">

          <!-- ยังไม่ส่ง -->
          <div class="glass-card overflow-hidden">
            <div class="px-5 py-4 border-b border-slate-50 flex items-center justify-between">
              <h3 class="font-bold text-amber-600 flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                ยังไม่ส่ง ({{ pendingSchools.length }})
              </h3>
            </div>
            <div v-if="pendingSchools.length === 0" class="text-center py-6 text-slate-400 text-sm">
              ทุกโรงเรียนส่งแล้ว ✓
            </div>
            <div v-else class="divide-y divide-slate-50">
              <div v-for="s in pendingSchools" :key="s.id"
                class="flex items-center justify-between px-5 py-3 hover:bg-slate-50 transition-colors">
                <div class="flex items-center gap-2 flex-1 min-w-0">
                  <div class="w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0"/>
                  <span class="text-sm text-slate-700 truncate">{{ s.name }}</span>
                  <span class="text-xs text-slate-400">{{ s.district }}</span>
                </div>
                <button @click="openUploadModal(s)"
                  :disabled="period?.is_archived"
                  class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex-shrink-0 ml-2">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                  </svg>
                  อัปโหลดแทน
                </button>
              </div>
            </div>
          </div>

          <!-- ส่งแล้ว -->
          <div class="glass-card overflow-hidden">
            <div class="px-5 py-4 border-b border-slate-50">
              <h3 class="font-bold text-emerald-600 flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                ส่งแล้ว ({{ doneSchools.length }})
              </h3>
            </div>
            <div class="divide-y divide-slate-50">
              <div v-for="s in doneSchools" :key="s.id"
                class="flex items-center gap-3 px-5 py-3 hover:bg-slate-50 transition-colors">
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-slate-700 truncate">{{ s.name }}</p>
                  <p class="text-xs text-slate-400">
                    {{ uploads.find(u=>u.school_id===s.id)?.total?.toLocaleString() }} คน ·
                    {{ formatDate(uploads.find(u=>u.school_id===s.id)?.uploaded_at) }}
                  </p>
                </div>
                <div class="flex gap-1.5 flex-shrink-0">
                  <!-- ดูรายละเอียด -->
                  <button @click="viewUploadDetail(s)"
                    class="px-2.5 py-1.5 text-xs font-bold text-slate-600 bg-slate-100 rounded-lg hover:bg-slate-200 transition-colors">
                    ดู
                  </button>
                  <!-- อัปโหลดใหม่แทน -->
                  <button @click="openUploadModal(s)"
                    :disabled="period?.is_archived"
                    class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
                    อัปเดต
                  </button>
                  <!-- ลบ -->
                  <button @click="deleteUpload(s)"
                    :disabled="period?.is_archived"
                    class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
                    ลบ
                  </button>
                </div>
              </div>
            </div>
          </div>

        </div>
      </template>
    </template>
  </div>

  <!-- ── Admin Upload Modal ──────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="uploadModal.open"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="glass-panel rounded-[1.25rem] w-full max-w-lg">

          <!-- Header -->
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h2 class="font-extrabold text-slate-800">อัปโหลดแทนโรงเรียน</h2>
              <p class="text-xs text-slate-400 mt-0.5">{{ uploadModal.school?.name }}</p>
            </div>
            <button @click="closeUploadModal" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="px-6 py-5 space-y-4">

            <!-- File picker -->
            <div v-if="!adminParsed">
              <input type="file" id="admin-file-input" accept=".xlsx,.xls" class="sr-only"
                @change="onAdminFileChange"/>
              <label for="admin-file-input"
                class="flex flex-col items-center justify-center gap-2 p-8 border-2 border-dashed border-slate-300 rounded-2xl cursor-pointer hover:border-primary hover:bg-primary/5 transition-all text-center">
                <div v-if="adminParsing" class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
                <svg v-else class="w-10 h-10 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                </svg>
                <p class="font-bold text-slate-600 text-sm">{{ adminParsing ? 'กำลังวิเคราะห์...' : 'คลิกเพื่อเลือกไฟล์ Excel DMC' }}</p>
                <p class="text-xs text-slate-400">รองรับ .xlsx / .xls</p>
              </label>
            </div>

            <!-- Preview -->
            <div v-else class="bg-slate-50 rounded-2xl p-4 space-y-3">
              <div class="flex items-center justify-between">
                <p class="font-bold text-slate-700">ตรวจสอบข้อมูล</p>
                <button @click="adminFile=null; adminParsed=null" class="text-xs text-slate-400 hover:text-red-500">เลือกใหม่</button>
              </div>
              <div class="grid grid-cols-2 gap-2 text-center text-sm">
                <div class="bg-primary/5 rounded-xl p-3">
                  <p class="text-xl font-extrabold text-primary">{{ adminParsed.total.toLocaleString() }}</p>
                  <p class="text-xs text-slate-500">นักเรียนทั้งหมด</p>
                </div>
                <div class="bg-blue-50 rounded-xl p-3">
                  <p class="text-xl font-extrabold text-blue-600">{{ adminParsed.gender.male }} / {{ adminParsed.gender.female }}</p>
                  <p class="text-xs text-slate-500">ชาย / หญิง</p>
                </div>
                <div :class="['rounded-xl p-3', Number(adminParsed.disadvantaged.pct) > 50 ? 'bg-red-50' : 'bg-amber-50']">
                  <p :class="['text-xl font-extrabold', Number(adminParsed.disadvantaged.pct) > 50 ? 'text-red-600' : 'text-amber-600']">
                    {{ adminParsed.disadvantaged.pct }}%
                  </p>
                  <p class="text-xs text-slate-500">เด็กยากจน</p>
                </div>
                <div class="bg-emerald-50 rounded-xl p-3">
                  <p class="text-xl font-extrabold text-emerald-600">{{ adminParsed.bmi.normal }}</p>
                  <p class="text-xs text-slate-500">BMI ปกติ</p>
                </div>
              </div>
              <div class="flex flex-wrap gap-1.5">
                <span v-for="(g, grade) in adminParsed.by_grade" :key="grade"
                  class="text-xs bg-white border border-slate-200 px-2.5 py-1 rounded-lg">
                  {{ grade }}: {{ g.total }}
                </span>
              </div>
            </div>
          </div>

          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="closeUploadModal" class="px-4 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="saveAdminUpload" :disabled="!adminParsed || adminSaving"
              class="flex items-center gap-2 px-6 py-2.5 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              <svg v-if="adminSaving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              {{ adminSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- ── Bulk Import Modal (นำเข้าจากไฟล์เขต) ──────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="bulkModal.open"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="glass-panel rounded-[1.25rem] w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden">

          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <div>
              <h2 class="font-extrabold text-slate-800">นำเข้าข้อมูลจากไฟล์เขต</h2>
              <p class="text-xs text-slate-400 mt-0.5">ไฟล์สรุปจำนวนนักเรียนรายโรงเรียน (CSV จาก DMC ระดับเขต)</p>
            </div>
            <button @click="closeBulkModal" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

            <!-- File picker -->
            <div v-if="!bulkParsed">
              <input type="file" id="bulk-file-input" accept=".csv" class="sr-only" @change="onBulkFileChange"/>
              <label for="bulk-file-input"
                class="flex flex-col items-center justify-center gap-2 p-8 border-2 border-dashed border-slate-300 rounded-2xl cursor-pointer hover:border-primary hover:bg-primary/5 transition-all text-center">
                <div v-if="bulkParsing" class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
                <svg v-else class="w-10 h-10 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                </svg>
                <p class="font-bold text-slate-600 text-sm">{{ bulkParsing ? 'กำลังวิเคราะห์...' : 'คลิกเพื่อเลือกไฟล์ CSV ระดับเขต' }}</p>
                <p class="text-xs text-slate-400">รองรับ .csv (จาก DMC ระดับเขต — สรุปทุกโรงเรียนในไฟล์เดียว)</p>
              </label>
            </div>

            <!-- Preview -->
            <div v-else class="space-y-4">
              <div class="flex items-center justify-between">
                <p class="font-bold text-slate-700">ตรวจสอบก่อนบันทึก</p>
                <button @click="bulkFile=null; bulkParsed=null" class="text-xs text-slate-400 hover:text-red-500">เลือกไฟล์ใหม่</button>
              </div>

              <div class="grid grid-cols-3 gap-2 text-center text-sm">
                <div class="bg-primary/5 rounded-xl p-3">
                  <p class="text-xl font-extrabold text-primary">{{ bulkMatched.length }}</p>
                  <p class="text-xs text-slate-500">จับคู่โรงเรียนได้</p>
                </div>
                <div :class="['rounded-xl p-3', bulkUnmatched.length > 0 ? 'bg-red-50' : 'bg-slate-50']">
                  <p :class="['text-xl font-extrabold', bulkUnmatched.length > 0 ? 'text-red-600' : 'text-slate-400']">{{ bulkUnmatched.length }}</p>
                  <p class="text-xs text-slate-500">ไม่พบในระบบ</p>
                </div>
                <div class="bg-emerald-50 rounded-xl p-3">
                  <p class="text-xl font-extrabold text-emerald-600">{{ bulkTotalStudents.toLocaleString() }}</p>
                  <p class="text-xs text-slate-500">นักเรียนรวม</p>
                </div>
              </div>

              <!-- ยอดตามศูนย์เครือข่าย -->
              <div class="bg-slate-50 rounded-2xl p-4">
                <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">ยอดแยกตามศูนย์เครือข่าย</p>
                <BarChart :items="bulkClusterPreview.map(c => ({ label: c.label, value: c.value, bar: 'bg-primary' }))"/>
              </div>

              <!-- โรงเรียนไม่พบในระบบ -->
              <div v-if="bulkUnmatched.length > 0" class="bg-red-50 border border-red-200 rounded-2xl p-4">
                <p class="text-xs font-bold text-red-600 mb-2">⚠️ โรงเรียนในไฟล์ที่ไม่พบในระบบ (จะถูกข้าม)</p>
                <div class="flex flex-wrap gap-1.5">
                  <span v-for="r in bulkUnmatched" :key="r.dmc_code"
                    class="text-xs bg-white border border-red-200 px-2.5 py-1 rounded-lg text-red-500">
                    {{ r.dmc_code }} — {{ r.file_school_name }}
                  </span>
                </div>
              </div>

              <!-- ชนกับข้อมูลรายบุคคลเดิม -->
              <div v-if="bulkConflicts.length > 0" class="bg-amber-50 border border-amber-200 rounded-2xl p-4 space-y-2">
                <p class="text-xs font-bold text-amber-700">
                  ⚠️ {{ bulkConflicts.length }} โรงเรียนเคยอัปโหลดไฟล์รายบุคคลไว้แล้ว (มี BMI/ครอบครัวครบกว่า)
                  — เลือกยืนยันหากต้องการทับด้วยข้อมูลจากไฟล์เขต
                </p>
                <label v-for="r in bulkConflicts" :key="r.school.id"
                  class="flex items-center gap-2 bg-white rounded-xl px-3 py-2 cursor-pointer text-sm">
                  <input type="checkbox" :checked="bulkOverrideConflicts.has(r.school.id)"
                    @change="toggleBulkOverride(r.school.id)" class="w-4 h-4 accent-amber-600 rounded"/>
                  <span class="flex-1 text-slate-700">{{ r.school.name }}</span>
                  <span class="text-xs text-slate-400">ทับด้วย {{ r.summary.total }} คน</span>
                </label>
              </div>
            </div>
          </div>

          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end flex-shrink-0">
            <button @click="closeBulkModal" class="px-4 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="saveBulkImport" :disabled="!bulkParsed || bulkSaving || bulkRowsToSave === 0"
              class="flex items-center gap-2 px-6 py-2.5 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              <svg v-if="bulkSaving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              {{ bulkSaving ? 'กำลังบันทึก...' : `นำเข้า ${bulkRowsToSave} โรงเรียน` }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
