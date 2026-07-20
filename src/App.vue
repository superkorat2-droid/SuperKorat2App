<script setup>
import { onMounted, ref, computed } from 'vue'
import { useRouter, useRoute, RouterLink, RouterView } from 'vue-router'
import { supabase } from './supabase'
import { useAreaConfig } from './composables/useAreaConfig'
import { useNavPages } from './composables/useNavPages'
import { iconPath, isIconKey } from './composables/useIcons.js'
import WelcomePopup from './components/WelcomePopup.vue'
import ScrollToTopButton from './components/ScrollToTopButton.vue'
import Swal from 'sweetalert2'

const router    = useRouter()
const route     = useRoute()

// ซ่อน navbar+footer เฉพาะ school portal (/school และ /school/...) ไม่รวม /schools
const isSchoolRoute = computed(() =>
  route.path === '/school' || route.path.startsWith('/school/')
)
const isDashboardRoute = computed(() => route.path.startsWith('/dashboard'))
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
const contactPhone   = computed(() => config.value?.contact_phone || '')
const contactEmail   = computed(() => config.value?.contact_email || '')
const contactAddress = computed(() => config.value?.contact_address || '')
const contactFax     = computed(() => config.value?.contact_fax || '')
const siteWebsite    = computed(() => config.value?.website_url || '')
const currentYear    = computed(() => new Date().getFullYear())

// ── Footer: โซเชียล — SVG path เดียวกับที่ ContactView.vue ใช้ ──────────
const FOOTER_ICONS = {
  facebook: 'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244',
  line:     'M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 01-.923 1.785A5.969 5.969 0 006 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337z',
  youtube:  'M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z',
}
const socialLinks = computed(() => {
  const c = config.value || {}
  const items = []
  if (c.facebook_url) items.push({ svgPath: FOOTER_ICONS.facebook, label: 'Facebook', url: c.facebook_url })
  if (c.line_url)     items.push({ svgPath: FOOTER_ICONS.line,     label: 'LINE',     url: c.line_url })
  if (c.youtube_url)  items.push({ svgPath: FOOTER_ICONS.youtube,  label: 'YouTube',  url: c.youtube_url })
  return items
})

// ── Footer: ลิงก์ด่วน — ใช้เมนูจริงชุดเดียวกับ navbar (navItems) ไม่ดึงข้อมูลซ้ำ ──
const footerQuickLinks = computed(() => {
  const flat = []
  navItems.value.forEach(item => {
    if (item.children) item.children.forEach(c => flat.push({ label: c.label, to: c.to, external: c.external }))
    else if (item.to) flat.push({ label: item.label, to: item.to, external: false })
  })
  const home    = flat.find(l => l.to === '/')
  const contact = flat.find(l => l.to === '/contact')
  const middle  = flat.filter(l => l.to !== '/' && l.to !== '/contact').slice(0, 5)
  return [home, ...middle, contact].filter(Boolean)
})

// ── Footer: คอลัมน์เพิ่มเติมที่ admin สร้างเอง (ตั้งค่าเขต → ลิงก์ท้ายเว็บไซต์) ──
const footerExtraTitle = computed(() => config.value?.footer_extra_title || '')
const footerExtraLinks = computed(() =>
  [...(config.value?.footer_extra_links || [])].sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
)

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

// navItems ผสม: หน้าแรก + DB groups + ลิงก์คงที่
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
                      'absolute top-[calc(100%+8px)] left-0 z-50 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-lg shadow-slate-200/60 py-1.5 origin-top-left max-h-[70vh] overflow-y-auto',
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

            <!-- Dark mode toggle: ปิดไว้ชั่วคราวระหว่างพัฒนา (ดู composables/useTheme.js) -->

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
    <footer v-if="!isSchoolRoute" class="relative overflow-hidden gradient-primary mt-16 font-sarabun">
      <!-- ลายจุดจางๆ แบบเดียวกับ PageHero ให้พื้นดูมีมิติ ไม่แบนเรียบ -->
      <div class="absolute inset-0 opacity-[0.07] pointer-events-none">
        <svg width="100%" height="100%"><defs><pattern id="footer-dots" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="12" cy="12" r="1" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#footer-dots)"/></svg>
      </div>

      <div class="relative max-w-7xl mx-auto px-6 pt-12 pb-20 sm:pb-8">
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-[2.6fr_0.75fr_0.95fr_0.65fr_0.65fr] gap-10">

          <!-- แบรนด์ -->
          <div class="sm:col-span-2 md:col-span-1">
            <div class="flex items-center gap-3">
              <div v-if="config?.logo_url" class="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0 bg-white/10 ring-1 ring-white/20">
                <img :src="config.logo_url" class="w-full h-full object-contain" alt="logo"/>
              </div>
              <div v-else class="w-10 h-10 rounded-xl bg-white/15 backdrop-blur ring-1 ring-white/20 flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-extrabold text-white leading-snug">{{ areaName }}</p>
                <p class="text-xs text-white/60 mt-0.5">{{ areaShort }}</p>
              </div>
            </div>
          </div>

          <!-- ลิงก์ด่วน -->
          <div>
            <p class="text-xs font-bold text-white/40 uppercase tracking-widest mb-4">ลิงก์ด่วน</p>
            <ul class="space-y-2.5">
              <li v-for="l in footerQuickLinks" :key="l.to">
                <a v-if="l.external" :href="l.to" target="_blank" rel="noopener noreferrer"
                  class="text-sm text-white/70 hover:text-white transition-colors">{{ l.label }}</a>
                <RouterLink v-else :to="l.to" class="text-sm text-white/70 hover:text-white transition-colors">{{ l.label }}</RouterLink>
              </li>
            </ul>
          </div>

          <!-- ติดต่อเรา -->
          <div>
            <p class="text-xs font-bold text-white/40 uppercase tracking-widest mb-4">ติดต่อเรา</p>
            <ul class="space-y-2.5 text-sm text-white/70">
              <li v-if="contactAddress" class="leading-relaxed">{{ contactAddress }}</li>
              <li v-if="contactPhone">
                <a :href="`tel:${contactPhone}`" class="hover:text-white transition-colors">โทร. {{ contactPhone }}</a>
                <span v-if="contactFax"> · แฟกซ์ {{ contactFax }}</span>
              </li>
              <li v-if="contactEmail">
                <a :href="`mailto:${contactEmail}`" class="hover:text-white transition-colors">{{ contactEmail }}</a>
              </li>
              <li v-if="siteWebsite">
                <a :href="siteWebsite" target="_blank" rel="noopener noreferrer" class="hover:text-white transition-colors">{{ siteWebsite.replace(/^https?:\/\//, '') }}</a>
              </li>
            </ul>
          </div>

          <!-- ติดตามเรา -->
          <div v-if="socialLinks.length">
            <p class="text-xs font-bold text-white/40 uppercase tracking-widest mb-4">ติดตามเรา</p>
            <div class="flex gap-2.5">
              <a v-for="s in socialLinks" :key="s.label" :href="s.url" target="_blank" rel="noopener noreferrer" :title="s.label"
                class="w-9 h-9 rounded-full bg-white/10 backdrop-blur ring-1 ring-white/20 flex items-center justify-center hover:bg-white/20 transition-colors">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="s.svgPath"/>
                </svg>
              </a>
            </div>
          </div>

          <!-- ลิงก์เพิ่มเติม (คอลัมน์ที่ admin กำหนดเอง จากตั้งค่าเขต → ลิงก์ท้ายเว็บไซต์) -->
          <div v-if="footerExtraLinks.length">
            <p class="text-xs font-bold text-white/40 uppercase tracking-widest mb-4">{{ footerExtraTitle || 'ลิงก์เพิ่มเติม' }}</p>
            <ul class="space-y-2.5">
              <li v-for="(l, i) in footerExtraLinks" :key="i">
                <a v-if="l.type === 'external'" :href="l.url" target="_blank" rel="noopener noreferrer"
                  class="text-sm text-white/70 hover:text-white transition-colors">{{ l.label }}</a>
                <RouterLink v-else :to="l.url" class="text-sm text-white/70 hover:text-white transition-colors">{{ l.label }}</RouterLink>
              </li>
            </ul>
          </div>
        </div>

        <!-- แถบล่างสุด — ไม่ใส่อะไรชิดขวาสุด กันซ้อนกับปุ่มลอย "กลับขึ้นบน" -->
        <div class="mt-10 pt-6 border-t border-white/10 text-center sm:text-left">
          <p class="text-xs text-white/40">© {{ currentYear }} {{ areaName }} · สงวนลิขสิทธิ์</p>
        </div>
      </div>
    </footer>

    <WelcomePopup v-if="!isSchoolRoute && !isDashboardRoute"/>
    <ScrollToTopButton v-if="!isSchoolRoute"/>
  </div>
</template>

<style>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
