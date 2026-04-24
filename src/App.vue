<script setup>
import { onMounted, ref, computed } from 'vue'
import { useRouter, RouterLink, RouterView } from 'vue-router'
import { supabase } from './supabase'
import { useAreaConfig } from './composables/useAreaConfig'
import Swal from 'sweetalert2'

const router = useRouter()
const session = ref(null)
const mobileOpen = ref(false)
const openDropdown = ref(null)
const mobileExpanded = ref(null)
let closeTimer = null

// ── Area config (dynamic theme + ชื่อเขต) ─────────────────────
const { config, fetchConfig } = useAreaConfig()

const areaName  = computed(() => config.value?.area_name      || 'กลุ่มนิเทศ ติดตามและประเมินผล')
const areaShort = computed(() => {
  // ถ้ามี tagline ที่กำหนดเอง ใช้เลย
  if (config.value?.tagline) return config.value.tagline
  // fallback: ประกอบจากฟิลด์ area_type + province + area_number
  const t = config.value?.area_type   || ''
  const p = config.value?.province    || ''
  const n = config.value?.area_number || ''
  return (t || p || n) ? `${t}${p ? ' ' + p : ''}${n ? ' ' + n : ''}` : 'สำนักงานเขตพื้นที่การศึกษา'
})
const contactPhone = computed(() => config.value?.contact_phone || '0X-XXXX-XXXX')
const contactEmail = computed(() => config.value?.contact_email || 'nithet@obec.go.th')

const navItems = [
  { key: 'home', label: 'หน้าแรก', to: '/' },
  {
    key: 'general', label: 'ข้อมูลทั่วไป',
    children: [
      { label: 'วิสัยทัศน์และพันธกิจ', to: '/vision',    icon: '👁️', desc: 'วิสัยทัศน์ พันธกิจ เป้าประสงค์' },
      { label: 'โครงสร้างการบริหาร',    to: '/org',       icon: '🏢', desc: 'แผนผังการบริหารงานภายในกลุ่ม' },
      { label: 'ทำเนียบบุคลากร',        to: '/personnel', icon: '👥', desc: 'รายชื่อศึกษานิเทศก์ทั้งหมด' },
      { label: 'ข้อมูลสารสนเทศ',        to: '/site-info', icon: '📊', desc: 'สถิติโรงเรียน ครู นักเรียน' },
    ]
  },
  {
    key: 'work', label: 'งานนิเทศติดตาม',
    children: [
      { label: 'พัฒนาหลักสูตรการศึกษา',    to: '/curriculum',      icon: '📖', desc: 'หลักสูตรแกนกลาง ท้องถิ่น ปฐมวัย พิเศษ' },
      { label: 'นิเทศการศึกษา',             to: '/supervision-edu', icon: '🔍', desc: 'แผนนิเทศ 8 กลุ่มสาระ Active Learning' },
      { label: 'วัดและประเมินผล',           to: '/evaluation',      icon: '📊', desc: 'RT NT O-NET PISA ระบบรายงาน' },
      { label: 'ประกันคุณภาพการศึกษา',      to: '/quality',         icon: '⭐', desc: 'IQA EQA มาตรฐานการศึกษา' },
      { label: 'วิจัย สื่อ และเทคโนโลยี',  to: '/research',        icon: '🔬', desc: 'คลังวิจัย DLTV DLIT วิทยฐานะ PA' },
      { label: 'ส่งเสริมพัฒนาการบริหาร',   to: '/secretariat',     icon: '📋', desc: 'ก.ต.ป.น. โครงการพิเศษ รายงานประจำปี' },
    ]
  },
  {
    key: 'service', label: 'บริการ',
    children: [
      { label: 'ดาวน์โหลดเอกสาร', to: '/download',  icon: '⬇️', desc: 'แบบฟอร์ม คู่มือ เอกสารราชการ' },
      { label: 'ย่อลิงค์',         to: '/url-short', icon: '🔗', desc: 'ย่อ URL ยาวให้สั้นและแชร์ง่าย' },
      { label: 'สร้าง QR Code',   to: '/qrcode',    icon: '📱', desc: 'สร้าง QR Code จากข้อความหรือลิงค์' },
    ]
  },
  { key: 'contact', label: 'ติดต่อสอบถาม', to: '/contact' },
]

onMounted(async () => {
  // โหลด area config + apply theme ทันที
  fetchConfig()

  const { data: { session: s } } = await supabase.auth.getSession()
  session.value = s
  supabase.auth.onAuthStateChange((_e, _s) => { session.value = _s })
})

function showDropdown(key) {
  clearTimeout(closeTimer)
  openDropdown.value = key
}
function scheduleHide() {
  closeTimer = setTimeout(() => { openDropdown.value = null }, 150)
}
function toggleMobileItem(key) {
  mobileExpanded.value = mobileExpanded.value === key ? null : key
}

const handleLogout = async () => {
  const res = await Swal.fire({
    title: 'ยืนยันการออกจากระบบ?', icon: 'question',
    showCancelButton: true, confirmButtonColor: '#3b82f6',
    cancelButtonColor: '#64748b', confirmButtonText: 'ตกลง',
    cancelButtonText: 'ยกเลิก', reverseButtons: true,
  })
  if (res.isConfirmed) {
    await supabase.auth.signOut()
    mobileOpen.value = false
    Swal.fire({ icon: 'success', title: 'ออกจากระบบเรียบร้อย', showConfirmButton: false, timer: 1500 })
    router.push({ name: 'home' })
  }
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50 font-sarabun">

    <!-- ── Top accent stripe ──────────────────────────────────────────── -->
    <div class="fixed top-0 inset-x-0 z-50 h-1 gradient-primary"></div>

    <!-- ── Navbar ─────────────────────────────────────────────────────── -->
    <nav class="fixed top-1 inset-x-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6">
        <div class="flex items-center justify-between h-16">

          <!-- Logo -->
          <RouterLink to="/" class="flex items-center gap-3 group flex-shrink-0 mr-4">
            <!-- Logo image หรือ icon fallback -->
            <div v-if="config?.logo_url"
              class="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0 group-hover:scale-105 transition-transform shadow-md">
              <img :src="config.logo_url" class="w-full h-full object-cover" alt="logo"/>
            </div>
            <div v-else
              class="w-9 h-9 bg-primary rounded-xl flex items-center justify-center shadow-md group-hover:scale-105 transition-transform flex-shrink-0">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
              </svg>
            </div>
            <div class="hidden sm:block leading-tight">
              <p class="text-sm font-extrabold text-slate-800 line-clamp-1">{{ areaName }}</p>
              <p class="text-[10px] text-slate-400 font-medium">{{ areaShort }}</p>
            </div>
          </RouterLink>

          <!-- Desktop nav ─────────────────────────────────────────────── -->
          <div class="hidden lg:flex items-center gap-0.5 flex-1">
            <template v-for="item in navItems" :key="item.key">

              <!-- Simple link -->
              <RouterLink v-if="item.to && !item.children" :to="item.to"
                class="px-3.5 py-2 rounded-xl text-sm font-semibold text-slate-600 hover:text-blue-700 hover:bg-blue-50 transition-all whitespace-nowrap"
                active-class="!text-blue-700 !bg-blue-50">
                {{ item.label }}
              </RouterLink>

              <!-- Dropdown trigger -->
              <div v-else class="relative"
                @mouseenter="showDropdown(item.key)"
                @mouseleave="scheduleHide()">
                <button :class="[
                  'flex items-center gap-1 px-3.5 py-2 rounded-xl text-sm font-semibold transition-all whitespace-nowrap',
                  openDropdown === item.key
                    ? 'text-blue-700 bg-blue-50'
                    : 'text-slate-600 hover:text-blue-700 hover:bg-blue-50'
                ]">
                  {{ item.label }}
                  <svg class="w-3.5 h-3.5 flex-shrink-0 transition-transform duration-200"
                    :class="openDropdown === item.key ? 'rotate-180' : ''"
                    fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                <!-- Dropdown panel -->
                <Transition
                  enter-active-class="transition duration-150 ease-out"
                  enter-from-class="opacity-0 scale-95 -translate-y-1"
                  enter-to-class="opacity-100 scale-100 translate-y-0"
                  leave-active-class="transition duration-100 ease-in"
                  leave-from-class="opacity-100 scale-100 translate-y-0"
                  leave-to-class="opacity-0 scale-95 -translate-y-1">
                  <div v-if="openDropdown === item.key"
                    :class="[
                      'absolute top-[calc(100%+6px)] left-0 z-50 bg-white rounded-2xl shadow-xl shadow-slate-200/80 border border-slate-100 py-2 origin-top-left',
                      item.key === 'work' ? 'w-80' : 'w-64'
                    ]"
                    @mouseenter="showDropdown(item.key)"
                    @mouseleave="scheduleHide()">
                    <RouterLink
                      v-for="child in item.children" :key="child.to"
                      :to="child.to"
                      @click="openDropdown = null"
                      class="flex items-start gap-3 px-4 py-2.5 hover:bg-blue-50 transition-colors group/child mx-1 rounded-xl">
                      <span class="text-xl flex-shrink-0 mt-0.5">{{ child.icon }}</span>
                      <div>
                        <p class="font-bold text-sm text-slate-800 group-hover/child:text-blue-700 transition-colors leading-snug">{{ child.label }}</p>
                        <p class="text-[11px] text-slate-400 mt-0.5">{{ child.desc }}</p>
                      </div>
                    </RouterLink>
                  </div>
                </Transition>
              </div>
            </template>
          </div>

          <!-- Right: auth + hamburger ──────────────────────────────────── -->
          <div class="flex items-center gap-2 ml-2">
            <div class="hidden lg:flex items-center gap-1.5">
              <template v-if="session">
                <RouterLink to="/dashboard"
                  class="text-sm font-semibold text-slate-600 hover:text-blue-700 px-3 py-2 rounded-xl hover:bg-blue-50 transition-all">
                  แผงควบคุม
                </RouterLink>
                <button @click="handleLogout"
                  class="text-sm font-semibold text-red-500 hover:text-red-600 px-3 py-2 rounded-xl hover:bg-red-50 transition-all">
                  ออกจากระบบ
                </button>
              </template>
              <RouterLink v-else to="/login"
                class="flex items-center gap-1.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold px-5 py-2.5 rounded-xl shadow-md hover:shadow-lg hover:-translate-y-0.5 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/>
                </svg>
                เข้าสู่ระบบ
              </RouterLink>
            </div>

            <!-- Hamburger -->
            <button @click="mobileOpen = !mobileOpen"
              class="lg:hidden w-9 h-9 flex items-center justify-center rounded-xl text-slate-500 hover:bg-slate-100 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path v-if="!mobileOpen" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Mobile menu ──────────────────────────────────────────────────── -->
      <Transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="opacity-0 -translate-y-3"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-150 ease-in"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 -translate-y-3">
        <div v-if="mobileOpen" class="lg:hidden border-t border-slate-100 bg-white max-h-[80vh] overflow-y-auto">
          <div class="px-3 py-3 space-y-0.5">
            <template v-for="item in navItems" :key="item.key">
              <!-- Simple -->
              <RouterLink v-if="item.to && !item.children" :to="item.to"
                @click="mobileOpen = false"
                class="flex items-center px-4 py-3 rounded-xl text-sm font-semibold text-slate-700 hover:bg-blue-50 hover:text-blue-700 transition-all"
                active-class="!bg-blue-50 !text-blue-700">
                {{ item.label }}
              </RouterLink>

              <!-- Accordion -->
              <div v-else>
                <button @click="toggleMobileItem(item.key)"
                  :class="[
                    'w-full flex items-center justify-between px-4 py-3 rounded-xl text-sm font-semibold transition-all',
                    mobileExpanded === item.key ? 'bg-blue-50 text-blue-700' : 'text-slate-700 hover:bg-slate-50'
                  ]">
                  {{ item.label }}
                  <svg class="w-4 h-4 text-slate-400 transition-transform duration-200"
                    :class="mobileExpanded === item.key ? 'rotate-180 text-blue-500' : ''"
                    fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>
                <Transition
                  enter-active-class="transition-all duration-200 ease-out overflow-hidden"
                  enter-from-class="max-h-0 opacity-0"
                  enter-to-class="max-h-96 opacity-100"
                  leave-active-class="transition-all duration-150 ease-in overflow-hidden"
                  leave-from-class="max-h-96 opacity-100"
                  leave-to-class="max-h-0 opacity-0">
                  <div v-if="mobileExpanded === item.key" class="ml-4 pl-3 border-l-2 border-blue-100 mt-1 mb-1 space-y-0.5">
                    <RouterLink v-for="child in item.children" :key="child.to"
                      :to="child.to"
                      @click="mobileOpen = false"
                      class="flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm text-slate-600 hover:bg-blue-50 hover:text-blue-700 transition-all">
                      <span class="text-base flex-shrink-0">{{ child.icon }}</span>
                      <span class="font-medium">{{ child.label }}</span>
                    </RouterLink>
                  </div>
                </Transition>
              </div>
            </template>

            <!-- Auth mobile -->
            <div class="pt-3 mt-2 border-t border-slate-100 space-y-1">
              <template v-if="session">
                <RouterLink to="/dashboard" @click="mobileOpen = false"
                  class="flex items-center px-4 py-3 rounded-xl text-sm font-semibold text-slate-700 hover:bg-blue-50 hover:text-blue-700 transition-all">
                  แผงควบคุม
                </RouterLink>
                <button @click="handleLogout"
                  class="w-full text-left flex items-center px-4 py-3 rounded-xl text-sm font-semibold text-red-500 hover:bg-red-50 transition-all">
                  ออกจากระบบ
                </button>
              </template>
              <RouterLink v-else to="/login" @click="mobileOpen = false"
                class="flex items-center justify-center gap-2 bg-primary text-white text-sm font-bold px-4 py-3 rounded-xl hover:bg-primary-dark transition-colors shadow-md">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/>
                </svg>
                เข้าสู่ระบบ
              </RouterLink>
            </div>
          </div>
        </div>
      </Transition>
    </nav>

    <!-- Spacer: 1px stripe + 64px nav = 65px -->
    <div class="h-[65px] flex-shrink-0"></div>

    <!-- Main content -->
    <main class="flex-grow">
      <RouterView v-slot="{ Component }">
        <Transition
          mode="out-in"
          enter-active-class="transition duration-200"
          enter-from-class="opacity-0 translate-y-2"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-150"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <!-- Footer -->
    <footer class="bg-white border-t border-slate-200 mt-10">
      <div class="max-w-7xl mx-auto px-4 py-10">
        <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
          <div class="flex items-center gap-3">
            <div v-if="config?.logo_url"
              class="w-10 h-10 rounded-xl overflow-hidden flex-shrink-0 shadow-md">
              <img :src="config.logo_url" class="w-full h-full object-cover" alt="logo"/>
            </div>
            <div v-else class="w-10 h-10 bg-primary rounded-xl flex items-center justify-center shadow-md flex-shrink-0">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
              </svg>
            </div>
            <div>
              <p class="font-extrabold text-slate-800">{{ areaName }}</p>
              <p class="text-xs text-slate-400 mt-0.5">{{ areaShort }}</p>
            </div>
          </div>
          <div class="flex flex-col items-start md:items-end gap-1">
            <div class="flex gap-4 text-sm text-slate-500">
              <span v-if="contactPhone">📞 {{ contactPhone }}</span>
              <span v-if="contactEmail">📧 {{ contactEmail }}</span>
            </div>
            <p class="text-xs text-slate-400">© 2568 {{ config?.area_name_short || 'กลุ่มนิเทศติดตามฯ' }} · Developed by Kruwinai</p>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<style>
/* ── Active nav link ใช้สี primary ─────────────────────────── */
.router-link-active.nav-link,
.router-link-exact-active.nav-link {
  color: var(--color-primary) !important;
  background-color: var(--color-primary-light) !important;
}
</style>
