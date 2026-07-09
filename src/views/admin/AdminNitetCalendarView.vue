<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import MonthCalendar from '../../components/calendar/MonthCalendar.vue'
import { toDateKey } from '../../composables/useCalendarGrid'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { TYPE_LABEL, TYPE_COLOR, STATUS_LABEL, STATUS_COLOR, displayName, formatEventDateRange, formatResponsible } from '../../composables/useNithetEventMeta'

const { config: areaConfig, fetchConfig } = useAreaConfig()
const personnelGroups = computed(() => areaConfig.value?.personnel_groups || [])
function groupLabel(key) { return personnelGroups.value.find(g => g.key === key)?.label || key }

const events        = ref([])
const schools       = ref([])
const responsibleOptions = ref([])
const loading       = ref(true)
const saving        = ref(false)
const showModal     = ref(false)
const viewMode      = ref('list') // 'list' | 'month'
const currentYear   = ref(new Date().getFullYear())
const currentMonth  = ref(new Date().getMonth())
const activeType    = ref('all')
const myEventsOnly  = ref(false)
const currentProfile = ref(null)
const currentUserId  = ref(null)

const isAdmin = computed(() => ['super_admin','admin'].includes(currentProfile.value?.role))

const TYPES = ['school_visit', 'meeting', 'training', 'other']

const typeCounts = computed(() => {
  const counts = { all: events.value.length }
  for (const t of TYPES) counts[t] = events.value.filter(e => e.type === t).length
  return counts
})

const filtered = computed(() =>
  activeType.value === 'all' ? events.value : events.value.filter(e => e.type === activeType.value)
)

const districts = computed(() => [...new Set(schools.value.map(s => s.district))].filter(Boolean).sort())

// ── ตัวกรองโรงเรียนในฟอร์ม (สำหรับ modal เพิ่ม/แก้ไข) ─────────
const schoolFilterDistrict = ref('all')
const schoolFilterGroup    = ref('all')
const schoolFilterSearch   = ref('')
const schoolGroups = computed(() => [...new Set(schools.value.map(s => s.school_group))].filter(Boolean).sort())
const filteredSchools = computed(() => {
  const q = schoolFilterSearch.value.trim().toLowerCase()
  return schools.value.filter(s =>
    (schoolFilterDistrict.value === 'all' || s.district === schoolFilterDistrict.value) &&
    (schoolFilterGroup.value    === 'all' || s.school_group === schoolFilterGroup.value) &&
    (!q || s.name.toLowerCase().includes(q))
  )
})
const filteredDistricts = computed(() => [...new Set(filteredSchools.value.map(s => s.district))].filter(Boolean).sort())
function resetSchoolFilters() { schoolFilterDistrict.value = 'all'; schoolFilterGroup.value = 'all'; schoolFilterSearch.value = '' }
function selectAllEventSchools() { form.value.school_ids = [...new Set([...form.value.school_ids, ...filteredSchools.value.map(s => s.id)])] }
function clearEventSchools() { form.value.school_ids = [] }

function canEdit(event) {
  return isAdmin.value || event.created_by === currentUserId.value
}

function responsibleNamesFor(event) {
  return (event.responsible_ids || [])
    .map(id => responsibleOptions.value.find(p => p.id === id))
    .filter(Boolean)
    .map(displayName)
}

function schoolNamesFor(event) {
  return (event.school_ids || [])
    .map(id => schools.value.find(s => s.id === id)?.name)
    .filter(Boolean)
}

function emptyForm() {
  const today = toDateKey(new Date())
  return {
    id: null, type: 'school_visit', title: '', description: '',
    start_date: today, end_date: today, start_time: '', end_time: '',
    school_ids: [], location: '', responsible_ids: [], responsible_group: '',
    status: 'scheduled', show_public: true,
  }
}
const form = ref(emptyForm())

watch(() => form.value.start_date, (v) => {
  if (v && (!form.value.end_date || form.value.end_date < v)) form.value.end_date = v
})

async function load() {
  loading.value = true
  let query = supabase
    .from('nithet_events')
    .select('*')
    .order('start_date', { ascending: true })
  if (!isAdmin.value || myEventsOnly.value) query = query.eq('created_by', currentUserId.value)
  const { data, error } = await query
  if (!error) events.value = data || []
  loading.value = false
}

function openAdd(dateKey) {
  form.value = emptyForm()
  if (dateKey) { form.value.start_date = dateKey; form.value.end_date = dateKey }
  showModal.value = true
}

function openEdit(event) {
  form.value = {
    id: event.id, type: event.type, title: event.title, description: event.description || '',
    start_date: event.start_date, end_date: event.end_date,
    start_time: event.start_time ? event.start_time.slice(0,5) : '', end_time: event.end_time ? event.end_time.slice(0,5) : '',
    school_ids: [...(event.school_ids || [])], location: event.location || '',
    responsible_ids: [...(event.responsible_ids || [])], responsible_group: event.responsible_group || '',
    status: event.status, show_public: event.show_public,
  }
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อกิจกรรม' })
    return
  }
  if (form.value.type === 'school_visit' && form.value.school_ids.length === 0) {
    Swal.fire({ icon: 'warning', title: 'กรุณาเลือกโรงเรียน', text: 'การนิเทศโรงเรียนต้องระบุโรงเรียนที่ไปนิเทศอย่างน้อย 1 แห่ง' })
    return
  }
  saving.value = true
  const payload = {
    type: form.value.type,
    title: form.value.title.trim(),
    description: form.value.description,
    start_date: form.value.start_date,
    end_date: form.value.end_date,
    start_time: form.value.start_time || null,
    end_time: form.value.end_time || null,
    school_ids: form.value.school_ids,
    location: form.value.location,
    responsible_ids: form.value.responsible_ids,
    responsible_group: form.value.responsible_group,
    status: form.value.status,
    show_public: form.value.show_public,
  }
  let error
  if (form.value.id) {
    const res = await supabase.from('nithet_events').update(payload).eq('id', form.value.id)
    error = res.error
  } else {
    payload.created_by = currentUserId.value
    const res = await supabase.from('nithet_events').insert(payload)
    error = res.error
  }
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
    return
  }
  showModal.value = false
  await load()
}

async function deleteEvent(event) {
  const result = await Swal.fire({
    title: 'ลบกิจกรรมนี้?',
    text: `"${event.title}" จะถูกลบถาวร`,
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: 'ลบ',
    cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#ef4444',
  })
  if (!result.isConfirmed) return
  const { error } = await supabase.from('nithet_events').delete().eq('id', event.id)
  if (error) Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message })
  else load()
}

function onSelectEvent(ev) {
  const full = events.value.find(e => e.id === ev.id)
  if (full) openEdit(full)
}

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  currentUserId.value = user?.id
  if (user?.id) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    currentProfile.value = p
  }
  const { data: sc } = await supabase.from('schools').select('id, name, district, school_group').order('district').order('name')
  schools.value = sc || []
  const { data: pp } = await supabase.from('profiles')
    .select('id, title, first_name, last_name, full_name, role')
    .in('role', ['supervisor','staff','super_admin','admin'])
    .order('first_name')
  responsibleOptions.value = pp || []
  await load()
})
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="calendar" class="w-6 h-6 text-primary"/>
          ปฏิทินนิเทศ
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการกำหนดการนิเทศโรงเรียนและกิจกรรมของกลุ่มนิเทศ</p>
      </div>
      <button @click="openAdd()"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <SvgIcon name="plus" class="w-4 h-4"/>
        เพิ่มกิจกรรม
      </button>
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
      <!-- Admin tabs: ทั้งหมด / ของฉัน -->
      <div v-if="isAdmin" class="flex gap-1 bg-slate-100 p-1 rounded-xl w-fit">
        <button @click="myEventsOnly = false; load()"
          :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
            !myEventsOnly ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          ทั้งหมด
        </button>
        <button @click="myEventsOnly = true; load()"
          :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
            myEventsOnly ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          ของฉัน
        </button>
      </div>
      <div v-else></div>

      <!-- List/Month toggle -->
      <div class="flex gap-1 bg-slate-100 p-1 rounded-xl w-fit">
        <button @click="viewMode = 'list'"
          :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
            viewMode === 'list' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          รายการ
        </button>
        <button @click="viewMode = 'month'"
          :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
            viewMode === 'month' ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          ปฏิทิน
        </button>
      </div>
    </div>

    <!-- Type filter tabs -->
    <div class="flex flex-wrap gap-2">
      <button @click="activeType = 'all'"
        :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
          activeType === 'all' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
        ทั้งหมด ({{ typeCounts.all }})
      </button>
      <button v-for="t in TYPES" :key="t" @click="activeType = t"
        :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
          activeType === t ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
        {{ TYPE_LABEL[t] }} ({{ typeCounts[t] }})
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <!-- Month view -->
    <MonthCalendar v-else-if="viewMode === 'month'" :events="filtered" v-model:year="currentYear" v-model:month="currentMonth"
      @select-event="onSelectEvent" @select-day="openAdd"/>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
      <SvgIcon name="calendar" class="w-12 h-12 mx-auto mb-3 opacity-30"/>
      <p class="font-medium">ยังไม่มีกิจกรรม</p>
      <p class="text-sm mt-1">กด "เพิ่มกิจกรรม" เพื่อเริ่มต้น</p>
    </div>

    <!-- List -->
    <div v-else class="space-y-3">
      <div v-for="event in filtered" :key="event.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 hover:shadow-md transition-shadow">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
                {{ TYPE_LABEL[event.type] }}
              </span>
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', STATUS_COLOR[event.status]]">
                {{ STATUS_LABEL[event.status] }}
              </span>
              <span v-if="!event.show_public" class="text-xs bg-slate-100 text-slate-400 font-bold px-2.5 py-0.5 rounded-full">
                🔒 ไม่แสดงสาธารณะ
              </span>
            </div>
            <h2 class="font-bold text-slate-800 text-lg leading-snug">{{ event.title }}</h2>
            <p v-if="event.description" class="text-sm text-slate-500 mt-0.5 line-clamp-2">{{ event.description }}</p>
            <div class="flex flex-wrap gap-4 mt-2 text-xs text-slate-400">
              <span>{{ formatEventDateRange(event) }}</span>
              <span v-if="event.school_ids?.length">โรงเรียน: {{ schoolNamesFor(event).join(', ') }}</span>
              <span v-if="event.location">สถานที่: {{ event.location }}</span>
              <span v-if="event.responsible_group || event.responsible_ids?.length">
                ผู้รับผิดชอบ: {{ formatResponsible(responsibleNamesFor(event), event.responsible_group ? groupLabel(event.responsible_group) : '') }}
              </span>
            </div>
          </div>

          <div v-if="canEdit(event)" class="flex flex-wrap gap-2 flex-shrink-0">
            <button @click="openEdit(event)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
              <SvgIcon name="wrench" class="w-3.5 h-3.5"/>
              แก้ไข
            </button>
            <button @click="deleteEvent(event)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:text-red-500 hover:bg-red-50 transition-colors">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
              ลบ
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showModal = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">

            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg flex items-center gap-2">
                <SvgIcon name="calendar" class="w-5 h-5 text-primary"/>
                {{ form.id ? 'แก้ไขกิจกรรม' : 'เพิ่มกิจกรรมใหม่' }}
              </h3>
              <button @click="showModal = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="flex-1 overflow-y-auto p-6 space-y-5">

              <!-- ① ประเภทกิจกรรม -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-2">ประเภทกิจกรรม <span class="text-red-400">*</span></label>
                <div class="flex flex-wrap gap-2">
                  <button v-for="t in TYPES" :key="t" @click="form.type = t" type="button"
                    :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
                      form.type === t ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                    {{ TYPE_LABEL[t] }}
                  </button>
                </div>
              </div>

              <!-- ② ข้อมูลทั่วไป -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อกิจกรรม <span class="text-red-400">*</span></label>
                <input v-model="form.title" type="text" placeholder="เช่น นิเทศติดตามการจัดการเรียนการสอน..."
                  class="input-field w-full"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">รายละเอียด</label>
                <textarea v-model="form.description" rows="2" placeholder="รายละเอียดเพิ่มเติม..."
                  class="input-field w-full resize-none"/>
              </div>

              <!-- ══ วันที่และเวลา ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">วันที่และเวลา</p>
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">วันที่เริ่ม <span class="text-red-400">*</span></label>
                  <input v-model="form.start_date" type="date" class="input-field w-full"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">วันที่สิ้นสุด</label>
                  <input v-model="form.end_date" type="date" :min="form.start_date" class="input-field w-full"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">เวลาเริ่ม</label>
                  <input v-model="form.start_time" type="time" class="input-field w-full"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">เวลาสิ้นสุด</label>
                  <input v-model="form.end_time" type="time" class="input-field w-full"/>
                </div>
              </div>

              <!-- ══ โรงเรียน/สถานที่ ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">โรงเรียน/สถานที่</p>
              </div>
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <label class="block text-xs font-bold text-slate-600">
                    โรงเรียน <span v-if="form.type === 'school_visit'" class="text-red-400">*</span>
                    <span class="font-normal text-slate-400">({{ form.school_ids.length }} โรงเรียน)</span>
                  </label>
                  <div class="flex gap-3">
                    <button type="button" @click="selectAllEventSchools" class="text-xs text-primary font-bold hover:underline">เลือกทั้งหมด</button>
                    <button type="button" @click="clearEventSchools" class="text-xs text-slate-400 font-bold hover:underline">ล้าง</button>
                  </div>
                </div>

                <!-- ตัวกรอง: ชื่อโรงเรียน / อำเภอ / ศูนย์เครือข่าย -->
                <div class="flex flex-wrap items-center gap-2">
                  <div class="relative flex-1 min-w-[160px]">
                    <SvgIcon name="magnify" class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400"/>
                    <input v-model="schoolFilterSearch" type="text" placeholder="ค้นหาชื่อโรงเรียน..."
                      class="w-full pl-8 pr-2.5 py-1.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-primary"/>
                  </div>
                  <select v-model="schoolFilterDistrict" class="px-2.5 py-1.5 border border-slate-200 rounded-lg text-xs bg-white focus:outline-none focus:border-primary">
                    <option value="all">ทุกอำเภอ</option>
                    <option v-for="dist in districts" :key="dist" :value="dist">อ.{{ dist }}</option>
                  </select>
                  <select v-model="schoolFilterGroup" class="px-2.5 py-1.5 border border-slate-200 rounded-lg text-xs bg-white focus:outline-none focus:border-primary">
                    <option value="all">ทุกศูนย์เครือข่าย</option>
                    <option v-for="g in schoolGroups" :key="g" :value="g">{{ g }}</option>
                  </select>
                  <button v-if="schoolFilterDistrict !== 'all' || schoolFilterGroup !== 'all' || schoolFilterSearch"
                    type="button" @click="resetSchoolFilters"
                    class="text-xs text-slate-400 hover:text-slate-600 font-bold">✕ ทั้งหมด</button>
                  <span class="text-xs text-slate-400 w-full text-right">พบ {{ filteredSchools.length }} โรงเรียน</span>
                </div>

                <div class="border border-slate-200 rounded-xl max-h-52 overflow-y-auto divide-y divide-slate-100 bg-white">
                  <template v-for="dist in filteredDistricts" :key="dist">
                    <p class="px-3 py-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider bg-slate-50 sticky top-0">อ.{{ dist }}</p>
                    <label v-for="s in filteredSchools.filter(x => x.district === dist)" :key="s.id"
                      class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-slate-50">
                      <input type="checkbox" :value="s.id" v-model="form.school_ids"
                        class="rounded border-slate-300 text-primary focus:ring-primary/30"/>
                      <span class="flex-1">{{ s.name }}</span>
                      <span v-if="s.school_group" class="text-[10px] text-slate-400">{{ s.school_group }}</span>
                    </label>
                  </template>
                  <p v-if="!schools.length" class="px-3 py-3 text-xs text-slate-400 text-center">กำลังโหลดรายชื่อโรงเรียน...</p>
                  <p v-else-if="!filteredSchools.length" class="px-3 py-3 text-xs text-slate-400 text-center">ไม่พบโรงเรียนตามตัวกรอง</p>
                </div>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">สถานที่ (ถ้ามี)</label>
                <input v-model="form.location" type="text" placeholder="เช่น ห้องประชุมสำนักงานเขตพื้นที่ฯ ชั้น 2..."
                  class="input-field w-full"/>
              </div>

              <!-- ══ ผู้รับผิดชอบ ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">ผู้รับผิดชอบ</p>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">มอบทั้งกลุ่ม (ถ้ามี)</label>
                <select v-model="form.responsible_group" class="input-field w-full">
                  <option value="">-- ไม่ระบุกลุ่ม --</option>
                  <option v-for="g in personnelGroups" :key="g.key" :value="g.key">{{ g.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ผู้รับผิดชอบรายบุคคล (เลือกได้หลายคน)</label>
                <div class="border border-slate-200 rounded-xl max-h-40 overflow-y-auto divide-y divide-slate-100">
                  <label v-for="p in responsibleOptions" :key="p.id"
                    class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-slate-50">
                    <input type="checkbox" :value="p.id" v-model="form.responsible_ids" class="rounded border-slate-300 text-primary focus:ring-primary/30"/>
                    {{ displayName(p) }}
                  </label>
                  <p v-if="!responsibleOptions.length" class="px-3 py-2 text-xs text-slate-400">ไม่มีรายชื่อ</p>
                </div>
              </div>

              <!-- ══ สถานะและการแสดงผล ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">สถานะและการแสดงผล</p>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">สถานะ</label>
                <select v-model="form.status" class="input-field w-full">
                  <option v-for="s in ['scheduled','done','cancelled']" :key="s" :value="s">{{ STATUS_LABEL[s] }}</option>
                </select>
              </div>
              <div class="flex items-start gap-3">
                <label class="relative inline-flex items-center cursor-pointer mt-0.5">
                  <input type="checkbox" v-model="form.show_public" class="sr-only peer"/>
                  <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors
                              after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                              after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5"/>
                </label>
                <div>
                  <p class="text-sm font-bold text-slate-700">แสดงในปฏิทินสาธารณะ</p>
                  <p class="text-xs text-slate-400">แสดงบนหน้า /nithet ให้บุคคลทั่วไปเห็น</p>
                </div>
              </div>
            </div>

            <div class="flex justify-end gap-2 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false" type="button"
                class="px-5 py-2.5 text-sm font-bold text-slate-500 rounded-2xl hover:bg-slate-100 transition-colors">
                ยกเลิก
              </button>
              <button @click="save" :disabled="saving" type="button"
                class="px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
                {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

.input-field {
  @apply px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none;
}
.input-field:focus {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-primary) 20%, transparent);
  outline: none;
}
</style>
