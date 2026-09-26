<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { NT_SUBJECTS } from '../../composables/useNtParser'

const router = useRouter()

const periods = ref([])
const scoreCounts = ref({})
const loading = ref(true)
const saving  = ref(false)

const EXAM_TYPES = [
  { value: 'NT',   label: 'NT — วัดผลสัมฤทธิ์ (ป.3)', grades: ['ป.3'], enabled: true },
  { value: 'ONET', label: 'O-NET (เร็วๆ นี้)',          grades: ['ป.6', 'ม.3', 'ม.6'], enabled: false },
  { value: 'RT',   label: 'RT — ความสามารถด้านการอ่าน (ป.1) (เร็วๆ นี้)', grades: ['ป.1'], enabled: false },
]

const currentThaiYear = new Date().getFullYear() + 543
const YEAR_OPTIONS = Array.from({ length: 8 }, (_, i) => String(currentThaiYear + 1 - i))

const showModal = ref(false)
const emptyForm = () => ({ exam_type: 'NT', grade_level: 'ป.3', academic_year: String(currentThaiYear), title: '' })
const form = ref(emptyForm())

const examTypeMeta = computed(() => EXAM_TYPES.find(e => e.value === form.value.exam_type))

function autoTitle() {
  const et = EXAM_TYPES.find(e => e.value === form.value.exam_type)
  return `ผลการทดสอบ${et ? ' ' + et.value : ''} ${form.value.grade_level} ปีการศึกษา ${form.value.academic_year}`
}

async function load() {
  loading.value = true
  const { data } = await supabase.from('nt_periods').select('*').order('academic_year', { ascending: false }).order('created_at', { ascending: false })
  periods.value = data || []
  loading.value = false
}

async function loadScoreCounts() {
  const { data } = await supabase.from('nt_school_scores').select('period_id')
  if (!data) return
  const map = {}
  data.forEach(r => { map[r.period_id] = (map[r.period_id] || 0) + 1 })
  scoreCounts.value = map
}

onMounted(async () => { await load(); await loadScoreCounts() })

function openCreate() {
  form.value = emptyForm()
  showModal.value = true
}

async function savePeriod() {
  if (!examTypeMeta.value?.enabled) {
    Swal.fire({ icon: 'warning', title: 'ประเภทสอบนี้ยังไม่รองรับการนำเข้า' }); return
  }
  const title = form.value.title.trim() || autoTitle()
  saving.value = true
  const { error } = await supabase.from('nt_periods').insert({
    exam_type: form.value.exam_type,
    grade_level: form.value.grade_level,
    academic_year: parseInt(form.value.academic_year, 10),
    title,
    subjects: NT_SUBJECTS,
  })
  saving.value = false
  if (error) {
    const msg = error.code === '23505' ? 'มีรอบของประเภทสอบ/ชั้น/ปีนี้อยู่แล้ว' : error.message
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: msg }); return
  }
  showModal.value = false
  await load()
  Swal.fire({ icon: 'success', title: 'สร้างรอบแล้ว', showConfirmButton: false, timer: 1200 })
}

async function deletePeriod(p) {
  const r = await Swal.fire({
    title: 'ลบรอบนี้?', text: `"${p.title}" และข้อมูลคะแนนทั้งหมดจะถูกลบถาวร`,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  const { error } = await supabase.from('nt_periods').delete().eq('id', p.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  await load(); await loadScoreCounts()
}

async function togglePublic(p) {
  const { error } = await supabase.from('nt_periods').update({ show_public: !p.show_public }).eq('id', p.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message }); return }
  await load()
}

async function toggleArchive(p) {
  const payload = p.is_archived
    ? { is_archived: false, archived_at: null }
    : { is_archived: true, archived_at: new Date().toISOString() }
  const { error } = await supabase.from('nt_periods').update(payload).eq('id', p.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message }); return }
  await load()
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

const examTypeLabel = (v) => EXAM_TYPES.find(e => e.value === v)?.value || v
</script>

<template>
  <div class="font-sarabun space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">ผลคะแนน NT / O-NET</h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการรอบผลการทดสอบ นำเข้าไฟล์ Local03 รายปี</p>
      </div>
      <div class="flex gap-2">
        <button @click="router.push('/dashboard/nt-trend')"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-indigo-50 text-indigo-700 rounded-2xl hover:bg-indigo-100 transition-all">
          ดูแนวโน้มข้ามปี
        </button>
        <button @click="openCreate"
          class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
          + สร้างรอบใหม่
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <div v-else-if="periods.length === 0" class="text-center py-12 glass-card text-slate-400">
      <p class="font-medium">ยังไม่มีรอบผลคะแนน</p>
      <p class="text-sm mt-1">กด "สร้างรอบใหม่" เพื่อเริ่มต้น</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="p in periods" :key="p.id" class="glass-card p-5">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-blue-100 text-blue-700">{{ examTypeLabel(p.exam_type) }}</span>
              <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-slate-100 text-slate-600">{{ p.grade_level }}</span>
              <span v-if="p.is_archived" class="text-xs bg-indigo-100 text-indigo-700 font-bold px-2 py-0.5 rounded-full">📦 เก็บถาวร</span>
              <span v-if="p.show_public" class="text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">🌐 เผยแพร่หน้าแรกแล้ว</span>
            </div>
            <h3 class="font-extrabold text-slate-800 text-lg">{{ p.title }}</h3>
            <p class="text-xs text-slate-400 mt-0.5">ปีการศึกษา {{ p.academic_year }} · นำเข้าแล้ว {{ scoreCounts[p.id] || 0 }} โรงเรียน</p>
            <p v-if="p.archived_at" class="text-xs text-slate-400">เก็บถาวร: {{ formatDate(p.archived_at) }}</p>
          </div>
          <div class="flex flex-wrap gap-2 flex-shrink-0">
            <button @click="router.push(`/dashboard/nt-scores/${p.id}`)"
              class="px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors">
              ดูข้อมูล / นำเข้าไฟล์
            </button>
            <button @click="togglePublic(p)"
              :class="['px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                p.show_public ? 'bg-slate-100 text-slate-600 hover:bg-slate-200' : 'bg-indigo-50 text-indigo-700 hover:bg-indigo-100']">
              {{ p.show_public ? 'ยกเลิกเผยแพร่' : 'เผยแพร่ที่หน้าแรก' }}
            </button>
            <button @click="toggleArchive(p)"
              :class="['px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                p.is_archived ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100' : 'bg-amber-50 text-amber-700 hover:bg-amber-100']">
              {{ p.is_archived ? 'ยกเลิกเก็บถาวร' : 'เก็บถาวร' }}
            </button>
            <button @click="deletePeriod(p)"
              class="px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:text-red-500 hover:bg-red-50 transition-colors">ลบ</button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="glass-panel rounded-[1.25rem] w-full max-w-md">
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <h2 class="font-extrabold text-slate-800">สร้างรอบผลคะแนนใหม่</h2>
            <button @click="showModal=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">✕</button>
          </div>
          <div class="px-6 py-5 space-y-4">
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ประเภทสอบ</label>
              <select v-model="form.exam_type" @change="form.grade_level = examTypeMeta?.grades[0]"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary">
                <option v-for="e in EXAM_TYPES" :key="e.value" :value="e.value" :disabled="!e.enabled">{{ e.label }}</option>
              </select>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชั้น</label>
                <select v-model="form.grade_level" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary">
                  <option v-for="g in examTypeMeta?.grades || []" :key="g" :value="g">{{ g }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ปีการศึกษา</label>
                <input v-model="form.academic_year" type="number" min="2550" max="2600" list="nt-year-suggestions"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <datalist id="nt-year-suggestions">
                  <option v-for="y in YEAR_OPTIONS" :key="y" :value="y"/>
                </datalist>
              </div>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อรอบ (ไม่บังคับ)</label>
              <input v-model="form.title" type="text" :placeholder="autoTitle()"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <p v-if="!examTypeMeta?.enabled" class="text-xs text-amber-600 bg-amber-50 rounded-xl px-3 py-2">
              ประเภทสอบนี้ยังไม่รองรับการนำเข้าไฟล์ในระบบตอนนี้
            </p>
          </div>
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="showModal=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="savePeriod" :disabled="saving || !examTypeMeta?.enabled"
              class="px-6 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              {{ saving ? 'กำลังบันทึก...' : 'สร้างรอบ' }}
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
