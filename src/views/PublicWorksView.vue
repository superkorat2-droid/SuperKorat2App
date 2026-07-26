<script setup>
/**
 * PublicWorksView — หน้าสาธารณะ /works
 *
 * อ่านจาก view works_public (มีแต่ status='approved' และ join ชื่อเจ้าของมาให้แล้ว)
 * โครงเดียวกับ PublicMediaView แต่เน้น "เครดิตเจ้าของผลงาน" ซึ่งเป็นจุดต่างหลัก
 * ของระบบผลงานกับคลังสื่อ — การ์ดจึงโชว์ชื่อ/รูปผู้สร้างชัดเจน
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import { WORK_TYPES, SUBJECT_GROUPS, GRADES, workTypeMeta } from '../composables/useWorks'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('works', { icon: 'star', title: 'ผลงานและนวัตกรรม', align: 'center' })
const router = useRouter()

const items      = ref([])
const loading    = ref(true)
const totalCount = ref(0)

const searchQ       = ref('')
const filterType    = ref('all')
const filterSubject = ref('all')
const filterGrade   = ref('all')
const filterYear    = ref('all')
const sortBy        = ref('newest')
const currentPage   = ref(1)
const PER_PAGE      = 20

const years = ref([])

const SORT_OPTIONS = [
  { value:'newest',  label:'ล่าสุด' },
  { value:'popular', label:'ยอดเข้าชม' },
  { value:'liked',   label:'ถูกใจมาก' },
]

// ปิดจากหน้าตั้งค่าเขตได้ — config โหลดเสร็จก่อนถึงจะตัดสิน (กันจอกระพริบ)
const configReady = ref(false)
const isEnabled = computed(() => config.value?.show_public_works !== false)

async function loadWorks() {
  loading.value = true
  let query = supabase.from('works_public')
    .select('id,work_type,title,description,subject_group,grade_levels,academic_year,cover_url,file_url,view_count,like_count,is_featured,published_at,created_at,school_name,owner_name,owner_position,owner_avatar',
      { count: 'exact' })

  if (filterType.value    !== 'all') query = query.eq('work_type', filterType.value)
  if (filterSubject.value !== 'all') query = query.eq('subject_group', filterSubject.value)
  if (filterGrade.value   !== 'all') query = query.contains('grade_levels', [filterGrade.value])
  if (filterYear.value    !== 'all') query = query.eq('academic_year', filterYear.value)
  if (searchQ.value.trim())          query = query.ilike('title', `%${searchQ.value.trim()}%`)

  const sortMap = { newest:'created_at', popular:'view_count', liked:'like_count' }
  // ผลงานที่ปักหมุดขึ้นก่อนเสมอ
  query = query.order('is_featured', { ascending: false })
               .order(sortMap[sortBy.value] || 'created_at', { ascending: false })
               .range((currentPage.value-1)*PER_PAGE, currentPage.value*PER_PAGE-1)

  const { data, count } = await query
  items.value      = data || []
  totalCount.value = count || 0
  loading.value    = false
}

/** ปีการศึกษาที่มีข้อมูลจริง — ไม่ hardcode เพื่อให้ตัวกรองไม่มีตัวเลือกที่กดแล้วว่าง */
async function loadYears() {
  const { data } = await supabase.from('works_public').select('academic_year').not('academic_year', 'is', null)
  years.value = [...new Set((data || []).map(r => r.academic_year).filter(Boolean))].sort().reverse()
}

onMounted(async () => {
  await fetchConfig()
  configReady.value = true
  if (!isEnabled.value) { loading.value = false; return }
  await Promise.all([loadWorks(), loadYears()])
})

watch([filterType, filterSubject, filterGrade, filterYear, sortBy], () => { currentPage.value = 1; loadWorks() })

let searchTimer
watch(searchQ, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { currentPage.value = 1; loadWorks() }, 400)
})
watch(currentPage, loadWorks)

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

function resetFilter() {
  searchQ.value = ''; filterType.value = 'all'; filterSubject.value = 'all'
  filterGrade.value = 'all'; filterYear.value = 'all'; sortBy.value = 'newest'; currentPage.value = 1
}

const isFiltered = computed(() =>
  searchQ.value.trim() || filterType.value !== 'all' || filterSubject.value !== 'all' ||
  filterGrade.value !== 'all' || filterYear.value !== 'all' || sortBy.value !== 'newest'
)
</script>

<template>
  <div class="font-sarabun min-h-screen">

    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name} · ${totalCount.toLocaleString()} ผลงาน`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="5xl"/>

    <!-- ปิดการแสดงผลงานสาธารณะจากหน้าตั้งค่าเขต -->
    <div v-if="configReady && !isEnabled" class="max-w-lg mx-auto px-4 py-24 text-center">
      <p class="text-4xl mb-3">🔒</p>
      <p class="font-bold text-slate-700">ยังไม่เปิดให้ดูผลงานสาธารณะ</p>
      <p class="text-sm text-slate-500 mt-1">ผู้ดูแลระบบสามารถเปิดได้ที่ ตั้งค่าเขต → แสดงผลงานสาธารณะ</p>
      <button @click="router.push('/')" class="mt-5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        กลับหน้าแรก
      </button>
    </div>

    <div v-else class="max-w-7xl mx-auto px-4 py-6 space-y-5">

      <!-- ค้นหา -->
      <div class="max-w-lg mx-auto relative">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อผลงาน..."
          class="w-full pl-11 pr-4 py-3 rounded-2xl border border-slate-200
                 bg-white/70 backdrop-blur text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- แท็บประเภท -->
      <div class="flex flex-wrap gap-2 justify-center">
        <button @click="filterType='all'; currentPage=1"
          :class="['px-3 py-2 text-xs font-bold rounded-xl border-2 transition-colors',
            filterType==='all' ? 'border-primary bg-primary text-white' : 'border-white/80 bg-white/70 backdrop-blur text-slate-600 hover:border-primary/50']">
          ทั้งหมด
        </button>
        <button v-for="t in WORK_TYPES" :key="t.value" @click="filterType=t.value; currentPage=1"
          :class="['flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl border-2 transition-colors',
            filterType===t.value ? 'border-primary bg-primary/10 text-primary' : 'border-white/80 bg-white/70 backdrop-blur text-slate-600 hover:border-slate-300']">
          <span>{{ t.icon }}</span> {{ t.label }}
        </button>
      </div>

      <!-- ตัวกรอง -->
      <div class="flex flex-wrap gap-2 items-center justify-center">
        <select v-model="filterSubject"
          class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกกลุ่มสาระ</option>
          <option v-for="s in SUBJECT_GROUPS" :key="s" :value="s">{{ s }}</option>
        </select>
        <select v-model="filterGrade"
          class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกระดับชั้น</option>
          <option v-for="g in GRADES" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-if="years.length" v-model="filterYear"
          class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option value="all">ทุกปีการศึกษา</option>
          <option v-for="y in years" :key="y" :value="y">ปี {{ y }}</option>
        </select>
        <select v-model="sortBy"
          class="px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
          <option v-for="s in SORT_OPTIONS" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
        <button v-if="isFiltered" @click="resetFilter"
          class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-red-500 transition-colors px-2 py-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
          ล้าง
        </button>
      </div>

      <div v-if="totalCount" class="text-center text-sm text-slate-500">
        แสดง {{ Math.min((currentPage-1)*PER_PAGE+1, totalCount) }}–{{ Math.min(currentPage*PER_PAGE, totalCount) }}
        จาก {{ totalCount.toLocaleString() }} ผลงาน
      </div>

      <!-- Loading -->
      <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <div v-for="i in 8" :key="i" class="glass-card overflow-hidden animate-pulse">
          <div class="aspect-[4/3] bg-slate-100"/>
          <div class="p-3 space-y-2"><div class="h-3 bg-slate-100 rounded w-3/4"/><div class="h-2.5 bg-slate-100 rounded w-1/2"/></div>
        </div>
      </div>

      <!-- ว่าง -->
      <div v-else-if="items.length === 0" class="text-center py-16 text-slate-400">
        <p class="text-4xl mb-3 opacity-40">🏆</p>
        <p class="font-bold">{{ isFiltered ? 'ไม่พบผลงานที่ตรงกัน' : 'ยังไม่มีผลงานเผยแพร่' }}</p>
        <button v-if="isFiltered" @click="resetFilter" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- การ์ด -->
      <div v-else class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <div v-for="item in items" :key="item.id"
          class="group glass-tile hover:shadow-lg hover:-translate-y-1 transition-all duration-200 overflow-hidden cursor-pointer flex flex-col"
          @click="router.push(`/works/${item.id}`)">

          <!-- ปก -->
          <div class="overflow-hidden bg-slate-100 relative aspect-[4/3]">
            <img v-if="item.cover_url" :src="item.cover_url" :alt="item.title"
              class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              loading="lazy" @error="$event.target.style.display='none'"/>
            <div v-else class="absolute inset-0 flex items-center justify-center text-4xl opacity-60">
              {{ workTypeMeta(item.work_type).icon }}
            </div>

            <div class="absolute inset-0 bg-black/0 group-hover:bg-black/25 transition-colors duration-200 flex items-center justify-center pointer-events-none">
              <span class="opacity-0 group-hover:opacity-100 transition-opacity bg-white/90 rounded-xl px-3 py-1.5 text-xs font-bold text-primary shadow">
                ดูผลงาน
              </span>
            </div>

            <span :class="['absolute top-2 left-2 z-10 text-[10px] font-bold px-2 py-0.5 rounded-full shadow-sm',
              workTypeMeta(item.work_type).bg, workTypeMeta(item.work_type).text]">
              {{ workTypeMeta(item.work_type).label }}
            </span>
            <span v-if="item.is_featured"
              class="absolute top-2 right-2 z-10 text-[10px] font-bold text-white bg-amber-500 px-2 py-0.5 rounded-full shadow-sm">
              ⭐ แนะนำ
            </span>
          </div>

          <!-- ข้อมูล -->
          <div class="p-3 flex-1 flex flex-col">
            <p class="font-bold text-slate-800 text-xs leading-snug line-clamp-2 mb-1.5">{{ item.title }}</p>

            <!-- เครดิตเจ้าของ — จุดต่างหลักจากคลังสื่อ -->
            <div class="flex items-center gap-1.5 mb-1">
              <img v-if="item.owner_avatar" :src="item.owner_avatar" :alt="item.owner_name"
                class="w-5 h-5 rounded-full object-cover flex-shrink-0" loading="lazy"/>
              <div v-else class="w-5 h-5 rounded-full bg-primary/15 flex items-center justify-center flex-shrink-0">
                <svg class="w-3 h-3 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"/></svg>
              </div>
              <p class="text-[11px] text-slate-500 truncate">{{ item.owner_name || item.school_name || '—' }}</p>
            </div>
            <p v-if="item.subject_group" class="text-[11px] text-slate-400 truncate">{{ item.subject_group }}</p>

            <div class="flex items-center gap-3 mt-2 pt-2 border-t border-slate-100 text-[11px] text-slate-400">
              <span class="flex items-center gap-0.5">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                {{ (item.view_count || 0).toLocaleString() }}
              </span>
              <span class="flex items-center gap-0.5">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/></svg>
                {{ (item.like_count || 0).toLocaleString() }}
              </span>
              <span v-if="item.academic_year" class="ml-auto">ปี {{ item.academic_year }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- แบ่งหน้า -->
      <div v-if="totalPages > 1" class="flex items-center justify-center gap-1.5 py-4">
        <button @click="currentPage--" :disabled="currentPage===1"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
        </button>
        <template v-for="p in pageRange()" :key="p">
          <span v-if="p==='...'" class="w-9 h-9 flex items-center justify-center text-slate-400 text-sm">…</span>
          <button v-else @click="currentPage=p"
            :class="['w-9 h-9 flex items-center justify-center rounded-xl text-sm font-bold transition-colors',
              currentPage===p ? 'bg-primary text-white border border-primary' : 'border border-slate-200 text-slate-600 hover:bg-primary hover:text-white hover:border-primary']">
            {{ p }}
          </button>
        </template>
        <button @click="currentPage++" :disabled="currentPage===totalPages"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-colors disabled:opacity-40 disabled:cursor-not-allowed">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
