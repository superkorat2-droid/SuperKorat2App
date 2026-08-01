<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import DriveCover from '../components/DriveCover.vue'
import { NEWSLETTER_CATEGORIES, MONTHS_TH,
         newsletterCatLabel, newsletterCatColor } from '../composables/useNewsletterMeta'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('newsletters', { icon: 'document', title: 'จดหมายข่าว / เอกสารเผยแพร่', align: 'center' })
const items    = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const filterCat    = ref('all')
const filterYear   = ref('all')
const filterSchool = ref('all')
const previewItem  = ref(null)   // item ที่กำลัง preview

// ย้ายไป useNewsletterMeta แล้ว เพราะเซกชันหน้าแรกใช้ชุดเดียวกัน — คงชื่อเดิมไว้ให้ template
const CATEGORIES = NEWSLETTER_CATEGORIES
const MONTHS = MONTHS_TH

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase
    .from('newsletters').select('*, schools(name, district)')
    .eq('is_published', true)
    .order('year', { ascending: false })
    .order('month', { ascending: false })
  items.value   = data || []
  loading.value = false
})

const years   = computed(() => [...new Set(items.value.map(n=>n.year).filter(Boolean))].sort((a,b)=>b-a))
const schools = computed(() => {
  const map = new Map()
  items.value.forEach(n => { if (n.schools) map.set(n.school_id, n.schools) })
  return [...map.entries()].map(([id, s]) => ({ id, ...s })).sort((a,b)=>a.name.localeCompare(b.name,'th'))
})

const filtered = computed(() => {
  let list = items.value
  if (filterCat.value !== 'all')    list = list.filter(n => n.category === filterCat.value)
  if (filterYear.value !== 'all')   list = list.filter(n => String(n.year) === filterYear.value)
  if (filterSchool.value !== 'all') list = list.filter(n => n.school_id === filterSchool.value || (filterSchool.value === 'spp' && !n.school_id))
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(n => n.title.toLowerCase().includes(q) || n.schools?.name?.toLowerCase().includes(q))
  }
  return list
})

const isFiltered = computed(() =>
  searchQ.value.trim() || filterCat.value !== 'all' || filterYear.value !== 'all' || filterSchool.value !== 'all'
)

function resetFilter() {
  searchQ.value = ''; filterCat.value = 'all'; filterYear.value = 'all'; filterSchool.value = 'all'
}

// ยังใช้อยู่ในโมดัล — ที่นั่นเปิดทีละอันตามที่ผู้ใช้กด ไม่ใช่ 20 อันพร้อมกันแบบการ์ด
function embedUrl(fileId) { return `https://drive.google.com/file/d/${fileId}/preview` }
const catLabel = newsletterCatLabel
// เดิมหมวด newsletter ใช้ `bg-primary/10` ซึ่ง **ไม่มีอยู่จริง** (primary ไม่ใช่สีใน
// theme ของ Tailwind) ป้ายจึงไม่มีพื้นหลังมาตลอด — ตัวใหม่ใช้ bg-sky-100
const catColor = newsletterCatColor
function monthLabel(m) { return m ? MONTHS[m-1] : '' }
</script>

<template>
  <div class="font-sarabun min-h-screen">

    <!-- ── Hero ───────────────────────────────────────────────────────────────── -->
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name} · ${items.length} รายการ`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="5xl"/>

    <div class="max-w-7xl mx-auto px-4 py-6 space-y-5">

      <!-- ── Search (แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ) ── -->
      <div class="max-w-lg mx-auto relative">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อเอกสาร โรงเรียน..."
          class="w-full pl-11 pr-4 py-3 rounded-2xl border border-slate-200
                 bg-white/70 backdrop-blur text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- ── Filters ─────────────────────────────────────────────────────────── -->
      <div class="flex flex-wrap gap-2 items-center justify-center">
        <select v-model="filterCat" class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกประเภท</option>
          <option v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
        </select>
        <select v-model="filterYear" class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกปี</option>
          <option v-for="y in years" :key="y" :value="String(y)">{{ y }}</option>
        </select>
        <select v-model="filterSchool" class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-[160px]">
          <option value="all">ทุกหน่วย</option>
          <option value="spp">สพป. (ส่วนกลาง)</option>
          <option v-for="s in schools" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
        <button v-if="isFiltered" @click="resetFilter" class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-red-500 transition-colors px-2 py-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
          ล้าง
        </button>
      </div>

      <!-- ── Loading ────────────────────────────────────────────────────────── -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        <div v-for="i in 8" :key="i" class="glass-card overflow-hidden animate-pulse">
          <div class="aspect-[3/4] bg-slate-100"/>
          <div class="p-3 space-y-2"><div class="h-3 bg-slate-100 rounded w-3/4"/><div class="h-2.5 bg-slate-100 rounded w-1/2"/></div>
        </div>
      </div>

      <!-- ── Empty ──────────────────────────────────────────────────────────── -->
      <div v-else-if="filtered.length === 0" class="text-center py-16 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/></svg>
        <p class="font-bold">ยังไม่มีเอกสาร</p>
        <button @click="resetFilter" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- ── Card grid ──────────────────────────────────────────────────────── -->
      <div v-else class="flex flex-wrap justify-center gap-4">
        <div v-for="n in filtered" :key="n.id"
          class="group glass-tile
                 hover:shadow-lg hover:-translate-y-1 transition-all duration-200 overflow-hidden cursor-pointer
                 w-full sm:w-[calc(50%-8px)] md:w-[calc(33.333%-11px)] lg:w-[calc(25%-12px)]"
          @click="previewItem = n">

          <!-- ภาพปก — เดิมเป็น iframe ของ Drive ครอบ pointer-events-none ให้ดูเหมือนรูป
               วัดจริงแล้ว 12 ใบ = 439 คำขอ / 38 MB เปลี่ยนมาเป็น <img> เหลือ 0.59 MB
               (iframe ยังใช้อยู่ในโมดัลข้างล่าง ซึ่งเปิดทีละอันจึงไม่เป็นปัญหา) -->
          <div class="aspect-[3/4] overflow-hidden bg-slate-100 relative">
            <DriveCover :file-id="n.file_id" :title="n.title"/>
            <!-- Hover overlay -->
            <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors duration-200 flex items-center justify-center">
              <div class="opacity-0 group-hover:opacity-100 transition-opacity bg-white/90 rounded-2xl px-4 py-2 text-sm font-bold text-primary shadow-lg">
                คลิกเพื่อดู
              </div>
            </div>
          </div>

          <!-- Card footer -->
          <div class="p-3">
            <!-- Category badge -->
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', catColor(n.category)]">
              {{ catLabel(n.category) }}
            </span>
            <!-- Title as link -->
            <a :href="n.drive_url" target="_blank" rel="noopener"
              class="block mt-1.5 text-sm font-bold text-slate-800 leading-snug hover:text-primary transition-colors line-clamp-2"
              @click.stop>
              {{ n.title }} ↗
            </a>
            <!-- Meta -->
            <p class="text-[11px] text-slate-400 mt-1 truncate">
              {{ n.schools?.name || 'สพป.' }}
              <span v-if="n.month || n.year">· {{ monthLabel(n.month) }} {{ n.year }}</span>
            </p>
          </div>
        </div>
      </div>

      <p class="text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</p>
    </div>
  </div>

  <!-- ── Preview Modal ─────────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="previewItem"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 font-sarabun"
        @click.self="previewItem=null">
        <div class="glass-panel rounded-[1.25rem] w-full max-w-3xl flex flex-col overflow-hidden"
          style="max-height: 92dvh">

          <!-- Modal header -->
          <div class="px-5 py-3 border-b border-slate-100 flex items-center gap-3 flex-shrink-0">
            <div class="flex-1 min-w-0">
              <p class="font-extrabold text-slate-800 truncate">{{ previewItem.title }}</p>
              <p class="text-xs text-slate-400">{{ previewItem.schools?.name || 'สพป.' }} · {{ monthLabel(previewItem.month) }} {{ previewItem.year }}</p>
            </div>
            <a :href="previewItem.drive_url" target="_blank" rel="noopener"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl hover:bg-primary/20 transition-colors flex-shrink-0">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/></svg>
              เปิดใน Drive
            </a>
            <button @click="previewItem=null"
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400 flex-shrink-0">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>

          <!-- Full iframe preview -->
          <div class="flex-1 overflow-hidden bg-slate-900" style="min-height:400px">
            <iframe v-if="previewItem.file_id"
              :src="embedUrl(previewItem.file_id)"
              class="w-full h-full border-0"
              allow="autoplay"
              style="height: calc(92dvh - 70px)"
            />
            <div v-else class="flex items-center justify-center h-full text-slate-400 text-sm">
              ไม่พบไฟล์ — กรุณาเปิดใน Google Drive
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
