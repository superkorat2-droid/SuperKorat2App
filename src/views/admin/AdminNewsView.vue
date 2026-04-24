<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import StorageBrowser from '../../components/StorageBrowser.vue'

// ── Constants ────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'all',        label: 'ทั้งหมด',          icon: '📋' },
  { value: 'pr',         label: 'ประชาสัมพันธ์',     icon: '📣' },
  { value: 'supervision',label: 'นิเทศการศึกษา',     icon: '🔍' },
  { value: 'training',   label: 'อบรม/สัมมนา',       icon: '📚' },
  { value: 'policy',     label: 'นโยบาย/หนังสือเวียน', icon: '📜' },
  { value: 'other',      label: 'ทั่วไป',             icon: '📌' },
]

// ── State ────────────────────────────────────────────────────────
const newsList       = ref([])
const loading        = ref(true)
const saving         = ref(false)
const showModal      = ref(false)
const showStorage    = ref(false)
const activeCategory = ref('all')
const searchQ        = ref('')

const emptyForm = () => ({
  id:           null,
  category:     'pr',
  title:        '',
  excerpt:      '',
  content:      '',
  cover_url:    '',
  file_url:     '',
  is_pinned:    false,
  is_published: false,
  published_at: '',
})
const form = ref(emptyForm())

// ── Fetch ─────────────────────────────────────────────────────────
async function fetchNews() {
  loading.value = true
  const { data, error } = await supabase
    .from('news')
    .select('*')
    .order('is_pinned', { ascending: false })
    .order('created_at', { ascending: false })
  if (!error) newsList.value = data || []
  loading.value = false
}
onMounted(fetchNews)

// ── Computed list ─────────────────────────────────────────────────
const filtered = computed(() => {
  let list = newsList.value
  if (activeCategory.value !== 'all')
    list = list.filter(n => n.category === activeCategory.value)
  if (searchQ.value)
    list = list.filter(n => n.title.toLowerCase().includes(searchQ.value.toLowerCase()))
  return list
})

const catCounts = computed(() => {
  const counts = { all: newsList.value.length }
  CATEGORIES.slice(1).forEach(c => {
    counts[c.value] = newsList.value.filter(n => n.category === c.value).length
  })
  return counts
})

// ── Open modal ────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  showModal.value = true
}
function openEdit(n) {
  form.value = {
    ...n,
    published_at: n.published_at ? n.published_at.slice(0, 16) : '',
  }
  showModal.value = true
}

// ── Save ──────────────────────────────────────────────────────────
async function saveNews() {
  if (!form.value.title.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อข่าว', confirmButtonColor: '#3b82f6' })

  saving.value = true
  const { data: { user } } = await supabase.auth.getUser()
  const payload = {
    category:     form.value.category,
    title:        form.value.title.trim(),
    excerpt:      form.value.excerpt.trim(),
    content:      form.value.content.trim(),
    cover_url:    form.value.cover_url.trim(),
    file_url:     form.value.file_url.trim(),
    is_pinned:    form.value.is_pinned,
    is_published: form.value.is_published,
    published_at: form.value.is_published
      ? (form.value.published_at || new Date().toISOString())
      : null,
    created_by: user?.id || null,
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('news').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('news').insert(payload))
  }

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
    showModal.value = false
    await fetchNews()
  }
  saving.value = false
}

// ── Toggle publish ────────────────────────────────────────────────
async function togglePublish(n) {
  const is_published = !n.is_published
  const published_at = is_published ? new Date().toISOString() : null
  const { error } = await supabase.from('news').update({ is_published, published_at }).eq('id', n.id)
  if (!error) { n.is_published = is_published; n.published_at = published_at }
}

// ── Delete ────────────────────────────────────────────────────────
async function deleteNews(n) {
  const res = await Swal.fire({
    title: 'ลบข่าวนี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('news').delete().eq('id', n.id)
  newsList.value = newsList.value.filter(x => x.id !== n.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

// ── Storage select ────────────────────────────────────────────────
const storageTarget = ref('cover') // 'cover' | 'file'
function pickStorage(target) {
  storageTarget.value = target
  showStorage.value = true
}
function onStorageSelect({ url }) {
  if (storageTarget.value === 'cover') form.value.cover_url = url
  else form.value.file_url = url
  showStorage.value = false
}

// ── Helpers ───────────────────────────────────────────────────────
function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' })
}
function getCatLabel(val) {
  return CATEGORIES.find(c => c.value === val)?.label || val
}
function getCatIcon(val) {
  return CATEGORIES.find(c => c.value === val)?.icon || '📌'
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">📰 จัดการข่าวสาร</h1>
        <p class="text-sm text-slate-500 mt-0.5">ข่าวประชาสัมพันธ์ นิเทศ อบรม และหนังสือเวียน</p>
      </div>
      <button @click="openAdd"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5">
        ➕ เพิ่มข่าวใหม่
      </button>
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
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อข่าว..."
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-48"/>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 5" :key="i" class="h-20 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="text-5xl mb-3">📰</div>
      <p class="font-bold text-slate-600 mb-1">ไม่มีข่าวสาร</p>
      <p class="text-sm text-slate-400">{{ searchQ ? 'ไม่พบข่าวที่ค้นหา' : 'เพิ่มข่าวแรกได้เลย' }}</p>
    </div>

    <!-- News table -->
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-slate-100 bg-slate-50">
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ข่าว</th>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider hidden md:table-cell">หมวดหมู่</th>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider hidden lg:table-cell">วันที่</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">สถานะ</th>
            <th class="px-4 py-3 text-right text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <tr v-for="n in filtered" :key="n.id" class="hover:bg-slate-50 transition-colors">
            <!-- Title + cover -->
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                <div v-if="n.cover_url" class="w-12 h-10 rounded-lg overflow-hidden flex-shrink-0 bg-slate-100">
                  <img :src="n.cover_url" class="w-full h-full object-cover"/>
                </div>
                <div v-else class="w-12 h-10 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0 text-xl">
                  {{ getCatIcon(n.category) }}
                </div>
                <div class="min-w-0">
                  <div class="flex items-center gap-1.5">
                    <span v-if="n.is_pinned" class="text-amber-500 text-xs">📌</span>
                    <p class="font-bold text-slate-800 truncate max-w-[200px] md:max-w-[300px]">{{ n.title }}</p>
                  </div>
                  <p v-if="n.excerpt" class="text-xs text-slate-400 truncate max-w-[200px] md:max-w-[300px] mt-0.5">{{ n.excerpt }}</p>
                </div>
              </div>
            </td>
            <!-- Category -->
            <td class="px-4 py-3 hidden md:table-cell">
              <span class="px-2 py-1 bg-slate-100 text-slate-600 rounded-lg text-xs font-bold">
                {{ getCatIcon(n.category) }} {{ getCatLabel(n.category) }}
              </span>
            </td>
            <!-- Date -->
            <td class="px-4 py-3 text-xs text-slate-400 hidden lg:table-cell whitespace-nowrap">
              {{ n.published_at ? formatDate(n.published_at) : '—' }}
            </td>
            <!-- Published badge -->
            <td class="px-4 py-3 text-center">
              <button @click="togglePublish(n)"
                :class="['px-2.5 py-1 rounded-full text-xs font-bold transition-all',
                  n.is_published ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                {{ n.is_published ? '✅ เผยแพร่' : '📝 ร่าง' }}
              </button>
            </td>
            <!-- Actions -->
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <button @click="openEdit(n)"
                  class="px-3 py-1.5 bg-blue-50 text-blue-600 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all">
                  ✏️
                </button>
                <button @click="deleteNews(n)"
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
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showModal = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">

            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg">{{ form.id ? '✏️ แก้ไขข่าว' : '➕ เพิ่มข่าวใหม่' }}</h3>
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
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อข่าว <span class="text-red-400">*</span></label>
                <input v-model="form.title" type="text" placeholder="ชื่อข่าวสาร..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>

              <!-- Excerpt -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">เนื้อหาย่อ</label>
                <textarea v-model="form.excerpt" rows="2" placeholder="สรุปสั้น ๆ..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"/>
              </div>

              <!-- Content -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">เนื้อหาเต็ม</label>
                <textarea v-model="form.content" rows="5" placeholder="รายละเอียดข่าวสาร..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 resize-y"/>
              </div>

              <!-- Cover image -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">📸 รูปปก</label>
                <div class="flex gap-2">
                  <input v-model="form.cover_url" type="text" placeholder="URL รูปปก..."
                    class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                  <button @click="pickStorage('cover')"
                    class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
                    🗂️
                  </button>
                </div>
                <div v-if="form.cover_url" class="mt-2 h-28 rounded-xl overflow-hidden bg-slate-100">
                  <img :src="form.cover_url" class="w-full h-full object-cover"/>
                </div>
              </div>

              <!-- File attachment -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">📎 ไฟล์แนบ</label>
                <div class="flex gap-2">
                  <input v-model="form.file_url" type="text" placeholder="URL ไฟล์แนบ (PDF, ฯลฯ)"
                    class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                  <button @click="pickStorage('file')"
                    class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
                    🗂️
                  </button>
                </div>
              </div>

              <!-- Published + Pinned + Date -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">สถานะการเผยแพร่</label>
                  <button @click="form.is_published = !form.is_published"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_published ? 'border-emerald-400 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_published ? '✅ เผยแพร่' : '📝 บันทึกร่าง' }}
                  </button>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ปักหมุด</label>
                  <button @click="form.is_pinned = !form.is_pinned"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_pinned ? 'border-amber-400 bg-amber-50 text-amber-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_pinned ? '📌 ปักหมุดแล้ว' : '📌 ไม่ปักหมุด' }}
                  </button>
                </div>
              </div>

              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">วันเวลาเผยแพร่</label>
                <input v-model="form.published_at" type="datetime-local"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>
            </div>

            <!-- Footer -->
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false"
                class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">
                ยกเลิก
              </button>
              <button @click="saveNews" :disabled="saving"
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
              <StorageBrowser
                :bucket="storageTarget === 'cover' ? 'images' : 'documents'"
                :title="storageTarget === 'cover' ? 'รูปภาพ' : 'เอกสาร'"
                :selectable="true"
                @select="onStorageSelect"/>
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
