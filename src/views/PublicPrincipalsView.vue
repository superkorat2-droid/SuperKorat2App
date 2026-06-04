<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()
const principals = ref([])
const loading    = ref(true)
const searchQ    = ref('')
const filterDistrict  = ref('all')
const filterGroup     = ref('all')
const filterSchool    = ref('all')
const filterPosition  = ref('all')

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase
    .from('school_principals')
    .select('*, schools(id, name, district, school_group)')
    .order('sort_order')
  principals.value = data || []
  loading.value = false
})

// ─── Filter options ────────────────────────────────────────────────────────────
const districts = computed(() =>
  [...new Set(principals.value.map(p => p.schools?.district).filter(Boolean))].sort()
)
const groups = computed(() => {
  const src = filterDistrict.value === 'all'
    ? principals.value
    : principals.value.filter(p => p.schools?.district === filterDistrict.value)
  return [...new Set(src.map(p => p.schools?.school_group).filter(Boolean))].sort()
})
const schoolsInFilter = computed(() => {
  let src = principals.value
  if (filterDistrict.value !== 'all') src = src.filter(p => p.schools?.district === filterDistrict.value)
  if (filterGroup.value !== 'all')    src = src.filter(p => p.schools?.school_group === filterGroup.value)
  return [...new Map(src.map(p => [p.schools?.id, p.schools])).values()].filter(Boolean).sort((a,b) => a.name.localeCompare(b.name, 'th'))
})
const positions = computed(() =>
  [...new Set(principals.value.map(p => p.position).filter(Boolean))].sort()
)

// ─── Realtime filtered ─────────────────────────────────────────────────────────
const filtered = computed(() => {
  let list = principals.value
  if (filterDistrict.value !== 'all') list = list.filter(p => p.schools?.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(p => p.schools?.school_group === filterGroup.value)
  if (filterSchool.value   !== 'all') list = list.filter(p => p.schools?.id === filterSchool.value)
  if (filterPosition.value !== 'all') list = list.filter(p => p.position === filterPosition.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(p =>
      p.name.toLowerCase().includes(q) ||
      p.position.toLowerCase().includes(q) ||
      p.schools?.name?.toLowerCase().includes(q)
    )
  }
  return list
})

const isFiltered = computed(() =>
  searchQ.value.trim() || filterDistrict.value !== 'all' ||
  filterGroup.value !== 'all' || filterSchool.value !== 'all' || filterPosition.value !== 'all'
)

function resetFilters() {
  searchQ.value = ''; filterDistrict.value = 'all'; filterGroup.value = 'all'
  filterSchool.value = 'all'; filterPosition.value = 'all'
}

function onDistrictChange() { filterGroup.value = 'all'; filterSchool.value = 'all' }
function onGroupChange()    { filterSchool.value = 'all' }

function initials(name) {
  return name?.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase() || '?'
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 dark:text-slate-100 min-h-screen">

    <!-- ── Hero ───────────────────────────────────────────────────────────────── -->
    <div class="relative overflow-hidden"
      style="background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%)">
      <div class="absolute inset-0 opacity-10">
        <svg width="100%" height="100%"><defs><pattern id="dp-p" width="24" height="24" patternUnits="userSpaceOnUse">
          <circle cx="12" cy="12" r="1" fill="white"/>
        </pattern></defs><rect width="100%" height="100%" fill="url(#dp-p)"/></svg>
      </div>
      <div class="relative max-w-5xl mx-auto px-4 py-12 md:py-14 text-center">
        <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-white/15 backdrop-blur ring-2 ring-white/20 mb-5 shadow-lg">
          <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"/>
          </svg>
        </div>
        <h1 class="text-2xl md:text-3xl font-extrabold text-white mb-2">ทำเนียบผู้บริหารสถานศึกษา</h1>
        <p class="text-white/60 text-sm">{{ config?.area_name }} · {{ principals.length }} คน จาก {{ new Set(principals.map(p=>p.school_id)).size }} โรงเรียน</p>

        <!-- Search -->
        <div class="mt-6 max-w-lg mx-auto relative">
          <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-white/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
          </svg>
          <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อผู้บริหาร ตำแหน่ง หรือโรงเรียน..."
            class="w-full pl-11 pr-4 py-3 rounded-2xl bg-white/15 border border-white/25
                   text-white placeholder-white/40 text-sm focus:outline-none focus:bg-white/25 focus:border-white/40 transition-all"/>
        </div>
      </div>
    </div>

    <div class="max-w-7xl mx-auto px-4 py-6 space-y-5">

      <!-- ── Stats ──────────────────────────────────────────────────────────── -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-4 text-center">
          <p class="text-2xl font-extrabold text-primary transition-all duration-300">{{ filtered.length }}</p>
          <p class="text-xs text-slate-500 mt-0.5">ผู้บริหาร</p>
        </div>
        <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-4 text-center">
          <p class="text-2xl font-extrabold text-slate-700 dark:text-slate-200 transition-all duration-300">
            {{ new Set(filtered.map(p=>p.school_id)).size }}
          </p>
          <p class="text-xs text-slate-500 mt-0.5">โรงเรียน</p>
        </div>
        <div v-for="pos in ['ผู้อำนวยการ','รองผู้อำนวยการ']" :key="pos"
          class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-4 text-center">
          <p class="text-2xl font-extrabold text-indigo-600 transition-all duration-300">
            {{ filtered.filter(p => p.position?.includes(pos.includes('รอง') ? 'รอง' : 'อำนวยการ') && !p.position?.includes('รอง') === !pos.includes('รอง')).length }}
          </p>
          <p class="text-xs text-slate-500 mt-0.5">{{ pos.includes('รอง') ? 'รอง ผอ.' : 'ผอ.' }}</p>
        </div>
      </div>

      <!-- ── Filters ────────────────────────────────────────────────────────── -->
      <div class="flex flex-wrap gap-2 items-center">
        <select v-model="filterDistrict" @change="onDistrictChange"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="filterGroup" @change="onGroupChange"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="filterSchool"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary min-w-[180px]">
          <option value="all">ทุกโรงเรียน</option>
          <option v-for="s in schoolsInFilter" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
        <select v-model="filterPosition"
          class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-800 focus:outline-none focus:border-primary">
          <option value="all">ทุกตำแหน่ง</option>
          <option v-for="pos in positions" :key="pos" :value="pos">{{ pos }}</option>
        </select>
        <button v-if="isFiltered" @click="resetFilters"
          class="flex items-center gap-1.5 px-3 py-2 text-sm text-slate-400 hover:text-red-500 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          ล้าง
        </button>
        <span v-if="isFiltered" class="text-xs text-primary font-medium">
          แสดง {{ filtered.length }} คน
        </span>
      </div>

      <!-- ── Loading ────────────────────────────────────────────────────────── -->
      <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
        <div v-for="i in 8" :key="i" class="bg-white rounded-2xl border border-slate-100 p-3 animate-pulse flex gap-3">
          <div class="w-10 h-10 rounded-full bg-slate-100 flex-shrink-0"/>
          <div class="flex-1 space-y-2">
            <div class="h-3 bg-slate-100 rounded w-3/4"/>
            <div class="h-2.5 bg-slate-100 rounded w-1/2"/>
            <div class="h-2.5 bg-slate-100 rounded w-full"/>
          </div>
        </div>
      </div>

      <!-- ── Empty ──────────────────────────────────────────────────────────── -->
      <div v-else-if="filtered.length === 0" class="text-center py-16 text-slate-400">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0z"/>
        </svg>
        <p class="font-bold">ไม่พบข้อมูลผู้บริหาร</p>
        <button @click="resetFilters" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- ── Card grid ──────────────────────────────────────────────────────── -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
        <div v-for="p in filtered" :key="p.id"
          class="group bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm
                 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 p-3 flex items-center gap-3">

          <!-- Photo circle -->
          <div class="w-11 h-11 rounded-full overflow-hidden bg-primary/10 flex items-center justify-center flex-shrink-0 shadow-sm">
            <img v-if="p.photo_url" :src="p.photo_url" :alt="p.name" class="w-full h-full object-cover"/>
            <span v-else class="text-xs font-bold text-primary">{{ initials(p.name) }}</span>
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <p class="font-bold text-slate-800 dark:text-slate-100 text-sm leading-snug truncate">{{ p.name }}</p>
            <span class="inline-block text-[10px] bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full mt-0.5">
              {{ p.position }}
            </span>
            <p class="text-[11px] text-slate-400 dark:text-slate-500 truncate mt-0.5">{{ p.schools?.name }}</p>
            <!-- Contact (visible only) -->
            <div class="flex gap-2 mt-1">
              <a v-if="p.phone && p.visibility?.phone" :href="`tel:${p.phone}`"
                class="text-[11px] text-slate-500 hover:text-primary transition-colors" title="โทรศัพท์">
                📞
              </a>
              <a v-if="p.email && p.visibility?.email" :href="`mailto:${p.email}`"
                class="text-[11px] text-slate-500 hover:text-primary transition-colors" title="อีเมล">
                ✉️
              </a>
              <span v-if="p.line_id && p.visibility?.line"
                class="text-[11px] text-slate-500" title="LINE">
                💚
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Credit -->
      <p class="text-center text-xs text-slate-300 dark:text-slate-600 pb-6">
        ข้อมูลจากระบบ · {{ config?.area_name }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
