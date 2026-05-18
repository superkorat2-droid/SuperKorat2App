<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()
const schools  = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')
const filterWebsite  = ref(false)

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase.rpc('get_schools_public')
  schools.value = data || []
  loading.value = false
})

const districts = computed(() => ['all', ...new Set(schools.value.map(s => s.district))])
const groups    = computed(() => {
  const src = filterDistrict.value === 'all'
    ? schools.value
    : schools.value.filter(s => s.district === filterDistrict.value)
  return ['all', ...new Set(src.map(s => s.school_group))]
})

const filtered = computed(() => {
  let list = schools.value
  if (filterWebsite.value)         list = list.filter(s => s.website_url)
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(s => s.school_group === filterGroup.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(s => s.name.toLowerCase().includes(q) || s.dmc_code.includes(q))
  }
  return list
})

const withWebsite = computed(() => schools.value.filter(s => s.website_url).length)
</script>

<template>
  <div class="font-sarabun bg-slate-50 min-h-screen">

    <!-- Hero -->
    <div class="gradient-primary py-10 md:py-14">
      <div class="max-w-7xl mx-auto px-4">
        <div class="w-8 h-0.5 bg-secondary mb-4"></div>
        <h1 class="text-2xl md:text-3xl font-extrabold text-white mb-1">ทำเนียบโรงเรียน</h1>
        <p class="text-white/60 text-sm">{{ config?.area_name || 'สพป.นม.2' }} · {{ schools.length }} โรงเรียน</p>

        <!-- Search -->
        <div class="mt-6 max-w-lg relative">
          <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40"
            fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
          </svg>
          <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน หรือ รหัส DMC..."
            class="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-white/15 border border-white/20
                   text-white placeholder-white/40 text-sm focus:outline-none focus:bg-white/25 transition-all"/>
        </div>
      </div>
    </div>

    <div class="max-w-7xl mx-auto px-4 py-8">

      <!-- Stats + Filters row -->
      <div class="flex flex-wrap items-center gap-3 mb-6">
        <!-- Stats -->
        <div class="flex items-center gap-2 px-3 py-1.5 bg-white rounded-xl border border-slate-200 text-xs font-bold text-slate-600">
          <span class="text-primary font-extrabold">{{ filtered.length }}</span> / {{ schools.length }} โรงเรียน
        </div>
        <div class="flex items-center gap-2 px-3 py-1.5 bg-emerald-50 rounded-xl border border-emerald-200 text-xs font-bold text-emerald-700">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3"/>
          </svg>
          มีเว็บไซต์ {{ withWebsite }} แห่ง
        </div>

        <!-- Filters -->
        <select v-model="filterDistrict" @change="filterGroup='all'"
          class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts.slice(1)" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="filterGroup"
          class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
          <option value="all">ทุกกลุ่ม</option>
          <option v-for="g in groups.slice(1)" :key="g" :value="g">{{ g }}</option>
        </select>
        <button @click="filterWebsite = !filterWebsite"
          :class="['flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border-2 transition-all',
            filterWebsite ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500 bg-white']">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3"/>
          </svg>
          มีเว็บไซต์เท่านั้น
        </button>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <div v-for="i in 8" :key="i" class="bg-white rounded-2xl border border-slate-100 p-4 animate-pulse">
          <div class="h-4 bg-slate-100 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-slate-100 rounded w-1/2 mb-3"></div>
          <div class="h-3 bg-slate-100 rounded w-full"></div>
        </div>
      </div>

      <!-- Empty -->
      <div v-else-if="filtered.length === 0" class="text-center py-20 text-slate-400">
        <p class="text-lg font-bold">ไม่พบโรงเรียน</p>
        <button @click="searchQ=''; filterDistrict='all'; filterGroup='all'; filterWebsite=false"
          class="mt-3 text-sm text-primary font-bold hover:underline">ล้างตัวกรอง</button>
      </div>

      <!-- Grid -->
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <div v-for="s in filtered" :key="s.id"
          class="group bg-white rounded-2xl border border-slate-100 shadow-sm p-4
                 hover:shadow-md hover:-translate-y-0.5 transition-all duration-300">

          <!-- Header -->
          <div class="flex items-start gap-3 mb-3">
            <div class="w-9 h-9 rounded-xl bg-primary-light flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75"/>
              </svg>
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-extrabold text-slate-800 text-sm leading-snug line-clamp-2">{{ s.name }}</p>
              <p class="text-[11px] text-slate-400 mt-0.5 font-mono">{{ s.dmc_code }}</p>
            </div>
          </div>

          <!-- Info -->
          <div class="space-y-1 mb-3">
            <div class="flex items-center gap-1.5 text-xs text-slate-500">
              <svg class="w-3.5 h-3.5 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"/>
              </svg>
              {{ s.subdistrict }} · อ.{{ s.district }}
            </div>
            <div class="flex items-center gap-1.5 text-xs text-slate-500">
              <svg class="w-3.5 h-3.5 flex-shrink-0 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"/>
              </svg>
              {{ s.school_group }}
            </div>
          </div>

          <!-- Website -->
          <div class="pt-3 border-t border-slate-50">
            <a v-if="s.website_url" :href="s.website_url" target="_blank" rel="noopener"
              class="flex items-center gap-1.5 text-xs font-bold text-primary hover:underline">
              <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
              </svg>
              <span class="truncate">{{ s.website_url.replace(/^https?:\/\//, '') }}</span>
            </a>
            <span v-else class="text-xs text-slate-300 italic">ยังไม่มีเว็บไซต์</span>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
