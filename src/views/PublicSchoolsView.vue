<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('schools', { icon: 'school', align: 'center' })
const schools  = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')
const filterWebsite  = ref(false)
const filterGps      = ref(false)

// ─── Detail modal ─────────────────────────────────────────────────────────────
const modalSchool    = ref(null)
const modalTab       = ref('info')
const modalPrincipals = ref([])
const loadingPrincipals = ref(false)

async function openModal(s) {
  modalSchool.value = s
  modalTab.value    = 'info'
  modalPrincipals.value = []
  loadingPrincipals.value = true
  const { data } = await supabase
    .from('school_principals').select('*')
    .eq('school_id', s.id).order('sort_order')
  modalPrincipals.value = data || []
  loadingPrincipals.value = false
}
function closeModal() { modalSchool.value = null }

// ─── Google Maps navigation ───────────────────────────────────────────────────
function navigateTo(s) {
  if (!s.lat || !s.lng) return
  window.open(
    `https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}&travelmode=driving`,
    '_blank', 'noopener'
  )
}

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase.rpc('get_schools_public')
  schools.value = data || []
  loading.value = false
})

// ─── Filter options ───────────────────────────────────────────────────────────
const districts = computed(() => [...new Set(schools.value.map(s => s.district))].sort())
const groups    = computed(() => {
  const src = filterDistrict.value === 'all'
    ? schools.value
    : schools.value.filter(s => s.district === filterDistrict.value)
  return [...new Set(src.map(s => s.school_group))].sort()
})

// ─── Filtered list ────────────────────────────────────────────────────────────
const filtered = computed(() => {
  let list = schools.value
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(s => s.school_group === filterGroup.value)
  if (filterWebsite.value)            list = list.filter(s => s.website_url)
  if (filterGps.value)                list = list.filter(s => s.lat && s.lng)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(s =>
      s.name.toLowerCase().includes(q) || (s.dmc_code || '').includes(q) || (s.school_code || '').includes(q)
    )
  }
  return list
})

// ─── Realtime stats ───────────────────────────────────────────────────────────
const stats = computed(() => {
  const list = filtered.value
  const withWebsite = list.filter(s => s.website_url).length
  const withGps     = list.filter(s => s.lat && s.lng).length
  const dists       = list.filter(s => s.distance_km > 0).map(s => Number(s.distance_km))
  const avgDist     = dists.length ? (dists.reduce((a, b) => a + b, 0) / dists.length).toFixed(1) : null
  return { total: list.length, withWebsite, withGps, avgDist }
})

function resetFilters() {
  searchQ.value = ''; filterDistrict.value = 'all'; filterGroup.value = 'all'
  filterWebsite.value = false; filterGps.value = false
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 dark:text-slate-100 min-h-screen transition-colors duration-300">

    <!-- ── Hero ── -->
    <PageHero v-if="!header.hidden"
      :title="header.title || config?.schools_page_title || 'ทำเนียบสถานศึกษา'"
      :subtitle="header.subtitle || `${config?.schools_page_subtitle || config?.area_name || 'สพป.'} · ${schools.length} โรงเรียน`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align"/>

    <div class="max-w-7xl mx-auto px-4 py-6 space-y-5">

      <!-- ── Search (แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ) ── -->
      <div class="relative max-w-lg mx-auto">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
          fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน รหัส DMC ..."
          class="w-full pl-11 pr-4 py-3 rounded-2xl border border-slate-200 dark:border-slate-700
                 bg-white dark:bg-slate-800 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <!-- ── Realtime stats ──────────────────────────────────────── -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-primary transition-all duration-300">{{ stats.total }}</p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">โรงเรียน</p>
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-emerald-600 transition-all duration-300">{{ stats.withWebsite }}</p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">มีเว็บไซต์</p>
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-blue-600 transition-all duration-300">{{ stats.withGps }}</p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">มีพิกัด GPS</p>
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 p-4 text-center shadow-sm">
          <p class="text-2xl font-extrabold text-amber-600 transition-all duration-300">
            {{ stats.avgDist ?? '—' }}<span v-if="stats.avgDist" class="text-sm font-normal ml-0.5">กม.</span>
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">ระยะทางเฉลี่ย</p>
        </div>
      </div>

      <!-- ── Filters ─────────────────────────────────────────────── -->
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="filterDistrict" @change="filterGroup='all'"
          class="px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-xl text-sm focus:outline-none focus:border-primary bg-white dark:bg-slate-800">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="filterGroup"
          class="px-3 py-2 border border-slate-200 dark:border-slate-600 rounded-xl text-sm focus:outline-none focus:border-primary bg-white dark:bg-slate-800">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
        </select>
        <button @click="filterWebsite = !filterWebsite"
          :class="['flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border-2 transition-all',
            filterWebsite ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 bg-white dark:bg-slate-800']">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3"/>
          </svg>
          มีเว็บไซต์
        </button>
        <button @click="filterGps = !filterGps"
          :class="['flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border-2 transition-all',
            filterGps ? 'border-blue-500 bg-blue-50 text-blue-700' : 'border-slate-200 text-slate-500 bg-white dark:bg-slate-800']">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"/>
          </svg>
          มี GPS
        </button>
        <button v-if="searchQ || filterDistrict!=='all' || filterGroup!=='all' || filterWebsite || filterGps"
          @click="resetFilters"
          class="flex items-center gap-1 text-xs text-slate-400 hover:text-red-500 px-2 py-2 transition-colors">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          ล้าง
        </button>
      </div>

      <!-- ── Loading skeleton ───────────────────────────────────── -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <div v-for="i in 8" :key="i" class="bg-white rounded-2xl border border-slate-100 p-4 animate-pulse">
          <div class="h-4 bg-slate-100 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-slate-100 rounded w-1/2 mb-3"></div>
          <div class="h-3 bg-slate-100 rounded w-full mb-2"></div>
          <div class="h-8 bg-slate-100 rounded w-full mt-3"></div>
        </div>
      </div>

      <!-- ── Empty ──────────────────────────────────────────────── -->
      <div v-else-if="filtered.length === 0" class="text-center py-20 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75"/>
        </svg>
        <p class="text-lg font-bold">ไม่พบโรงเรียน</p>
        <button @click="resetFilters" class="mt-3 text-sm text-primary font-bold hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- ── Cards ──────────────────────────────────────────────── -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <div v-for="s in filtered" :key="s.id"
          class="group bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm
                 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 flex flex-col">

          <!-- Card body -->
          <div class="p-4 flex-1">
            <div class="flex items-start gap-3 mb-3">
              <div class="w-9 h-9 rounded-xl bg-primary-light flex items-center justify-center flex-shrink-0 group-hover:bg-primary/20 transition-colors">
                <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                </svg>
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-extrabold text-slate-800 dark:text-slate-100 text-sm leading-snug line-clamp-2">{{ s.name }}</p>
                <p class="text-[11px] text-slate-400 mt-0.5 font-mono">{{ s.dmc_code }}</p>
              </div>
            </div>

            <div class="space-y-1.5 text-xs text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"/>
                </svg>
                {{ s.subdistrict }} · อ.{{ s.district }}
              </div>
              <div class="flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"/>
                </svg>
                <span class="truncate">{{ s.school_group }}</span>
              </div>
              <div v-if="s.distance_km" class="flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"/>
                </svg>
                ห่าง สพป. {{ s.distance_km }} กม.
              </div>
            </div>
          </div>

          <!-- Card actions -->
          <div class="px-4 pb-4 pt-2 border-t border-slate-50 dark:border-slate-700 flex gap-2">
            <!-- นำทาง -->
            <button @click="navigateTo(s)"
              :disabled="!s.lat || !s.lng"
              :title="s.lat && s.lng ? 'เปิด Google Maps นำทาง' : 'ไม่มีพิกัด GPS'"
              :class="['flex items-center justify-center gap-1.5 flex-1 py-2 rounded-xl text-xs font-bold transition-all',
                s.lat && s.lng
                  ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-400'
                  : 'bg-slate-50 text-slate-300 cursor-not-allowed dark:bg-slate-700 dark:text-slate-500']">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z"/>
              </svg>
              นำทาง
            </button>
            <!-- รายละเอียด -->
            <button @click="openModal(s)"
              class="flex items-center justify-center gap-1.5 flex-1 py-2 rounded-xl text-xs font-bold bg-primary/10 text-primary hover:bg-primary/20 dark:bg-primary/20 dark:hover:bg-primary/30 transition-all">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"/>
              </svg>
              รายละเอียด
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- ── Detail Modal ─────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-250 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0">
      <div v-if="modalSchool"
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-0 sm:p-4 font-sarabun"
        @click.self="closeModal">

        <Transition
          enter-active-class="transition duration-250 ease-out"
          enter-from-class="translate-y-full sm:translate-y-4 sm:opacity-0 sm:scale-95"
          enter-to-class="translate-y-0 sm:opacity-100 sm:scale-100"
          leave-active-class="transition duration-200"
          leave-from-class="translate-y-0 sm:opacity-100"
          leave-to-class="translate-y-full sm:opacity-0">
          <div class="bg-white dark:bg-slate-800 rounded-t-3xl sm:rounded-2xl shadow-2xl w-full sm:max-w-lg max-h-[92dvh] overflow-y-auto">

            <!-- Handle (mobile) -->
            <div class="flex justify-center pt-3 pb-1 sm:hidden">
              <div class="w-10 h-1 bg-slate-200 rounded-full"/>
            </div>

            <!-- Modal header -->
            <div class="sticky top-0 bg-white dark:bg-slate-800 px-5 py-4 border-b border-slate-100 dark:border-slate-700 flex items-start justify-between z-10">
              <div class="flex items-start gap-3 flex-1 min-w-0">
                <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                  </svg>
                </div>
                <div>
                  <h2 class="font-extrabold text-slate-800 dark:text-slate-100 leading-snug">{{ modalSchool.name }}</h2>
                  <p class="text-xs text-slate-400 font-mono mt-0.5">{{ modalSchool.dmc_code }}</p>
                </div>
              </div>
              <button @click="closeModal"
                class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-400 transition-colors flex-shrink-0 ml-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modal tabs -->
            <div class="px-5 pt-3 flex gap-1 bg-white dark:bg-slate-800">
              <button @click="modalTab='info'"
                :class="['px-4 py-2 text-sm font-bold rounded-xl transition-colors',
                  modalTab==='info' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-100']">
                ข้อมูลทั่วไป
              </button>
              <button @click="modalTab='principals'"
                :class="['flex items-center gap-1.5 px-4 py-2 text-sm font-bold rounded-xl transition-colors',
                  modalTab==='principals' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-100']">
                ผู้บริหาร
                <span class="text-xs bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded-full">{{ modalPrincipals.length }}</span>
              </button>
            </div>

            <!-- Principals tab -->
            <div v-if="modalTab === 'principals'" class="px-5 py-5">
              <div v-if="loadingPrincipals" class="flex justify-center py-8">
                <div class="w-6 h-6 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
              </div>
              <div v-else-if="modalPrincipals.length === 0" class="text-center py-8 text-slate-400">
                <p class="text-sm">ยังไม่มีข้อมูลผู้บริหาร</p>
              </div>
              <div v-else class="space-y-3">
                <div v-for="p in modalPrincipals" :key="p.id"
                  class="flex items-center gap-4 p-3 bg-slate-50 dark:bg-slate-700/50 rounded-2xl">
                  <!-- Photo -->
                  <div class="w-12 h-12 rounded-full overflow-hidden bg-primary/10 flex items-center justify-center flex-shrink-0 shadow-sm">
                    <img v-if="p.photo_url" :src="p.photo_url" :alt="p.name" class="w-full h-full object-cover"/>
                    <span v-else class="text-sm font-bold text-primary">
                      {{ p.name?.split(' ').map(n=>n[0]).join('').slice(0,2).toUpperCase() }}
                    </span>
                  </div>
                  <!-- Info -->
                  <div class="flex-1 min-w-0">
                    <p class="font-bold text-slate-800 dark:text-slate-100">{{ p.name }}</p>
                    <span class="text-xs bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">{{ p.position }}</span>
                    <div class="flex flex-wrap gap-x-3 mt-1.5 text-xs text-slate-500 dark:text-slate-400">
                      <a v-if="p.phone && p.visibility?.phone" :href="`tel:${p.phone}`"
                        class="flex items-center gap-1 hover:text-primary transition-colors">
                        📞 {{ p.phone }}
                      </a>
                      <a v-if="p.email && p.visibility?.email" :href="`mailto:${p.email}`"
                        class="flex items-center gap-1 hover:text-primary transition-colors">
                        ✉️ {{ p.email }}
                      </a>
                      <span v-if="p.line_id && p.visibility?.line" class="flex items-center gap-1">
                        💚 {{ p.line_id }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Info tab -->
            <div v-if="modalTab === 'info'" class="px-5 py-5 space-y-4">

              <!-- Location info -->
              <div class="bg-slate-50 dark:bg-slate-700/50 rounded-2xl p-4 space-y-2.5">
                <p class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">ที่ตั้ง</p>
                <div class="grid grid-cols-2 gap-2 text-sm">
                  <div>
                    <p class="text-[10px] text-slate-400 uppercase tracking-wide">ตำบล</p>
                    <p class="font-semibold text-slate-700 dark:text-slate-200">{{ modalSchool.subdistrict || '—' }}</p>
                  </div>
                  <div>
                    <p class="text-[10px] text-slate-400 uppercase tracking-wide">อำเภอ</p>
                    <p class="font-semibold text-slate-700 dark:text-slate-200">{{ modalSchool.district || '—' }}</p>
                  </div>
                  <div class="col-span-2">
                    <p class="text-[10px] text-slate-400 uppercase tracking-wide">ศูนย์เครือข่าย</p>
                    <p class="font-semibold text-slate-700 dark:text-slate-200">{{ modalSchool.school_group || '—' }}</p>
                  </div>
                  <div v-if="modalSchool.distance_km" class="col-span-2">
                    <p class="text-[10px] text-slate-400 uppercase tracking-wide">ระยะทางจาก สพป.</p>
                    <p class="font-semibold text-slate-700 dark:text-slate-200">{{ modalSchool.distance_km }} กิโลเมตร</p>
                  </div>
                </div>
              </div>

              <!-- Contact info -->
              <div class="bg-slate-50 dark:bg-slate-700/50 rounded-2xl p-4 space-y-2.5">
                <p class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">ข้อมูลติดต่อ</p>
                <div class="space-y-2 text-sm">
                  <div v-if="modalSchool.school_code" class="flex items-center gap-2">
                    <span class="text-xs text-slate-400 w-28 flex-shrink-0">รหัสสถานศึกษา</span>
                    <span class="font-mono font-semibold text-slate-700 dark:text-slate-200">{{ modalSchool.school_code }}</span>
                  </div>
                  <div v-if="modalSchool.email" class="flex items-center gap-2">
                    <span class="text-xs text-slate-400 w-28 flex-shrink-0">อีเมล</span>
                    <a :href="`mailto:${modalSchool.email}`"
                      class="font-semibold text-primary hover:underline truncate">{{ modalSchool.email }}</a>
                  </div>
                  <div v-if="modalSchool.website_url" class="flex items-center gap-2">
                    <span class="text-xs text-slate-400 w-28 flex-shrink-0">เว็บไซต์</span>
                    <a :href="modalSchool.website_url" target="_blank" rel="noopener"
                      class="font-semibold text-primary hover:underline truncate">
                      {{ modalSchool.website_url.replace(/^https?:\/\//, '') }}
                    </a>
                  </div>
                </div>
              </div>

              <!-- GPS -->
              <div v-if="modalSchool.lat && modalSchool.lng" class="bg-emerald-50 dark:bg-emerald-900/30 rounded-2xl p-4">
                <div class="flex items-center justify-between mb-2">
                  <p class="text-xs font-bold text-emerald-700 dark:text-emerald-400 uppercase tracking-wider">พิกัด GPS</p>
                  <span class="text-xs font-mono text-emerald-600 dark:text-emerald-400">
                    {{ modalSchool.lat?.toFixed(6) }}, {{ modalSchool.lng?.toFixed(6) }}
                  </span>
                </div>
                <!-- Maps preview image -->
                <div class="rounded-xl overflow-hidden border border-emerald-200 dark:border-emerald-700 h-36 bg-emerald-100">
                  <img
                    :src="`https://maps.googleapis.com/maps/api/staticmap?center=${modalSchool.lat},${modalSchool.lng}&zoom=14&size=480x160&markers=color:red%7C${modalSchool.lat},${modalSchool.lng}&key=`"
                    :alt="`แผนที่ ${modalSchool.name}`"
                    class="w-full h-full object-cover"
                    @error="$event.target.style.display='none'"
                  />
                  <!-- Fallback when no API key -->
                  <div class="w-full h-full flex items-center justify-center">
                    <a :href="`https://www.google.com/maps?q=${modalSchool.lat},${modalSchool.lng}`"
                      target="_blank" rel="noopener"
                      class="text-xs text-emerald-700 font-medium hover:underline">
                      ดูใน Google Maps
                    </a>
                  </div>
                </div>
              </div>
              <div v-else class="bg-slate-50 dark:bg-slate-700/50 rounded-2xl p-4 text-center text-xs text-slate-400">
                ยังไม่มีข้อมูลพิกัด GPS
              </div>

            </div>

            <!-- Modal footer: action buttons -->
            <div class="sticky bottom-0 bg-white dark:bg-slate-800 border-t border-slate-100 dark:border-slate-700 px-5 py-4 flex gap-3">
              <button v-if="modalSchool.lat && modalSchool.lng"
                @click="navigateTo(modalSchool)"
                class="flex-1 flex items-center justify-center gap-2 py-3 bg-emerald-600 text-white font-bold rounded-2xl hover:-translate-y-0.5 shadow-md shadow-emerald-200 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z"/>
                </svg>
                เริ่มนำทาง
              </button>
              <a v-if="modalSchool.website_url"
                :href="modalSchool.website_url" target="_blank" rel="noopener"
                class="flex-1 flex items-center justify-center gap-2 py-3 bg-primary/10 text-primary font-bold rounded-2xl hover:bg-primary/20 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3"/>
                </svg>
                เว็บไซต์
              </a>
              <button @click="closeModal"
                class="px-5 py-3 bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 font-bold rounded-2xl hover:bg-slate-200 transition-all">
                ปิด
              </button>
            </div>

          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
