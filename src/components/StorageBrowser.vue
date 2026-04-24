<script setup>
/**
 * StorageBrowser — แสดง/จัดการไฟล์ใน Supabase Storage bucket
 * Props: bucket (string), accept (string), title (string)
 * Emits: select({ url, path }) — เมื่อผู้ใช้เลือกไฟล์
 */
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../supabase'
import Swal from 'sweetalert2'

const props = defineProps({
  bucket:      { type: String, default: 'logos' },
  accept:      { type: String, default: 'image/*' },
  title:       { type: String, default: 'ไฟล์ทั้งหมด' },
  selectable:  { type: Boolean, default: false },
})
const emit = defineEmits(['select', 'refresh'])

const files       = ref([])
const loading     = ref(true)
const uploading   = ref(false)
const searchQ     = ref('')
const fileInput   = ref(null)
const sortBy      = ref('created_at') // created_at | name | metadata.size
const sortDesc    = ref(true)

// ── Load files ─────────────────────────────────────────────────
async function loadFiles() {
  loading.value = true
  const { data, error } = await supabase.storage.from(props.bucket).list('', {
    limit: 200, offset: 0,
    sortBy: { column: 'created_at', order: 'desc' }
  })
  if (!error) files.value = data?.filter(f => f.name !== '.emptyFolderPlaceholder') || []
  loading.value = false
}

onMounted(loadFiles)

// ── Public URL ─────────────────────────────────────────────────
function getUrl(path) {
  const { data } = supabase.storage.from(props.bucket).getPublicUrl(path)
  return data.publicUrl
}

// ── Upload ─────────────────────────────────────────────────────
async function onFileChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploading.value = true
  const ext  = file.name.split('.').pop()
  const name = `file-${Date.now()}.${ext}`
  const { data, error } = await supabase.storage.from(props.bucket)
    .upload(name, file, { contentType: file.type, upsert: false })
  if (error) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    await loadFiles()
    emit('refresh')
    Swal.fire({ icon: 'success', title: 'อัปโหลดสำเร็จ', showConfirmButton: false, timer: 1200 })
  }
  uploading.value = false
  e.target.value = ''
}

// ── Delete ─────────────────────────────────────────────────────
async function deleteFile(name) {
  const res = await Swal.fire({
    title: `ลบไฟล์ "${name}"?`, icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก'
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.storage.from(props.bucket).remove([name])
  if (error) {
    Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    files.value = files.value.filter(f => f.name !== name)
    emit('refresh')
    Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 1000 })
  }
}

// ── Copy URL ───────────────────────────────────────────────────
function copyUrl(name) {
  const url = getUrl(name)
  navigator.clipboard.writeText(url)
  Swal.fire({ icon: 'success', title: 'คัดลอก URL แล้ว', showConfirmButton: false, timer: 1000 })
}

// ── Filter & sort ──────────────────────────────────────────────
const filtered = computed(() => {
  let list = files.value
  if (searchQ.value) list = list.filter(f => f.name.toLowerCase().includes(searchQ.value.toLowerCase()))
  list = [...list].sort((a, b) => {
    if (sortBy.value === 'metadata.size') return (a.metadata?.size || 0) - (b.metadata?.size || 0)
    if (sortBy.value === 'name') return a.name.localeCompare(b.name)
    return new Date(a.created_at) - new Date(b.created_at)
  })
  return sortDesc.value ? list.reverse() : list
})

// ── Helpers ────────────────────────────────────────────────────
function formatSize(bytes) {
  if (!bytes) return '—'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1048576) return (bytes/1024).toFixed(1) + ' KB'
  return (bytes/1048576).toFixed(1) + ' MB'
}
function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('th-TH', { dateStyle:'short', timeStyle:'short' })
}
function isImage(name) {
  return /\.(jpg|jpeg|png|gif|webp|svg|ico)$/i.test(name)
}
function fileIcon(name) {
  if (isImage(name)) return '🖼️'
  if (/\.pdf$/i.test(name)) return '📄'
  if (/\.(doc|docx)$/i.test(name)) return '📝'
  if (/\.(xls|xlsx)$/i.test(name)) return '📊'
  return '📎'
}
</script>

<template>
  <div class="font-sarabun space-y-4">

    <!-- Toolbar -->
    <div class="flex flex-wrap items-center gap-2 justify-between">
      <h3 class="font-extrabold text-slate-700">🗂️ {{ title }} ({{ filtered.length }})</h3>
      <div class="flex items-center gap-2 flex-wrap">
        <!-- Search -->
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อไฟล์..."
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-100 w-44"/>
        <!-- Sort -->
        <select v-model="sortBy" class="px-3 py-1.5 border border-slate-200 rounded-xl text-xs bg-white">
          <option value="created_at">วันที่อัปโหลด</option>
          <option value="name">ชื่อไฟล์</option>
          <option value="metadata.size">ขนาด</option>
        </select>
        <button @click="sortDesc = !sortDesc" class="px-2 py-1.5 border border-slate-200 rounded-xl text-xs hover:bg-slate-50">
          {{ sortDesc ? '↓' : '↑' }}
        </button>
        <!-- Refresh -->
        <button @click="loadFiles" :disabled="loading"
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-xs font-bold hover:bg-slate-50 transition-colors">
          🔄 รีเฟรช
        </button>
        <!-- Upload -->
        <button @click="fileInput.click()" :disabled="uploading"
          class="flex items-center gap-1.5 px-4 py-1.5 bg-primary hover:bg-primary-dark text-white text-xs font-bold rounded-xl transition-colors disabled:opacity-50">
          <svg v-if="uploading" class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
          ⬆️ อัปโหลด
        </button>
        <input ref="fileInput" type="file" :accept="accept" class="hidden" @change="onFileChange"/>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
      <div v-for="i in 6" :key="i" class="aspect-square bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0" class="text-center py-12 text-slate-400">
      <div class="text-4xl mb-2">📂</div>
      <p class="text-sm font-bold">{{ searchQ ? 'ไม่พบไฟล์ที่ค้นหา' : 'ยังไม่มีไฟล์' }}</p>
    </div>

    <!-- Grid -->
    <div v-else class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 gap-3">
      <div v-for="file in filtered" :key="file.name"
        :class="[
          'group relative bg-white border-2 rounded-2xl overflow-hidden transition-all hover:shadow-md',
          selectable ? 'cursor-pointer hover:border-primary' : 'border-slate-100 hover:border-slate-200'
        ]"
        @click="selectable && emit('select', { url: getUrl(file.name), path: file.name })">

        <!-- Thumbnail -->
        <div class="aspect-square bg-slate-50 flex items-center justify-center overflow-hidden">
          <img v-if="isImage(file.name)"
            :src="getUrl(file.name)"
            class="w-full h-full object-contain p-1"
            loading="lazy"/>
          <span v-else class="text-4xl">{{ fileIcon(file.name) }}</span>
        </div>

        <!-- Info -->
        <div class="p-2 border-t border-slate-100">
          <p class="text-[10px] font-bold text-slate-700 truncate" :title="file.name">{{ file.name }}</p>
          <p class="text-[9px] text-slate-400">{{ formatSize(file.metadata?.size) }}</p>
          <p class="text-[9px] text-slate-400">{{ formatDate(file.created_at) }}</p>
        </div>

        <!-- Hover actions -->
        <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-2 p-2">
          <button v-if="selectable" @click.stop="emit('select', { url: getUrl(file.name), path: file.name })"
            class="w-full py-1 bg-primary text-white text-[10px] font-bold rounded-lg">
            ✅ เลือก
          </button>
          <button @click.stop="copyUrl(file.name)"
            class="w-full py-1 bg-white/90 text-slate-800 text-[10px] font-bold rounded-lg">
            📋 คัดลอก URL
          </button>
          <a :href="getUrl(file.name)" target="_blank" @click.stop
            class="w-full py-1 bg-white/90 text-slate-800 text-[10px] font-bold rounded-lg text-center">
            👁️ เปิดดู
          </a>
          <button @click.stop="deleteFile(file.name)"
            class="w-full py-1 bg-red-500 text-white text-[10px] font-bold rounded-lg">
            🗑️ ลบ
          </button>
        </div>

      </div>
    </div>

    <!-- Storage usage summary -->
    <div v-if="!loading && files.length > 0" class="text-right text-xs text-slate-400 pt-1">
      {{ files.length }} ไฟล์ ·
      รวม {{ formatSize(files.reduce((s, f) => s + (f.metadata?.size || 0), 0)) }}
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
