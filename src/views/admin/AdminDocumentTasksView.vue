<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { useMyTasksBadge } from '../../composables/useMyTasksBadge'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()
const { fetchPendingCount } = useMyTasksBadge()

const loading         = ref(true)
const tasks           = ref([])
const profiles        = ref([])
const currentUserId   = ref(null)
const currentRole     = ref(null)
const canManageDocs   = ref(false)

const activeTab      = ref('active')
const search         = ref('')
const filterStatus   = ref('all')
const filterDept     = ref('all')
const filterAssignee = ref('all')
const filterDateFrom = ref('')
const filterDateTo   = ref('')

const showModal   = ref(false)
const form        = ref(emptyForm())
const saving      = ref(false)

const showCloseModal = ref(false)
const closeTarget    = ref(null)
const closeForm      = ref({ memo_link: '', is_public: false, school_doc_link: '' })
const closing        = ref(false)

const showTypesPanel = ref(false)
const taskTypesDraft = ref([])
const savingTypes    = ref(false)

const STATUS_LABEL = { assigned: 'มอบหมายแล้ว', in_progress: 'กำลังดำเนินการ', submitted: 'ส่งตรวจแล้ว', completed: 'เสร็จสิ้น', cancelled: 'ยกเลิก' }
const STATUS_COLOR = {
  assigned:    'bg-slate-100 text-slate-600',
  in_progress: 'bg-amber-100 text-amber-700',
  submitted:   'bg-blue-100 text-blue-700',
  completed:   'bg-emerald-100 text-emerald-700',
  cancelled:   'bg-red-100 text-red-500',
}

function emptyForm() {
  return { id: null, task_type: '', department: '', title: '', description: '', source_link: '', assigned_to: '' }
}
function displayName(p) {
  if (!p) return '-'
  if (p.first_name || p.last_name) return `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim()
  return p.full_name || p.email || '-'
}

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    currentUserId.value = user.id
    const { data: me } = await supabase.from('profiles').select('role, can_manage_documents').eq('id', user.id).single()
    currentRole.value   = me?.role
    canManageDocs.value = ['super_admin', 'admin'].includes(me?.role) || me?.can_manage_documents === true
  }
  await Promise.all([load(), loadProfiles()])
})

async function load() {
  loading.value = true
  const { data, error } = await supabase.from('document_tasks').select('*').order('created_at', { ascending: false })
  if (!error) tasks.value = data || []
  loading.value = false
}

async function loadProfiles() {
  const { data } = await supabase
    .from('profiles')
    .select('id,title,first_name,last_name,full_name,email,role,avatar_url')
    .eq('role', 'supervisor')
    .order('sort_order', { ascending: true })
  profiles.value = data || []
}

const profileById = computed(() => Object.fromEntries(profiles.value.map(p => [p.id, p])))

const taskTypeOptions = computed(() =>
  (config.value?.task_types || []).filter(t => t.visible !== false).sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
)
const deptOptions = computed(() =>
  (config.value?.personnel_groups || []).filter(g => g.visible !== false).sort((a, b) => (a.order ?? 99) - (b.order ?? 99)).map(g => g.label)
)

const activeTasksAll  = computed(() => tasks.value.filter(t => t.status !== 'completed'))
const archiveTasksAll = computed(() => tasks.value.filter(t => t.status === 'completed'))

function filterList(list) {
  let out = list
  if (filterDept.value !== 'all') out = out.filter(t => t.department === filterDept.value)
  if (activeTab.value === 'active' && filterStatus.value !== 'all') out = out.filter(t => t.status === filterStatus.value)
  if (filterAssignee.value !== 'all') out = out.filter(t => t.assigned_to === filterAssignee.value)
  if (filterDateFrom.value) out = out.filter(t => t.created_at >= filterDateFrom.value)
  if (filterDateTo.value) out = out.filter(t => t.created_at <= filterDateTo.value + 'T23:59:59')

  // ค้นหาแบบแยกคำ ไม่สนใจลำดับ/จำนวนช่องว่าง (พิมพ์ "นิเทศ ประเมิน" ต้องเจอแม้ชื่อเรื่องจะเรียงคำสลับกัน)
  const terms = search.value.trim().toLowerCase().split(/\s+/).filter(Boolean)
  if (terms.length) out = out.filter(t => {
    const haystack = [t.title, t.description || '', displayName(profileById.value[t.assigned_to])]
      .join(' ').toLowerCase()
    return terms.every(term => haystack.includes(term))
  })
  return out
}
const filteredActive  = computed(() => filterList(activeTasksAll.value))
const filteredArchive = computed(() => filterList(archiveTasksAll.value))

function typeLabel(key) { return taskTypeOptions.value.find(t => t.key === key)?.label || key }

// ── Create/Edit ──────────────────────────────────────────────────
function openCreate() {
  form.value = emptyForm()
  showModal.value = true
}
function openEdit(t) {
  form.value = {
    id: t.id, task_type: t.task_type, department: t.department, title: t.title,
    description: t.description, source_link: t.source_link, assigned_to: t.assigned_to || '',
  }
  showModal.value = true
}
async function saveTask() {
  if (!form.value.title.trim() || !form.value.task_type) {
    Swal.fire({ icon: 'warning', title: 'กรอกชื่องานและประเภทหนังสือให้ครบ', confirmButtonColor: '#3b82f6' })
    return
  }
  saving.value = true
  const payload = {
    task_type:   form.value.task_type,
    department:  form.value.department,
    title:       form.value.title.trim(),
    description: form.value.description.trim(),
    source_link: form.value.source_link.trim(),
    assigned_to: form.value.assigned_to || null,
  }
  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('document_tasks').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('document_tasks').insert({ ...payload, created_by: currentUserId.value }))
  }
  saving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
  showModal.value = false
  await load()
}
async function deleteTask(t) {
  const res = await Swal.fire({
    title: 'ลบงานนี้?', icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('document_tasks').delete().eq('id', t.id)
  tasks.value = tasks.value.filter(x => x.id !== t.id)
}

// ── สถานะ: admin/ธุรการ เปลี่ยนเองได้โดยตรงทุกค่า (เผื่อศึกษานิเทศก์ไม่ใช้ระบบ) ──
async function setStatus(t, status) {
  const { error } = await supabase.from('document_tasks').update({ status }).eq('id', t.id)
  if (!error) t.status = status
  else Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
}

// ── ทางลัดฝั่งศึกษานิเทศก์ (ผ่าน RPC จำกัดสิทธิ์) ──────────────────
async function startTask(t) {
  const { data, error } = await supabase.rpc('update_my_task_status', { p_task_id: t.id, p_status: 'in_progress' })
  if (!error && data?.success) { t.status = 'in_progress'; fetchPendingCount(true) }
  else Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ' })
}
async function submitTask(t) {
  const { data, error } = await supabase.rpc('update_my_task_status', { p_task_id: t.id, p_status: 'submitted' })
  if (!error && data?.success) { t.status = 'submitted'; fetchPendingCount(true) }
  else Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ' })
}

// ── ปิดงาน (submitted -> completed) ───────────────────────────────
function openClose(t) {
  closeTarget.value = t
  closeForm.value = { memo_link: t.memo_link || '', is_public: t.is_public || false, school_doc_link: t.school_doc_link || '' }
  showCloseModal.value = true
}
async function completeTask() {
  if (!closeForm.value.memo_link.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรอกลิงก์บันทึกข้อความที่เซ็นแล้ว', confirmButtonColor: '#3b82f6' })
    return
  }
  if (closeForm.value.is_public && !closeForm.value.school_doc_link.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรอกลิงก์เอกสารที่ส่งโรงเรียน', confirmButtonColor: '#3b82f6' })
    return
  }
  closing.value = true
  const { error } = await supabase.from('document_tasks').update({
    status: 'completed',
    memo_link: closeForm.value.memo_link.trim(),
    is_public: closeForm.value.is_public,
    school_doc_link: closeForm.value.is_public ? closeForm.value.school_doc_link.trim() : '',
  }).eq('id', closeTarget.value.id)
  closing.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  showCloseModal.value = false
  Swal.fire({ icon: 'success', title: 'ปิดงานสำเร็จ', showConfirmButton: false, timer: 1200 })
  await load()
}

// ── จัดการประเภทหนังสือ (เหมือนจัดการกลุ่มงานใน AdminPersonnelView.vue) ──
function openTypesPanel() {
  taskTypesDraft.value = (config.value?.task_types || []).map(t => ({ ...t }))
  showTypesPanel.value = true
}
function addType() {
  taskTypesDraft.value.push({ key: 'type_' + Date.now(), label: '(ประเภทใหม่)', visible: true, order: taskTypesDraft.value.length + 1 })
}
function removeType(i) {
  taskTypesDraft.value.splice(i, 1)
  taskTypesDraft.value.forEach((t, idx) => t.order = idx + 1)
}
function moveTypeUp(i) {
  if (i === 0) return
  ;[taskTypesDraft.value[i - 1], taskTypesDraft.value[i]] = [taskTypesDraft.value[i], taskTypesDraft.value[i - 1]]
  taskTypesDraft.value.forEach((t, idx) => t.order = idx + 1)
}
function moveTypeDown(i) {
  if (i === taskTypesDraft.value.length - 1) return
  ;[taskTypesDraft.value[i + 1], taskTypesDraft.value[i]] = [taskTypesDraft.value[i], taskTypesDraft.value[i + 1]]
  taskTypesDraft.value.forEach((t, idx) => t.order = idx + 1)
}
async function saveTypes() {
  savingTypes.value = true
  await updateConfig({ task_types: taskTypesDraft.value })
  savingTypes.value = false
  showTypesPanel.value = false
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 800 })
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">ระบบธุรการ</h1>
        <p class="text-sm text-slate-400">มอบหมาย ติดตาม และเก็บเอกสารเข้าคลัง</p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button v-if="canManageDocs" @click="openTypesPanel" type="button"
          class="px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
          จัดการประเภทหนังสือ
        </button>
        <button v-if="canManageDocs" @click="openCreate" type="button"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl hover:bg-primary-dark transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
          เพิ่มงาน
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 bg-white border border-slate-200 p-1 rounded-2xl w-full sm:w-fit">
      <button @click="activeTab = 'active'"
        :class="['flex-1 sm:flex-none px-4 py-2 text-sm font-bold rounded-xl transition-colors',
          activeTab === 'active' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        กำลังดำเนินการ
      </button>
      <button @click="activeTab = 'archive'"
        :class="['flex-1 sm:flex-none px-4 py-2 text-sm font-bold rounded-xl transition-colors',
          activeTab === 'archive' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        คลังเอกสาร
      </button>
    </div>

    <!-- Filters -->
    <div class="flex flex-col sm:flex-row gap-2">
      <div class="relative flex-1">
        <svg class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="search" type="text" placeholder="ค้นหาชื่องาน/ผู้รับผิดชอบ..."
          class="w-full pl-9 pr-3 py-2.5 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary"/>
      </div>
      <select v-model="filterDept" class="px-3 py-2.5 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกกลุ่มงาน</option>
        <option v-for="d in deptOptions" :key="d" :value="d">{{ d }}</option>
      </select>
      <select v-model="filterAssignee" class="px-3 py-2.5 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกศึกษานิเทศก์</option>
        <option v-for="p in profiles" :key="p.id" :value="p.id">{{ displayName(p) }}</option>
      </select>
      <select v-if="activeTab === 'active'" v-model="filterStatus" class="px-3 py-2.5 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกสถานะ</option>
        <option v-for="(label, key) in STATUS_LABEL" :key="key" :value="key">{{ label }}</option>
      </select>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <label class="text-xs font-bold text-slate-400">ช่วงวันที่:</label>
      <input v-model="filterDateFrom" type="date" class="px-3 py-2 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary"/>
      <span class="text-slate-300">-</span>
      <input v-model="filterDateTo" type="date" class="px-3 py-2 text-sm border border-slate-200 rounded-2xl bg-white focus:outline-none focus:border-primary"/>
      <button v-if="filterDateFrom || filterDateTo" @click="filterDateFrom = ''; filterDateTo = ''" type="button"
        class="text-xs font-bold text-slate-400 hover:text-red-500 px-2">ล้างวันที่</button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <!-- Active list -->
    <div v-else-if="activeTab === 'active'" class="space-y-3">
      <div v-if="!filteredActive.length" class="text-center py-16 bg-white rounded-2xl border border-slate-200 text-slate-400">
        ไม่พบงาน
      </div>
      <div v-for="t in filteredActive" :key="t.id"
        class="bg-white rounded-2xl border border-slate-200 shadow-sm p-4 space-y-3">
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-secondary/10 text-secondary">{{ typeLabel(t.task_type) }}</span>
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', STATUS_COLOR[t.status]]">{{ STATUS_LABEL[t.status] }}</span>
              <span v-if="t.department" class="text-xs text-slate-400">{{ t.department }}</span>
            </div>
            <h3 class="font-bold text-slate-800 break-words">{{ t.title }}</h3>
            <p v-if="t.description" class="text-sm text-slate-500 mt-0.5 break-words">{{ t.description }}</p>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-xs text-slate-500">
          <span v-if="t.assigned_to" class="flex items-center gap-1.5">
            <span class="w-5 h-5 rounded-full bg-slate-100 flex items-center justify-center text-[9px] font-extrabold text-primary flex-shrink-0 overflow-hidden">
              <img v-if="profileById[t.assigned_to]?.avatar_url" :src="profileById[t.assigned_to].avatar_url" class="w-full h-full object-cover"/>
              <template v-else>{{ displayName(profileById[t.assigned_to])[0] }}</template>
            </span>
            {{ displayName(profileById[t.assigned_to]) }}
          </span>
          <a v-if="t.source_link" :href="t.source_link" target="_blank" rel="noopener" class="flex items-center gap-1 text-primary hover:underline">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/></svg>
            ลิงก์ต้นฉบับ
          </a>
        </div>

        <!-- Actions -->
        <div class="pt-2 border-t border-slate-100 space-y-2">
          <!-- ศึกษานิเทศก์เจ้าของงาน -->
          <template v-if="!canManageDocs && t.assigned_to === currentUserId">
            <button v-if="t.status === 'assigned'" @click="startTask(t)" type="button"
              class="w-full sm:w-auto px-4 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:bg-primary-dark transition-colors">
              เริ่มดำเนินการ
            </button>
            <button v-if="t.status === 'in_progress'" @click="submitTask(t)" type="button"
              class="w-full sm:w-auto px-4 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:bg-primary-dark transition-colors">
              ส่งงานแล้ว
            </button>
            <span v-if="t.status === 'submitted'" class="text-xs text-slate-400">รอธุรการตรวจและปิดงาน</span>
          </template>

          <!-- ธุรการ/admin: จัดการได้ทุกสถานะ -->
          <div v-if="canManageDocs" class="flex flex-col sm:flex-row sm:items-center gap-2">
            <div class="flex flex-wrap gap-2">
              <button v-if="t.status === 'assigned'" @click="setStatus(t, 'in_progress')" type="button"
                class="px-3 py-1.5 text-xs font-bold bg-amber-50 text-amber-700 rounded-xl hover:bg-amber-100 transition-colors">
                ตั้งเป็น กำลังดำเนินการ
              </button>
              <button v-if="['assigned','in_progress'].includes(t.status)" @click="setStatus(t, 'submitted')" type="button"
                class="px-3 py-1.5 text-xs font-bold bg-blue-50 text-blue-700 rounded-xl hover:bg-blue-100 transition-colors">
                ตั้งเป็น ส่งตรวจแล้ว
              </button>
              <button v-if="t.status === 'submitted'" @click="openClose(t)" type="button"
                class="px-3 py-1.5 text-xs font-bold bg-emerald-50 text-emerald-700 rounded-xl hover:bg-emerald-100 transition-colors">
                ปิดงาน
              </button>
              <button v-if="t.status !== 'cancelled'" @click="setStatus(t, 'cancelled')" type="button"
                class="px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:bg-red-50 hover:text-red-500 transition-colors">
                ยกเลิกงาน
              </button>
            </div>
            <div class="flex-1 hidden sm:block"></div>
            <div class="flex items-center gap-2 justify-end">
              <button @click="openEdit(t)" type="button" class="p-2 bg-blue-50 text-blue-600 rounded-xl hover:bg-blue-100 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"/></svg>
              </button>
              <button @click="deleteTask(t)" type="button" class="p-2 bg-red-50 text-red-500 rounded-xl hover:bg-red-100 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/></svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Archive -->
    <div v-else class="space-y-3">
      <div v-if="!filteredArchive.length" class="text-center py-16 bg-white rounded-2xl border border-slate-200 text-slate-400">
        ยังไม่มีเอกสารในคลัง
      </div>
      <div v-for="t in filteredArchive" :key="t.id"
        class="bg-white rounded-2xl border border-slate-200 shadow-sm p-4 space-y-2">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-secondary/10 text-secondary">{{ typeLabel(t.task_type) }}</span>
          <span v-if="t.is_public" class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-sky-100 text-sky-700">ส่งโรงเรียนแล้ว</span>
          <span v-if="t.department" class="text-xs text-slate-400">{{ t.department }}</span>
          <span class="text-xs text-slate-300 ml-auto">{{ new Date(t.created_at).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric' }) }}</span>
        </div>
        <h3 class="font-bold text-slate-800 break-words">{{ t.title }}</h3>
        <p v-if="t.assigned_to" class="text-xs text-slate-400">ผู้จัดทำ: {{ displayName(profileById[t.assigned_to]) }}</p>
        <div class="flex flex-wrap gap-3 pt-2 border-t border-slate-100 text-sm">
          <a v-if="t.memo_link" :href="t.memo_link" target="_blank" rel="noopener" class="flex items-center gap-1.5 text-primary hover:underline font-bold">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/></svg>
            บันทึกข้อความ
          </a>
          <a v-if="t.school_doc_link" :href="t.school_doc_link" target="_blank" rel="noopener" class="flex items-center gap-1.5 text-secondary hover:underline font-bold">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347"/></svg>
            เอกสารส่งโรงเรียน
          </a>
        </div>
      </div>
    </div>

    <!-- ══ MODAL: Add/Edit task ══════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">{{ form.id ? 'แก้ไขงาน' : 'เพิ่มงานเอกสาร' }}</h2>
              <button @click="showModal = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ประเภทหนังสือ</label>
                  <select v-model="form.task_type" class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">-- เลือก --</option>
                    <option v-for="t in taskTypeOptions" :key="t.key" :value="t.key">{{ t.label }}</option>
                  </select>
                </div>
                <div>
                  <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">กลุ่มงาน</label>
                  <select v-model="form.department" class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">-- ไม่ระบุ --</option>
                    <option v-for="d in deptOptions" :key="d" :value="d">{{ d }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ชื่องาน</label>
                <input v-model="form.title" type="text" placeholder="เช่น ประกาศรับสมัครนักเรียน ปีการศึกษา 2569"
                  class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">รายละเอียด</label>
                <textarea v-model="form.description" rows="3"
                  class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-none"></textarea>
              </div>
              <div>
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ลิงก์ต้นฉบับ (Google Drive)</label>
                <input v-model="form.source_link" type="text" placeholder="https://drive.google.com/..."
                  class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">มอบหมายให้ (ศึกษานิเทศก์)</label>
                <select v-model="form.assigned_to" class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option value="">-- ยังไม่มอบหมาย --</option>
                  <option v-for="p in profiles" :key="p.id" :value="p.id">{{ displayName(p) }}</option>
                </select>
              </div>
            </div>
            <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false" type="button" class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
                ยกเลิก
              </button>
              <button @click="saveTask" :disabled="saving" type="button" class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
                {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ══ MODAL: Close-out task ═══════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showCloseModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">ปิดงาน</h2>
              <button @click="showCloseModal = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
              <p class="text-sm text-slate-500">{{ closeTarget?.title }}</p>
              <div>
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">บันทึกข้อความที่เซ็นแล้ว (ลิงก์)</label>
                <input v-model="closeForm.memo_link" type="text" placeholder="https://drive.google.com/..."
                  class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <p class="text-[11px] text-slate-400 mt-1">เก็บเข้าคลังเอกสารภายในเสมอ</p>
              </div>
              <label class="flex items-center gap-2 cursor-pointer p-3 bg-slate-50 rounded-2xl border border-slate-200">
                <input v-model="closeForm.is_public" type="checkbox" class="w-4 h-4 accent-primary"/>
                <div>
                  <p class="text-sm font-bold text-slate-700">ต้องส่งโรงเรียน (แสดงหน้าสาธารณะ)</p>
                  <p class="text-xs text-slate-400">ขึ้นหน้า /school-documents ให้โรงเรียนค้นหา/ดาวน์โหลดได้</p>
                </div>
              </label>
              <div v-if="closeForm.is_public">
                <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">เอกสารที่ส่งโรงเรียน (ลิงก์)</label>
                <input v-model="closeForm.school_doc_link" type="text" placeholder="https://drive.google.com/..."
                  class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>
            <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showCloseModal = false" type="button" class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
                ยกเลิก
              </button>
              <button @click="completeTask" :disabled="closing" type="button" class="flex-1 py-2.5 rounded-2xl bg-emerald-600 text-white text-sm font-bold hover:bg-emerald-700 disabled:opacity-50">
                {{ closing ? 'กำลังบันทึก...' : 'ผ่าน (ปิดงาน)' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ══ MODAL: จัดการประเภทหนังสือ ═══════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showTypesPanel" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">จัดการประเภทหนังสือ</h2>
              <button @click="showTypesPanel = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-2">
              <div v-for="(t, i) in taskTypesDraft" :key="t.key"
                class="flex items-center gap-2 px-3 py-2 bg-slate-50 rounded-xl border border-slate-100">
                <div class="flex flex-col gap-0.5">
                  <button @click="moveTypeUp(i)" :disabled="i === 0" type="button" class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
                  </button>
                  <button @click="moveTypeDown(i)" :disabled="i === taskTypesDraft.length - 1" type="button" class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
                  </button>
                </div>
                <input v-model="t.label" type="text" class="flex-1 px-2 py-1 text-sm font-bold border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
                <button @click="t.visible = !t.visible" type="button"
                  :class="['px-2.5 py-1 text-xs font-bold rounded-lg transition-colors', t.visible ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-200 text-slate-400']">
                  {{ t.visible ? 'แสดง' : 'ซ่อน' }}
                </button>
                <button @click="removeType(i)" type="button" class="text-slate-300 hover:text-red-500">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                </button>
              </div>
              <button @click="addType" type="button" class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
                เพิ่มประเภท
              </button>
            </div>
            <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showTypesPanel = false" type="button" class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
                ยกเลิก
              </button>
              <button @click="saveTypes" :disabled="savingTypes" type="button" class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
                {{ savingTypes ? 'กำลังบันทึก...' : 'บันทึก' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
