<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('media', { icon: 'folder', title: 'คลังสื่อการเรียนรู้' })
const router = useRouter()

const items      = ref([])
const loading    = ref(true)
const totalCount = ref(0)

// ── Filter state ──────────────────────────────────────────────────────────────
const searchQ      = ref('')
const filterType   = ref('all')
const filterSubject = ref('all')
const filterGrade  = ref('all')
const sortBy       = ref('newest')
const currentPage  = ref(1)
const PER_PAGE     = 20

const MEDIA_TYPES = [
  { value:'book',       label:'หนังสือ',      icon:'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25', color:'bg-blue-500' },
  { value:'video',      label:'วิดีโอ',       icon:'M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h1.5C5.496 19.5 6 18.996 6 18.375m-3.75.125v-5.25A2.25 2.25 0 014.5 11.25h15a2.25 2.25 0 012.25 2.25v5.25', color:'bg-red-500' },
  { value:'image',      label:'รูปภาพ',       icon:'M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z', color:'bg-green-500' },
  { value:'audio',      label:'เสียง',        icon:'M9 9l10.5-3m0 6.553v3.75a2.25 2.25 0 01-1.632 2.163l-1.32.377a1.803 1.803 0 11-.99-3.467l2.31-.66a2.25 2.25 0 001.632-2.163zm0 0V2.25L9 5.25v10.303m0 0v3.75a2.25 2.25 0 01-1.632 2.163l-1.320.377a1.803 1.803 0 01-.99-3.467l2.31-.66A2.25 2.25 0 009 15.553z', color:'bg-purple-500' },
  { value:'app',        label:'แอปฯ',         icon:'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z', color:'bg-teal-500' },
  { value:'exam',       label:'ข้อสอบ',       icon:'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z', color:'bg-amber-500' },
  { value:'template',   label:'เทมเพลต',      icon:'M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z', color:'bg-indigo-500' },
  { value:'multimedia', label:'มัลติมีเดีย',  icon:'M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25m18 0A2.25 2.25 0 0018.75 3H5.25A2.25 2.25 0 003 5.25m18 0V12a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 12V5.25', color:'bg-rose-500' },
]

const SUBJECTS = ['ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ','สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ','กิจกรรมพัฒนาผู้เรียน','อื่นๆ/ข้ามสาระ']
const GRADES   = ['ป.1','ป.2','ป.3','ป.4','ป.5','ป.6','ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']

const SORT_OPTIONS = [
  { value:'newest',    label:'ล่าสุด' },
  { value:'popular',   label:'ยอดนิยม' },
  { value:'liked',     label:'ถูกใจมาก' },
  { value:'downloaded',label:'ดาวน์โหลดมาก' },
]

async function loadMedia() {
  loading.value = true
  let query = supabase.from('media').select('id,title,media_type,subject_group,grade_levels,author_name,thumbnail_url,file_id,drive_url,embed_url,external_url,view_count,like_count,download_count,created_at', { count: 'exact' })
    .eq('is_published', true).eq('is_approved', true)

  if (filterType.value !== 'all')    query = query.eq('media_type', filterType.value)
  if (filterSubject.value !== 'all') query = query.eq('subject_group', filterSubject.value)
  if (filterGrade.value !== 'all')   query = query.contains('grade_levels', [filterGrade.value])
  if (searchQ.value.trim())          query = query.ilike('title', `%${searchQ.value.trim()}%`)

  const sortMap = { newest:'created_at', popular:'view_count', liked:'like_count', downloaded:'download_count' }
  query = query.order(sortMap[sortBy.value] || 'created_at', { ascending: false })
  query = query.range((currentPage.value-1)*PER_PAGE, currentPage.value*PER_PAGE-1)

  const { data, count } = await query
  items.value      = data || []
  totalCount.value = count || 0
  loading.value    = false
}

onMounted(async () => { await fetchConfig(); await loadMedia() })

// reset page on filter change
watch([filterType, filterSubject, filterGrade, sortBy], () => { currentPage.value = 1; loadMedia() })

let searchTimer
watch(searchQ, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { currentPage.value = 1; loadMedia() }, 400)
})
watch(currentPage, loadMedia)

const totalPages = computed(() => Math.ceil(totalCount.value / PER_PAGE))

function pageRange() {
  const p = currentPage.value, t = totalPages.value
  const pages = []
  if (t <= 7) { for (let i=1;i<=t;i++) pages.push(i) }
  else {
    pages.push(1)
    if (p > 3) pages.push('...')
    for (let i=Math.max(2,p-1); i<=Math.min(t-1,p+1); i++) pages.push(i)
    if (p < t-2) pages.push('...')
    pages.push(t)
  }
  return pages
}

function typeInfo(type) { return MEDIA_TYPES.find(t=>t.value===type) || { label:type, color:'bg-slate-400', icon:'' } }

function getYoutubeThumbnail(url) {
  const m = url?.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
  return m ? `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg` : null
}

function getThumbnail(item) {
  if (item.thumbnail_url) return item.thumbnail_url
  if (item.embed_url) return getYoutubeThumbnail(item.embed_url)
  return null
}

function getDrivePreviewUrl(fileId) {
  return fileId ? `https://drive.google.com/file/d/${fileId}/preview` : null
}

function getMainUrl(item) {
  return item.drive_url || item.embed_url || item.external_url || null
}

function resetFilter() {
  searchQ.value = ''; filterType.value = 'all'; filterSubject.value = 'all'
  filterGrade.value = 'all'; sortBy.value = 'newest'; currentPage.value = 1
}

const isFiltered = computed(() =>
  searchQ.value.trim() || filterType.value !== 'all' ||
  filterSubject.value !== 'all' || filterGrade.value !== 'all' || sortBy.value !== 'newest'
)
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 min-h-screen">

    <!-- Hero -->
    <PageHero
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name} · ${totalCount.toLocaleString()} รายการ`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      max-width="5xl"/>

    <div class="max-w-7xl mx-auto px-4 py-6 space-y-5">

      <!-- Search (แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ) -->
      <div class="max-w-lg mx-auto relative">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อสื่อ..."
          class="w-full pl-11 pr-4 py-3 rounded-2xl border border-slate-200 dark:border-slate-700
                 bg-white dark:bg-slate-800 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- Type tabs -->
      <div class="flex flex-wrap gap-2 justify-center">
        <button @click="filterType='all'; currentPage=1"
          :class="['flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl border-2 transition-colors',
            filterType==='all' ? 'border-primary bg-primary text-white' : 'border-slate-200 bg-white text-slate-600 hover:border-primary/50']">
          ทั้งหมด
        </button>
        <button v-for="t in MEDIA_TYPES" :key="t.value" @click="filterType=t.value; currentPage=1"
          :class="['flex items-center gap-2 px-3 py-2 text-xs font-bold rounded-xl border-2 transition-colors',
            filterType===t.value ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300']">
          <div :class="['w-5 h-5 rounded-lg flex items-center justify-center flex-shrink-0', t.color]">
            <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="t.icon"/>
            </svg>
          </div>
          {{ t.label }}
        </button>
      </div>

      <!-- Filter row -->
      <div class="flex flex-wrap gap-2 items-center justify-center">
        <select v-model="filterSubject"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option value="all">ทุกกลุ่มสาระ</option>
          <option v-for="s in SUBJECTS" :key="s" :value="s">{{ s }}</option>
        </select>
        <select v-model="filterGrade"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option value="all">ทุกระดับชั้น</option>
          <option v-for="g in GRADES" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="sortBy"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option v-for="s in SORT_OPTIONS" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
        <button v-if="isFiltered" @click="resetFilter"
          class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-red-500 transition-colors px-2 py-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
          ล้าง
        </button>
      </div>

      <!-- Count info -->
      <div class="text-center text-sm text-slate-500">
        แสดง {{ Math.min((currentPage-1)*PER_PAGE+1, totalCount) }}–{{ Math.min(currentPage*PER_PAGE, totalCount) }}
        จาก {{ totalCount.toLocaleString() }} รายการ
      </div>

      <!-- Loading -->
      <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <div v-for="i in 8" :key="i" class="bg-white rounded-2xl border border-slate-100 overflow-hidden animate-pulse">
          <div class="aspect-[4/3] bg-slate-100"/>
          <div class="p-3 space-y-2"><div class="h-3 bg-slate-100 rounded w-3/4"/><div class="h-2.5 bg-slate-100 rounded w-1/2"/></div>
        </div>
      </div>

      <!-- Empty -->
      <div v-else-if="items.length === 0" class="text-center py-16 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 6v.776"/></svg>
        <p class="font-bold">ไม่พบสื่อที่ตรงกัน</p>
        <button @click="resetFilter" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- Cards -->
      <div v-else class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
        <div v-for="item in items" :key="item.id"
          class="group bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm
                 hover:shadow-lg hover:-translate-y-1 transition-all duration-200 overflow-hidden cursor-pointer"
          @click="router.push(`/media/${item.id}`)">

          <!-- Preview -->
          <div class="overflow-hidden bg-slate-100 dark:bg-slate-900 relative" style="aspect-ratio:3/4">

            <!-- 1. thumbnail_url (อัปโหลด/ครอบ) — priority สูงสุด -->
            <img v-if="item.thumbnail_url"
              :src="item.thumbnail_url" :alt="item.title"
              class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              @error="$event.target.style.display='none'"/>

            <!-- 2. YouTube thumbnail (static image, works) -->
            <img v-else-if="getYoutubeThumbnail(item.embed_url)"
              :src="getYoutubeThumbnail(item.embed_url)" :alt="item.title"
              class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"/>

            <!-- 3. Drive iframe (เมื่อไม่มี thumbnail อื่น) -->
            <template v-else-if="item.file_id">
              <div class="absolute inset-0 overflow-hidden">
                <iframe :src="getDrivePreviewUrl(item.file_id)"
                  class="absolute pointer-events-none w-full"
                  style="top:-44px;height:calc(100% + 44px);border:none"
                  sandbox="allow-scripts allow-same-origin" loading="lazy"/>
              </div>
            </template>

            <!-- Fallback: type icon -->
            <div v-else class="absolute inset-0 flex items-center justify-center">
              <div :class="['w-12 h-12 rounded-2xl flex items-center justify-center', typeInfo(item.media_type).color]">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="typeInfo(item.media_type).icon || 'M3.75 9.776c.112-.017.227-.026.344-.026h15.812'"/>
                </svg>
              </div>
            </div>

            <!-- Hover overlay -->
            <div class="absolute inset-0 bg-black/0 group-hover:bg-black/25 transition-colors duration-200 flex items-center justify-center pointer-events-none">
              <span class="opacity-0 group-hover:opacity-100 transition-opacity bg-white/90 rounded-xl px-3 py-1.5 text-xs font-bold text-primary shadow">
                ดูสื่อ
              </span>
            </div>

            <!-- Type badge -->
            <div class="absolute top-2 left-2 z-10">
              <span :class="['text-[10px] font-bold text-white px-2 py-0.5 rounded-full shadow-sm', typeInfo(item.media_type).color]">
                {{ typeInfo(item.media_type).label }}
              </span>
            </div>
          </div>

          <!-- Info -->
          <div class="p-3">
            <p class="font-bold text-slate-800 dark:text-slate-100 text-xs leading-snug line-clamp-2 mb-1">{{ item.title }}</p>
            <p v-if="item.author_name" class="text-[11px] text-slate-400 truncate">
              <svg class="w-3 h-3 inline mr-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"/></svg>
              {{ item.author_name }}
            </p>
            <p v-if="item.subject_group" class="text-[11px] text-slate-400 truncate mt-0.5">{{ item.subject_group }}</p>
            <!-- Stats -->
            <div class="flex items-center gap-3 mt-2 text-[11px] text-slate-400">
              <span class="flex items-center gap-0.5">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                {{ item.view_count.toLocaleString() }}
              </span>
              <span class="flex items-center gap-0.5">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/></svg>
                {{ item.like_count.toLocaleString() }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="totalPages > 1" class="flex items-center justify-center gap-1.5 py-4">
        <button @click="currentPage--" :disabled="currentPage===1"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 dark:border-slate-700 text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
        </button>
        <template v-for="p in pageRange()" :key="p">
          <span v-if="p==='...'" class="w-9 h-9 flex items-center justify-center text-slate-400 text-sm">…</span>
          <button v-else @click="currentPage=p"
            :class="['w-9 h-9 flex items-center justify-center rounded-xl text-sm font-bold transition-colors',
              currentPage===p ? 'bg-primary text-white border border-primary' : 'border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-primary hover:text-white hover:border-primary']">
            {{ p }}
          </button>
        </template>
        <button @click="currentPage++" :disabled="currentPage===totalPages"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 dark:border-slate-700 text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
