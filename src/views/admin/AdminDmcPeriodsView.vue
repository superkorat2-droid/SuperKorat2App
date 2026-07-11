<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const router = useRouter()

const periods  = ref([])
const schools  = ref([])
const loading  = ref(true)
const saving   = ref(false)

// ── Modal: create/edit period ─────────────────────────────────────────────
const showModal  = ref(false)
const editPeriod = ref(null)
// ปีการศึกษาไทย = ค.ศ. + 543
const currentThaiYear = new Date().getFullYear() + 543
const YEAR_OPTIONS = Array.from({ length: 8 }, (_, i) => String(currentThaiYear + 1 - i))

const emptyForm  = () => ({
  id: null, title: '', academic_year: String(currentThaiYear), semester: 1,
  is_active: true, deadline: '',
})
const form = ref(emptyForm())

// ── Visibility modal ──────────────────────────────────────────────────────
const showVisibility = ref(false)
const visPeriod      = ref(null)

const VIS_FIELDS = [
  { key: 'total',            label: 'จำนวนนักเรียนรวม',           risk: 'low' },
  { key: 'by_grade',         label: 'แยกตามระดับชั้น',             risk: 'low' },
  { key: 'gender',           label: 'แยกตามเพศ',                   risk: 'low' },
  { key: 'bmi',              label: 'ภาวะโภชนาการ (BMI)',          risk: 'medium' },
  { key: 'disadvantaged',    label: 'ความด้อยโอกาส / เด็กยากจน',   risk: 'high' },
  { key: 'guardian_relation',label: 'ผู้ปกครอง (ความสัมพันธ์)',    risk: 'high' },
  { key: 'parent_jobs',      label: 'อาชีพผู้ปกครอง',              risk: 'high' },
  { key: 'religion',         label: 'ศาสนา',                        risk: 'high' },
  { key: 'nationality',      label: 'เชื้อชาติ / สัญชาติ',          risk: 'high' },
]

const RISK_COLOR = {
  low:    'bg-emerald-100 text-emerald-700',
  medium: 'bg-amber-100 text-amber-700',
  high:   'bg-red-100 text-red-600',
}
const RISK_LABEL = { low: 'ต่ำ', medium: 'กลาง', high: 'สูง' }

async function load() {
  loading.value = true
  const [{ data: p }, { data: sc }] = await Promise.all([
    supabase.from('dmc_periods').select('*').order('created_at', { ascending: false }),
    supabase.from('schools').select('id, name, district').order('district').order('name'),
  ])
  periods.value = p || []
  schools.value = sc || []
  loading.value = false
}

// ── Upload status per period ───────────────────────────────────────────────
const uploadCounts = ref({})
async function loadUploadCounts() {
  const { data } = await supabase
    .from('dmc_school_uploads')
    .select('period_id, school_id')
  if (!data) return
  const map = {}
  data.forEach(u => {
    if (!map[u.period_id]) map[u.period_id] = new Set()
    map[u.period_id].add(u.school_id)
  })
  Object.keys(map).forEach(pid => {
    uploadCounts.value[pid] = map[pid].size
  })
}

onMounted(async () => { await load(); await loadUploadCounts() })

// ── Create / Edit ─────────────────────────────────────────────────────────
function openCreate() {
  form.value = emptyForm()
  showModal.value = true
}
function openEdit(p) {
  form.value = {
    id: p.id, title: p.title, academic_year: p.academic_year,
    semester: p.semester, is_active: p.is_active,
    deadline: p.deadline ? p.deadline.slice(0, 16) : '',
  }
  showModal.value = true
}

async function savePeriod() {
  if (!form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณาใส่ชื่อรอบ' }); return
  }
  saving.value = true
  const payload = {
    title:         form.value.title.trim(),
    academic_year: form.value.academic_year,
    semester:      Number(form.value.semester),
    is_active:     form.value.is_active,
    deadline:      form.value.deadline || null,
    updated_at:    new Date().toISOString(),
  }
  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('dmc_periods').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('dmc_periods').insert(payload))
  }
  saving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  showModal.value = false
  await load()
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1200 })
}

async function deletePeriod(p) {
  const r = await Swal.fire({
    title: 'ลบรอบนี้?', text: `"${p.title}" และข้อมูลทั้งหมดจะถูกลบถาวร`,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  const { error } = await supabase.from('dmc_periods').delete().eq('id', p.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  await load(); await loadUploadCounts()
}

// ── Toggle active ─────────────────────────────────────────────────────────
async function toggleActive(p) {
  await supabase.from('dmc_periods').update({ is_active: !p.is_active }).eq('id', p.id)
  await load()
}

// ── Visibility modal ──────────────────────────────────────────────────────
function openVisibility(p) {
  visPeriod.value = {
    ...p,
    visibility: { ...p.visibility },
    show_public: p.show_public,
  }
  showVisibility.value = true
}
async function saveVisibility() {
  const { id, visibility, show_public } = visPeriod.value
  const { error } = await supabase.from('dmc_periods')
    .update({ visibility, show_public, updated_at: new Date().toISOString() }).eq('id', id)
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  showVisibility.value = false
  await load()
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1000 })
}

// ── Archive ───────────────────────────────────────────────────────────────
async function archivePeriod(p) {
  const uploadedCount = uploadCounts.value[p.id] || 0
  const r = await Swal.fire({
    title: 'เก็บถาวร?',
    html: `<div class="text-sm text-left">
      <p>รอบ: <b>${p.title}</b></p>
      <p>โรงเรียนส่งแล้ว: <b>${uploadedCount}/${schools.value.length}</b></p>
      <p class="mt-2 text-amber-600">หลังเก็บถาวรแล้ว จะไม่สามารถแก้ไขข้อมูลได้อีก</p>
    </div>`,
    icon: 'question', showCancelButton: true,
    confirmButtonText: 'เก็บถาวร', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#6366f1',
  })
  if (!r.isConfirmed) return
  const { error } = await supabase.from('dmc_periods').update({
    is_archived: true, is_active: false,
    archived_at: new Date().toISOString(),
    updated_at:  new Date().toISOString(),
  }).eq('id', p.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message }); return }
  Swal.fire({ icon: 'success', title: 'เก็บถาวรแล้ว', showConfirmButton: false, timer: 1500 })
  await load()
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

const activePeriods   = computed(() => periods.value.filter(p => !p.is_archived))
const archivedPeriods = computed(() => periods.value.filter(p => p.is_archived))
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 15.75V18m-7.5-6.75h.008v.008H8.25v-.008zm0 2.25h.008v.008H8.25V13.5zm0 2.25h.008v.008H8.25v-.008zm0 2.25h.008v.008H8.25V18zm2.498-6.75h.007v.008h-.007v-.008zm0 2.25h.007v.008h-.007V13.5zm0 2.25h.007v.008h-.007v-.008zm0 2.25h.007v.008h-.007V18zm2.504-6.75h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V13.5zm0 2.25h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V18zm2.498-6.75h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V13.5zM8.25 6h7.5v2.25h-7.5V6zM12 2.25c-1.892 0-3.758.11-5.593.322C5.307 2.7 4.5 3.65 4.5 4.757V19.5a2.25 2.25 0 002.25 2.25h10.5a2.25 2.25 0 002.25-2.25V4.757c0-1.108-.806-2.057-1.907-2.185A48.507 48.507 0 0012 2.25z"/>
          </svg>
          รอบการเก็บข้อมูล DMC
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการรอบการอัปโหลดข้อมูลนักเรียน</p>
      </div>
      <button @click="openCreate"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        สร้างรอบใหม่
      </button>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else>
      <!-- Active periods -->
      <div v-if="activePeriods.length > 0" class="space-y-4">
        <h2 class="text-sm font-bold text-slate-500 uppercase tracking-wider">รอบที่เปิดอยู่</h2>
        <div v-for="p in activePeriods" :key="p.id"
          class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full',
                  p.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500']">
                  {{ p.is_active ? '● เปิดรับ' : '○ ปิดรับ' }}
                </span>
                <span v-if="p.deadline && new Date(p.deadline) < new Date()"
                  class="text-xs bg-red-100 text-red-600 font-bold px-2 py-0.5 rounded-full">หมดเวลา</span>
              </div>
              <h3 class="font-extrabold text-slate-800 text-lg">{{ p.title }}</h3>
              <p class="text-xs text-slate-400 mt-0.5">ปีการศึกษา {{ p.academic_year }} ภาค {{ p.semester }}</p>
              <p v-if="p.deadline" class="text-xs text-slate-400">กำหนดส่ง: {{ formatDate(p.deadline) }}</p>

              <!-- Progress -->
              <div class="mt-3">
                <div class="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span>โรงเรียนส่งแล้ว {{ uploadCounts[p.id] || 0 }} / {{ schools.length }} โรง</span>
                  <span class="font-bold text-primary">{{ schools.length > 0 ? Math.round(((uploadCounts[p.id]||0)/schools.length)*100) : 0 }}%</span>
                </div>
                <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-primary to-blue-400 rounded-full transition-all"
                    :style="`width:${schools.length > 0 ? Math.round(((uploadCounts[p.id]||0)/schools.length)*100) : 0}%`"/>
                </div>
              </div>
            </div>

            <div class="flex flex-wrap gap-2 flex-shrink-0">
              <button @click="router.push(`/dashboard/dmc/${p.id}`)"
                class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75z M9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625z M16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/></svg>
                ดูสถิติ
              </button>
              <button @click="openVisibility(p)"
                class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-indigo-50 text-indigo-700 rounded-xl hover:bg-indigo-100 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                การแสดงผล
              </button>
              <button @click="toggleActive(p)"
                :class="['flex items-center gap-1 px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                  p.is_active ? 'bg-amber-50 text-amber-700 hover:bg-amber-100' : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100']">
                {{ p.is_active ? 'ปิดรับ' : 'เปิดรับ' }}
              </button>
              <button @click="archivePeriod(p)"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"/></svg>
                เก็บถาวร
              </button>
              <button @click="openEdit(p)"
                class="px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">แก้ไข</button>
              <button @click="deletePeriod(p)"
                class="px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:text-red-500 hover:bg-red-50 transition-colors">ลบ</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Empty active -->
      <div v-else
        class="text-center py-12 bg-white rounded-2xl border border-slate-100 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>
        </svg>
        <p class="font-medium">ยังไม่มีรอบการเก็บข้อมูล</p>
        <p class="text-sm mt-1">กด "สร้างรอบใหม่" เพื่อเริ่มต้น</p>
      </div>

      <!-- Archived periods -->
      <div v-if="archivedPeriods.length > 0" class="space-y-3">
        <h2 class="text-sm font-bold text-slate-500 uppercase tracking-wider">รอบที่เก็บถาวรแล้ว</h2>
        <div v-for="p in archivedPeriods" :key="p.id"
          class="bg-slate-50 rounded-2xl border border-slate-200 p-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <div class="flex items-center gap-2 mb-0.5">
              <span class="text-xs bg-indigo-100 text-indigo-700 font-bold px-2 py-0.5 rounded-full">📦 เก็บถาวร</span>
              <span v-if="p.show_public" class="text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">🌐 สาธารณะ</span>
            </div>
            <p class="font-bold text-slate-700">{{ p.title }}</p>
            <p class="text-xs text-slate-400">โรงเรียนส่ง {{ uploadCounts[p.id] || 0 }} โรง · เก็บถาวร {{ formatDate(p.archived_at) }}</p>
          </div>
          <div class="flex gap-2">
            <button @click="router.push(`/dashboard/dmc/${p.id}`)"
              class="px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors">
              ดูสถิติ
            </button>
            <button @click="openVisibility(p)"
              class="px-3 py-1.5 text-xs font-bold bg-indigo-50 text-indigo-700 rounded-xl hover:bg-indigo-100 transition-colors">
              การแสดงผล
            </button>
            <button @click="deletePeriod(p)"
              class="px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:text-red-500 hover:bg-red-50 transition-colors">
              ลบ
            </button>
          </div>
        </div>
      </div>
    </template>
  </div>

  <!-- ── Create/Edit Modal ──────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md">
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <h2 class="font-extrabold text-slate-800">{{ form.id ? 'แก้ไขรอบ' : 'สร้างรอบใหม่' }}</h2>
            <button @click="showModal=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="px-6 py-5 space-y-4">
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อรอบ <span class="text-red-500">*</span></label>
              <input v-model="form.title" type="text" placeholder="เช่น ข้อมูลนักเรียน ภาคเรียนที่ 1/2568"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ปีการศึกษา</label>
                <div class="relative">
                  <input v-model="form.academic_year" type="number" min="2550" max="2600"
                    list="year-suggestions"
                    class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                  <datalist id="year-suggestions">
                    <option v-for="y in YEAR_OPTIONS" :key="y" :value="y"/>
                  </datalist>
                </div>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ภาคเรียน</label>
                <select v-model="form.semester" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option :value="1">ภาคเรียนที่ 1</option>
                  <option :value="2">ภาคเรียนที่ 2</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">กำหนดส่ง (ไม่บังคับ)</label>
              <input v-model="form.deadline" type="datetime-local"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="form.is_active" class="w-4 h-4 accent-primary rounded"/>
              <span class="text-sm font-medium text-slate-700">เปิดรับข้อมูลทันที</span>
            </label>
          </div>
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="showModal=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="savePeriod" :disabled="saving" class="px-6 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- ── Visibility Modal ────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showVisibility && visPeriod" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden">
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <div>
              <h2 class="font-extrabold text-slate-800">การแสดงผลสาธารณะ</h2>
              <p class="text-xs text-slate-400 mt-0.5">{{ visPeriod.title }}</p>
            </div>
            <button @click="showVisibility=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
            <!-- Master toggle -->
            <div class="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-200">
              <div>
                <p class="font-bold text-slate-700">เปิดแสดงต่อสาธารณะ</p>
                <p class="text-xs text-slate-400 mt-0.5">หน้า /student-stats บนเว็บไซต์</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox" v-model="visPeriod.show_public" class="sr-only peer"/>
                <div class="w-11 h-6 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors
                            after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                            after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-5"/>
              </label>
            </div>

            <!-- Field toggles -->
            <div v-if="visPeriod.show_public" class="space-y-2">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">หมวดข้อมูลที่อนุญาต</p>
              <div v-for="f in VIS_FIELDS" :key="f.key"
                class="flex items-center gap-3 p-3 bg-white rounded-xl border border-slate-100">
                <label class="relative inline-flex items-center cursor-pointer flex-shrink-0">
                  <input type="checkbox" v-model="visPeriod.visibility[f.key]" class="sr-only peer"/>
                  <div class="w-9 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors
                              after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                              after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-4"/>
                </label>
                <span class="text-sm text-slate-700 flex-1">{{ f.label }}</span>
                <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', RISK_COLOR[f.risk]]">
                  ความเสี่ยง {{ RISK_LABEL[f.risk] }}
                </span>
              </div>
            </div>
            <p v-else class="text-xs text-slate-400 text-center py-4">เปิด "แสดงต่อสาธารณะ" ก่อนจึงจะกำหนดหมวดข้อมูลได้</p>
          </div>
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end flex-shrink-0">
            <button @click="showVisibility=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="saveVisibility" class="px-6 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all">
              บันทึก
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
