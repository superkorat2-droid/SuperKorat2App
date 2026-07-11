<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import StorageBrowser from '../../components/StorageBrowser.vue'
import { useAreaConfig } from '../../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()
const deptOptions = computed(() => (config.value?.personnel_groups || []).map(g => g.label))

// ── Constants ────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'all',        label: 'ทั้งหมด',            icon: '📋' },
  { value: 'form',       label: 'แบบฟอร์ม',           icon: '📝' },
  { value: 'supervision',label: 'นิเทศการศึกษา',      icon: '🔍' },
  { value: 'curriculum', label: 'หลักสูตร',            icon: '📖' },
  { value: 'report',     label: 'รายงาน',              icon: '📊' },
  { value: 'policy',     label: 'นโยบาย/หนังสือเวียน', icon: '📜' },
  { value: 'other',      label: 'ทั่วไป',              icon: '📌' },
]

const FILE_TYPES = ['PDF', 'Word', 'Excel', 'PowerPoint', 'ZIP', 'อื่น ๆ']

// ── State ────────────────────────────────────────────────────────
const docList        = ref([])
const loading        = ref(true)
const saving         = ref(false)
const showModal      = ref(false)
const showStorage    = ref(false)
const activeCategory = ref('all')
const searchQ        = ref('')

const emptyForm = () => ({
  id:             null,
  category:       'form',
  title:          '',
  description:    '',
  file_url:       '',
  file_type:      'PDF',
  file_size:      '',
  is_published:   true,
  sort_order:     0,
  publisher_name: '',
  publisher_dept: '',
})
const form = ref(emptyForm())
const myProfile = ref(null)

// ── Fetch ─────────────────────────────────────────────────────────
async function fetchDocs() {
  loading.value = true
  const { data, error } = await supabase
    .from('documents')
    .select('*')
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: false })
  if (!error) docList.value = data || []
  loading.value = false
}
async function fetchMyProfile() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return
  const { data } = await supabase.from('profiles').select('full_name, department').eq('id', user.id).single()
  myProfile.value = data || null
}
onMounted(() => { fetchDocs(); fetchConfig(); fetchMyProfile() })

// ── Computed ──────────────────────────────────────────────────────
const filtered = computed(() => {
  let list = docList.value
  if (activeCategory.value !== 'all')
    list = list.filter(d => d.category === activeCategory.value)
  if (searchQ.value)
    list = list.filter(d => d.title.toLowerCase().includes(searchQ.value.toLowerCase()))
  return list
})

const catCounts = computed(() => {
  const counts = { all: docList.value.length }
  CATEGORIES.slice(1).forEach(c => {
    counts[c.value] = docList.value.filter(d => d.category === c.value).length
  })
  return counts
})

// ── Open modal ────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  form.value.sort_order = docList.value.length
  form.value.publisher_name = myProfile.value?.full_name || ''
  form.value.publisher_dept = myProfile.value?.department || ''
  showModal.value = true
}
function openEdit(d) {
  form.value = { ...d }
  showModal.value = true
}

// ── Save ──────────────────────────────────────────────────────────
async function saveDoc() {
  if (!form.value.title.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อเอกสาร', confirmButtonColor: '#3b82f6' })
  if (!form.value.file_url.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณาใส่ URL ไฟล์', confirmButtonColor: '#3b82f6' })

  saving.value = true
  const { data: { user } } = await supabase.auth.getUser()
  const payload = {
    category:       form.value.category,
    title:          form.value.title.trim(),
    description:    form.value.description.trim(),
    file_url:       form.value.file_url.trim(),
    file_type:      form.value.file_type,
    file_size:      form.value.file_size.trim(),
    is_published:   form.value.is_published,
    sort_order:     Number(form.value.sort_order) || 0,
    created_by:     user?.id || null,
    publisher_name: form.value.publisher_name.trim(),
    publisher_dept: form.value.publisher_dept.trim(),
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('documents').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('documents').insert(payload))
  }

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
    showModal.value = false
    await fetchDocs()
  }
  saving.value = false
}

// ── Toggle publish ────────────────────────────────────────────────
async function togglePublish(d) {
  const { error } = await supabase.from('documents').update({ is_published: !d.is_published }).eq('id', d.id)
  if (!error) d.is_published = !d.is_published
}

// ── Delete ────────────────────────────────────────────────────────
async function deleteDoc(d) {
  const res = await Swal.fire({
    title: 'ลบเอกสารนี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('documents').delete().eq('id', d.id)
  docList.value = docList.value.filter(x => x.id !== d.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

// ── Storage ───────────────────────────────────────────────────────
function onStorageSelect({ url, path }) {
  form.value.file_url = url
  // Auto-detect file type
  const ext = path.split('.').pop()?.toUpperCase()
  if (['PDF'].includes(ext)) form.value.file_type = 'PDF'
  else if (['DOC', 'DOCX'].includes(ext)) form.value.file_type = 'Word'
  else if (['XLS', 'XLSX'].includes(ext)) form.value.file_type = 'Excel'
  else if (['PPT', 'PPTX'].includes(ext)) form.value.file_type = 'PowerPoint'
  else if (['ZIP', 'RAR'].includes(ext)) form.value.file_type = 'ZIP'
  showStorage.value = false
}

// ── Helpers ───────────────────────────────────────────────────────
function getCatLabel(val) { return CATEGORIES.find(c => c.value === val)?.label || val }
function getCatIcon(val)  { return CATEGORIES.find(c => c.value === val)?.icon  || '📌' }

function fileTypeColor(t) {
  const map = {
    PDF: 'bg-red-100 text-red-700',
    Word: 'bg-blue-100 text-blue-700',
    Excel: 'bg-emerald-100 text-emerald-700',
    PowerPoint: 'bg-orange-100 text-orange-700',
    ZIP: 'bg-purple-100 text-purple-700',
  }
  return map[t] || 'bg-slate-100 text-slate-600'
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'short' })
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2"><SvgIcon name="folder" class="w-6 h-6 text-primary"/> เอกสารและดาวน์โหลด</h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการแบบฟอร์ม รายงาน และไฟล์สำหรับดาวน์โหลด</p>
      </div>
      <button @click="openAdd"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5">
        ➕ เพิ่มเอกสารใหม่
      </button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">📂</div>
        <div>
          <p class="text-xl font-extrabold text-slate-800">{{ docList.length }}</p>
          <p class="text-xs text-slate-500">ทั้งหมด</p>
        </div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">✅</div>
        <div>
          <p class="text-xl font-extrabold text-emerald-600">{{ docList.filter(d=>d.is_published).length }}</p>
          <p class="text-xs text-slate-500">เผยแพร่</p>
        </div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">📥</div>
        <div>
          <p class="text-xl font-extrabold text-blue-600">{{ docList.reduce((s,d)=>s+(d.download_count||0),0).toLocaleString() }}</p>
          <p class="text-xs text-slate-500">ดาวน์โหลดรวม</p>
        </div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">📝</div>
        <div>
          <p class="text-xl font-extrabold text-amber-600">{{ docList.filter(d=>d.category==='form').length }}</p>
          <p class="text-xs text-slate-500">แบบฟอร์ม</p>
        </div>
      </div>
    </div>

    <!-- Category tabs + search -->
    <div class="flex flex-wrap gap-2 items-center">
      <button v-for="cat in CATEGORIES" :key="cat.value"
        @click="activeCategory = cat.value"
        :class="['flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-bold transition-all',
          activeCategory === cat.value
            ? 'bg-primary text-white shadow'
            : 'bg-white border border-slate-200 text-slate-600 hover:border-primary hover:text-primary']">
        {{ cat.icon }} {{ cat.label }}
        <span :class="['text-xs px-1.5 py-0.5 rounded-full',
          activeCategory === cat.value ? 'bg-white/30 text-white' : 'bg-slate-100 text-slate-500']">
          {{ catCounts[cat.value] || 0 }}
        </span>
      </button>
      <div class="ml-auto">
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อเอกสาร..."
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-48"/>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-2">
      <div v-for="i in 6" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="text-5xl mb-3">📂</div>
      <p class="font-bold text-slate-600 mb-1">ไม่มีเอกสาร</p>
      <p class="text-sm text-slate-400">{{ searchQ ? 'ไม่พบเอกสารที่ค้นหา' : 'เพิ่มเอกสารแรกได้เลย' }}</p>
    </div>

    <!-- Document list -->
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-slate-100 bg-slate-50">
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">เอกสาร</th>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider hidden md:table-cell">หมวดหมู่</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden sm:table-cell">ประเภท</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden lg:table-cell">ดาวน์โหลด</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">สถานะ</th>
            <th class="px-4 py-3 text-right text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <tr v-for="d in filtered" :key="d.id" class="hover:bg-slate-50 transition-colors">
            <!-- Title -->
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-xl"
                  :class="fileTypeColor(d.file_type)">
                  {{ d.file_type === 'PDF' ? '📄' : d.file_type === 'Word' ? '📝' : d.file_type === 'Excel' ? '📊' : '📎' }}
                </div>
                <div class="min-w-0">
                  <p class="font-bold text-slate-800 truncate max-w-[180px] md:max-w-[280px]">{{ d.title }}</p>
                  <p v-if="d.description" class="text-xs text-slate-400 truncate max-w-[180px] md:max-w-[280px] mt-0.5">{{ d.description }}</p>
                  <p v-if="d.publisher_name || d.publisher_dept" class="text-[11px] text-slate-400 truncate max-w-[180px] md:max-w-[280px] mt-0.5">
                    👤 {{ [d.publisher_name, d.publisher_dept].filter(Boolean).join(' · ') }}
                  </p>
                </div>
              </div>
            </td>
            <!-- Category -->
            <td class="px-4 py-3 hidden md:table-cell">
              <span class="px-2 py-1 bg-slate-100 text-slate-600 rounded-lg text-xs font-bold whitespace-nowrap">
                {{ getCatIcon(d.category) }} {{ getCatLabel(d.category) }}
              </span>
            </td>
            <!-- File type -->
            <td class="px-4 py-3 text-center hidden sm:table-cell">
              <span :class="['px-2 py-1 rounded-lg text-xs font-bold', fileTypeColor(d.file_type)]">
                {{ d.file_type }}
              </span>
            </td>
            <!-- Downloads -->
            <td class="px-4 py-3 text-center text-xs text-slate-500 font-bold hidden lg:table-cell">
              📥 {{ (d.download_count || 0).toLocaleString() }}
            </td>
            <!-- Status -->
            <td class="px-4 py-3 text-center">
              <button @click="togglePublish(d)"
                :class="['px-2.5 py-1 rounded-full text-xs font-bold transition-all',
                  d.is_published ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                {{ d.is_published ? '✅ เผยแพร่' : '🚫 ซ่อน' }}
              </button>
            </td>
            <!-- Actions -->
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <a :href="d.file_url" target="_blank"
                  class="px-3 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-100 transition-all">
                  👁️
                </a>
                <button @click="openEdit(d)"
                  class="px-3 py-1.5 bg-blue-50 text-blue-600 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all">
                  ✏️
                </button>
                <button @click="deleteDoc(d)"
                  class="px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">
                  🗑️
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- ── MODAL ADD/EDIT ──────────────────────────────────────── -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[92vh] flex flex-col overflow-hidden">

            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg">{{ form.id ? '✏️ แก้ไขเอกสาร' : '➕ เพิ่มเอกสาร' }}</h3>
              <button @click="showModal = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 text-lg">✕</button>
            </div>

            <!-- Body -->
            <div class="flex-1 overflow-y-auto p-6 space-y-4">

              <!-- Category -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-2">หมวดหมู่ <span class="text-red-400">*</span></label>
                <div class="flex flex-wrap gap-2">
                  <button v-for="cat in CATEGORIES.slice(1)" :key="cat.value"
                    @click="form.category = cat.value"
                    :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
                      form.category===cat.value ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                    {{ cat.icon }} {{ cat.label }}
                  </button>
                </div>
              </div>

              <!-- Title -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อเอกสาร <span class="text-red-400">*</span></label>
                <input v-model="form.title" type="text" placeholder="ชื่อเอกสาร..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>

              <!-- Description -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">คำอธิบาย</label>
                <textarea v-model="form.description" rows="2" placeholder="รายละเอียดเพิ่มเติม..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"/>
              </div>

              <!-- Publisher -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ผู้เผยแพร่</label>
                  <input v-model="form.publisher_name" type="text" placeholder="ชื่อผู้เผยแพร่ (ถ้ามี)"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">กลุ่มงาน</label>
                  <input v-model="form.publisher_dept" type="text" list="doc-dept-options" placeholder="เลือกหรือพิมพ์กลุ่มงาน"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                  <datalist id="doc-dept-options">
                    <option v-for="dep in deptOptions" :key="dep" :value="dep"/>
                  </datalist>
                </div>
              </div>

              <!-- File URL -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">📎 URL ไฟล์ <span class="text-red-400">*</span></label>
                <div class="flex gap-2">
                  <input v-model="form.file_url" type="text" placeholder="https://..."
                    class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                  <button @click="showStorage = true"
                    class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors whitespace-nowrap">
                    🗂️ เลือก
                  </button>
                </div>
              </div>

              <!-- File type + size -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ประเภทไฟล์</label>
                  <select v-model="form.file_type"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/30">
                    <option v-for="t in FILE_TYPES" :key="t" :value="t">{{ t }}</option>
                  </select>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ขนาดไฟล์</label>
                  <input v-model="form.file_size" type="text" placeholder="เช่น 2.5 MB"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                </div>
              </div>

              <!-- Sort + Published -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ลำดับ</label>
                  <input v-model.number="form.sort_order" type="number" min="0"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">สถานะ</label>
                  <button @click="form.is_published = !form.is_published"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_published ? 'border-emerald-400 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_published ? '✅ เผยแพร่' : '🚫 ซ่อน' }}
                  </button>
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false"
                class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">
                ยกเลิก
              </button>
              <button @click="saveDoc" :disabled="saving"
                class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
                <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                💾 บันทึก
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Storage Browser Modal -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showStorage"
          class="fixed inset-0 z-[150] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showStorage = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800">🗂️ เลือกไฟล์จาก Storage</h3>
              <button @click="showStorage = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 text-lg">✕</button>
            </div>
            <div class="flex-1 overflow-y-auto p-6">
              <StorageBrowser bucket="documents" title="เอกสาร" accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip" :selectable="true" @select="onStorageSelect"/>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
