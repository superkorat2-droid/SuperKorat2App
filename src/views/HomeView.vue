<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig, DEFAULT_HOME_SECTIONS } from '../composables/useAreaConfig'

const router = useRouter()

const { config, fetchConfig } = useAreaConfig()

// ── Banners ─────────────────────────────────────────────────────
const currentSlide   = ref(0)
const banners        = ref([])
const loadingBanners = ref(true)
let slideInterval = null

function extractYoutubeId(url) {
  if (!url) return ''
  const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
  return m ? m[1] : url.trim()
}
// thumbnail คุณภาพสูงสุด (อาจไม่มีใน clip สั้น)
function youtubeThumbnailFull(url) {
  return `https://img.youtube.com/vi/${extractYoutubeId(url)}/maxresdefault.jpg`
}
// fallback ถ้า maxresdefault ไม่มี
function youtubeThumbnailSD(url) {
  return `https://img.youtube.com/vi/${extractYoutubeId(url)}/hqdefault.jpg`
}
// URL สำหรับคลิกเปิด YouTube
function youtubeWatchUrl(url) {
  return `https://www.youtube.com/watch?v=${extractYoutubeId(url)}`
}
// ยังเก็บไว้ใช้ใน admin preview ถ้าต้องการ
function youtubeEmbed(url) {
  const id = extractYoutubeId(url)
  return `https://www.youtube.com/embed/${id}?autoplay=1&mute=1&loop=1&playlist=${id}&controls=0`
}

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
  await Promise.all([fetchBanners(), fetchLatestNews()])
  if (banners.value.length > 1)
    slideInterval = setInterval(nextSlide, 7000)
})
onUnmounted(() => { if (slideInterval) clearInterval(slideInterval) })

// ── Quick links ─────────────────────────────────────────────────
const quickLinks = [
  {
    label: 'กลุ่มนิเทศติดตามฯ', href: '#/nithet',
    path: 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
    fill: 'none',
  },
  {
    label: 'ดาวน์โหลดเอกสาร', href: '#/download',
    path: 'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3',
    fill: 'none',
  },
  {
    label: 'สร้าง QR Code', href: '#/qrcode',
    path: 'M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0113.5 9.375v-4.5z M6.75 6.75h.75v.75h-.75v-.75zM6.75 16.5h.75v.75h-.75v-.75zM16.5 6.75h.75v.75h-.75v-.75zM13.5 13.5h.75v.75h-.75v-.75zM13.5 19.5h.75v.75h-.75v-.75zM19.5 13.5h.75v.75h-.75v-.75zM19.5 19.5h.75v.75h-.75v-.75zM16.5 16.5h.75v.75h-.75v-.75z',
    fill: 'none',
  },
  {
    label: 'ย่อลิงค์', href: '#/url-short',
    path: 'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244',
    fill: 'none',
  },
  {
    label: 'ระบบ SAR Online', href: '#',
    path: 'M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z',
    fill: 'none',
  },
  {
    label: 'คลังสื่อนวัตกรรม', href: '#',
    path: 'M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18',
    fill: 'none',
  },
  {
    label: 'ลงทะเบียนอบรม', href: '#',
    path: 'M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10',
    fill: 'none',
  },
  {
    label: 'ติดต่อเรา', href: '#/contact',
    path: 'M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z',
    fill: 'none',
  },
]

// ── Latest News ──────────────────────────────────────────────────
const latestNews    = ref([])
const loadingNews   = ref(true)

async function fetchLatestNews() {
  const { data } = await supabase
    .from('news')
    .select('id, title, excerpt, cover_url, category, published_at, is_pinned, view_count')
    .eq('is_published', true)
    .order('is_pinned',    { ascending: false })
    .order('published_at', { ascending: false })
    .limit(8)
  latestNews.value = data || []
  loadingNews.value = false
}

const catLabel = {
  pr: 'ประชาสัมพันธ์', supervision: 'นิเทศการศึกษา',
  training: 'อบรม/สัมมนา', policy: 'นโยบาย', other: 'ทั่วไป',
}
const catStyle = {
  pr:         'bg-blue-100 text-blue-700',
  supervision:'bg-primary-light text-primary',
  training:   'bg-emerald-100 text-emerald-700',
  policy:     'bg-amber-100 text-amber-700',
  other:      'bg-slate-100 text-slate-600',
}

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric' })
}

// ── Home sections (ordered, from config) ─────────────────────────
const orderedSections = computed(() => {
  const raw = config.value?.home_sections
  const arr = Array.isArray(raw) && raw.length ? raw : DEFAULT_HOME_SECTIONS
  return [...arr].sort((a, b) => a.order - b.order)
})

// ── Stats ────────────────────────────────────────────────────────
const stats = [
  {
    label: 'โรงเรียนในสังกัด', value: '—',
    path: 'M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z',
  },
  {
    label: 'ศึกษานิเทศก์', value: '—',
    path: 'M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z',
  },
  {
    label: 'ผลงานที่เผยแพร่', value: '—',
    path: 'M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 002.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 012.916.52 6.003 6.003 0 01-5.395 4.972m0 0a6.726 6.726 0 01-2.749 1.35m0 0a6.772 6.772 0 01-3.044 0',
  },
  {
    label: 'เอกสารดาวน์โหลด', value: '—',
    path: 'M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776',
  },
]
</script>

<template>
  <div class="font-sarabun text-slate-800 bg-slate-50">

    <!-- ── SECTION 1: BANNER / HERO ─────────────────────────────── -->
    <section class="max-w-7xl mx-auto px-0 md:px-4 mt-0 md:mt-4">

      <!-- แบนเนอร์จาก DB -->
      <div v-if="!loadingBanners && banners.length > 0"
        class="relative overflow-hidden rounded-none md:rounded-[1.75rem] shadow-xl aspect-video bg-slate-900 group">
        <div v-for="(slide, i) in banners" :key="slide.id"
          class="absolute inset-0 transition-all duration-1000"
          :class="i === currentSlide ? 'opacity-100' : 'opacity-0'">
          <!-- image -->
          <img v-if="slide.banner_type === 'image' || !slide.banner_type"
            :src="slide.image_url" class="w-full h-full object-cover"/>
          <!-- video file — autoplay muted loop (ดีที่สุด) -->
          <video v-else-if="slide.banner_type === 'video'"
            :src="slide.image_url" class="w-full h-full object-cover"
            autoplay muted loop playsinline/>
          <!-- youtube — แสดง thumbnail + play overlay (ไม่มีโฆษณา ไม่มีปัญหา autoplay) -->
          <template v-else-if="slide.banner_type === 'youtube'">
            <img :src="youtubeThumbnailFull(slide.image_url)"
              class="w-full h-full object-cover"
              @error="$event.target.src = youtubeThumbnailSD(slide.image_url)"/>
            <!-- play button overlay — คลิกเปิด YouTube ในแท็บใหม่ -->
            <a :href="youtubeWatchUrl(slide.image_url)" target="_blank" rel="noopener"
              class="absolute inset-0 flex items-center justify-center group/play">
              <div class="w-16 h-16 md:w-20 md:h-20 rounded-full bg-black/60 flex items-center justify-center
                          backdrop-blur-sm border-2 border-white/40
                          group-hover/play:bg-red-600 group-hover/play:border-red-500
                          transition-all duration-300 shadow-2xl">
                <svg class="w-7 h-7 md:w-9 md:h-9 text-white ml-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              </div>
            </a>
          </template>
          <div v-if="slide.title" class="absolute inset-0 bg-gradient-to-t from-black/65 via-transparent to-transparent flex items-end">
            <div class="p-8 md:p-14">
              <h2 class="text-2xl md:text-5xl font-extrabold text-white drop-shadow-xl">{{ slide.title }}</h2>
              <p v-if="slide.subtitle" class="text-white/75 mt-2 text-sm md:text-lg">{{ slide.subtitle }}</p>
            </div>
          </div>
        </div>
        <template v-if="banners.length > 1">
          <button @click="prevSlide"
            class="absolute left-4 top-1/2 -translate-y-1/2 w-10 h-10 bg-black/25 hover:bg-primary text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <button @click="nextSlide"
            class="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 bg-black/25 hover:bg-primary text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
            </svg>
          </button>
          <div class="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5">
            <button v-for="(_, i) in banners" :key="i" @click="currentSlide = i"
              :class="['rounded-full transition-all', i === currentSlide ? 'bg-white w-6 h-2' : 'bg-white/45 w-2 h-2']"/>
          </div>
        </template>
      </div>

      <!-- Fallback Hero -->
      <div v-else-if="!loadingBanners"
        class="relative overflow-hidden rounded-none md:rounded-[1.75rem] gradient-primary min-h-[320px] md:min-h-[440px] flex items-center">
        <!-- Dot grid -->
        <div class="absolute inset-0 opacity-[0.06]">
          <svg width="100%" height="100%">
            <defs>
              <pattern id="dot-hero" width="28" height="28" patternUnits="userSpaceOnUse">
                <circle cx="14" cy="14" r="1.2" fill="white"/>
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#dot-hero)"/>
          </svg>
        </div>
        <!-- Accent orb -->
        <div class="absolute -top-24 -right-24 w-80 h-80 rounded-full"
          style="background: radial-gradient(circle, rgba(255,255,255,0.07) 0%, transparent 70%)"></div>
        <div class="absolute -bottom-16 -left-16 w-60 h-60 rounded-full"
          style="background: radial-gradient(circle, rgba(255,255,255,0.05) 0%, transparent 70%)"></div>

        <div class="relative max-w-7xl mx-auto px-8 md:px-16 py-16 flex flex-col md:flex-row items-center gap-10 w-full">
          <!-- Logo or SVG building icon -->
          <div class="flex-shrink-0">
            <div v-if="config?.logo_url"
              class="w-28 h-28 md:w-36 md:h-36 rounded-3xl overflow-hidden shadow-2xl bg-white/10 p-3 ring-1 ring-white/20">
              <img :src="config.logo_url" class="w-full h-full object-contain"/>
            </div>
            <div v-else
              class="w-24 h-24 md:w-32 md:h-32 rounded-3xl bg-white/10 ring-1 ring-white/20 flex items-center justify-center shadow-xl">
              <svg class="w-12 h-12 md:w-16 md:h-16 text-white/70" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round"
                  d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
              </svg>
            </div>
          </div>

          <!-- Text -->
          <div class="text-white text-center md:text-left flex-1">
            <p class="text-white/55 text-xs font-semibold mb-2 uppercase tracking-[0.2em]">
              {{ config?.area_type || 'สพป.' }}
            </p>
            <h1 class="text-2xl md:text-4xl lg:text-5xl font-extrabold leading-tight mb-3">
              {{ config?.area_name || 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา' }}
            </h1>
            <p class="text-white/65 text-base md:text-lg font-medium mb-8">
              {{ config?.tagline || [config?.province, config?.area_number].filter(Boolean).join(' ') || 'สำนักงานเขตพื้นที่การศึกษา' }}
            </p>
            <div class="flex flex-wrap gap-3 justify-center md:justify-start">
              <a href="#/nithet"
                class="inline-flex items-center gap-2 px-6 py-2.5 bg-white text-primary font-bold rounded-2xl text-sm shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                เกี่ยวกับกลุ่มนิเทศ
              </a>
              <a href="#/contact"
                class="inline-flex items-center gap-2 px-6 py-2.5 bg-white/10 ring-1 ring-white/30 text-white font-bold rounded-2xl text-sm hover:bg-white/20 transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"/>
                </svg>
                ติดต่อเรา
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- Loading skeleton -->
      <div v-else class="rounded-none md:rounded-[1.75rem] bg-slate-200 animate-pulse min-h-[320px] md:min-h-[440px]"></div>
    </section>

    <!-- ── DYNAMIC SECTIONS (ลำดับและสีจาก Admin) ───────────────── -->
    <template v-for="sec in orderedSections" :key="sec.key">
      <template v-if="sec.visible">

        <!-- ══ NEWS ══ -->
        <section v-if="sec.key === 'news'"
          :style="{ backgroundColor: sec.bg || '#ffffff' }"
          class="py-12 md:py-16">
          <div class="max-w-7xl mx-auto px-4">
            <div class="flex items-end justify-between mb-8">
              <div>
                <span class="text-secondary font-bold uppercase text-xs tracking-[0.18em] block mb-1">Latest News</span>
                <h2 class="text-2xl md:text-3xl font-extrabold text-slate-900 accent-line">{{ sec.title || 'ข่าวสารและประชาสัมพันธ์' }}</h2>
              </div>
              <a href="#/news" class="hidden sm:flex items-center gap-1.5 text-sm font-bold text-primary hover:gap-3 transition-all">
                ดูทั้งหมด
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                </svg>
              </a>
            </div>
            <!-- Loading -->
            <div v-if="loadingNews" class="grid grid-cols-2 md:grid-cols-4 gap-5">
              <div v-for="i in 8" :key="i" class="rounded-2xl overflow-hidden animate-pulse">
                <div class="h-40 bg-slate-100"></div>
                <div class="p-4 space-y-2 bg-white border border-t-0 border-slate-100">
                  <div class="h-4 bg-slate-100 rounded w-3/4"></div>
                  <div class="h-3 bg-slate-100 rounded w-full"></div>
                </div>
              </div>
            </div>
            <!-- Empty -->
            <div v-else-if="latestNews.length === 0" class="text-center py-12 text-slate-400 text-sm">
              ยังไม่มีข่าวสาร
            </div>
            <!-- 8 cards — 4 col grid -->
            <div v-else class="grid grid-cols-2 md:grid-cols-4 gap-5">
              <div v-for="n in latestNews" :key="n.id"
                @click="router.push(`/news/${n.id}`)"
                class="group bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden cursor-pointer hover:shadow-xl hover:-translate-y-1 transition-all duration-300">
                <div class="relative aspect-video bg-slate-100 overflow-hidden ring-1 ring-inset ring-slate-900/8">
                  <img v-if="n.cover_url" :src="n.cover_url"
                    class="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-500"/>
                  <div v-else class="w-full h-full flex items-center justify-center gradient-primary opacity-80">
                    <svg class="w-10 h-10 text-white/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
                    </svg>
                  </div>
                  <div v-if="n.is_pinned" class="absolute top-2 left-2">
                    <span class="flex items-center gap-1 px-2 py-0.5 bg-amber-400 text-white text-[10px] font-bold rounded-full shadow">
                      <svg class="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24"><path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/></svg>
                      ปักหมุด
                    </span>
                  </div>
                  <div class="absolute bottom-2 left-2">
                    <span :class="['text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow-sm', catStyle[n.category] || 'bg-slate-100 text-slate-600']">
                      {{ catLabel[n.category] || n.category }}
                    </span>
                  </div>
                </div>
                <div class="p-4">
                  <p class="font-extrabold text-slate-800 text-sm leading-snug line-clamp-2 group-hover:text-primary transition-colors duration-200 mb-2">{{ n.title }}</p>
                  <p v-if="n.excerpt" class="text-xs text-slate-400 line-clamp-2 leading-relaxed mb-3">{{ n.excerpt }}</p>
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2.5">
                      <span class="text-[11px] text-slate-400">{{ fmtDate(n.published_at) }}</span>
                      <span class="flex items-center gap-0.5 text-[11px] text-slate-400">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        </svg>
                        {{ n.view_count || 0 }}
                      </span>
                    </div>
                    <span class="text-[11px] font-bold text-primary flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      อ่านต่อ
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                      </svg>
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <div class="text-center mt-8 sm:hidden">
              <a href="#/news" class="inline-flex items-center gap-2 px-6 py-2.5 border border-primary text-primary font-bold rounded-2xl text-sm hover:bg-primary hover:text-white transition-all">
                ดูข่าวทั้งหมด
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                </svg>
              </a>
            </div>
          </div>
        </section>

        <!-- ══ SERVICES (stats + e-services) ══ -->
        <section v-else-if="sec.key === 'services'" :style="{ backgroundColor: sec.bg || '#f8fafc' }">
          <div class="max-w-7xl mx-auto px-4 pt-10">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div v-for="s in stats" :key="s.label"
                class="bg-white rounded-2xl shadow-md border border-slate-100 p-5 flex items-center gap-4 hover:shadow-lg transition-shadow">
                <div class="w-11 h-11 rounded-xl bg-primary-light flex items-center justify-center flex-shrink-0">
                  <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" :d="s.path"/>
                  </svg>
                </div>
                <div>
                  <p class="text-xl font-extrabold text-slate-800">{{ s.value }}</p>
                  <p class="text-xs text-slate-500 font-medium leading-snug">{{ s.label }}</p>
                </div>
              </div>
            </div>
          </div>
          <div class="py-12 md:py-16">
            <div class="max-w-7xl mx-auto px-4">
              <div class="text-center mb-12">
                <span class="text-secondary font-bold uppercase text-xs tracking-[0.18em] mb-2 block">E-Service Center</span>
                <h2 class="text-3xl md:text-4xl font-extrabold text-slate-900 accent-line-center">{{ sec.title || 'บริการออนไลน์' }}</h2>
              </div>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <a v-for="link in quickLinks" :key="link.label" :href="link.href"
                  class="group flex flex-col items-center p-6 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-xl hover:-translate-y-1 hover:border-primary/20 transition-all duration-300">
                  <div class="w-14 h-14 rounded-2xl bg-primary-light flex items-center justify-center mb-4 group-hover:bg-primary transition-colors duration-300">
                    <svg class="w-6 h-6 text-primary group-hover:text-white transition-colors duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" :d="link.path"/>
                    </svg>
                  </div>
                  <span class="text-sm font-bold text-slate-700 text-center leading-snug group-hover:text-primary transition-colors">{{ link.label }}</span>
                </a>
              </div>
            </div>
          </div>
        </section>

        <!-- ══ CTA ══ -->
        <section v-else-if="sec.key === 'cta'"
          :style="{ backgroundColor: sec.bg || '#ffffff' }"
          class="pb-16">
          <div class="max-w-7xl mx-auto px-4">
            <div class="gradient-primary rounded-3xl p-8 md:p-12 text-center text-white relative overflow-hidden">
              <div class="absolute inset-0 opacity-[0.06]">
                <svg width="100%" height="100%">
                  <defs><pattern id="grid-cta" width="32" height="32" patternUnits="userSpaceOnUse">
                    <path d="M 32 0 L 0 0 0 32" fill="none" stroke="white" stroke-width="0.5"/>
                  </pattern></defs>
                  <rect width="100%" height="100%" fill="url(#grid-cta)"/>
                </svg>
              </div>
              <div class="absolute -right-16 -bottom-16 w-56 h-56 rounded-full"
                style="background: radial-gradient(circle, rgba(255,255,255,0.08) 0%, transparent 70%)"></div>
              <div class="relative">
                <div class="w-8 h-0.5 bg-secondary mx-auto mb-5"></div>
                <h2 class="text-2xl md:text-3xl font-extrabold mb-3">{{ sec.title || 'ระบบกลุ่มนิเทศ ติดตามและประเมินผล' }}</h2>
                <p class="text-white/65 mb-8 text-sm md:text-base max-w-lg mx-auto">ศูนย์กลางข้อมูลการนิเทศ ติดตาม และประเมินผลการจัดการศึกษา</p>
                <div class="flex flex-wrap gap-3 justify-center">
                  <a href="#/nithet" class="inline-flex items-center gap-2 px-6 py-3 bg-white text-primary font-bold rounded-2xl text-sm shadow-lg hover:-translate-y-0.5 transition-all">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    ดูข้อมูลกลุ่มนิเทศ
                  </a>
                  <a href="#/download" class="inline-flex items-center gap-2 px-6 py-3 bg-white/10 ring-1 ring-white/30 text-white font-bold rounded-2xl text-sm hover:bg-white/20 transition-all">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776"/>
                    </svg>
                    ดาวน์โหลดเอกสาร
                  </a>
                </div>
              </div>
            </div>
          </div>
        </section>

      </template>
    </template>
    <!-- ── /DYNAMIC SECTIONS ────────────────────────────────────── -->

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
