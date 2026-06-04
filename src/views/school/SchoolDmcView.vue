<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { read, utils } from 'xlsx'
import Swal from 'sweetalert2'
import { parseDmcFile } from '../../composables/useDmcParser'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const activeTab = ref('dmc')   // 'dmc' | 'students' | 'history'

// ── DMC Period Upload (new system) ────────────────────────────────────────
const activePeriod    = ref(null)
const myUpload        = ref(null)   // latest upload for active period
const dmcFile         = ref(null)
const dmcParsed       = ref(null)   // summary after parse
const dmcParsing      = ref(false)
const dmcSaving       = ref(false)
const dmcDragging     = ref(false)

async function loadActivePeriod() {
  if (!props.school?.id) return
  const { data: periods } = await supabase
    .from('dmc_periods').select('*').eq('is_active', true)
    .order('created_at', { ascending: false }).limit(1)
  activePeriod.value = periods?.[0] || null

  if (activePeriod.value) {
    const { data: up } = await supabase
      .from('dmc_school_uploads').select('*')
      .eq('period_id', activePeriod.value.id)
      .eq('school_id', props.school.id)
      .maybeSingle()
    myUpload.value = up
  }
}

function onDmcDrop(e) {
  dmcDragging.value = false
  const file = e.dataTransfer?.files?.[0] || e.target?.files?.[0]
  if (file) handleDmcFile(file)
}

async function handleDmcFile(file) {
  if (!file.name.match(/\.(xlsx|xls)$/i)) {
    Swal.fire({ icon: 'warning', title: 'กรุณาใช้ไฟล์ Excel (.xlsx/.xls)' }); return
  }
  dmcFile.value    = file
  dmcParsed.value  = null
  dmcParsing.value = true
  try {
    dmcParsed.value = await parseDmcFile(file)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่ได้', text: err.message })
    dmcFile.value = null
  }
  dmcParsing.value = false
}

async function saveDmcUpload() {
  if (!dmcParsed.value || !activePeriod.value || !props.school?.id) return
  dmcSaving.value = true
  const payload = {
    period_id:   activePeriod.value.id,
    school_id:   props.school.id,
    total:       dmcParsed.value.total,
    summary:     dmcParsed.value,
    uploaded_by: props.profile?.id || null,
    uploaded_at: new Date().toISOString(),
  }
  const { error } = await supabase.from('dmc_school_uploads')
    .upsert(payload, { onConflict: 'period_id,school_id' })
  dmcSaving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  await loadActivePeriod()
  dmcFile.value   = null
  dmcParsed.value = null
  Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1500 })
}

function clearDmcFile() { dmcFile.value = null; dmcParsed.value = null }

function formatDmcDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' })
}

const bmiTotal = computed(() => {
  if (!dmcParsed.value?.bmi) return 0
  const b = dmcParsed.value.bmi
  return b.underweight + b.normal + b.overweight + b.obese
})

// Existing tabs state
const previousActiveTab = activeTab.value
const academicYear  = ref('2568')
const term          = ref('1')

const currentThaiYear = new Date().getFullYear() + 543
const YEAR_OPTIONS = Array.from({ length: 8 }, (_, i) => String(currentThaiYear + 1 - i))
const TERM_OPTIONS = [
  { value: '1', label: 'ภาคเรียนที่ 1' },
  { value: '2', label: 'ภาคเรียนที่ 2' },
]

// ── Column mapping (0-indexed, data rows start at index 2) ───
const COL = {
  school_code: 0, school_name: 1, national_id: 2, grade: 3, room: 4,
  student_code: 5, gender: 6, prefix: 7, first_name: 8, last_name: 9,
  birth_date: 10, age: 11, weight: 12, height: 13, blood_type: 14,
  religion: 15, nationality: 17, disadvantaged: 34,
}

// ── Parse Excel → raw data rows ──────────────────────────────
async function parseExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb   = read(e.target.result, { type: 'array' })
        const ws   = wb.Sheets[wb.SheetNames[0]]
        const all  = utils.sheet_to_json(ws, { header: 1, defval: '' })
        // row 0 = metadata, row 1 = headers, row 2+ = data
        const rows = all.slice(2).filter(r => r[COL.school_code] && String(r[COL.school_code]).trim())
        resolve(rows)
      } catch (err) { reject(err) }
    }
    reader.onerror = reject
    reader.readAsArrayBuffer(file)
  })
}

function num(val) { return val !== '' && val !== null ? Number(val) : null }
function str(val) { return String(val ?? '').trim() }

function rowToStudent(row) {
  const weight = num(row[COL.weight])
  const height = num(row[COL.height])
  return {
    school_id:    props.school.id,
    national_id:  str(row[COL.national_id]),
    student_code: str(row[COL.student_code]),
    grade:        str(row[COL.grade]),
    room:         parseInt(row[COL.room]) || 1,
    gender:       str(row[COL.gender]),
    prefix:       str(row[COL.prefix]),
    first_name:   str(row[COL.first_name]),
    last_name:    str(row[COL.last_name]),
    birth_date:   str(row[COL.birth_date]),
    age_years:    row[COL.age] !== '' ? parseInt(row[COL.age]) : null,
    weight, height,
    blood_type:   str(row[COL.blood_type]),
    religion:     str(row[COL.religion]),
    nationality:  str(row[COL.nationality]),
    disadvantaged:str(row[COL.disadvantaged]),
    academic_year: academicYear.value,
    term:          term.value,
  }
}

function buildPreview(rows) {
  const grades = {}
  let male = 0, female = 0, disadvantaged = 0
  let totalW = 0, totalH = 0, wCnt = 0, hCnt = 0
  let underweight = 0, normal_ = 0, overweight = 0, obese = 0

  for (const row of rows) {
    const grade = str(row[COL.grade])
    const gender = str(row[COL.gender])
    const dis = str(row[COL.disadvantaged])
    const w = num(row[COL.weight])
    const h = num(row[COL.height])

    if (!grades[grade]) grades[grade] = { total: 0, male: 0, female: 0 }
    grades[grade].total++
    if (gender === 'ช') { male++; grades[grade].male++ }
    else if (gender === 'ญ') { female++; grades[grade].female++ }
    if (dis && dis !== '-') disadvantaged++

    if (w && w > 0) { totalW += w; wCnt++ }
    if (h && h > 0) { totalH += h; hCnt++ }

    if (w && h && h > 0) {
      const bmi = w / Math.pow(h / 100, 2)
      if (bmi < 18.5) underweight++
      else if (bmi < 23) normal_++
      else if (bmi < 25) overweight++
      else obese++
    }
  }

  return {
    total: rows.length, grades, male, female, disadvantaged,
    health: {
      avg_weight:  wCnt > 0 ? +(totalW / wCnt).toFixed(1) : null,
      avg_height:  hCnt > 0 ? +(totalH / hCnt).toFixed(1) : null,
      underweight, normal: normal_, overweight, obese,
    },
  }
}

// ════════════════════════════════════════════════════════════
// TAB 1 — นักเรียนปัจจุบัน
// ════════════════════════════════════════════════════════════
const s1File       = ref(null)
const s1FileRef    = ref(null)
const s1Preview    = ref(null)
const s1Importing  = ref(false)
const s1History    = ref([])
const s1Loading    = ref(true)

function onS1File(e) {
  const f = e.target.files?.[0]
  if (f) previewS1(f)
}

async function previewS1(file) {
  if (!file.name.match(/\.(xlsx|xls)$/i)) {
    Swal.fire({ icon: 'warning', title: 'ไฟล์ไม่รองรับ', text: 'รองรับเฉพาะ .xlsx, .xls' })
    return
  }
  try {
    const rows = await parseExcel(file)
    s1File.value = file
    s1Preview.value = { ...buildPreview(rows), fileName: file.name, rowCount: rows.length }
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่ได้', text: err.message })
  }
}

async function importStudents() {
  if (!s1Preview.value) return
  const ok = await Swal.fire({
    title: 'นำเข้าข้อมูลนักเรียน?',
    html: `ข้อมูลนักเรียนปี <b>${academicYear.value}</b> ภาคเรียน <b>${term.value}</b> จะถูกแทนที่ด้วยข้อมูลใหม่<br>
           จำนวน <b>${s1Preview.value.total} คน</b>`,
    icon: 'question', showCancelButton: true,
    confirmButtonText: 'นำเข้า', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#3b82f6',
  })
  if (!ok.isConfirmed) return

  s1Importing.value = true
  try {
    // ลบข้อมูลเดิม
    const { error: delErr } = await supabase
      .from('students').delete()
      .eq('school_id', props.school.id)
      .eq('academic_year', academicYear.value)
      .eq('term', term.value)
    if (delErr) throw delErr

    // parse + insert เป็น chunk
    const rows    = await parseExcel(s1File.value)
    const records = rows.map(r => rowToStudent(r))
    const CHUNK   = 200
    for (let i = 0; i < records.length; i += CHUNK) {
      const { error } = await supabase.from('students').insert(records.slice(i, i + CHUNK))
      if (error) throw error
    }

    s1File.value = null; s1Preview.value = null
    if (s1FileRef.value) s1FileRef.value.value = ''
    Swal.fire({ icon: 'success', title: `นำเข้าสำเร็จ ${records.length} คน`, showConfirmButton: false, timer: 1500 })
    await fetchS1History()
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'นำเข้าไม่สำเร็จ', text: err.message })
  } finally { s1Importing.value = false }
}

async function fetchS1History() {
  s1Loading.value = true
  const { data } = await supabase.rpc('get_student_batches', { p_school_id: props.school.id })
  s1History.value = data || []
  s1Loading.value = false
}

async function deleteStudentBatch(year, trm) {
  const ok = await Swal.fire({
    title: `ลบข้อมูลนักเรียนปี ${year} เทอม ${trm}?`,
    icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!ok.isConfirmed) return
  const { error } = await supabase.from('students').delete()
    .eq('school_id', props.school.id).eq('academic_year', year).eq('term', trm)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  Swal.fire({ icon: 'success', title: 'ลบสำเร็จ', showConfirmButton: false, timer: 900 })
  await fetchS1History()
}

// ════════════════════════════════════════════════════════════
// TAB 2 — สถิติย้อนหลัง
// ════════════════════════════════════════════════════════════
const s2File      = ref(null)
const s2FileRef   = ref(null)
const s2Preview   = ref(null)
const s2Importing = ref(false)
const s2History   = ref([])
const s2Loading   = ref(true)
const countDate   = ref('')

function onS2File(e) {
  const f = e.target.files?.[0]
  if (f) previewS2(f)
}

async function previewS2(file) {
  if (!file.name.match(/\.(xlsx|xls)$/i)) {
    Swal.fire({ icon: 'warning', title: 'ไฟล์ไม่รองรับ', text: 'รองรับเฉพาะ .xlsx, .xls' })
    return
  }
  try {
    const rows = await parseExcel(file)
    s2File.value = file
    s2Preview.value = { ...buildPreview(rows), fileName: file.name }
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่ได้', text: err.message })
  }
}

async function importStats() {
  if (!s2Preview.value) return
  s2Importing.value = true
  const p = s2Preview.value
  const { error } = await supabase.from('enrollment_stats').upsert({
    school_id:          props.school.id,
    academic_year:      academicYear.value,
    term:               term.value,
    count_date:         countDate.value || null,
    total_students:     p.total,
    male_count:         p.male,
    female_count:       p.female,
    grade_stats:        p.grades,
    health_stats:       p.health,
    disadvantaged_count:p.disadvantaged,
    source_filename:    p.fileName,
  }, { onConflict: 'school_id,academic_year,term' })
  s2Importing.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  s2File.value = null; s2Preview.value = null
  if (s2FileRef.value) s2FileRef.value.value = ''
  Swal.fire({ icon: 'success', title: 'บันทึกสถิติสำเร็จ', showConfirmButton: false, timer: 1200 })
  await fetchS2History()
}

async function fetchS2History() {
  s2Loading.value = true
  const { data } = await supabase
    .from('enrollment_stats').select('*')
    .eq('school_id', props.school.id)
    .order('academic_year', { ascending: false })
    .order('term', { ascending: false })
  s2History.value = data || []
  s2Loading.value = false
}

async function deleteStat(id, year, trm) {
  const ok = await Swal.fire({
    title: `ลบสถิติปี ${year} เทอม ${trm}?`, icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!ok.isConfirmed) return
  const { error } = await supabase.from('enrollment_stats').delete().eq('id', id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  Swal.fire({ icon: 'success', title: 'ลบสำเร็จ', showConfirmButton: false, timer: 900 })
  await fetchS2History()
}

// ── DMC History (ระบบใหม่) ────────────────────────────────────────────────
const dmcHistory    = ref([])
const dmcHistLoading = ref(false)
const expandedHistory = ref(null)  // period_id ที่ขยาย

async function loadDmcHistory() {
  if (!props.school?.id) return
  dmcHistLoading.value = true
  const { data } = await supabase
    .from('dmc_school_uploads')
    .select('*, dmc_periods(id, title, academic_year, semester, is_archived, archived_at)')
    .eq('school_id', props.school.id)
    .order('uploaded_at', { ascending: false })
  dmcHistory.value    = data || []
  dmcHistLoading.value = false
}

function toggleHistory(id) {
  expandedHistory.value = expandedHistory.value === id ? null : id
}

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function bmiPct(summary, key) {
  const total = (summary?.bmi?.underweight||0) + (summary?.bmi?.normal||0)
    + (summary?.bmi?.overweight||0) + (summary?.bmi?.obese||0)
  if (!total) return '0'
  return ((summary?.bmi?.[key]||0) / total * 100).toFixed(1)
}

onMounted(() => Promise.all([loadActivePeriod(), loadDmcHistory()]))
</script>

<template>
  <div class="space-y-5 max-w-3xl font-sarabun">

    <div>
      <h1 class="text-xl font-extrabold text-slate-800">ข้อมูล DMC นักเรียน</h1>
      <p class="text-sm text-slate-500 mt-0.5">นำเข้าข้อมูลนักเรียนจากไฟล์ Excel ของ DMC</p>
    </div>

    <!-- Tabs -->
    <div class="flex bg-slate-100 rounded-2xl p-1">
      <button @click="activeTab='dmc'"
        :class="['flex-1 py-2.5 text-sm font-bold rounded-xl transition-all flex items-center justify-center gap-2',
          activeTab==='dmc' ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
        </svg>
        อัปโหลด DMC
      </button>
      <button @click="activeTab='stats'"
        :class="['flex-1 py-2.5 text-sm font-bold rounded-xl transition-all flex items-center justify-center gap-2',
          activeTab==='stats' ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
        </svg>
        สถิติย้อนหลัง
      </button>
    </div>

    <!-- ─────────────── DMC Upload Tab ─────────────── -->
    <template v-if="activeTab === 'dmc'">

      <!-- No active period -->
      <div v-if="!activePeriod"
        class="text-center py-12 bg-slate-50 rounded-2xl border border-slate-200">
        <svg class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <p class="font-bold text-slate-600">ยังไม่มีรอบการเก็บข้อมูลที่เปิดอยู่</p>
        <p class="text-sm text-slate-400 mt-1">รอ admin เปิดรอบการอัปโหลดข้อมูลนักเรียน</p>
      </div>

      <!-- Active period -->
      <template v-else>
        <!-- Period info -->
        <div class="bg-primary/5 border border-primary/20 rounded-2xl p-4">
          <div class="flex items-center justify-between flex-wrap gap-2">
            <div>
              <p class="font-extrabold text-primary">{{ activePeriod.title }}</p>
              <p class="text-xs text-slate-500 mt-0.5">ปีการศึกษา {{ activePeriod.academic_year }} ภาคเรียน {{ activePeriod.semester }}</p>
              <p v-if="activePeriod.deadline" class="text-xs text-slate-400">กำหนดส่ง: {{ formatDmcDate(activePeriod.deadline) }}</p>
            </div>
            <span v-if="myUpload" class="text-xs bg-emerald-100 text-emerald-700 font-bold px-3 py-1.5 rounded-full">
              ✓ ส่งแล้ว {{ formatDmcDate(myUpload.uploaded_at) }}
            </span>
            <span v-else class="text-xs bg-amber-100 text-amber-700 font-bold px-3 py-1.5 rounded-full">
              รอส่ง
            </span>
          </div>
        </div>

        <!-- File upload zone -->
        <div v-if="!dmcParsed"
          @dragenter.prevent="dmcDragging=true"
          @dragleave.prevent="dmcDragging=false"
          @dragover.prevent
          @drop.prevent="onDmcDrop"
          :class="['border-2 border-dashed rounded-2xl p-10 text-center transition-all cursor-pointer',
            dmcDragging ? 'border-primary bg-primary/5' : 'border-slate-300 hover:border-primary hover:bg-primary/5']"
          @click="$refs.dmcInput.click()">
          <input ref="dmcInput" type="file" accept=".xlsx,.xls" class="sr-only"
            @change="handleDmcFile($event.target.files[0])"/>
          <svg v-if="!dmcParsing" class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
          </svg>
          <div v-if="dmcParsing" class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin mx-auto mb-3"/>
          <p class="font-bold text-slate-600">{{ dmcParsing ? 'กำลังวิเคราะห์ไฟล์...' : 'ลากไฟล์ Excel มาวาง หรือคลิกเพื่อเลือก' }}</p>
          <p class="text-sm text-slate-400 mt-1">รองรับไฟล์ DMC .xlsx / .xls</p>
        </div>

        <!-- Preview summary -->
        <template v-if="dmcParsed">
          <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
            <div class="px-5 py-4 border-b border-slate-50 flex items-center justify-between">
              <div>
                <p class="font-extrabold text-slate-800">ตรวจสอบข้อมูลก่อนบันทึก</p>
                <p class="text-xs text-slate-400 mt-0.5">{{ dmcFile?.name }}</p>
              </div>
              <button @click="clearDmcFile" class="text-xs text-slate-400 hover:text-red-500 transition-colors">เลือกไฟล์ใหม่</button>
            </div>
            <div class="p-5 space-y-4">
              <!-- Stats grid -->
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div class="text-center bg-primary/5 rounded-xl p-3">
                  <p class="text-2xl font-extrabold text-primary">{{ dmcParsed.total.toLocaleString() }}</p>
                  <p class="text-xs text-slate-500 mt-0.5">นักเรียนทั้งหมด</p>
                </div>
                <div class="text-center bg-blue-50 rounded-xl p-3">
                  <p class="text-2xl font-extrabold text-blue-600">{{ dmcParsed.gender.male.toLocaleString() }}</p>
                  <p class="text-xs text-slate-500 mt-0.5">ชาย</p>
                </div>
                <div class="text-center bg-pink-50 rounded-xl p-3">
                  <p class="text-2xl font-extrabold text-pink-500">{{ dmcParsed.gender.female.toLocaleString() }}</p>
                  <p class="text-xs text-slate-500 mt-0.5">หญิง</p>
                </div>
                <div :class="['text-center rounded-xl p-3', Number(dmcParsed.disadvantaged.pct) > 50 ? 'bg-red-50' : 'bg-amber-50']">
                  <p :class="['text-2xl font-extrabold', Number(dmcParsed.disadvantaged.pct) > 50 ? 'text-red-600' : 'text-amber-600']">
                    {{ dmcParsed.disadvantaged.pct }}%
                  </p>
                  <p class="text-xs text-slate-500 mt-0.5">ยากจน</p>
                </div>
              </div>

              <!-- Grade breakdown -->
              <div class="grid grid-cols-3 sm:grid-cols-6 gap-2">
                <div v-for="(data, grade) in dmcParsed.by_grade" :key="grade"
                  class="text-center bg-slate-50 rounded-xl p-2">
                  <p class="text-xs font-bold text-slate-600">{{ grade }}</p>
                  <p class="text-lg font-extrabold text-slate-800">{{ data.total }}</p>
                  <p class="text-[10px] text-slate-400">ช {{ data.male }} ญ {{ data.female }}</p>
                </div>
              </div>

              <!-- BMI -->
              <div class="grid grid-cols-4 gap-2 text-center text-xs">
                <div class="bg-orange-50 rounded-xl p-2">
                  <p class="font-bold text-orange-600 text-lg">{{ dmcParsed.bmi.underweight }}</p>
                  <p class="text-slate-500">ต่ำกว่าเกณฑ์</p>
                </div>
                <div class="bg-emerald-50 rounded-xl p-2">
                  <p class="font-bold text-emerald-600 text-lg">{{ dmcParsed.bmi.normal }}</p>
                  <p class="text-slate-500">ปกติ</p>
                </div>
                <div class="bg-amber-50 rounded-xl p-2">
                  <p class="font-bold text-amber-600 text-lg">{{ dmcParsed.bmi.overweight }}</p>
                  <p class="text-slate-500">น้ำหนักเกิน</p>
                </div>
                <div class="bg-red-50 rounded-xl p-2">
                  <p class="font-bold text-red-600 text-lg">{{ dmcParsed.bmi.obese }}</p>
                  <p class="text-slate-500">อ้วน</p>
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-slate-50 flex gap-3 justify-end">
              <button @click="clearDmcFile" class="px-4 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">
                ยกเลิก
              </button>
              <button @click="saveDmcUpload" :disabled="dmcSaving"
                class="flex items-center gap-2 px-6 py-2.5 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
                <svg v-if="dmcSaving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
                {{ dmcSaving ? 'กำลังบันทึก...' : myUpload ? 'อัปเดตข้อมูล' : 'บันทึกข้อมูล' }}
              </button>
            </div>
          </div>
        </template>
      </template>
    </template>
    <!-- ─────────────── End DMC Tab ─────────────── -->

    <!-- ── ปีการศึกษา + ภาคเรียน (shared) ────────────── -->
    <div class="grid grid-cols-2 gap-4">
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1.5">ปีการศึกษา</label>
        <select v-model="academicYear"
          class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
          <option v-for="y in YEAR_OPTIONS" :key="y" :value="y">{{ y }}</option>
        </select>
      </div>
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1.5">ภาคเรียน</label>
        <select v-model="term"
          class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
          <option v-for="t in TERM_OPTIONS" :key="t.value" :value="t.value">{{ t.label }}</option>
        </select>
      </div>
    </div>

    <!-- ════════════════════════════════════════════════ -->
    <!-- TAB เก่า: ซ่อนไว้ (ไม่ลบเพื่อ backward compat) -->
    <!-- ════════════════════════════════════════════════ -->
    <template v-if="false && activeTab==='__hidden_students__'">

      <!-- Upload card -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
        <h2 class="font-extrabold text-slate-800 text-sm">อัปโหลดไฟล์ Excel DMC (นักเรียนรายคน)</h2>

        <label class="flex flex-col items-center justify-center gap-3 border-2 border-dashed border-slate-200
                       rounded-2xl p-8 cursor-pointer hover:border-primary/50 hover:bg-slate-50 transition-all group">
          <input ref="s1FileRef" type="file" accept=".xlsx,.xls" class="hidden" @change="onS1File"/>
          <div class="w-12 h-12 rounded-2xl bg-primary-light flex items-center justify-center group-hover:scale-105 transition-transform">
            <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
            </svg>
          </div>
          <div class="text-center">
            <p class="font-bold text-slate-700">คลิกเพื่อเลือกไฟล์</p>
            <p class="text-xs text-slate-400 mt-0.5">รองรับ .xlsx, .xls จาก DMC</p>
          </div>
        </label>

        <!-- Preview -->
        <div v-if="s1Preview" class="space-y-4">
          <div class="p-3 bg-blue-50 border border-blue-200 rounded-xl text-xs text-blue-700 font-bold flex items-center gap-2">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/>
            </svg>
            {{ s1Preview.fileName }}
          </div>

          <!-- Stats -->
          <div class="grid grid-cols-3 gap-3">
            <div class="bg-slate-50 rounded-xl p-3 text-center">
              <p class="text-2xl font-extrabold text-primary">{{ s1Preview.total.toLocaleString() }}</p>
              <p class="text-xs text-slate-500 mt-0.5">นักเรียนทั้งหมด</p>
            </div>
            <div class="bg-blue-50 rounded-xl p-3 text-center">
              <p class="text-2xl font-extrabold text-blue-600">{{ s1Preview.male.toLocaleString() }}</p>
              <p class="text-xs text-slate-500 mt-0.5">ชาย</p>
            </div>
            <div class="bg-pink-50 rounded-xl p-3 text-center">
              <p class="text-2xl font-extrabold text-pink-500">{{ s1Preview.female.toLocaleString() }}</p>
              <p class="text-xs text-slate-500 mt-0.5">หญิง</p>
            </div>
          </div>

          <!-- Grade breakdown -->
          <div class="space-y-1.5">
            <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">แยกตามชั้น</p>
            <div v-for="(val, gr) in s1Preview.grades" :key="gr"
              class="flex items-center gap-3 text-xs">
              <span class="w-10 font-bold text-slate-600 flex-shrink-0">{{ gr }}</span>
              <div class="flex-1 bg-slate-100 rounded-full h-2 overflow-hidden">
                <div class="h-full bg-primary rounded-full transition-all"
                  :style="{ width: Math.round(val.total / s1Preview.total * 100) + '%' }"></div>
              </div>
              <span class="w-12 text-right font-mono text-slate-500">{{ val.total }} คน</span>
            </div>
          </div>

          <div class="flex items-center gap-2 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
            </svg>
            ข้อมูลเดิมปี {{ academicYear }} เทอม {{ term }} จะถูกลบและแทนที่ใหม่ทั้งหมด
          </div>

          <div class="flex gap-3">
            <button @click="s1Preview=null; s1File=null; if(s1FileRef) s1FileRef.value=''"
              class="flex-1 py-2.5 border border-slate-200 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-50 transition-all">
              ยกเลิก
            </button>
            <button @click="importStudents" :disabled="s1Importing"
              class="flex-1 py-2.5 bg-primary text-white rounded-xl text-sm font-bold hover:bg-primary-dark transition-all disabled:opacity-50 flex items-center justify-center gap-2">
              <svg v-if="s1Importing" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
              </svg>
              {{ s1Importing ? 'กำลังนำเข้า...' : 'นำเข้าข้อมูล' }}
            </button>
          </div>
        </div>
      </div>

      <!-- History -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50">
          <h2 class="font-extrabold text-slate-800 text-sm">ข้อมูลที่นำเข้าแล้ว</h2>
        </div>
        <div v-if="s1Loading" class="p-8 text-center text-slate-400 text-sm">กำลังโหลด...</div>
        <div v-else-if="!s1History.length" class="p-8 text-center text-slate-400 text-sm">ยังไม่มีข้อมูล</div>
        <div v-else class="divide-y divide-slate-50">
          <div v-for="h in s1History" :key="`${h.academic_year}-${h.term}`"
            class="flex items-center gap-4 px-5 py-4">
            <div class="flex-1">
              <p class="font-bold text-slate-800 text-sm">ปีการศึกษา {{ h.academic_year }} ภาคเรียนที่ {{ h.term }}</p>
              <p class="text-xs text-slate-400 mt-0.5">{{ h.count.toLocaleString() }} คน · นำเข้าล่าสุด {{ fmtDate(h.imported_at) }}</p>
            </div>
            <button @click="deleteStudentBatch(h.academic_year, h.term)"
              class="px-3 py-1.5 text-xs font-bold text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors">
              ลบ
            </button>
          </div>
        </div>
      </div>
    </template>

    <!-- ════════════════════════════════════════════════ -->
    <!-- TAB 2: สถิติย้อนหลัง (ระบบใหม่ dmc_school_uploads) -->
    <!-- ════════════════════════════════════════════════ -->
    <template v-if="activeTab === 'stats'">

      <!-- Loading -->
      <div v-if="dmcHistLoading" class="flex justify-center py-12">
        <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
      </div>

      <!-- Empty -->
      <div v-else-if="dmcHistory.length === 0"
        class="text-center py-14 bg-slate-50 rounded-2xl border border-slate-200">
        <svg class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75z M9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625z M16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
        </svg>
        <p class="font-bold text-slate-500">ยังไม่มีประวัติการส่ง DMC</p>
        <p class="text-sm text-slate-400 mt-1">อัปโหลดข้อมูลในแท็บ "อัปโหลด DMC" เพื่อเริ่มต้น</p>
      </div>

      <!-- History list -->
      <div v-else class="space-y-3">
        <p class="text-xs text-slate-500 font-bold uppercase tracking-wider">ประวัติการส่งข้อมูล DMC ({{ dmcHistory.length }} รอบ)</p>

        <div v-for="h in dmcHistory" :key="h.id"
          class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">

          <!-- Header row -->
          <div class="flex items-center gap-4 px-5 py-4 cursor-pointer hover:bg-slate-50 transition-colors"
            @click="toggleHistory(h.id)">
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-0.5">
                <span class="text-xs font-bold bg-primary/10 text-primary px-2.5 py-0.5 rounded-full">
                  {{ h.dmc_periods?.title || 'รอบไม่ทราบชื่อ' }}
                </span>
                <span v-if="h.dmc_periods?.is_archived"
                  class="text-xs bg-indigo-100 text-indigo-600 font-bold px-2 py-0.5 rounded-full">
                  📦 เก็บถาวร
                </span>
              </div>
              <p class="text-sm font-bold text-slate-800">{{ h.total.toLocaleString() }} คน</p>
              <p class="text-xs text-slate-400">อัปโหลด {{ fmtDate(h.uploaded_at) }}</p>
            </div>

            <!-- Quick stats -->
            <div class="hidden sm:flex gap-4 text-center text-xs flex-shrink-0">
              <div>
                <p class="font-bold text-blue-600">{{ h.summary?.gender?.male || 0 }}</p>
                <p class="text-slate-400">ชาย</p>
              </div>
              <div>
                <p class="font-bold text-pink-500">{{ h.summary?.gender?.female || 0 }}</p>
                <p class="text-slate-400">หญิง</p>
              </div>
              <div>
                <p :class="['font-bold', Number(h.summary?.disadvantaged?.pct||0) > 50 ? 'text-red-500' : 'text-amber-600']">
                  {{ h.summary?.disadvantaged?.pct || '0' }}%
                </p>
                <p class="text-slate-400">ยากจน</p>
              </div>
            </div>

            <!-- Expand icon -->
            <svg :class="['w-4 h-4 text-slate-400 transition-transform flex-shrink-0',
              expandedHistory === h.id ? 'rotate-180' : '']"
              fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
            </svg>
          </div>

          <!-- Expanded detail -->
          <Transition
            enter-active-class="transition duration-200 ease-out"
            enter-from-class="opacity-0 -translate-y-2"
            enter-to-class="opacity-100 translate-y-0"
            leave-active-class="transition duration-150"
            leave-to-class="opacity-0">
            <div v-if="expandedHistory === h.id" class="border-t border-slate-100 px-5 py-4 bg-slate-50 space-y-4">

              <!-- Grade breakdown -->
              <div v-if="h.summary?.by_grade && Object.keys(h.summary.by_grade).length">
                <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">แยกตามชั้น</p>
                <div class="flex flex-wrap gap-2">
                  <div v-for="(g, grade) in h.summary.by_grade" :key="grade"
                    class="text-center bg-white rounded-xl px-3 py-2 border border-slate-200">
                    <p class="text-xs font-bold text-slate-600">{{ grade }}</p>
                    <p class="text-base font-extrabold text-primary">{{ g.total }}</p>
                    <p class="text-[10px] text-slate-400">ช {{ g.male }} ญ {{ g.female }}</p>
                  </div>
                </div>
              </div>

              <!-- BMI -->
              <div v-if="h.summary?.bmi">
                <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">ภาวะโภชนาการ (BMI)</p>
                <div class="grid grid-cols-4 gap-2 text-center text-xs">
                  <div class="bg-orange-50 rounded-xl p-2">
                    <p class="font-bold text-orange-600 text-base">{{ h.summary.bmi.underweight }}</p>
                    <p class="text-slate-500">ต่ำเกณฑ์</p>
                    <p class="text-slate-400">{{ bmiPct(h.summary,'underweight') }}%</p>
                  </div>
                  <div class="bg-emerald-50 rounded-xl p-2">
                    <p class="font-bold text-emerald-600 text-base">{{ h.summary.bmi.normal }}</p>
                    <p class="text-slate-500">ปกติ</p>
                    <p class="text-slate-400">{{ bmiPct(h.summary,'normal') }}%</p>
                  </div>
                  <div class="bg-amber-50 rounded-xl p-2">
                    <p class="font-bold text-amber-600 text-base">{{ h.summary.bmi.overweight }}</p>
                    <p class="text-slate-500">น้ำหนักเกิน</p>
                    <p class="text-slate-400">{{ bmiPct(h.summary,'overweight') }}%</p>
                  </div>
                  <div class="bg-red-50 rounded-xl p-2">
                    <p class="font-bold text-red-600 text-base">{{ h.summary.bmi.obese }}</p>
                    <p class="text-slate-500">อ้วน</p>
                    <p class="text-slate-400">{{ bmiPct(h.summary,'obese') }}%</p>
                  </div>
                </div>
              </div>

              <!-- Disadvantaged -->
              <div v-if="h.summary?.disadvantaged?.count > 0">
                <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">ความด้อยโอกาส</p>
                <p class="text-sm">
                  เด็กยากจน
                  <span :class="['font-bold', Number(h.summary.disadvantaged.pct) > 50 ? 'text-red-600' : 'text-amber-600']">
                    {{ h.summary.disadvantaged.count.toLocaleString() }} คน ({{ h.summary.disadvantaged.pct }}%)
                  </span>
                </p>
              </div>

            </div>
          </Transition>
        </div>
      </div>

      <!-- Hidden legacy section placeholder -->
      <div class="hidden">
        <h2 class="font-extrabold text-slate-800 text-sm">อัปโหลดไฟล์ (เก็บเฉพาะสถิติ ไม่บันทึกรายชื่อ)</h2>

        <label class="flex flex-col items-center justify-center gap-3 border-2 border-dashed border-slate-200
                       rounded-2xl p-8 cursor-pointer hover:border-emerald-400/60 hover:bg-emerald-50/30 transition-all group">
          <input ref="s2FileRef" type="file" accept=".xlsx,.xls" class="hidden" @change="onS2File"/>
          <div class="w-12 h-12 rounded-2xl bg-emerald-100 flex items-center justify-center group-hover:scale-105 transition-transform">
            <svg class="w-6 h-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
            </svg>
          </div>
          <div class="text-center">
            <p class="font-bold text-slate-700">คลิกเพื่อเลือกไฟล์</p>
            <p class="text-xs text-slate-400 mt-0.5">ระบบจะคำนวณสถิติและไม่เก็บรายชื่อ</p>
          </div>
        </label>

        <!-- Preview -->
        <div v-if="s2Preview" class="space-y-4">
          <p class="text-xs font-bold text-slate-500">{{ s2Preview.fileName }}</p>

          <!-- Summary stats -->
          <div class="grid grid-cols-2 gap-3">
            <div class="bg-slate-50 rounded-xl p-3">
              <p class="text-xl font-extrabold text-slate-800">{{ s2Preview.total.toLocaleString() }}</p>
              <p class="text-xs text-slate-500">นักเรียนทั้งหมด</p>
            </div>
            <div class="bg-amber-50 rounded-xl p-3">
              <p class="text-xl font-extrabold text-amber-700">{{ s2Preview.disadvantaged.toLocaleString() }}</p>
              <p class="text-xs text-slate-500">นักเรียนด้อยโอกาส</p>
            </div>
          </div>

          <!-- Health stats -->
          <div v-if="s2Preview.health.avg_weight" class="bg-slate-50 rounded-xl p-4 space-y-2">
            <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">ข้อมูลสุขภาพ (เฉลี่ย)</p>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <p class="text-lg font-extrabold text-slate-800">{{ s2Preview.health.avg_weight }} kg</p>
                <p class="text-xs text-slate-500">น้ำหนักเฉลี่ย</p>
              </div>
              <div>
                <p class="text-lg font-extrabold text-slate-800">{{ s2Preview.health.avg_height }} cm</p>
                <p class="text-xs text-slate-500">ส่วนสูงเฉลี่ย</p>
              </div>
            </div>
            <div class="grid grid-cols-4 gap-2 pt-1">
              <div v-for="(val, key) in { 'ผอม': s2Preview.health.underweight, 'ปกติ': s2Preview.health.normal, 'เกิน': s2Preview.health.overweight, 'อ้วน': s2Preview.health.obese }"
                :key="key" class="text-center">
                <p class="font-extrabold text-sm text-slate-700">{{ val }}</p>
                <p class="text-[10px] text-slate-400">{{ key }}</p>
              </div>
            </div>
          </div>

          <div class="flex gap-3">
            <button @click="s2Preview=null; s2File=null; if(s2FileRef) s2FileRef.value=''"
              class="flex-1 py-2.5 border border-slate-200 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-50 transition-all">
              ยกเลิก
            </button>
            <button @click="importStats" :disabled="s2Importing"
              class="flex-1 py-2.5 bg-emerald-500 text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all disabled:opacity-50 flex items-center justify-center gap-2">
              <svg v-if="s2Importing" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
              </svg>
              {{ s2Importing ? 'กำลังบันทึก...' : 'บันทึกสถิติ' }}
            </button>
          </div>
        </div>
      </div>

      <!-- legacy hidden -->
      <div class="hidden">
        <h2>สถิติย้อนหลัง (เก่า)</h2>
        <div class="p-5 space-y-4">
          <!-- Bar chart -->
          <div class="space-y-3">
            <div v-for="h in s2History" :key="h.id" class="space-y-1">
              <div class="flex items-center justify-between text-xs">
                <span class="font-bold text-slate-700">ปี {{ h.academic_year }} เทอม {{ h.term }}
                  <span v-if="h.count_date" class="font-normal text-slate-400 ml-1">({{ fmtDate(h.count_date) }})</span>
                </span>
                <div class="flex items-center gap-2">
                  <span class="font-extrabold text-primary">{{ h.total_students.toLocaleString() }} คน</span>
                  <button @click="deleteStat(h.id, h.academic_year, h.term)"
                    class="text-red-400 hover:text-red-600 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              </div>
              <!-- Stacked bar: ชาย / หญิง -->
              <div class="h-6 bg-slate-100 rounded-full overflow-hidden flex">
                <div class="h-full bg-blue-400 transition-all flex items-center justify-end pr-1"
                  :style="{ width: barPct(h.male_count) + '%' }">
                  <span v-if="barPct(h.male_count) > 10" class="text-[10px] text-white font-bold">{{ h.male_count }}</span>
                </div>
                <div class="h-full bg-pink-400 transition-all flex items-center justify-end pr-1"
                  :style="{ width: barPct(h.female_count) + '%' }">
                  <span v-if="barPct(h.female_count) > 10" class="text-[10px] text-white font-bold">{{ h.female_count }}</span>
                </div>
              </div>
              <!-- Health mini row -->
              <div v-if="h.health_stats?.avg_weight" class="flex gap-3 text-[10px] text-slate-400">
                <span>น้ำหนักเฉลี่ย {{ h.health_stats.avg_weight }} kg</span>
                <span>ส่วนสูงเฉลี่ย {{ h.health_stats.avg_height }} cm</span>
                <span class="text-amber-600">ด้อยโอกาส {{ h.disadvantaged_count }} คน</span>
              </div>
            </div>
          </div>
          <!-- Legend -->
          <div class="flex gap-3 text-xs text-slate-500 pt-1">
            <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-blue-400 inline-block"></span>ชาย</span>
            <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-pink-400 inline-block"></span>หญิง</span>
          </div>
        </div>
      </div>
    </template>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
