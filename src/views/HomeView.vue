<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig, DEFAULT_HOME_SECTIONS } from '../composables/useAreaConfig'
import ImageLinkGallery from '../components/ImageLinkGallery.vue'
import { ICON_MAP } from '../composables/useIcons.js'
import { useEducationNews } from '../composables/useEducationNews'
import { useTheme } from '../composables/useTheme'
import { TYPE_LABEL, TYPE_COLOR, formatEventDateRange } from '../composables/useNithetEventMeta'

const router = useRouter()

const { config, fetchConfig } = useAreaConfig()
const { isDark } = useTheme()

// ── Section background style ─────────────────────────────────────
// สีพื้นหลังที่ admin ตั้งไว้เป็นโทนสว่างเสมอ (ออกแบบไว้สำหรับโหมดสว่างเท่านั้น)
// โหมดมืดเลยไม่ใช้สีนี้ ปล่อยให้ใช้พื้นหลังเข้มมาตรฐานแทน ไม่งั้นตัวหนังสือสีขาว (dark:text-*) จะกลืนกับพื้นสว่างจนมองไม่เห็น
function getBgStyle(sec) {
  if (isDark.value) return {}
  const c1 = sec.bg  || '#ffffff'
  const c2 = sec.bg2 || '#f1f5f9'
  switch (sec.bg_type) {
    case 'gradient-tb': return { background: `linear-gradient(to bottom, ${c1}, ${c2})` }
    case 'gradient-bt': return { background: `linear-gradient(to top, ${c1}, ${c2})` }
    case 'gradient-lr': return { background: `linear-gradient(to right, ${c1}, ${c2})` }
    case 'gradient-rl': return { background: `linear-gradient(to left, ${c1}, ${c2})` }
    case 'radial':      return { background: `radial-gradient(ellipse at center, ${c1} 0%, ${c2} 100%)` }
    case 'radial-in':   return { background: `radial-gradient(ellipse at center, ${c2} 0%, ${c1} 100%)` }
    default:            return { backgroundColor: c1 }
  }
}

// ── Banners ─────────────────────────────────────────────────────
const currentSlide   = ref(0)
const banners        = ref([])
const loadingBanners = ref(true)
let slideTimer = null

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
// path สำหรับ router-link จาก link_url ภายใน (รองรับทั้ง "#/page" และ "/page")
function bannerInternalPath(url) {
  if (!url) return '/'
  return url.startsWith('#') ? url.slice(1) : url
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

// ── ตัวจับเวลาเลื่อนสไลด์ — อ่านระยะเวลาต่อแบนเนอร์ (duration_seconds) แทนค่าคงที่เดียวกันหมด ──
function scheduleNextSlide() {
  clearTimeout(slideTimer)
  if (banners.value.length <= 1) return
  const seconds = banners.value[currentSlide.value]?.duration_seconds || 7
  slideTimer = setTimeout(() => { nextSlide(); scheduleNextSlide() }, Math.max(seconds, 1) * 1000)
}
function goToSlide(i) {
  currentSlide.value = i
  scheduleNextSlide()
}

// ── ปัดซ้าย/ขวาเปลี่ยนแบนเนอร์ (มือถือ) ────────────────────────────
// swiping = true เฉพาะตอนลากจริง (ระยะทางแนวนอน > แนวตั้ง และเกิน threshold)
// ใช้กันไม่ให้ลิงก์ทับแบนเนอร์ทำงานตอนปัด แต่แตะเฉยๆ (ไม่ลาก) ลิงก์ยังทำงานปกติ
const touchStartX = ref(0)
const touchStartY = ref(0)
const swiping     = ref(false)
let swipeResetTimer = null

function onBannerTouchStart(e) {
  touchStartX.value = e.touches[0].clientX
  touchStartY.value = e.touches[0].clientY
  swiping.value = false
}
function onBannerTouchMove(e) {
  const dx = e.touches[0].clientX - touchStartX.value
  const dy = e.touches[0].clientY - touchStartY.value
  if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy)) swiping.value = true
}
function onBannerTouchEnd(e) {
  if (!swiping.value) return
  const dx = e.changedTouches[0].clientX - touchStartX.value
  if (Math.abs(dx) > 40) { dx < 0 ? nextSlide() : prevSlide(); scheduleNextSlide() }
  // เผื่อ browser ยิง click ตามหลัง touchend ให้ onBannerLinkClick กันไว้อีกชั้น
  clearTimeout(swipeResetTimer)
  swipeResetTimer = setTimeout(() => { swiping.value = false }, 300)
}
function onBannerLinkClick(e) {
  if (swiping.value) e.preventDefault()
}

// ── Supervision list (home section) ──────────────────────────────
const supervisionForms   = ref([])
const loadingSupervision = ref(false)
const supervisionStatus  = ref({})   // { [formId]: { total, responded, responded_schools, pending_schools } }
const loadingStatus      = ref({})   // { [formId]: boolean }
const expandedStatus     = ref(null) // formId ที่กำลังขยาย
const userSession        = ref(null)

const needsSupervisionSection = computed(() =>
  orderedSections.value.some(s => s.key === 'supervision_list' && s.visible)
)

const { news: educationNews, loading: loadingEduNews, error: eduNewsError, fetchNews: fetchEduNews } = useEducationNews()
const needsEduNewsSection = computed(() =>
  orderedSections.value.some(s => s.key === 'education_news' && s.visible)
)

// ── Nithet calendar (home section) ────────────────────────────────
const nithetEvents        = ref([])
const loadingNithetEvents = ref(false)
const NITHET_HOME_LIMIT = 4

const needsNithetCalendarSection = computed(() =>
  orderedSections.value.some(s => s.key === 'nithet_calendar' && s.visible)
)

async function fetchNithetEvents() {
  loadingNithetEvents.value = true
  const { data } = await supabase.rpc('get_nithet_events_public')
  const today = new Date().toISOString().slice(0, 10)
  nithetEvents.value = (Array.isArray(data) ? data : [])
    .filter(e => e.end_date >= today)
    .sort((a, b) => a.start_date.localeCompare(b.start_date) || (a.start_time || '').localeCompare(b.start_time || ''))
    .slice(0, NITHET_HOME_LIMIT)
  loadingNithetEvents.value = false
}

async function fetchSupervisionForms() {
  loadingSupervision.value = true
  const { data } = await supabase.rpc('get_supervision_list_public')
  supervisionForms.value = Array.isArray(data) ? data : []
  loadingSupervision.value = false
}

async function loadFormStatus(form) {
  if (form.status_visibility === 'hidden') return
  if (form.status_visibility === 'authenticated' && !userSession.value) return
  if (supervisionStatus.value[form.id]) {
    // toggle collapse
    expandedStatus.value = expandedStatus.value === form.id ? null : form.id
    return
  }
  loadingStatus.value = { ...loadingStatus.value, [form.id]: true }
  const { data } = await supabase.rpc('get_supervision_status_public', { p_form_id: form.id })
  if (data && !data.error) {
    supervisionStatus.value = { ...supervisionStatus.value, [form.id]: data }
  }
  loadingStatus.value = { ...loadingStatus.value, [form.id]: false }
  expandedStatus.value = form.id
}

function formatDeadline(d) {
  if (!d) return null
  const date = new Date(d)
  const now  = new Date()
  const diff = Math.ceil((date - now) / 86400000)
  const label = date.toLocaleDateString('th-TH', { month: 'short', day: 'numeric' })
  if (diff < 0)  return { label: `หมดเขต ${label}`, color: 'text-red-500 bg-red-50' }
  if (diff <= 7) return { label: `อีก ${diff} วัน (${label})`, color: 'text-amber-600 bg-amber-50' }
  return { label: `ถึง ${label}`, color: 'text-slate-500 bg-slate-100' }
}

onMounted(async () => {
  await fetchConfig()
  const { data: { session: s } } = await supabase.auth.getSession()
  userSession.value = s
  await Promise.all([fetchBanners(), fetchLatestNews()])
  scheduleNextSlide()
  if (needsSupervisionSection.value) fetchSupervisionForms()
  if (needsEduNewsSection.value) fetchEduNews()
  if (needsNithetCalendarSection.value) fetchNithetEvents()

  // รีโหลดแบบนิเทศเมื่อ tab กลับมา (หลังแก้ไขในหน้า admin)
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && needsSupervisionSection.value) {
      supervisionStatus.value = {}
      expandedStatus.value    = null
      fetchSupervisionForms()
    }
  })
})
onUnmounted(() => {
  clearTimeout(slideTimer)
  clearTimeout(swipeResetTimer)
})

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
    label: 'ย่อลิงก์', href: '#/url-short',
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

// ── Services จาก config (แทน quickLinks hardcode) ────────────────
const configServices = computed(() => {
  const svcs = config.value?.services
  if (!svcs?.length) return quickLinks  // fallback hardcode
  return svcs
    .filter(s => s.visible !== false)
    .sort((a,b) => (a.order||99) - (b.order||99))
})

// สีประจำแต่ละบริการ — ระบบวนสีให้อัตโนมัติตามลำดับ (i % length) ให้ไอคอนมีสีสัน ไม่จำเจ
// ต้องเป็น class string เต็มตัวอักษร (Tailwind JIT ถึงจะไม่ purge ทิ้ง)
const SERVICE_COLORS = [
  { chip:'bg-blue-100',    chipHover:'group-hover:bg-blue-600',    icon:'text-blue-600',    iconHover:'group-hover:text-white' },
  { chip:'bg-emerald-100', chipHover:'group-hover:bg-emerald-600', icon:'text-emerald-600', iconHover:'group-hover:text-white' },
  { chip:'bg-amber-100',   chipHover:'group-hover:bg-amber-600',   icon:'text-amber-600',   iconHover:'group-hover:text-white' },
  { chip:'bg-violet-100',  chipHover:'group-hover:bg-violet-600',  icon:'text-violet-600',  iconHover:'group-hover:text-white' },
  { chip:'bg-rose-100',    chipHover:'group-hover:bg-rose-600',    icon:'text-rose-600',    iconHover:'group-hover:text-white' },
  { chip:'bg-cyan-100',    chipHover:'group-hover:bg-cyan-600',    icon:'text-cyan-600',    iconHover:'group-hover:text-white' },
  { chip:'bg-indigo-100',  chipHover:'group-hover:bg-indigo-600',  icon:'text-indigo-600',  iconHover:'group-hover:text-white' },
  { chip:'bg-orange-100',  chipHover:'group-hover:bg-orange-600',  icon:'text-orange-600',  iconHover:'group-hover:text-white' },
]
function serviceColor(i) { return SERVICE_COLORS[i % SERVICE_COLORS.length] }

function serviceHref(svc) {
  if (!svc.url) return '#'
  if (svc.type === 'internal') return '#' + svc.url
  return svc.url
}

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

// ── Banner aspect ratio ───────────────────────────────────────────
const bannerAspectStyle = computed(() => {
  const r = config.value?.banner_aspect_ratio || '21:9'
  const [w, h] = r.split(':').map(Number)
  return `aspect-ratio: ${w} / ${h}`
})

// ── Home sections (merge stored config + new defaults) ───────────
const orderedSections = computed(() => {
  const raw = config.value?.home_sections
  if (!Array.isArray(raw) || raw.length === 0) {
    return [...DEFAULT_HOME_SECTIONS].sort((a, b) => a.order - b.order)
  }
  // merge: เพิ่ม section ใหม่จาก DEFAULT ที่ยังไม่มีใน stored config
  const storedKeys = new Set(raw.map(s => s.key))
  const maxOrder   = Math.max(...raw.map(s => s.order || 0))
  // backfill subtitle จาก DEFAULT ถ้า stored section ยังไม่มี
  const rawWithSubtitle = raw.map(s => {
    if (s.subtitle !== undefined) return s
    const def = DEFAULT_HOME_SECTIONS.find(d => d.key === s.key)
    return { ...s, subtitle: def?.subtitle ?? '' }
  })
  const merged = [
    ...rawWithSubtitle,
    ...DEFAULT_HOME_SECTIONS
      .filter(s => !storedKeys.has(s.key))
      .map((s, i) => ({ ...s, order: maxOrder + i + 1 })),
  ]
  return merged.sort((a, b) => a.order - b.order)
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
  <div class="font-sarabun text-slate-800 dark:text-slate-100 bg-slate-50 dark:bg-slate-950 transition-colors duration-300">

    <!-- ── SECTION 1: BANNER / HERO (full-width) ─────────────────── -->
    <section class="w-full">

      <!-- แบนเนอร์จาก DB — full width, configurable ratio -->
      <div v-if="!loadingBanners && banners.length > 0" class="w-full">
        <div class="relative overflow-hidden shadow-xl w-full bg-slate-900"
          :style="bannerAspectStyle"
          @touchstart.passive="onBannerTouchStart"
          @touchmove.passive="onBannerTouchMove"
          @touchend="onBannerTouchEnd">
          <div v-for="(slide, i) in banners" :key="slide.id"
            class="absolute inset-0 transition-all duration-1000"
            :class="i === currentSlide ? 'opacity-100 z-10' : 'opacity-0 pointer-events-none'">
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
            <div v-if="slide.title" class="absolute inset-0 bg-gradient-to-t from-black/65 via-transparent to-transparent flex items-end justify-center text-center pointer-events-none">
              <div class="p-8 md:p-14">
                <h2 class="text-xl md:text-4xl font-extrabold text-white drop-shadow-xl">{{ slide.title }}</h2>
                <p v-if="slide.subtitle" class="text-white/75 mt-2 text-sm md:text-lg">{{ slide.subtitle }}</p>
              </div>
            </div>
            <!-- คลิกแบนเนอร์เพื่อเปิดลิงก์ (image/video เท่านั้น — youtube มี play button ของตัวเอง) -->
            <component v-if="slide.banner_type !== 'youtube' && slide.link_type && slide.link_type !== 'none' && slide.link_url"
              :is="slide.link_type === 'external' ? 'a' : 'router-link'"
              :href="slide.link_type === 'external' ? slide.link_url : undefined"
              :to="slide.link_type === 'internal' ? bannerInternalPath(slide.link_url) : undefined"
              :target="slide.link_type === 'external' ? '_blank' : undefined"
              :rel="slide.link_type === 'external' ? 'noopener' : undefined"
              @click="onBannerLinkClick"
              class="absolute inset-0 cursor-pointer" :aria-label="slide.title || 'banner link'"/>
          </div>
          <!-- TV vignette — gradient ขอบทั้ง 4 ด้าน -->
          <div class="absolute inset-0 pointer-events-none"
            style="background: radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.55) 100%)"></div>
        </div>

        <!-- ตัวเลื่อนสไลด์ — อยู่ใต้แบนเนอร์ ไม่บังคลิก -->
        <div v-if="banners.length > 1" class="flex items-center justify-center gap-3 py-3 bg-slate-50 dark:bg-slate-950">
          <button @click="prevSlide(); scheduleNextSlide()"
            class="w-7 h-7 rounded-full border border-slate-200 dark:border-slate-700 flex items-center justify-center text-slate-400 hover:text-primary hover:border-primary transition-colors">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="3">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <div class="flex gap-1.5">
            <button v-for="(_, i) in banners" :key="i" @click="goToSlide(i)"
              :class="['rounded-full transition-all', i === currentSlide ? 'bg-primary w-5 h-1.5' : 'bg-slate-300 dark:bg-slate-600 w-1.5 h-1.5 hover:bg-slate-400']"/>
          </div>
          <button @click="nextSlide(); scheduleNextSlide()"
            class="w-7 h-7 rounded-full border border-slate-200 dark:border-slate-700 flex items-center justify-center text-slate-400 hover:text-primary hover:border-primary transition-colors">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="3">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
            </svg>
          </button>
        </div>
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
            <h1 class="font-extrabold leading-tight mb-3 whitespace-nowrap overflow-hidden"
                style="font-size: clamp(1rem, 3vw, 2.25rem)">
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
          :style="getBgStyle(sec)"
          class="py-8 md:py-12">
          <div class="max-w-7xl mx-auto px-4">
            <div class="flex items-end justify-between mb-8">
              <div>
                <span v-if="sec.subtitle || sec.key === 'news'" class="text-secondary font-bold uppercase text-xs tracking-[0.18em] block mb-1">{{ sec.subtitle || 'Latest News' }}</span>
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
            <div v-if="loadingNews" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-5">
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
            <div v-else class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-5">
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

        <!-- ══ SUPERVISION LIST ══ -->
        <section v-else-if="sec.key === 'supervision_list'" :style="getBgStyle(sec)" class="py-8 md:py-12">
          <div class="max-w-4xl mx-auto px-4">
            <h2 class="text-2xl md:text-3xl font-extrabold text-slate-800 dark:text-slate-100 mb-2 text-center">{{ sec.title }}</h2>
            <p class="text-slate-500 dark:text-slate-400 text-sm mb-8 text-center">แบบนิเทศและแบบสอบถามที่เปิดรับอยู่</p>

            <div v-if="loadingSupervision" class="flex justify-center py-12">
              <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
            </div>

            <div v-else-if="supervisionForms.length === 0"
              class="text-center py-12 bg-white/60 dark:bg-slate-800/60 rounded-2xl border border-slate-200 dark:border-slate-700 text-slate-400">
              <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z"/>
              </svg>
              <p class="font-medium">ยังไม่มีแบบนิเทศที่เปิดรับอยู่</p>
            </div>

            <div v-else class="space-y-4">
              <div v-for="form in supervisionForms" :key="form.id"
                class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden">
                <div class="p-5">
                  <div class="flex flex-col sm:flex-row gap-4">
                    <div class="flex items-start gap-4 flex-1 min-w-0">
                    <!-- Icon -->
                    <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                      <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z"/>
                      </svg>
                    </div>

                    <div class="flex-1 min-w-0">
                      <div class="flex flex-wrap items-center gap-2 mb-1">
                        <span v-if="form.respondent_type === 'individual'" class="inline-flex items-center gap-1 text-xs bg-purple-100 text-purple-700 font-bold px-2 py-0.5 rounded-full">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"/></svg>
                          แบบสอบถาม
                        </span>
                        <span v-else class="inline-flex items-center gap-1 text-xs bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">
                          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18"/></svg>
                          แบบนิเทศ
                        </span>
                        <span v-if="form.deadline" :class="['text-xs font-medium px-2 py-0.5 rounded-full', formatDeadline(form.deadline)?.color]">
                          {{ formatDeadline(form.deadline)?.label }}
                        </span>
                      </div>
                      <h3 class="font-extrabold text-slate-800 dark:text-slate-100 leading-snug">{{ form.title }}</h3>
                      <p v-if="form.description" class="text-sm text-slate-500 dark:text-slate-400 mt-0.5 line-clamp-2">{{ form.description }}</p>

                      <!-- Progress bar (school mode) -->
                      <div v-if="form.respondent_type === 'school' && form.target_count > 0" class="mt-3">
                        <div class="flex justify-between text-xs text-slate-400 mb-1">
                          <span>{{ form.response_count }} / {{ form.target_count }} โรงเรียน</span>
                          <span>{{ Math.round(form.response_count / form.target_count * 100) }}%</span>
                        </div>
                        <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                          <div class="h-full bg-gradient-to-r from-primary to-blue-400 rounded-full transition-all"
                            :style="`width:${Math.min(100, Math.round(form.response_count / form.target_count * 100))}%`"/>
                        </div>
                      </div>
                      <!-- Individual mode count -->
                      <p v-else-if="form.respondent_type === 'individual' && form.response_count > 0"
                        class="mt-2 text-xs text-slate-500">{{ form.response_count }} คนตอบแล้ว</p>
                    </div>
                    </div>

                    <!-- Fill button -->
                    <div class="flex-shrink-0 w-full sm:w-auto">
                      <!-- สาธารณะ: กรอกได้เลย -->
                      <a v-if="form.allow_public && form.public_token"
                        :href="`#/supervision/${form.public_token}`"
                        class="flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-sm transition-all whitespace-nowrap w-full sm:w-auto">
                        {{ form.respondent_type === 'individual' ? 'ร่วมตอบ' : 'ดำเนินการ' }}
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                        </svg>
                      </a>
                      <!-- ต้อง login: logged in แล้ว → ไปกรอก -->
                      <router-link v-else-if="!form.allow_public && userSession"
                        :to="`/school/supervision/${form.id}`"
                        class="flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-sm transition-all whitespace-nowrap w-full sm:w-auto">
                        {{ form.respondent_type === 'individual' ? 'ร่วมตอบ' : 'ดำเนินการ' }}
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                        </svg>
                      </router-link>
                      <!-- ต้อง login: ยังไม่ login → ปุ่มไปหน้า login พร้อม redirect กลับมา -->
                      <router-link v-else-if="!form.allow_public && !userSession"
                        :to="`/login?next=/school/supervision/${form.id}`"
                        class="flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-bold border-2 border-primary text-primary rounded-xl hover:bg-primary hover:text-white transition-all whitespace-nowrap w-full sm:w-auto">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                        </svg>
                        เข้าสู่ระบบ
                      </router-link>
                    </div>
                  </div>

                  <!-- Status button row -->
                  <div v-if="form.status_visibility !== 'hidden' && (form.status_visibility === 'public' || (form.status_visibility === 'authenticated' && userSession))"
                    class="mt-3 pt-3 border-t border-slate-100 dark:border-slate-700">
                    <button @click="loadFormStatus(form)"
                      :disabled="loadingStatus[form.id]"
                      class="flex items-center gap-1.5 text-sm text-slate-500 hover:text-primary font-medium transition-colors">
                      <svg v-if="loadingStatus[form.id]" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                      </svg>
                      <svg v-else class="w-4 h-4 transition-transform" :class="expandedStatus === form.id ? 'rotate-180' : ''"
                        fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                      </svg>
                      ดูสถานะโรงเรียน
                      <svg v-if="form.status_visibility === 'authenticated'" class="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Status expand panel -->
                <Transition
                  enter-active-class="transition duration-200"
                  enter-from-class="opacity-0 -translate-y-2"
                  enter-to-class="opacity-100 translate-y-0"
                  leave-active-class="transition duration-150"
                  leave-from-class="opacity-100"
                  leave-to-class="opacity-0">
                  <div v-if="expandedStatus === form.id && supervisionStatus[form.id]"
                    class="border-t border-slate-100 dark:border-slate-700 px-5 py-4 bg-slate-50 dark:bg-slate-900">
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <!-- ส่งแล้ว -->
                      <div>
                        <p class="text-xs font-bold text-emerald-600 mb-2 flex items-center gap-1.5">
                          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                          </svg>
                          ดำเนินการแล้ว ({{ supervisionStatus[form.id].responded }})
                        </p>
                        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
                          <span v-for="s in supervisionStatus[form.id].responded_schools" :key="s.id"
                            class="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-lg">
                            {{ s.name }}
                          </span>
                          <span v-if="!supervisionStatus[form.id].responded_schools?.length" class="text-xs text-slate-400">ยังไม่มี</span>
                        </div>
                      </div>
                      <!-- ยังไม่ส่ง -->
                      <div>
                        <p class="text-xs font-bold text-amber-600 mb-2 flex items-center gap-1.5">
                          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"/>
                          </svg>
                          ยังไม่ดำเนินการ ({{ supervisionStatus[form.id].pending_schools?.length || 0 }})
                        </p>
                        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
                          <span v-for="s in supervisionStatus[form.id].pending_schools" :key="s.id"
                            class="text-xs bg-amber-50 text-amber-700 border border-amber-200 px-2 py-0.5 rounded-lg">
                            {{ s.name }}
                          </span>
                          <span v-if="!supervisionStatus[form.id].pending_schools?.length" class="text-xs text-slate-400">ทุกโรงเรียนดำเนินการแล้ว ✓</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </Transition>
              </div>
            </div>
          </div>
        </section>

        <!-- ══ NITHET CALENDAR ══ -->
        <section v-else-if="sec.key === 'nithet_calendar'" :style="getBgStyle(sec)" class="py-8 md:py-12">
          <div class="max-w-4xl mx-auto px-4">
            <h2 class="text-2xl md:text-3xl font-extrabold text-slate-800 dark:text-slate-100 mb-2 text-center">{{ sec.title }}</h2>
            <p class="text-slate-500 dark:text-slate-400 text-sm mb-8 text-center">กำหนดการนิเทศโรงเรียนและกิจกรรมของกลุ่มนิเทศที่ใกล้ถึง</p>

            <div v-if="loadingNithetEvents" class="flex justify-center py-12">
              <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
            </div>

            <div v-else-if="nithetEvents.length === 0"
              class="text-center py-12 bg-white/60 dark:bg-slate-800/60 rounded-2xl border border-slate-200 dark:border-slate-700 text-slate-400">
              <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5m-9-6h.008v.008H12v-.008z"/>
              </svg>
              <p class="font-medium">ยังไม่มีกำหนดการในขณะนี้</p>
            </div>

            <div v-else class="space-y-3">
              <RouterLink v-for="event in nithetEvents" :key="event.id" to="/nithet"
                class="block bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 hover:shadow-md transition-shadow">
                <div class="flex flex-wrap items-center gap-2 mb-1.5">
                  <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
                    {{ TYPE_LABEL[event.type] }}
                  </span>
                  <span class="text-xs text-slate-400">{{ formatEventDateRange(event) }}</span>
                </div>
                <h3 class="font-bold text-slate-800 dark:text-slate-100">{{ event.title }}</h3>
                <p v-if="event.schools?.length" class="text-xs text-slate-400 mt-1">โรงเรียน: {{ event.schools.map(s => s.name).join(', ') }}</p>
              </RouterLink>
            </div>

            <div class="text-center mt-8">
              <RouterLink to="/nithet"
                class="inline-flex items-center gap-2 px-6 py-2.5 border border-primary text-primary font-bold rounded-2xl text-sm hover:bg-primary hover:text-white transition-all">
                ดูปฏิทินทั้งหมด
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                </svg>
              </RouterLink>
            </div>
          </div>
        </section>

        <!-- ══ EDUCATION NEWS (Google RSS) ══ -->
        <section v-else-if="sec.key === 'education_news'" :style="getBgStyle(sec)" class="py-8 md:py-10">
          <div class="max-w-7xl mx-auto px-4">
            <!-- Header -->
            <div class="flex items-end justify-between mb-6">
              <div>
                <span class="text-secondary font-bold uppercase text-xs tracking-[0.18em] block mb-1">{{ sec.subtitle || 'Education News' }}</span>
                <h2 class="text-2xl md:text-3xl font-extrabold text-slate-900 accent-line">{{ sec.title || 'ข่าวการศึกษา' }}</h2>
              </div>
              <a href="#/education-news" class="hidden sm:flex items-center gap-1.5 text-sm font-bold text-primary hover:gap-3 transition-all">
                ดูทั้งหมด
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                </svg>
              </a>
            </div>
            <!-- Loading skeleton -->
            <div v-if="loadingEduNews" class="space-y-2">
              <div v-for="i in 5" :key="i" class="h-12 bg-slate-100 rounded-xl animate-pulse"/>
            </div>
            <!-- Error -->
            <div v-else-if="eduNewsError"
              class="text-center py-8 text-slate-400 text-sm bg-white rounded-2xl border border-slate-100">
              ไม่สามารถโหลดข่าวได้ในขณะนี้
            </div>
            <!-- Empty -->
            <div v-else-if="educationNews.length === 0"
              class="text-center py-8 text-slate-400 text-sm bg-white rounded-2xl border border-slate-100">
              ยังไม่มีข้อมูลข่าว
            </div>
            <!-- Link list (max 8) -->
            <ul v-else class="divide-y divide-slate-100 bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
              <li v-for="item in educationNews.slice(0, 8)" :key="item.link"
                class="group flex items-start gap-3 px-4 py-3 hover:bg-primary/5 transition-colors">
                <span class="mt-2.5 w-1.5 h-1.5 rounded-full bg-primary/40 flex-shrink-0 group-hover:bg-primary transition-colors"/>
                <div class="flex-1 min-w-0">
                  <a :href="item.link" target="_blank" rel="noopener noreferrer"
                    class="text-sm font-semibold text-slate-800 hover:text-primary transition-colors line-clamp-1 leading-snug">
                    {{ item.title }}
                  </a>
                  <p class="text-xs text-slate-400 mt-0.5 truncate">
                    <span v-if="item.source">{{ item.source }}</span>
                    <span v-if="item.source && item.pubDate"> · </span>
                    {{ fmtDate(item.pubDate) }}
                  </p>
                </div>
                <svg class="w-3 h-3 text-slate-300 group-hover:text-primary flex-shrink-0 mt-1.5 transition-colors"
                  fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round"
                    d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
                </svg>
              </li>
            </ul>
            <!-- Mobile CTA -->
            <div class="text-center mt-5 sm:hidden">
              <a href="#/education-news"
                class="inline-flex items-center gap-2 px-6 py-2.5 border border-primary text-primary font-bold rounded-2xl text-sm hover:bg-primary hover:text-white transition-all">
                ดูข่าวทั้งหมด
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
                </svg>
              </a>
            </div>
          </div>
        </section>

        <!-- ══ SERVICES (e-services) ══ -->
        <section v-else-if="sec.key === 'services'" :style="getBgStyle(sec)">
          <div class="py-8 md:py-12">
            <div class="max-w-7xl mx-auto px-4">
              <div class="text-center mb-12">
                <span v-if="sec.subtitle || sec.key === 'services'" class="text-secondary font-bold uppercase text-xs tracking-[0.18em] mb-2 block">{{ sec.subtitle || 'E-Service Center' }}</span>
                <h2 class="text-3xl md:text-4xl font-extrabold text-slate-900 accent-line-center">{{ sec.title || 'บริการออนไลน์' }}</h2>
              </div>
              <div class="flex flex-wrap justify-center gap-4">
                <component
                  v-for="(svc, si) in configServices" :key="svc.key || svc.label"
                  :is="svc.type === 'external' ? 'a' : 'router-link'"
                  :href="svc.type === 'external' ? (svc.url || '#') : undefined"
                  :to="svc.type !== 'external' ? (svc.url || '#') : undefined"
                  :target="svc.type === 'external' ? '_blank' : undefined"
                  :rel="svc.type === 'external' ? 'noopener' : undefined"
                  class="group flex flex-col items-center p-6 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-xl hover:-translate-y-1 hover:border-slate-200 transition-all duration-300 w-[calc(50%-8px)] md:w-[calc(25%-12px)]">
                  <div :class="['w-14 h-14 rounded-2xl flex items-center justify-center mb-4 transition-colors duration-300', serviceColor(si).chip, serviceColor(si).chipHover]">
                    <svg :class="['w-6 h-6 group-hover:scale-110 transition-all duration-300', serviceColor(si).icon, serviceColor(si).iconHover]" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round"
                        :d="svc.icon ? (ICON_MAP[svc.icon] || svc.path) : svc.path"/>
                    </svg>
                  </div>
                  <span class="text-sm font-bold text-slate-700 text-center leading-snug group-hover:text-slate-900 transition-colors">{{ svc.label }}</span>
                  <span v-if="svc.type === 'external'" class="text-[10px] text-slate-400 mt-0.5">↗</span>
                </component>
              </div>
            </div>
          </div>
        </section>

        <!-- ══ IMAGE GALLERY (เพิ่มได้หลายเซกชัน key ขึ้นต้นด้วย image_gallery ข้อมูลฝังในตัว sec.gallery) ══ -->
        <section v-else-if="sec.key.startsWith('image_gallery') && sec.gallery?.items?.length"
          :style="getBgStyle(sec)" class="py-8 md:py-12">
          <div class="max-w-7xl mx-auto px-4">
            <div class="text-center mb-12">
              <span v-if="sec.subtitle" class="text-secondary font-bold uppercase text-xs tracking-[0.18em] mb-2 block">{{ sec.subtitle }}</span>
              <h2 class="text-3xl md:text-4xl font-extrabold text-slate-900 accent-line-center">{{ sec.title || 'ภาพลิงก์' }}</h2>
            </div>
            <ImageLinkGallery :layout="sec.gallery.layout" :items="sec.gallery.items"/>
          </div>
        </section>

        <!-- ══ CTA ══ -->
        <section v-else-if="sec.key === 'cta'"
          :style="getBgStyle(sec)"
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
