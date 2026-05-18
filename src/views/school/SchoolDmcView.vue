<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { read, utils } from 'xlsx'
import Swal from 'sweetalert2'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const activeTab     = ref('students')
const academicYear  = ref('2568')
const term          = ref('1')

const YEAR_OPTIONS = ['2568', '2567', '2566', '2565', '2564']
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

// bar chart helpers
const s2MaxTotal = computed(() => Math.max(...s2History.value.map(h => h.total_students), 1))

function barPct(val) { return Math.round((val / s2MaxTotal.value) * 100) }

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

onMounted(() => Promise.all([fetchS1History(), fetchS2History()]))
</script>

<template>
  <div class="space-y-5 max-w-3xl font-sarabun">

    <div>
      <h1 class="text-xl font-extrabold text-slate-800">ข้อมูล DMC นักเรียน</h1>
      <p class="text-sm text-slate-500 mt-0.5">นำเข้าข้อมูลนักเรียนจากไฟล์ Excel ของ DMC</p>
    </div>

    <!-- Tabs -->
    <div class="flex bg-slate-100 rounded-2xl p-1">
      <button @click="activeTab='students'"
        :class="['flex-1 py-2.5 text-sm font-bold rounded-xl transition-all flex items-center justify-center gap-2',
          activeTab==='students' ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197"/>
        </svg>
        นักเรียนปัจจุบัน
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
    <!-- TAB 1: นักเรียนปัจจุบัน                         -->
    <!-- ════════════════════════════════════════════════ -->
    <template v-if="activeTab==='students'">

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
    <!-- TAB 2: สถิติย้อนหลัง                            -->
    <!-- ════════════════════════════════════════════════ -->
    <template v-else>

      <!-- Count date -->
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1.5">วันที่นับนักเรียน (เช่น 10 มิ.ย.)</label>
        <input v-model="countDate" type="date"
          class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white"/>
      </div>

      <!-- Upload card -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
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

      <!-- Stats history + bar chart -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50">
          <h2 class="font-extrabold text-slate-800 text-sm">สถิติย้อนหลัง</h2>
        </div>
        <div v-if="s2Loading" class="p-8 text-center text-slate-400 text-sm">กำลังโหลด...</div>
        <div v-else-if="!s2History.length" class="p-8 text-center text-slate-400 text-sm">ยังไม่มีสถิติ</div>
        <div v-else class="p-5 space-y-4">
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
