<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'

const router = useRouter()
const route  = useRoute()
const { config, fetchConfig } = useAreaConfig()

const profile = ref(null)
const school  = ref(null)
const sidebarOpen = ref(false)

const NAV = [
  {
    to: '/school',
    label: 'หน้าหลัก',
    icon: 'M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25',
  },
  {
    to: '/school/profile',
    label: 'ข้อมูลโรงเรียน',
    icon: 'M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z',
  },
  {
    to: '/school/dmc',
    label: 'อัปโหลดไฟล์ DMC',
    icon: 'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5',
  },
]

const isActive = (path) => {
  if (path === '/school') return route.path === '/school'
  return route.path.startsWith(path)
}

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) { router.push('/school/login'); return }

  const { data: p } = await supabase
    .from('profiles')
    .select('*, schools(*)')
    .eq('id', user.id)
    .single()

  if (!p || p.role !== 'school') {
    await supabase.auth.signOut()
    router.push('/school/login')
    return
  }
  profile.value = p
  school.value  = p.schools
})

async function logout() {
  await supabase.auth.signOut()
  router.push('/school/login')
}
</script>

<template>
  <div class="font-sarabun min-h-screen bg-slate-50 flex">

    <!-- ── Sidebar ─────────────────────────────────────────────── -->
    <!-- Overlay mobile -->
    <div v-if="sidebarOpen"
      class="fixed inset-0 bg-black/40 z-20 lg:hidden"
      @click="sidebarOpen = false"/>

    <aside :class="[
      'fixed inset-y-0 left-0 z-30 w-64 flex flex-col transition-transform duration-300 shadow-xl',
      'gradient-primary',
      sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]">

      <!-- Logo / Header -->
      <div class="px-5 py-5 border-b border-white/10">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-white/15 flex items-center justify-center flex-shrink-0">
            <img v-if="config?.logo_url" :src="config.logo_url" class="w-8 h-8 object-contain"/>
            <svg v-else class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75"/>
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-white font-extrabold text-sm leading-tight">ระบบโรงเรียน</p>
            <p class="text-white/50 text-[10px] truncate">{{ config?.area_name_short || 'สพป.นม.2' }}</p>
          </div>
        </div>
      </div>

      <!-- School info card -->
      <div v-if="school" class="mx-3 mt-3 px-3 py-3 bg-white/10 rounded-2xl">
        <p class="text-white/60 text-[10px] font-bold uppercase tracking-widest mb-0.5">โรงเรียนของคุณ</p>
        <p class="text-white font-extrabold text-sm leading-snug line-clamp-2">{{ school.name }}</p>
        <p class="text-white/50 text-[11px] mt-0.5">{{ school.district }} · {{ school.school_group }}</p>
      </div>

      <!-- Nav -->
      <nav class="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        <router-link v-for="item in NAV" :key="item.to" :to="item.to"
          @click="sidebarOpen = false"
          :class="['flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-bold transition-all',
            isActive(item.to)
              ? 'bg-white text-primary shadow-md'
              : 'text-white/75 hover:bg-white/10 hover:text-white']">
          <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" :d="item.icon"/>
          </svg>
          {{ item.label }}
        </router-link>
      </nav>

      <!-- Bottom: logout -->
      <div class="px-3 pb-5 border-t border-white/10 pt-3">
        <button @click="logout"
          class="w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-bold
                 text-white/60 hover:bg-white/10 hover:text-white transition-all">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75"/>
          </svg>
          ออกจากระบบ
        </button>
      </div>
    </aside>

    <!-- ── Main ───────────────────────────────────────────────── -->
    <div class="flex-1 flex flex-col lg:ml-64 min-w-0">

      <!-- Topbar -->
      <header class="sticky top-0 z-10 bg-white border-b border-slate-100 shadow-sm px-4 h-14 flex items-center gap-3">
        <button @click="sidebarOpen = !sidebarOpen"
          class="lg:hidden w-9 h-9 rounded-xl flex items-center justify-center border border-slate-200 text-slate-500 hover:bg-slate-50">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>
          </svg>
        </button>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-extrabold text-slate-700 truncate">
            {{ school?.name || 'กำลังโหลด...' }}
          </p>
          <p class="text-[11px] text-slate-400 truncate">DMC: {{ school?.dmc_code }}</p>
        </div>
        <a href="/" target="_blank"
          class="hidden sm:flex items-center gap-1.5 text-xs font-bold text-slate-400 hover:text-primary transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
          </svg>
          เว็บไซต์หลัก
        </a>
      </header>

      <!-- Page content -->
      <main class="flex-1 p-4 md:p-6">
        <router-view v-if="school" :school="school" :profile="profile" @refresh="$router.go(0)"/>
        <div v-else class="flex items-center justify-center h-64">
          <div class="flex flex-col items-center gap-3 text-slate-400">
            <svg class="w-8 h-8 animate-spin text-primary" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
            </svg>
            <p class="text-sm font-medium">กำลังโหลดข้อมูล...</p>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
