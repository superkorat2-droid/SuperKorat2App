<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()

// ── Banners ─────────────────────────────────────────────────────
const currentSlide  = ref(0)
const banners       = ref([])
const loadingBanners = ref(true)
let slideInterval = null

const fetchBanners = async () => {
  try {
    const { data } = await supabase
      .from('banners')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
    banners.value = data || []
  } catch { banners.value = [] }
  finally { loadingBanners.value = false }
}

const nextSlide = () => {
  if (banners.value.length > 1)
    currentSlide.value = (currentSlide.value + 1) % banners.value.length
}
const prevSlide = () => {
  if (banners.value.length > 1)
    currentSlide.value = (currentSlide.value - 1 + banners.value.length) % banners.value.length
}

onMounted(async () => {
  await fetchConfig()
  await fetchBanners()
  if (banners.value.length > 1)
    slideInterval = setInterval(nextSlide, 7000)
})
onUnmounted(() => { if (slideInterval) clearInterval(slideInterval) })

// ── Quick links ─────────────────────────────────────────────────
const quickLinks = [
  { label: 'กลุ่มนิเทศติดตามฯ',  icon: '🔍', color: 'bg-blue-50 text-blue-600',    href: '#/nithet' },
  { label: 'ดาวน์โหลดเอกสาร',    icon: '📄', color: 'bg-amber-50 text-amber-600',   href: '#/download' },
  { label: 'สร้าง QR Code',      icon: '📱', color: 'bg-emerald-50 text-emerald-600', href: '#/qrcode' },
  { label: 'ย่อลิงค์',           icon: '🔗', color: 'bg-purple-50 text-purple-600',  href: '#/url-short' },
  { label: 'ระบบ SAR Online',    icon: '📊', color: 'bg-rose-50 text-rose-600',      href: '#' },
  { label: 'คลังสื่อนวัตกรรม',   icon: '💡', color: 'bg-indigo-50 text-indigo-600', href: '#' },
  { label: 'ลงทะเบียนอบรม',      icon: '📝', color: 'bg-cyan-50 text-cyan-600',     href: '#' },
  { label: 'ติดต่อเรา',          icon: '📞', color: 'bg-slate-50 text-slate-600',   href: '#/contact' },
]

// ── Stats (mock — จะเชื่อมจริงทีหลัง) ───────────────────────────
const stats = [
  { label: 'โรงเรียนในสังกัด', value: '—', icon: '🏫' },
  { label: 'ศึกษานิเทศก์',     value: '—', icon: '👨‍🏫' },
  { label: 'ผลงานที่เผยแพร่',  value: '—', icon: '🏆' },
  { label: 'เอกสารดาวน์โหลด',  value: '—', icon: '📂' },
]
</script>

<template>
  <div class="font-sarabun text-slate-800 bg-slate-50">

    <!-- ── SECTION 1: BANNER / HERO ─────────────────────────── -->
    <section class="max-w-7xl mx-auto px-0 md:px-4 mt-0 md:mt-4">

      <!-- มีแบนเนอร์จาก DB -->
      <div v-if="!loadingBanners && banners.length > 0"
        class="relative overflow-hidden rounded-none md:rounded-[2rem] shadow-xl aspect-video bg-slate-900 group">
        <div v-for="(slide, i) in banners" :key="slide.id"
          class="absolute inset-0 transition-all duration-1000"
          :class="i === currentSlide ? 'opacity-100' : 'opacity-0'">
          <img v-if="slide.banner_type !== 'video'" :src="slide.image_url" class="w-full h-full object-cover"/>
          <video v-else :src="slide.image_url" class="w-full h-full object-cover" autoplay muted loop playsinline/>
          <div v-if="slide.title" class="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent flex items-end">
            <div class="p-8 md:p-14">
              <h2 class="text-2xl md:text-5xl font-extrabold text-white drop-shadow-xl">{{ slide.title }}</h2>
              <p v-if="slide.subtitle" class="text-white/80 mt-2 text-sm md:text-lg">{{ slide.subtitle }}</p>
            </div>
          </div>
        </div>
        <template v-if="banners.length > 1">
          <button @click="prevSlide" class="absolute left-4 top-1/2 -translate-y-1/2 w-10 h-10 bg-black/30 hover:bg-primary text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M15 19l-7-7 7-7"/></svg>
          </button>
          <button @click="nextSlide" class="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 bg-black/30 hover:bg-primary text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 5l7 7-7 7"/></svg>
          </button>
          <div class="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5">
            <button v-for="(_, i) in banners" :key="i" @click="currentSlide=i"
              :class="['w-2 h-2 rounded-full transition-all', i===currentSlide ? 'bg-white w-6' : 'bg-white/50']"/>
          </div>
        </template>
      </div>

      <!-- Fallback Hero (ยังไม่มีแบนเนอร์) -->
      <div v-else-if="!loadingBanners"
        class="relative overflow-hidden rounded-none md:rounded-[2rem] gradient-primary min-h-[320px] md:min-h-[420px] flex items-center">
        <!-- Pattern bg -->
        <div class="absolute inset-0 opacity-10">
          <svg width="100%" height="100%"><defs><pattern id="dots" width="32" height="32" patternUnits="userSpaceOnUse"><circle cx="16" cy="16" r="1.5" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#dots)"/></svg>
        </div>
        <!-- Decorative circles -->
        <div class="absolute -top-20 -right-20 w-72 h-72 rounded-full bg-white/5"></div>
        <div class="absolute -bottom-12 -left-12 w-48 h-48 rounded-full bg-white/5"></div>

        <div class="relative max-w-7xl mx-auto px-8 md:px-16 py-16 flex flex-col md:flex-row items-center gap-10">
          <!-- Logo -->
          <div v-if="config?.logo_url" class="w-28 h-28 md:w-36 md:h-36 rounded-3xl overflow-hidden shadow-2xl flex-shrink-0 bg-white/10 p-2">
            <img :src="config.logo_url" class="w-full h-full object-contain"/>
          </div>
          <div v-else class="w-24 h-24 md:w-32 md:h-32 rounded-3xl bg-white/20 flex items-center justify-center text-5xl md:text-6xl flex-shrink-0 shadow-xl">
            📋
          </div>
          <!-- Text -->
          <div class="text-white text-center md:text-left">
            <p class="text-white/70 text-sm font-medium mb-2 uppercase tracking-widest">{{ config?.area_type || 'สพป.' }}</p>
            <h1 class="text-2xl md:text-4xl lg:text-5xl font-extrabold leading-tight mb-3 drop-shadow">
              {{ config?.area_name || 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา' }}
            </h1>
            <p class="text-white/80 text-base md:text-lg font-medium">
              {{ [config?.province, config?.area_number].filter(Boolean).join(' ') || 'สำนักงานเขตพื้นที่การศึกษา' }}
            </p>
            <div class="flex flex-wrap gap-3 mt-6 justify-center md:justify-start">
              <a href="#/nithet" class="px-6 py-2.5 bg-white text-primary font-bold rounded-2xl text-sm shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all">
                🔍 เกี่ยวกับกลุ่มนิเทศ
              </a>
              <a href="#/contact" class="px-6 py-2.5 bg-white/20 text-white font-bold rounded-2xl text-sm border border-white/30 hover:bg-white/30 transition-all">
                📞 ติดต่อเรา
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- Loading skeleton -->
      <div v-else class="rounded-none md:rounded-[2rem] bg-slate-200 animate-pulse min-h-[320px] md:min-h-[420px]"></div>
    </section>

    <!-- ── SECTION 2: STATS ──────────────────────────────────── -->
    <section class="max-w-7xl mx-auto px-4 -mt-6 relative z-10">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div v-for="s in stats" :key="s.label"
          class="bg-white rounded-2xl shadow-md border border-slate-100 p-5 flex items-center gap-4">
          <div class="text-3xl">{{ s.icon }}</div>
          <div>
            <p class="text-xl font-extrabold text-slate-800">{{ s.value }}</p>
            <p class="text-xs text-slate-500 font-medium">{{ s.label }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ── SECTION 3: E-SERVICES ─────────────────────────────── -->
    <section class="py-16 md:py-20">
      <div class="max-w-7xl mx-auto px-4">
        <div class="text-center mb-12">
          <span class="text-primary font-bold uppercase text-xs tracking-widest mb-2 block">E-Service Center</span>
          <h2 class="text-3xl md:text-4xl font-extrabold text-slate-900">บริการออนไลน์</h2>
          <div class="h-1 w-16 bg-primary mx-auto mt-4 rounded-full"></div>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <a v-for="link in quickLinks" :key="link.label" :href="link.href"
            class="group flex flex-col items-center p-6 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
            <div :class="[link.color, 'w-14 h-14 rounded-2xl flex items-center justify-center text-3xl mb-4 group-hover:scale-110 transition-transform']">
              {{ link.icon }}
            </div>
            <span class="text-sm font-bold text-slate-700 text-center leading-snug group-hover:text-primary transition-colors">
              {{ link.label }}
            </span>
          </a>
        </div>
      </div>
    </section>

    <!-- ── SECTION 4: CTA ────────────────────────────────────── -->
    <section class="pb-16">
      <div class="max-w-7xl mx-auto px-4">
        <div class="gradient-primary rounded-3xl p-8 md:p-12 text-center text-white relative overflow-hidden">
          <div class="absolute inset-0 opacity-10">
            <svg width="100%" height="100%"><defs><pattern id="d2" width="40" height="40" patternUnits="userSpaceOnUse"><circle cx="20" cy="20" r="1.5" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#d2)"/></svg>
          </div>
          <div class="relative">
            <h2 class="text-2xl md:text-3xl font-extrabold mb-3">ระบบกลุ่มนิเทศ ติดตามและประเมินผล</h2>
            <p class="text-white/80 mb-6 text-sm md:text-base">ศูนย์กลางข้อมูลการนิเทศ ติดตาม และประเมินผลการจัดการศึกษา</p>
            <div class="flex flex-wrap gap-3 justify-center">
              <a href="#/nithet" class="px-6 py-3 bg-white text-primary font-bold rounded-2xl text-sm shadow-lg hover:-translate-y-0.5 transition-all">
                🔍 ดูข้อมูลกลุ่มนิเทศ
              </a>
              <a href="#/download" class="px-6 py-3 bg-white/20 border border-white/40 text-white font-bold rounded-2xl text-sm hover:bg-white/30 transition-all">
                📂 ดาวน์โหลดเอกสาร
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
