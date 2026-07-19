<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { fetchConfig } = useAreaConfig()
const header = usePageHeader('schoolWebsites', {
  icon: 'globe', title: 'เว็บไซต์โรงเรียนในสังกัด', subtitle: 'ค้นหาและเข้าสู่เว็บไซต์ของโรงเรียนแต่ละแห่ง',
  align: 'center',
})

const schools = ref([])
const loading = ref(true)
const searchQ = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')
const sortKey = ref('school_group')   // 'name' | 'school_group'
const sortDir = ref('asc')            // 'asc' | 'desc'

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100, 'all']
const pageSize    = ref(20)
const currentPage = ref(1)

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase.rpc('get_schools_public')
  schools.value = data || []
  loading.value = false
})

const districts = computed(() => [...new Set(schools.value.map(s => s.district))].sort((a, b) => a.localeCompare(b, 'th')))
const groups    = computed(() => {
  const src = filterDistrict.value === 'all'
    ? schools.value
    : schools.value.filter(s => s.district === filterDistrict.value)
  return [...new Set(src.map(s => s.school_group))].sort((a, b) => a.localeCompare(b, 'th'))
})

// ค้นหาแบบแยกคำ ไม่สนใจลำดับ (พิมพ์ "จักราช บ้าน" ต้องเจอแม้ชื่อจะเรียงคำสลับกัน)
function matchesSearch(s, terms) {
  const haystack = `${s.name} ${s.school_group}`.toLowerCase()
  return terms.every(t => haystack.includes(t))
}

const filtered = computed(() => {
  let list = schools.value
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(s => s.school_group === filterGroup.value)
  const terms = searchQ.value.trim().toLowerCase().split(/\s+/).filter(Boolean)
  if (terms.length) list = list.filter(s => matchesSearch(s, terms))
  return list
})

const sorted = computed(() => {
  const list = [...filtered.value]
  list.sort((a, b) => {
    const av = (a[sortKey.value] || '').toString()
    const bv = (b[sortKey.value] || '').toString()
    const cmp = av.localeCompare(bv, 'th')
    return sortDir.value === 'asc' ? cmp : -cmp
  })
  return list
})

function toggleSort(key) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = 'asc'
  }
}

// ─── Pagination ───────────────────────────────────────────────────────────
const totalPages = computed(() => pageSize.value === 'all' ? 1 : Math.max(1, Math.ceil(sorted.value.length / pageSize.value)))

const paginated = computed(() => {
  if (pageSize.value === 'all') return sorted.value
  const start = (currentPage.value - 1) * pageSize.value
  return sorted.value.slice(start, start + pageSize.value)
})

const rangeStart = computed(() => sorted.value.length === 0 ? 0 : pageSize.value === 'all' ? 1 : (currentPage.value - 1) * pageSize.value + 1)
const rangeEnd   = computed(() => pageSize.value === 'all' ? sorted.value.length : Math.min(currentPage.value * pageSize.value, sorted.value.length))

// หน้าตัวเลข แบบมี ... เมื่อหน้าเยอะ (แสดงหน้าแรก/สุดท้ายเสมอ + รอบๆ หน้าปัจจุบัน)
const pageNumbers = computed(() => {
  const tp = totalPages.value, cur = currentPage.value, delta = 1
  const withDots = []
  let last = 0
  for (let i = 1; i <= tp; i++) {
    if (i === 1 || i === tp || (i >= cur - delta && i <= cur + delta)) {
      if (last && i - last === 2) withDots.push(last + 1)
      else if (last && i - last > 2) withDots.push('...')
      withDots.push(i)
      last = i
    }
  }
  return withDots
})

function goToPage(p) { if (p >= 1 && p <= totalPages.value) currentPage.value = p }

watch([searchQ, filterDistrict, filterGroup, pageSize, sortKey, sortDir], () => { currentPage.value = 1 })
watch(totalPages, tp => { if (currentPage.value > tp) currentPage.value = tp })

const stats = computed(() => ({
  total: filtered.value.length,
  withWebsite: filtered.value.filter(s => s.website_url).length,
}))

const hasActiveFilter = computed(() => !!searchQ.value || filterDistrict.value !== 'all' || filterGroup.value !== 'all')
function resetFilters() {
  searchQ.value = ''; filterDistrict.value = 'all'; filterGroup.value = 'all'
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 dark:text-slate-100 min-h-screen transition-colors duration-300">

    <PageHero v-if="!header.hidden" :title="header.title" :subtitle="header.subtitle"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align"/>

    <div class="max-w-5xl mx-auto px-4 py-6 space-y-5">

      <!-- ── Search ── -->
      <div class="relative max-w-lg mx-auto">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
          fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน หรือศูนย์เครือข่าย..."
          class="w-full pl-11 pr-4 py-3 rounded-2xl border border-slate-200 dark:border-slate-700
                 bg-white dark:bg-slate-800 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- ── Stats ── -->
      <div class="grid grid-cols-2 gap-3 max-w-md mx-auto">
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-primary transition-all duration-300">{{ stats.total }}</p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">โรงเรียน</p>
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-emerald-600 transition-all duration-300">{{ stats.withWebsite }}</p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">มีเว็บไซต์</p>
        </div>
      </div>

      <!-- ── Filters ── -->
      <div class="flex flex-wrap items-center justify-center gap-2">
        <select v-model="filterDistrict" @change="filterGroup = 'all'"
          class="px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-xl text-sm focus:outline-none focus:border-primary bg-white dark:bg-slate-800">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="filterGroup"
          class="px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-xl text-sm focus:outline-none focus:border-primary bg-white dark:bg-slate-800">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="pageSize"
          class="px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-xl text-sm focus:outline-none focus:border-primary bg-white dark:bg-slate-800">
          <option v-for="n in PAGE_SIZE_OPTIONS" :key="n" :value="n">{{ n === 'all' ? 'แสดงทั้งหมด' : `แสดง ${n} รายการ` }}</option>
        </select>
        <button v-if="hasActiveFilter" @click="resetFilters"
          class="flex items-center gap-1 text-xs text-slate-400 hover:text-red-500 px-2 py-2 transition-colors">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          ล้าง
        </button>
      </div>

      <!-- ── Loading skeleton ── -->
      <div v-if="loading" class="space-y-2">
        <div v-for="i in 8" :key="i" class="h-14 bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 animate-pulse"></div>
      </div>

      <!-- ── Empty ── -->
      <div v-else-if="sorted.length === 0" class="text-center py-20 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <p class="text-lg font-bold">ไม่พบโรงเรียน</p>
        <button @click="resetFilters" class="mt-3 text-sm text-primary font-bold hover:underline">ล้างตัวกรอง</button>
      </div>

      <template v-else>
        <!-- ── Desktop/tablet table ── -->
        <div class="hidden md:block bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-900/30">
                <th class="text-left px-5 py-3 cursor-pointer select-none hover:text-primary transition-colors" @click="toggleSort('school_group')">
                  <span class="inline-flex items-center gap-1">
                    ศูนย์เครือข่าย
                    <svg v-if="sortKey === 'school_group'" class="w-3 h-3 transition-transform" :class="{ 'rotate-180': sortDir === 'desc' }"
                      fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                    </svg>
                  </span>
                </th>
                <th class="text-left px-5 py-3 cursor-pointer select-none hover:text-primary transition-colors" @click="toggleSort('name')">
                  <span class="inline-flex items-center gap-1">
                    ชื่อโรงเรียน
                    <svg v-if="sortKey === 'name'" class="w-3 h-3 transition-transform" :class="{ 'rotate-180': sortDir === 'desc' }"
                      fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                    </svg>
                  </span>
                </th>
                <th class="text-center px-5 py-3">เว็บไซต์</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(s, i) in paginated" :key="s.id"
                :class="['border-b border-slate-50 dark:border-slate-700/50 last:border-0 hover:bg-primary/5 dark:hover:bg-primary/10 transition-colors',
                  i % 2 === 1 ? 'bg-slate-50/70 dark:bg-slate-900/20' : '']">
                <td class="px-5 py-3 text-slate-500 dark:text-slate-400">{{ s.school_group }}</td>
                <td class="px-5 py-3 font-bold text-slate-800 dark:text-slate-100">{{ s.name }}</td>
                <td class="px-5 py-3 text-center">
                  <a v-if="s.website_url" :href="s.website_url" target="_blank" rel="noopener noreferrer"
                    class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-primary/10 text-primary text-xs font-bold hover:bg-primary/20 transition-colors">
                    <SvgIcon name="globe" class="w-3.5 h-3.5"/> เยี่ยมชมเว็บไซต์
                  </a>
                  <span v-else class="inline-flex items-center px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-400 text-xs font-bold">
                    ยังไม่มีเว็บไซต์
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- ── Mobile card list ── -->
        <div class="md:hidden space-y-3">
          <div v-for="(s, i) in paginated" :key="s.id"
            :class="['rounded-2xl border border-slate-100 dark:border-slate-700 p-4 shadow-sm',
              i % 2 === 1 ? 'bg-slate-50 dark:bg-slate-900/30' : 'bg-white dark:bg-slate-800']">
            <p class="text-[11px] text-slate-400 font-semibold uppercase tracking-wide">{{ s.school_group }}</p>
            <p class="font-extrabold text-slate-800 dark:text-slate-100 mt-0.5 mb-3">{{ s.name }}</p>
            <a v-if="s.website_url" :href="s.website_url" target="_blank" rel="noopener noreferrer"
              class="flex items-center justify-center gap-1.5 w-full py-2.5 rounded-xl bg-primary/10 text-primary text-sm font-bold hover:bg-primary/20 transition-colors">
              <SvgIcon name="globe" class="w-4 h-4"/> เยี่ยมชมเว็บไซต์
            </a>
            <span v-else class="flex items-center justify-center w-full py-2.5 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-400 text-sm font-bold">
              ยังไม่มีเว็บไซต์
            </span>
          </div>
        </div>

        <!-- ── Pagination ── -->
        <div v-if="pageSize !== 'all' && totalPages > 1" class="flex flex-col sm:flex-row items-center justify-between gap-3 pt-1">
          <p class="text-xs text-slate-400 order-2 sm:order-1">
            แสดง {{ rangeStart }}-{{ rangeEnd }} จาก {{ sorted.length }} รายการ
          </p>
          <div class="flex items-center gap-1 order-1 sm:order-2">
            <button @click="goToPage(currentPage - 1)" :disabled="currentPage === 1"
              class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 dark:border-slate-600 text-slate-500 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
              </svg>
            </button>
            <template v-for="(p, idx) in pageNumbers" :key="idx">
              <span v-if="p === '...'" class="w-9 h-9 flex items-center justify-center text-slate-300 text-sm">…</span>
              <button v-else @click="goToPage(p)"
                :class="['w-9 h-9 flex items-center justify-center rounded-xl text-sm font-bold transition-colors',
                  p === currentPage ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-700']">
                {{ p }}
              </button>
            </template>
            <button @click="goToPage(currentPage + 1)" :disabled="currentPage === totalPages"
              class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 dark:border-slate-600 text-slate-500 disabled:opacity-30 disabled:cursor-not-allowed hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
              </svg>
            </button>
          </div>
        </div>
        <p v-else class="text-center text-xs text-slate-400">แสดงทั้งหมด {{ sorted.length }} รายการ</p>
      </template>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
