<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'

const categories = [
  { key: 'all',         label: 'ทั้งหมด',              icon: '📂' },
  { key: 'form',        label: 'แบบฟอร์มธุรการ',       icon: '📝' },
  { key: 'supervision', label: 'เอกสารนิเทศ',          icon: '🔍' },
  { key: 'curriculum',  label: 'หลักสูตรและมาตรฐาน',   icon: '📖' },
  { key: 'report',      label: 'รายงานและสถิติ',        icon: '📊' },
  { key: 'policy',      label: 'นโยบาย/หนังสือเวียน',  icon: '📜' },
  { key: 'other',       label: 'ทั่วไป',                icon: '📌' },
]

const files    = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const activeCategory = ref('all')

async function fetchFiles() {
  loading.value = true
  const { data, error } = await supabase
    .from('documents')
    .select('*')
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: false })
  if (!error) files.value = data || []
  loading.value = false
}
onMounted(fetchFiles)

const filtered = computed(() => {
  let list = files.value
  if (activeCategory.value !== 'all') list = list.filter(f => f.category === activeCategory.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(f => f.title.toLowerCase().includes(q))
  return list
})

const catCounts = computed(() => {
  const counts = { all: files.value.length }
  categories.slice(1).forEach(c => {
    counts[c.key] = files.value.filter(f => f.category === c.key).length
  })
  return counts
})

const typeColor = {
  PDF: 'bg-red-100 text-red-700', Word: 'bg-blue-100 text-blue-700',
  Excel: 'bg-emerald-100 text-emerald-700', PowerPoint: 'bg-orange-100 text-orange-700',
  ZIP: 'bg-purple-100 text-purple-700',
}
const typeIcon = { PDF: '📄', Word: '📝', Excel: '📊', PowerPoint: '📑', ZIP: '🗜️' }

function publisherLine(f) {
  return [f.publisher_name, f.publisher_dept].filter(Boolean).join(' · ')
}

async function download(file) {
  file.download_count = (file.download_count || 0) + 1
  window.open(file.file_url, '_blank', 'noopener')
  await supabase.rpc('increment_document_download', { p_id: file.id })
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="font-sarabun text-slate-800 dark:text-slate-100 py-10">
    <div class="max-w-5xl mx-auto px-4">

      <!-- Header -->
      <div class="mb-10">
        <p class="text-xs text-primary font-bold uppercase tracking-widest mb-1">Downloads</p>
        <h1 class="text-3xl font-extrabold text-slate-900 dark:text-slate-100">ดาวน์โหลดเอกสาร</h1>
        <p class="text-slate-500 dark:text-slate-400 mt-2">แบบฟอร์ม คู่มือ เอกสารราชการ และรายงานต่าง ๆ</p>
      </div>

      <!-- Search + stats -->
      <div class="flex flex-col sm:flex-row gap-3 mb-6">
        <div class="relative flex-1">
          <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0"/>
          </svg>
          <input v-model="searchQ" type="text" placeholder="ค้นหาเอกสาร..."
            class="w-full pl-10 pr-4 py-2.5 border border-slate-200 dark:border-slate-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary bg-white dark:bg-slate-800"/>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-2.5 flex-shrink-0">
          <span class="font-bold text-primary">{{ filtered.length }}</span>
          <span>รายการ</span>
        </div>
      </div>

      <!-- Category tabs -->
      <div class="flex flex-wrap gap-2 mb-6">
        <button v-for="cat in categories" :key="cat.key"
          @click="activeCategory = cat.key"
          :class="['flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all border',
            activeCategory === cat.key
              ? 'bg-primary text-white border-primary shadow-md'
              : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-primary hover:text-primary']">
          {{ cat.icon }} {{ cat.label }}
          <span :class="['text-[10px] px-1.5 py-0.5 rounded-full',
            activeCategory === cat.key ? 'bg-white/30 text-white' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400']">
            {{ catCounts[cat.key] || 0 }}
          </span>
        </button>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="space-y-3">
        <div v-for="i in 5" :key="i" class="h-20 bg-slate-100 dark:bg-slate-800 rounded-2xl animate-pulse"></div>
      </div>

      <!-- File list -->
      <div v-else-if="filtered.length === 0" class="text-center py-20 text-slate-400">
        <span class="text-5xl block mb-3">🔍</span>
        <p>ไม่พบเอกสารที่ค้นหา</p>
      </div>
      <div v-else class="space-y-3">
        <div v-for="file in filtered" :key="file.id"
          class="flex items-center gap-4 bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 shadow-sm hover:shadow-md hover:border-primary/30 transition-all group">
          <div class="w-12 h-12 bg-slate-50 dark:bg-slate-700 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">
            {{ typeIcon[file.file_type] || '📎' }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-bold text-slate-800 dark:text-slate-100 group-hover:text-primary transition-colors leading-snug truncate">{{ file.title }}</p>
            <p v-if="file.description" class="text-xs text-slate-400 truncate mt-0.5">{{ file.description }}</p>
            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded font-mono', typeColor[file.file_type] || 'bg-slate-100 text-slate-600']">{{ file.file_type }}</span>
              <span v-if="file.file_size" class="text-xs text-slate-400">{{ file.file_size }}</span>
              <span class="text-xs text-slate-400">{{ formatDate(file.created_at) }}</span>
              <span v-if="publisherLine(file)" class="text-xs text-slate-400">👤 {{ publisherLine(file) }}</span>
              <span class="text-xs text-slate-400">📥 {{ (file.download_count || 0).toLocaleString() }}</span>
            </div>
          </div>
          <button @click="download(file)"
            class="flex items-center gap-1.5 bg-primary-light hover:bg-primary text-primary hover:text-white text-xs font-bold px-4 py-2 rounded-xl transition-all flex-shrink-0 border border-primary/20 hover:border-primary">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
            </svg>
            ดาวน์โหลด
          </button>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
