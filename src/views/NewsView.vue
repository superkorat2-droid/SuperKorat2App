<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig, DEFAULT_HOME_SECTIONS } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const router = useRouter()
const { config, fetchConfig } = useAreaConfig()

// ดึง title ของ section "news" จาก config (ตั้งค่าได้ใน Admin)
const newsSection = computed(() => {
  const sections = config.value?.home_sections
  if (Array.isArray(sections)) return sections.find(s => s.key === 'news') || DEFAULT_HOME_SECTIONS[0]
  return DEFAULT_HOME_SECTIONS[0]
})
const header = usePageHeader('news', {})

// ── Constants ────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'all',         label: 'ทั้งหมด',              icon: 'M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z' },
  { value: 'pr',          label: 'ประชาสัมพันธ์',        icon: 'M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46' },
  { value: 'supervision', label: 'นิเทศการศึกษา',        icon: 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z' },
  { value: 'training',    label: 'อบรม/สัมมนา',          icon: 'M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5' },
  { value: 'policy',      label: 'นโยบาย/หนังสือเวียน',  icon: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  { value: 'other',       label: 'ทั่วไป',               icon: 'M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5M6 7.5h3v3H6v-3z' },
]

// ── State ────────────────────────────────────────────────────────
const newsList    = ref([])
const loading     = ref(true)
const activeCategory = ref('all')
const searchQ     = ref('')
const page        = ref(1)
const PAGE_SIZE   = 12

// ── Fetch ────────────────────────────────────────────────────────
async function fetchNews() {
  loading.value = true
  const { data } = await supabase
    .from('news')
    .select('id, title, excerpt, cover_url, category, is_pinned, published_at, file_url, view_count')
    .eq('is_published', true)
    .order('is_pinned',    { ascending: false })
    .order('published_at', { ascending: false })
  newsList.value = data || []
  loading.value  = false
}

onMounted(async () => {
  await fetchConfig()
  await fetchNews()
})

// ── Filter + Search ───────────────────────────────────────────────
const filtered = computed(() => {
  let list = newsList.value
  if (activeCategory.value !== 'all')
    list = list.filter(n => n.category === activeCategory.value)
  if (searchQ.value.trim())
    list = list.filter(n =>
      n.title.includes(searchQ.value) || (n.excerpt || '').includes(searchQ.value)
    )
  return list
})

const paginated = computed(() => {
  const start = (page.value - 1) * PAGE_SIZE
  return filtered.value.slice(start, start + PAGE_SIZE)
})

const totalPages = computed(() => Math.ceil(filtered.value.length / PAGE_SIZE))

function setCategory(cat) {
  activeCategory.value = cat
  page.value = 1
}

// ── Counts per category ───────────────────────────────────────────
const countOf = (cat) => cat === 'all'
  ? newsList.value.length
  : newsList.value.filter(n => n.category === cat).length

// ── Format date ───────────────────────────────────────────────────
function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', {
    year: 'numeric', month: 'short', day: 'numeric',
  })
}

// ── Category meta ─────────────────────────────────────────────────
const catMeta = {
  pr:         { bg: 'bg-blue-100',   text: 'text-blue-700',   label: 'ประชาสัมพันธ์' },
  supervision:{ bg: 'bg-primary-light', text: 'text-primary', label: 'นิเทศการศึกษา' },
  training:   { bg: 'bg-emerald-100',text: 'text-emerald-700',label: 'อบรม/สัมมนา' },
  policy:     { bg: 'bg-amber-100',  text: 'text-amber-700',  label: 'นโยบาย/หนังสือเวียน' },
  other:      { bg: 'bg-slate-100',  text: 'text-slate-600',  label: 'ทั่วไป' },
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 dark:text-slate-100 min-h-screen transition-colors duration-300">

    <!-- ── Hero bar ──────────────────────────────────────────────── -->
    <PageHero
      :title="header.title || newsSection.title || 'ข่าวสารและประชาสัมพันธ์'"
      :subtitle="header.subtitle || config?.area_name || 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา'"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      size="md" align="left" max-width="7xl"/>

    <div class="max-w-7xl mx-auto px-4 py-8">

      <!-- ── Search (แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ) ── -->
      <div class="max-w-lg relative mb-8">
        <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
          fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" @input="page=1" type="text" placeholder="ค้นหาข่าว..."
          class="w-full pl-10 pr-4 py-2.5 rounded-2xl border border-slate-200 dark:border-slate-700
                 bg-white dark:bg-slate-800 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- ── Category tabs ─────────────────────────────────────── -->
      <div class="flex gap-2 flex-wrap mb-8">
        <button v-for="cat in CATEGORIES" :key="cat.value"
          @click="setCategory(cat.value)"
          :class="['flex items-center gap-1.5 px-4 py-2 rounded-full text-sm font-bold border transition-all',
            activeCategory === cat.value
              ? 'bg-primary text-white border-primary shadow-md'
              : 'bg-white text-slate-500 border-slate-200 hover:border-primary/40 hover:text-primary']">
          <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" :d="cat.icon"/>
          </svg>
          {{ cat.label }}
          <span class="ml-0.5 opacity-60 text-xs">({{ countOf(cat.value) }})</span>
        </button>
      </div>

      <!-- ── Loading ───────────────────────────────────────────── -->
      <div v-if="loading" class="grid grid-cols-2 md:grid-cols-4 gap-5">
        <div v-for="i in 8" :key="i" class="bg-white rounded-2xl overflow-hidden animate-pulse">
          <div class="aspect-video bg-slate-200"></div>
          <div class="p-4 space-y-2">
            <div class="h-4 bg-slate-100 rounded w-3/4"></div>
            <div class="h-3 bg-slate-100 rounded w-full"></div>
            <div class="h-3 bg-slate-100 rounded w-2/3"></div>
          </div>
        </div>
      </div>

      <!-- ── Empty ─────────────────────────────────────────────── -->
      <div v-else-if="filtered.length === 0"
        class="flex flex-col items-center py-20 text-center">
        <div class="w-16 h-16 rounded-2xl bg-primary-light flex items-center justify-center mb-4">
          <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
          </svg>
        </div>
        <p class="text-slate-500 font-semibold">ไม่พบข่าวในหมวดนี้</p>
        <button v-if="activeCategory !== 'all' || searchQ"
          @click="activeCategory='all'; searchQ=''"
          class="mt-3 text-sm text-primary font-bold hover:underline">
          ดูข่าวทั้งหมด
        </button>
      </div>

      <!-- ── News grid ─────────────────────────────────────────── -->
      <div v-else>
        <!-- Pinned news (ถ้ามี — แถวพิเศษ) -->
        <div v-if="page===1 && paginated.some(n=>n.is_pinned)" class="mb-6">
          <p class="text-xs font-bold text-amber-600 uppercase tracking-widest mb-3 flex items-center gap-1.5">
            <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/>
            </svg>
            ข่าวปักหมุด
          </p>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div v-for="n in paginated.filter(x=>x.is_pinned)" :key="'pin-'+n.id"
              @click="router.push(`/news/${n.id}`)"
              class="group flex gap-4 bg-white rounded-2xl border-2 border-amber-200 shadow-sm
                     p-4 cursor-pointer hover:shadow-md hover:-translate-y-0.5 transition-all">
              <img v-if="n.cover_url" :src="n.cover_url"
                class="w-28 h-20 rounded-xl object-cover flex-shrink-0 group-hover:opacity-90"/>
              <div v-else class="w-28 h-20 rounded-xl bg-amber-50 flex items-center justify-center flex-shrink-0">
                <svg class="w-8 h-8 text-amber-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
                </svg>
              </div>
              <div class="flex-1 min-w-0">
                <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', catMeta[n.category]?.bg, catMeta[n.category]?.text]">
                  {{ catMeta[n.category]?.label }}
                </span>
                <p class="font-extrabold text-slate-800 text-sm mt-1.5 line-clamp-2 group-hover:text-primary transition-colors">{{ n.title }}</p>
                <div class="flex items-center gap-3 mt-1">
                  <p class="text-xs text-slate-400">{{ fmtDate(n.published_at) }}</p>
                  <span class="flex items-center gap-0.5 text-xs text-slate-400">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    {{ n.view_count || 0 }} ครั้ง
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- All news grid — 4 columns -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
          <div v-for="n in paginated.filter(x => page!==1 || !x.is_pinned)" :key="n.id"
            @click="router.push(`/news/${n.id}`)"
            class="group bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden
                   cursor-pointer hover:shadow-xl hover:-translate-y-1 transition-all duration-300">

            <!-- Cover image -->
            <div class="relative aspect-video bg-slate-100 overflow-hidden ring-1 ring-inset ring-slate-900/8">
              <img v-if="n.cover_url" :src="n.cover_url"
                class="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-500"/>
              <div v-else class="w-full h-full flex items-center justify-center gradient-primary opacity-80">
                <svg class="w-10 h-10 text-white/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
                </svg>
              </div>
              <!-- Pinned badge -->
              <div v-if="n.is_pinned" class="absolute top-2 left-2">
                <span class="flex items-center gap-1 px-2 py-0.5 bg-amber-400 text-white text-[10px] font-bold rounded-full shadow">
                  <svg class="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24"><path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/></svg>
                  ปักหมุด
                </span>
              </div>
              <!-- Category badge -->
              <div class="absolute bottom-2 left-2">
                <span :class="['text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow-sm',
                  catMeta[n.category]?.bg || 'bg-slate-100', catMeta[n.category]?.text || 'text-slate-600']">
                  {{ catMeta[n.category]?.label || n.category }}
                </span>
              </div>
              <!-- File badge -->
              <div v-if="n.file_url" class="absolute top-2 right-2">
                <span class="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 bg-white/90 text-slate-600 rounded-full shadow-sm">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13"/>
                  </svg>
                  ไฟล์
                </span>
              </div>
            </div>

            <!-- Content -->
            <div class="p-4">
              <p class="font-extrabold text-slate-800 text-sm leading-snug line-clamp-2
                         group-hover:text-primary transition-colors duration-200 mb-2">
                {{ n.title }}
              </p>
              <p v-if="n.excerpt" class="text-xs text-slate-400 line-clamp-2 leading-relaxed mb-3">
                {{ n.excerpt }}
              </p>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2.5">
                  <span class="text-[11px] text-slate-400">{{ fmtDate(n.published_at) }}</span>
                  <span class="flex items-center gap-0.5 text-[11px] text-slate-400">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    {{ n.view_count || 0 }}
                  </span>
                </div>
                <span class="text-[11px] font-bold text-primary flex items-center gap-1
                             opacity-0 group-hover:opacity-100 transition-opacity">
                  อ่านต่อ
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                  </svg>
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Pagination -->
        <div v-if="totalPages > 1" class="flex items-center justify-center gap-2 mt-10">
          <button @click="page--" :disabled="page===1"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200
                   text-slate-500 hover:bg-primary hover:text-white hover:border-primary
                   transition-all disabled:opacity-30">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <button v-for="p in totalPages" :key="p" @click="page=p"
            :class="['w-9 h-9 rounded-xl text-sm font-bold border transition-all',
              page===p ? 'bg-primary text-white border-primary shadow-md' : 'border-slate-200 text-slate-600 hover:border-primary/40']">
            {{ p }}
          </button>
          <button @click="page++" :disabled="page===totalPages"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200
                   text-slate-500 hover:bg-primary hover:text-white hover:border-primary
                   transition-all disabled:opacity-30">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.line-clamp-2 { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
</style>
