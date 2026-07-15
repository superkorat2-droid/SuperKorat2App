<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('school-documents', {
  icon: 'document', title: 'หนังสือถึงโรงเรียน',
  subtitle: 'ประกาศ คำสั่ง และหนังสือราชการสำหรับโรงเรียนในสังกัด',
  align: 'left',
})

const docs    = ref([])
const loading = ref(true)
const searchQ = ref('')
const activeType = ref('all')

async function fetchDocs() {
  loading.value = true
  const { data } = await supabase.rpc('get_school_documents_public')
  docs.value = Array.isArray(data) ? data : []
  loading.value = false
}
onMounted(() => { fetchDocs(); fetchConfig() })

const typeOptions = computed(() =>
  (config.value?.task_types || []).filter(t => t.visible !== false).sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
)
function typeLabel(key) { return typeOptions.value.find(t => t.key === key)?.label || key }

const filtered = computed(() => {
  let list = docs.value
  if (activeType.value !== 'all') list = list.filter(d => d.task_type === activeType.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(d => d.title.toLowerCase().includes(q) || (d.department || '').toLowerCase().includes(q))
  return list
})

const typeCounts = computed(() => {
  const counts = { all: docs.value.length }
  typeOptions.value.forEach(t => { counts[t.key] = docs.value.filter(d => d.task_type === t.key).length })
  return counts
})

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="font-sarabun min-h-[60vh] bg-slate-50 dark:bg-slate-950">
    <PageHero v-if="!header.hidden" :title="header.title" :subtitle="header.subtitle" :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      size="md" :align="header.align" max-width="6xl"/>

    <div class="max-w-5xl mx-auto px-4 py-8">
      <!-- Search + stats -->
      <div class="flex flex-col sm:flex-row gap-3 mb-6">
        <div class="relative flex-1">
          <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0"/>
          </svg>
          <input v-model="searchQ" type="text" placeholder="ค้นหาหนังสือ..."
            class="w-full pl-10 pr-4 py-2.5 border border-slate-200 dark:border-slate-700 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary bg-white dark:bg-slate-800"/>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-2.5 flex-shrink-0">
          <span class="font-bold text-primary">{{ filtered.length }}</span>
          <span>รายการ</span>
        </div>
      </div>

      <!-- Type tabs -->
      <div class="flex flex-wrap gap-2 mb-6">
        <button @click="activeType = 'all'"
          :class="['flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all border',
            activeType === 'all' ? 'bg-primary text-white border-primary shadow-md' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-primary hover:text-primary']">
          ทั้งหมด
          <span :class="['text-[10px] px-1.5 py-0.5 rounded-full', activeType === 'all' ? 'bg-white/30 text-white' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400']">{{ typeCounts.all || 0 }}</span>
        </button>
        <button v-for="t in typeOptions" :key="t.key" @click="activeType = t.key"
          :class="['flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all border',
            activeType === t.key ? 'bg-primary text-white border-primary shadow-md' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-primary hover:text-primary']">
          {{ t.label }}
          <span :class="['text-[10px] px-1.5 py-0.5 rounded-full', activeType === t.key ? 'bg-white/30 text-white' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400']">{{ typeCounts[t.key] || 0 }}</span>
        </button>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="space-y-3">
        <div v-for="i in 4" :key="i" class="h-20 bg-slate-100 dark:bg-slate-800 rounded-2xl animate-pulse"></div>
      </div>

      <!-- Empty -->
      <div v-else-if="filtered.length === 0" class="text-center py-20 text-slate-400">
        <span class="text-5xl block mb-3">📭</span>
        <p>ไม่พบหนังสือที่ค้นหา</p>
      </div>

      <!-- List -->
      <div v-else class="space-y-3">
        <div v-for="d in filtered" :key="d.id"
          class="flex flex-col sm:flex-row sm:items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 shadow-sm hover:shadow-md hover:border-primary/30 transition-all group">
          <div class="w-12 h-12 bg-slate-50 dark:bg-slate-700 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">📄</div>
          <div class="flex-1 min-w-0">
            <p class="font-bold text-slate-800 dark:text-slate-100 group-hover:text-primary transition-colors leading-snug break-words">{{ d.title }}</p>
            <p v-if="d.description" class="text-xs text-slate-400 mt-0.5 break-words">{{ d.description }}</p>
            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
              <span class="text-[10px] font-bold px-2 py-0.5 rounded bg-secondary/10 text-secondary">{{ typeLabel(d.task_type) }}</span>
              <span v-if="d.department" class="text-xs text-slate-400">{{ d.department }}</span>
              <span class="text-xs text-slate-400">{{ formatDate(d.created_at) }}</span>
            </div>
          </div>
          <a :href="d.school_doc_link" target="_blank" rel="noopener"
            class="flex items-center justify-center gap-1.5 bg-primary-light hover:bg-primary text-primary hover:text-white text-xs font-bold px-4 py-2 rounded-xl transition-all flex-shrink-0 border border-primary/20 hover:border-primary w-full sm:w-auto">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
            </svg>
            เปิดเอกสาร
          </a>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
