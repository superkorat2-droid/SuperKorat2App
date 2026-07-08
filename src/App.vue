<script setup>
import { onMounted, ref, computed } from 'vue'
import { useRouter, useRoute, RouterLink, RouterView } from 'vue-router'
import { supabase } from './supabase'
import { useAreaConfig } from './composables/useAreaConfig'
import { useNavPages } from './composables/useNavPages'
import { useTheme } from './composables/useTheme'
import { iconPath, isIconKey } from './composables/useIcons.js'
import Swal from 'sweetalert2'

const { isDark, toggle: toggleTheme } = useTheme()

const router    = useRouter()
const route     = useRoute()

// ซ่อน navbar+footer เฉพาะ school portal (/school และ /school/...) ไม่รวม /schools
const isSchoolRoute = computed(() =>
  route.path === '/school' || route.path.startsWith('/school/')
)
const session   = ref(null)
const userRole  = ref('')
const isAdmin      = computed(() => ['super_admin','admin'].includes(userRole.value))
const isSchoolUser = computed(() => userRole.value === 'school')
const mobileOpen = ref(false)
const openDropdown = ref(null)
const mobileExpanded = ref(null)
let closeTimer = null

const { config, fetchConfig } = useAreaConfig()
const { fetchNavPages, getNavGroups, pageRoute, isExternal } = useNavPages()

const areaName = computed(() => config.value?.area_name || 'กลุ่มนิเทศ ติดตามและประเมินผล')
const areaShort = computed(() => {
  if (config.value?.tagline) return config.value.tagline
  const t = config.value?.area_type   || ''
  const p = config.value?.province    || ''
  const n = config.value?.area_number || ''
  return (t || p || n) ? `${t}${p ? ' ' + p : ''}${n ? ' ' + n : ''}` : 'สำนักงานเขตพื้นที่การศึกษา'
})
const contactPhone = computed(() => config.value?.contact_phone || '')
const contactEmail = computed(() => config.value?.contact_email || '')

// ── ฟอนต์ชื่อระบบใน navbar: คำนวณตามความยาวข้อความจริง เพื่อไม่ให้ตัดบรรทัด ──
// ใช้หน่วย cqw (container query width) แทน vw เพราะพื้นที่ว่างจริงถูกกินโดยโลโก้/ปุ่มต่างๆ
// ไม่ใช่สัดส่วนคงที่ของ viewport — cqw จะอิงความกว้าง container ที่ layout คำนวณให้แล้ว
function fitFontSize(text, { min, max, maxCqw, avgChar = 0.54 }) {
  const len = Math.max((text || '').length, 8)
  const cqw = Math.min(maxCqw, 100 / (len * avgChar))
  return `clamp(${min}px, ${cqw.toFixed(2)}cqw, ${max}px)`
}
// สาเหตุจริงของวรรณยุกต์ไทยถูกตัด (เช่น ไม้โท ใน "พื้น") คือ overflow-hidden+line-height แน่นเกินไป
// ตัด "ไม้" ด้านบนตัวอักษร ไม่ใช่ตัวฟอนต์เล็กเกินไป — แก้ที่ overflow-y/leading แทน (ดู template)
// ตรงนี้ยก min ขึ้นเล็กน้อยเป็นตัวช่วยเสริมเฉยๆ ไม่บีบจนรัดเกิน
const titleFontSize = computed(() => fitFontSize(areaName.value, { min: 8, max: 19, maxCqw: 6.5 }))
const subtitleFontSize = computed(() => fitFontSize(areaShort.value, { min: 7, max: 13, maxCqw: 4.5 }))

// navItems ผสม: หน้าแรก + DB groups + ลิงค์คงที่
const staticBefore = [
  { key: 'home', label: 'หน้าแรก', to: '/' },
]
const staticAfter = [
  { key: 'contact', label: 'ติดต่อสอบถาม', to: '/contact' },
]
const navItems = computed(() => {
  const dbGroups = getNavGroups(config.value?.nav_groups).map(g => ({
    key: g.key,
    label: g.label,
    children: g.items.map(p => ({
      label:    p.title,
      to:       pageRoute(p),
      icon:     p.nav_icon || '📄',
      desc:     '',
      external: isExternal(p),
    })),
  }))
  return [...staticBefore, ...dbGroups, ...staticAfter]
})

async function loadUserRole(userId) {
  if (!userId) { userRole.value = ''; return }
  const { data } = await supabase.from('profiles').select('role').eq('id', userId).single()
  userRole.value = data?.role || ''
}

onMounted(async () => {
  fetchConfig()
  fetchNavPages()
  const { data: { session: s } } = await supabase.auth.getSession()
  session.value = s
  loadUserRole(s?.user?.id)
  supabase.auth.onAuthStateChange((_e, _s) => {
    session.value = _s
    loadUserRole(_s?.user?.id)
  })
})

function showDropdown(key) { clearTimeout(closeTimer); openDropdown.value = key }
function scheduleHide()    { closeTimer = setTimeout(() => { openDropdown.value = null }, 150) }
function toggleMobileItem(key) { mobileExpanded.value = mobileExpanded.value === key ? null : key }

const handleLogout = async () => {
  const res = await Swal.fire({
    title: 'ยืนยันการออกจากระบบ?', icon: 'question',
    showCancelButton: true, confirmButtonColor: 'var(--color-primary)',
    cancelButtonColor: '#64748b', confirmButtonText: 'ตกลง',
    cancelButtonText: 'ยกเลิก', reverseButtons: true,
  })
  if (res.isConfirmed) {
    await supabase.auth.signOut()
    mobileOpen.value = false
    router.push({ name: 'home' })
  }
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50 dark:bg-slate-950 font-sarabun transition-colors duration-300">

    <!-- ── Top accent line + Navbar (hidden in school portal) ──────── -->
    <template v-if="!isSchoolRoute">
    <div class="fixed top-0 inset-x-0 z-50 h-[3px] bg-primary"></div>

    <!-- ── Navbar ─────────────────────────────────────────────────── -->
    <nav class="fixed top-[3px] inset-x-0 z-40 bg-white dark:bg-slate-900 border-b border-slate-200/80 dark:border-slate-700/80 shadow-sm shadow-slate-900/[0.03] transition-colors duration-300">
      <div class="w-full px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-[58px] sm:h-[68px] lg:h-20">

          <!-- Logo -->
          <RouterLink to="/" class="flex items-center gap-2 sm:gap-3 min-w-0 flex-1 lg:flex-none mr-2 sm:mr-5 lg:mr-6 group">
            <div v-if="config?.logo_url"
              class="w-9 h-9 sm:w-10 sm:h-10 lg:w-12 lg:h-12 rounded-lg overflow-hidden flex-shrink-0">
              <img :src="config.logo_url" class="w-full h-full object-contain" alt="logo"/>
            </div>
            <div v-else
              class="w-9 h-9 sm:w-10 sm:h-10 lg:w-12 lg:h-12 bg-primary rounded-lg flex items-center justify-center flex-shrink-0">
              <svg class="text-white" style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
              </svg>
            </div>
            <div class="brand-fit-container leading-snug min-w-0 flex-1 lg:flex-none"
              :style="{ '--fit-title': titleFontSize, '--fit-subtitle': subtitleFontSize }">
              <p class="brand-title-shine font-extrabold whitespace-nowrap overflow-x-hidden overflow-y-visible text-ellipsis">{{ areaName }}</p>
              <p class="brand-subtitle-fit text-slate-500 dark:text-slate-400 font-medium tracking-wide whitespace-nowrap overflow-x-hidden overflow-y-visible text-ellipsis mt-[3px]">{{ areaShort }}</p>
            </div>
          </RouterLink>

          <!-- Desktop nav -->
          <div class="hidden lg:flex items-center gap-1 lg:ml-auto">
            <template v-for="item in navItems" :key="item.key">

              <!-- Simple link -->
              <RouterLink v-if="item.to && !item.children" :to="item.to"
                class="relative px-3 py-2 text-[13px] font-medium text-slate-600 dark:text-slate-300 hover:text-primary transition-colors whitespace-nowrap group">
                {{ item.label }}
                <span class="absolute inset-x-3 bottom-0 h-[2px] bg-primary scale-x-0 group-hover:scale-x-100 transition-transform origin-left rounded-full"></span>
              </RouterLink>

              <!-- Dropdown -->
              <div v-else class="relative"
                @mouseenter="showDropdown(item.key)"
                @mouseleave="scheduleHide()">
                <button :class="[
                  'relative flex items-center gap-1 px-3 py-2 text-[13px] font-medium transition-colors whitespace-nowrap group',
                  openDropdown === item.key ? 'text-primary' : 'text-slate-600 dark:text-slate-300 hover:text-primary'
                ]">
                  {{ item.label }}
                  <svg class="w-3 h-3 mt-0.5 flex-shrink-0 transition-transform duration-200"
                    :class="openDropdown === item.key ? 'rotate-180' : ''"
                    fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                  </svg>
                  <span class="absolute inset-x-3 bottom-0 h-[2px] bg-primary transition-transform origin-left rounded-full"
                    :class="openDropdown === item.key ? 'scale-x-100' : 'scale-x-0'"></span>
                </button>

                <!-- Dropdown panel -->
                <Transition
                  enter-active-class="transition duration-150 ease-out"
                  enter-from-class="opacity-0 translate-y-1"
                  enter-to-class="opacity-100 translate-y-0"
                  leave-active-class="transition duration-100 ease-in"
                  leave-from-class="opacity-100"
                  leave-to-class="opacity-0">
                  <div v-if="openDropdown === item.key"
                    :class="[
                      'absolute top-[calc(100%+8px)] left-0 z-50 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-lg shadow-slate-200/60 py-1.5 origin-top-left',
                      item.key === 'work' ? 'w-72' : 'w-60'
                    ]"
                    @mouseenter="showDropdown(item.key)"
                    @mouseleave="scheduleHide()">
                    <template v-for="child in item.children" :key="child.to">
                      <!-- External link -->
                      <a v-if="child.external"
                        :href="child.to" target="_blank" rel="noopener"
                        @click="openDropdown = null"
                        class="flex items-center gap-3 px-4 py-2.5 hover:bg-primary-light dark:hover:bg-slate-700 transition-colors group/c mx-1.5 rounded-lg">
                        <div class="w-7 h-7 flex-shrink-0 flex items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-700 group-hover/c:bg-primary/10 transition-colors">
                          <svg v-if="isIconKey(child.icon)" class="w-4 h-4 text-slate-500 dark:text-slate-400 group-hover/c:text-primary transition-colors" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(child.icon)"/>
                          </svg>
                          <span v-else class="text-sm">{{ child.icon }}</span>
                        </div>
                        <p class="text-[13px] font-semibold text-slate-700 dark:text-slate-200 group-hover/c:text-primary transition-colors flex items-center gap-1">
                          {{ child.label }}
                          <svg class="w-3 h-3 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
                          </svg>
                        </p>
                      </a>
                      <!-- Internal link -->
                      <RouterLink v-else :to="child.to" @click="openDropdown = null"
                        class="flex items-center gap-3 px-4 py-2.5 hover:bg-primary-light dark:hover:bg-slate-700 transition-colors group/c mx-1.5 rounded-lg">
                        <!-- icon -->
                        <div class="w-7 h-7 flex-shrink-0 flex items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-700 group-hover/c:bg-primary/10 transition-colors">
                          <svg v-if="isIconKey(child.icon)" class="w-4 h-4 text-slate-500 dark:text-slate-400 group-hover/c:text-primary transition-colors" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(child.icon)"/>
                          </svg>
                          <span v-else class="text-sm">{{ child.icon }}</span>
                        </div>
                        <p class="text-[13px] font-semibold text-slate-700 dark:text-slate-200 group-hover/c:text-primary transition-colors">{{ child.label }}</p>
                      </RouterLink>
                    </template>
                  </div>
                </Transition>
              </div>
            </template>
          </div>

          <!-- Right: auth + hamburger -->
          <div class="flex items-center gap-2 ml-2">

            <div class="hidden lg:flex items-center gap-1">
              <template v-if="session">

                <!-- ── School user: ไม่มี admin icons ── -->
                <template v-if="isSchoolUser">
                  <RouterLink to="/school" title="ระบบโรงเรียนของฉัน"
                    class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-[13px] font-semibold bg-primary text-white hover:opacity-90 transition-all shadow-sm">
                    <svg style="width:15px;height:15px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                    </svg>
                    ระบบโรงเรียน
                  </RouterLink>
                </template>

                <!-- ── Staff/Admin: admin icons ── -->
                <template v-else>
                  <RouterLink v-if="isAdmin" to="/dashboard/settings" title="ตั้งค่าเขตพื้นที่"
                    class="w-9 h-9 flex items-center justify-center rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
                    <svg style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                  </RouterLink>
                  <RouterLink to="/dashboard/profile" title="โปรไฟล์ของฉัน"
                    class="w-9 h-9 flex items-center justify-center rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
                    <svg style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                  </RouterLink>
                </template>

                <!-- ออกจากระบบ (ทุก role) -->
                <button @click="handleLogout" title="ออกจากระบบ"
                  class="w-9 h-9 flex items-center justify-center rounded-xl text-slate-400 dark:text-slate-500 hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-900/30 transition-colors">
                  <svg style="width:17px;height:17px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
                  </svg>
                </button>
              </template>

              <RouterLink v-else to="/login"
                class="flex items-center gap-1.5 px-2 py-2 rounded-lg text-[13px] font-semibold text-slate-600 dark:text-slate-300 hover:text-[var(--color-primary)] dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-all">
                <svg style="width:14px;height:14px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
                </svg>
                เข้าสู่ระบบ
              </RouterLink>
            </div>

            <!-- Dark mode toggle -->
            <button @click="toggleTheme"
              class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              :title="isDark ? 'เปลี่ยนเป็นโหมดสว่าง' : 'เปลี่ยนเป็นโหมดมืด'">
              <!-- Sun (dark mode active) -->
              <svg v-if="isDark" style="width:17px;height:17px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z"/>
              </svg>
              <!-- Moon (light mode active) -->
              <svg v-else style="width:17px;height:17px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z"/>
              </svg>
            </button>

            <!-- Hamburger -->
            <button @click="mobileOpen = !mobileOpen"
              class="lg:hidden w-9 h-9 flex items-center justify-center rounded-lg text-slate-500 hover:bg-slate-100 transition-colors">
              <svg style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path v-if="!mobileOpen" stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Mobile menu -->
      <Transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="opacity-0 -translate-y-2"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-150"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0">
        <div v-if="mobileOpen" class="lg:hidden border-t border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-900 max-h-[80vh] overflow-y-auto">
          <div class="px-3 py-3 space-y-px">
            <template v-for="item in navItems" :key="item.key">
              <RouterLink v-if="item.to && !item.children" :to="item.to"
                @click="mobileOpen = false"
                class="flex items-center px-4 py-2.5 rounded-lg text-[13px] font-medium text-slate-700 hover:bg-primary-light hover:text-primary transition-all">
                {{ item.label }}
              </RouterLink>
              <div v-else>
                <button @click="toggleMobileItem(item.key)"
                  :class="[
                    'w-full flex items-center justify-between px-4 py-2.5 rounded-lg text-[13px] font-medium transition-all',
                    mobileExpanded === item.key ? 'bg-primary-light text-primary' : 'text-slate-700 hover:bg-slate-50'
                  ]">
                  {{ item.label }}
                  <svg style="width:14px;height:14px" class="text-slate-400 transition-transform duration-200"
                    :class="mobileExpanded === item.key ? 'rotate-180 text-primary' : ''"
                    fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>
                <div v-if="mobileExpanded === item.key" class="ml-4 pl-3 border-l border-slate-200 mt-1 mb-1 space-y-px">
                  <template v-for="child in item.children" :key="child.to">
                    <a v-if="child.external" :href="child.to" target="_blank" rel="noopener"
                      @click="mobileOpen = false"
                      class="flex items-center px-3 py-2 rounded-lg text-[13px] text-slate-600 hover:bg-primary-light hover:text-primary transition-all">
                      {{ child.label }} <span class="ml-1 text-[10px] text-slate-400">↗</span>
                    </a>
                    <RouterLink v-else :to="child.to" @click="mobileOpen = false"
                      class="flex items-center px-3 py-2 rounded-lg text-[13px] text-slate-600 hover:bg-primary-light hover:text-primary transition-all">
                      {{ child.label }}
                    </RouterLink>
                  </template>
                </div>
              </div>
            </template>

            <!-- Auth -->
            <div class="pt-2 mt-1 border-t border-slate-100 space-y-px">
              <template v-if="session">
                <!-- School user: ไประบบโรงเรียน -->
                <RouterLink v-if="isSchoolUser" to="/school" @click="mobileOpen = false"
                  class="flex items-center gap-2 px-4 py-2.5 rounded-lg text-[13px] font-medium bg-primary/10 text-primary hover:bg-primary hover:text-white transition-all">
                  <svg style="width:15px;height:15px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                  </svg>
                  ระบบโรงเรียน
                </RouterLink>
                <!-- Staff/Admin: ไปแดชบอร์ด -->
                <RouterLink v-else to="/dashboard" @click="mobileOpen = false"
                  class="flex items-center px-4 py-2.5 rounded-lg text-[13px] font-medium text-slate-700 hover:bg-primary-light hover:text-primary transition-all">
                  แผงควบคุม
                </RouterLink>
                <button @click="handleLogout"
                  class="w-full text-left flex items-center px-4 py-2.5 rounded-lg text-[13px] font-medium text-red-500 hover:bg-red-50 transition-all">
                  ออกจากระบบ
                </button>
              </template>
              <RouterLink v-else to="/login" @click="mobileOpen = false"
                class="flex items-center justify-center gap-2 bg-primary text-white text-[13px] font-semibold px-4 py-3 rounded-lg hover:bg-primary-dark transition-colors">
                เข้าสู่ระบบ
              </RouterLink>
            </div>
          </div>
        </div>
      </Transition>
    </nav>

    <!-- Spacer: 3px accent + nav height (must match nav's h-*) -->
    <div class="h-[61px] sm:h-[71px] lg:h-[83px] flex-shrink-0"></div>
    </template><!-- end v-if="!isSchoolRoute" -->

    <!-- Main content -->
    <main class="flex-grow">
      <RouterView v-slot="{ Component, route }">
        <Transition
          enter-active-class="transition duration-200"
          enter-from-class="opacity-0 translate-y-1"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-100"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0">
          <component :is="Component" :key="route.path" />
        </Transition>
      </RouterView>
    </main>

    <!-- ── Footer (hidden in school portal) ─────────────────────────── -->
    <footer v-if="!isSchoolRoute" class="bg-white border-t border-slate-200 mt-16">
      <div class="max-w-7xl mx-auto px-6 py-10">
        <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
          <!-- Brand -->
          <div class="flex items-center gap-3">
            <div v-if="config?.logo_url"
              class="w-9 h-9 rounded-lg overflow-hidden flex-shrink-0 border border-slate-200">
              <img :src="config.logo_url" class="w-full h-full object-contain" alt="logo"/>
            </div>
            <div v-else class="w-9 h-9 bg-primary rounded-lg flex items-center justify-center flex-shrink-0">
              <svg style="width:16px;height:16px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24" class="text-white">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
              </svg>
            </div>
            <div>
              <p class="text-[13px] font-bold text-slate-800">{{ areaName }}</p>
              <p class="text-xs text-slate-400 mt-0.5">{{ areaShort }}</p>
            </div>
          </div>

          <!-- Contact + copyright -->
          <div class="flex flex-col items-start md:items-end gap-1.5">
            <div class="flex flex-wrap gap-x-4 gap-y-1 text-[13px] text-slate-500">
              <a v-if="contactPhone" :href="`tel:${contactPhone}`"
                class="flex items-center gap-1.5 hover:text-primary transition-colors">
                <svg style="width:14px;height:14px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"/>
                </svg>
                {{ contactPhone }}
              </a>
              <a v-if="contactEmail" :href="`mailto:${contactEmail}`"
                class="flex items-center gap-1.5 hover:text-primary transition-colors">
                <svg style="width:14px;height:14px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/>
                </svg>
                {{ contactEmail }}
              </a>
            </div>
            <p class="text-xs text-slate-400">© 2026 Developed by Winai · Educational Supervisor</p>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<style>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
