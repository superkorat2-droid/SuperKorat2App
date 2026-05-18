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

const { config, fetchConfig } = useAreaConfig()

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
      { label: 'พัฒนาหลักสูตรการศึกษา',    to: '/curriculum',      icon: '📖', desc: 'หลักสูตรแกนกลาง ท้องถิ่น ปฐมวัย' },
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
  fetchConfig()
  const { data: { session: s } } = await supabase.auth.getSession()
  session.value = s
  supabase.auth.onAuthStateChange((_e, _s) => { session.value = _s })
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
  <div class="min-h-screen flex flex-col bg-slate-50 font-sarabun">

    <!-- ── Top accent line (3px primary) ─────────────────────────── -->
    <div class="fixed top-0 inset-x-0 z-50 h-[3px] bg-primary"></div>

    <!-- ── Navbar ─────────────────────────────────────────────────── -->
    <nav class="fixed top-[3px] inset-x-0 z-40 bg-white border-b border-slate-200/80">
      <div class="max-w-7xl mx-auto px-4 sm:px-6">
        <div class="flex items-center justify-between h-16">

          <!-- Logo -->
          <RouterLink to="/" class="flex items-center gap-3 flex-shrink-0 mr-6 group">
            <div v-if="config?.logo_url"
              class="w-9 h-9 rounded-lg overflow-hidden flex-shrink-0 border border-slate-200 group-hover:border-primary transition-colors">
              <img :src="config.logo_url" class="w-full h-full object-contain" alt="logo"/>
            </div>
            <div v-else
              class="w-9 h-9 bg-primary rounded-lg flex items-center justify-center flex-shrink-0">
              <svg class="w-4.5 h-4.5 text-white" style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
              </svg>
            </div>
            <div class="leading-tight min-w-0">
              <p class="text-[13px] font-bold text-slate-900 truncate max-w-[130px] sm:max-w-[260px] lg:max-w-none tracking-tight">{{ areaName }}</p>
              <p class="text-[10px] text-slate-400 truncate max-w-[130px] sm:max-w-[260px] lg:max-w-none mt-0.5">{{ areaShort }}</p>
            </div>
          </RouterLink>

          <!-- Desktop nav -->
          <div class="hidden lg:flex items-center gap-1 flex-1">
            <template v-for="item in navItems" :key="item.key">

              <!-- Simple link -->
              <RouterLink v-if="item.to && !item.children" :to="item.to"
                class="relative px-3 py-2 text-[13px] font-medium text-slate-600 hover:text-primary transition-colors whitespace-nowrap group">
                {{ item.label }}
                <span class="absolute inset-x-3 bottom-0 h-[2px] bg-primary scale-x-0 group-hover:scale-x-100 transition-transform origin-left rounded-full"></span>
              </RouterLink>

              <!-- Dropdown -->
              <div v-else class="relative"
                @mouseenter="showDropdown(item.key)"
                @mouseleave="scheduleHide()">
                <button :class="[
                  'relative flex items-center gap-1 px-3 py-2 text-[13px] font-medium transition-colors whitespace-nowrap group',
                  openDropdown === item.key ? 'text-primary' : 'text-slate-600 hover:text-primary'
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
                      'absolute top-[calc(100%+8px)] left-0 z-50 bg-white border border-slate-200 rounded-xl shadow-lg shadow-slate-200/60 py-1.5 origin-top-left',
                      item.key === 'work' ? 'w-72' : 'w-60'
                    ]"
                    @mouseenter="showDropdown(item.key)"
                    @mouseleave="scheduleHide()">
                    <RouterLink v-for="child in item.children" :key="child.to"
                      :to="child.to"
                      @click="openDropdown = null"
                      class="flex items-start gap-3 px-4 py-2.5 hover:bg-primary-light transition-colors group/c mx-1.5 rounded-lg">
                      <div class="flex-1 min-w-0">
                        <p class="text-[13px] font-semibold text-slate-700 group-hover/c:text-primary transition-colors">{{ child.label }}</p>
                        <p class="text-[11px] text-slate-400 mt-0.5 leading-snug">{{ child.desc }}</p>
                      </div>
                    </RouterLink>
                  </div>
                </Transition>
              </div>
            </template>
          </div>

          <!-- Right: auth + hamburger -->
          <div class="flex items-center gap-2 ml-2">
            <div class="hidden lg:flex items-center gap-1.5">
              <template v-if="session">
                <RouterLink to="/dashboard"
                  class="text-[13px] font-medium text-slate-600 hover:text-primary px-3 py-2 transition-colors">
                  แผงควบคุม
                </RouterLink>
                <button @click="handleLogout"
                  class="text-[13px] font-medium text-slate-400 hover:text-red-500 px-3 py-2 transition-colors">
                  ออกจากระบบ
                </button>
              </template>
              <RouterLink v-else to="/login"
                class="flex items-center gap-1.5 border border-primary text-primary text-[13px] font-semibold px-4 py-2 rounded-lg hover:bg-primary hover:text-white transition-all">
                <svg style="width:14px;height:14px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
                </svg>
                เข้าสู่ระบบ
              </RouterLink>
            </div>

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
        <div v-if="mobileOpen" class="lg:hidden border-t border-slate-100 bg-white max-h-[80vh] overflow-y-auto">
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
                  <RouterLink v-for="child in item.children" :key="child.to" :to="child.to"
                    @click="mobileOpen = false"
                    class="flex items-center px-3 py-2 rounded-lg text-[13px] text-slate-600 hover:bg-primary-light hover:text-primary transition-all">
                    {{ child.label }}
                  </RouterLink>
                </div>
              </div>
            </template>

            <!-- Auth -->
            <div class="pt-2 mt-1 border-t border-slate-100 space-y-px">
              <template v-if="session">
                <RouterLink to="/dashboard" @click="mobileOpen = false"
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

    <!-- Spacer: 3px + 64px nav -->
    <div class="h-[67px] flex-shrink-0"></div>

    <!-- Main content -->
    <main class="flex-grow">
      <RouterView v-slot="{ Component }">
        <Transition mode="out-in"
          enter-active-class="transition duration-200"
          enter-from-class="opacity-0 translate-y-1"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-150"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <!-- ── Footer ─────────────────────────────────────────────────── -->
    <footer class="bg-white border-t border-slate-200 mt-16">
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
            <p class="text-xs text-slate-400">© 2568 {{ config?.area_name_short || 'กลุ่มนิเทศฯ' }} · Developed by Kruwinai</p>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<style>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
