<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import StorageBrowser    from '../../components/StorageBrowser.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import { useAreaConfig } from '../../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()

// ── Banner ratio config ──────────────────────────────────────────
const BANNER_RATIOS = [
  { value: '21:9', label: '21:9 — Cinematic (แนะนำ)', size: '1920×823px หรือ 1200×514px', ratio: 21/9 },
  { value: '16:9', label: '16:9 — มาตรฐาน',           size: '1920×1080px หรือ 1280×720px', ratio: 16/9 },
  { value: '3:1',  label: '3:1  — เว็บราชการ',        size: '1500×500px หรือ 1200×400px',  ratio: 3/1 },
  { value: '4:1',  label: '4:1  — แบนเนอร์บาง',       size: '1200×300px หรือ 1600×400px',  ratio: 4/1 },
]

const currentRatioInfo = computed(() =>
  BANNER_RATIOS.find(r => r.value === (config.value?.banner_aspect_ratio || '21:9'))
  ?? BANNER_RATIOS[0]
)

// ── State ────────────────────────────────────────────────────────
const banners      = ref([])
const loading      = ref(true)
const saving       = ref(false)
const showModal    = ref(false)
const showStorage  = ref(false)
const showCropper  = ref(false)
const uploading    = ref(false)
const activeFilter = ref('all')   // all | active | hidden | pinned | video

// Video upload
const videoFileInput      = ref(null)   // hidden <input type="file">
const uploadingVideo      = ref(false)
const videoUploadProgress = ref(0)
const videoUploadError    = ref('')

const emptyForm = () => ({
  id:          null,
  title:       '',
  subtitle:    '',
  description: '',
  image_url:   '',
  banner_type: 'image',   // image | video | youtube
  link_type:   'none',    // none | internal | external
  link_url:    '',
  is_active:   true,
  is_pinned:   false,
  sort_order:  0,
})
const form = ref(emptyForm())

// ── Fetch ────────────────────────────────────────────────────────
async function fetchBanners() {
  loading.value = true
  const { data, error } = await supabase
    .from('banners')
    .select('*')
    .order('is_pinned', { ascending: false })
    .order('sort_order',  { ascending: true })
  if (!error) banners.value = data || []
  loading.value = false
}
onMounted(() => { fetchConfig(); fetchBanners() })

// ── Filters / Stats ──────────────────────────────────────────────
const filterTabs = [
  { key: 'all',    label: 'ทั้งหมด' },
  { key: 'active', label: 'แสดงอยู่' },
  { key: 'hidden', label: 'ซ่อนอยู่' },
  { key: 'pinned', label: 'ปักหมุด' },
  { key: 'video',  label: 'วิดีโอ' },
]

const filteredBanners = computed(() => {
  const list = banners.value
  if (activeFilter.value === 'active') return list.filter(b => b.is_active)
  if (activeFilter.value === 'hidden') return list.filter(b => !b.is_active)
  if (activeFilter.value === 'pinned') return list.filter(b => b.is_pinned)
  if (activeFilter.value === 'video')  return list.filter(b => b.banner_type !== 'image')
  return list
})

const stats = computed(() => ({
  total:  banners.value.length,
  active: banners.value.filter(b =>  b.is_active).length,
  hidden: banners.value.filter(b => !b.is_active).length,
  pinned: banners.value.filter(b =>  b.is_pinned).length,
  video:  banners.value.filter(b =>  b.banner_type !== 'image').length,
}))

// ── YouTube helper ────────────────────────────────────────────────
function extractYoutubeId(url) {
  if (!url) return null
  const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
  return m ? m[1] : null
}
function youtubeThumbnail(url) {
  const id = extractYoutubeId(url)
  return id ? `https://img.youtube.com/vi/${id}/maxresdefault.jpg` : ''
}
function youtubeEmbed(url) {
  const id = extractYoutubeId(url)
  return id
    ? `https://www.youtube.com/embed/${id}?autoplay=1&mute=1&loop=1&playlist=${id}&controls=0`
    : url
}

// ── Preview thumbnail for card ────────────────────────────────────
function cardThumb(b) {
  if (b.banner_type === 'youtube') return youtubeThumbnail(b.image_url)
  return b.image_url
}

// ── Open modal ────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  form.value.sort_order = banners.value.length
  showModal.value = true
}
function openEdit(b) {
  form.value = {
    ...emptyForm(),
    ...b,
    // fallback fields ที่ DB เก่าอาจไม่มี
    is_pinned:   b.is_pinned   ?? false,
    link_type:   b.link_type   || (b.link_url ? 'external' : 'none'),
    description: b.description || '',
  }
  showModal.value = true
}

// ── Save ──────────────────────────────────────────────────────────
async function saveBanner() {
  if (!form.value.image_url.trim()) {
    return Swal.fire({ icon: 'warning', title: 'กรุณาใส่ URL หรืออัปโหลดสื่อก่อน', confirmButtonColor: 'var(--color-primary)' })
  }
  saving.value = true
  const payload = {
    title:       form.value.title.trim(),
    subtitle:    form.value.subtitle.trim(),
    description: form.value.description?.trim() || '',
    image_url:   form.value.image_url.trim(),
    banner_type: form.value.banner_type,
    link_type:   form.value.link_type,
    link_url:    form.value.link_type === 'none' ? '' : form.value.link_url.trim(),
    is_active:   form.value.is_active,
    is_pinned:   form.value.is_pinned,
    sort_order:  Number(form.value.sort_order) || 0,
  }
  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('banners').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('banners').insert(payload))
  }
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#ef4444' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 900 })
    showModal.value = false
    await fetchBanners()
  }
}

// ── Toggle helpers ────────────────────────────────────────────────
async function toggleActive(b) {
  const { error } = await supabase.from('banners').update({ is_active: !b.is_active }).eq('id', b.id)
  if (!error) b.is_active = !b.is_active
}
async function togglePin(b) {
  const { error } = await supabase.from('banners').update({ is_pinned: !b.is_pinned }).eq('id', b.id)
  if (!error) {
    b.is_pinned = !b.is_pinned
    // re-sort local list
    banners.value = [...banners.value].sort((a, x) => {
      if (a.is_pinned && !x.is_pinned) return -1
      if (!a.is_pinned && x.is_pinned)  return  1
      return (a.sort_order || 0) - (x.sort_order || 0)
    })
  }
}

// ── Delete ────────────────────────────────────────────────────────
async function deleteBanner(b) {
  const res = await Swal.fire({
    title: `ลบ "${b.title || 'แบนเนอร์นี้'}"?`,
    text: 'ไม่สามารถกู้คืนได้',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ',
    cancelButtonText:  'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('banners').delete().eq('id', b.id)
  banners.value = banners.value.filter(x => x.id !== b.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

// ── Reorder ────────────────────────────────────────────────────────
async function moveUp(b) {
  const list = banners.value
  const i = list.indexOf(b)
  if (i <= 0) return
  await swapOrder(i, i - 1)
}
async function moveDown(b) {
  const list = banners.value
  const i = list.indexOf(b)
  if (i >= list.length - 1) return
  await swapOrder(i, i + 1)
}
async function swapOrder(i, j) {
  const a = banners.value[i]
  const c = banners.value[j]
  const tmp = a.sort_order; a.sort_order = c.sort_order; c.sort_order = tmp
  ;[banners.value[i], banners.value[j]] = [banners.value[j], banners.value[i]]
  await Promise.all([
    supabase.from('banners').update({ sort_order: a.sort_order }).eq('id', a.id),
    supabase.from('banners').update({ sort_order: c.sort_order }).eq('id', c.id),
  ])
}

// ── Video upload (XHR + progress) ─────────────────────────────────
function triggerVideoUpload() {
  videoFileInput.value?.click()
}

async function onVideoFileSelected(e) {
  const file = e.target.files?.[0]
  if (!file) return
  e.target.value = ''   // reset so same file can be re-selected

  // ── Validate size (max 50 MB — storage bucket limit)
  const MAX_MB = 50
  if (file.size > MAX_MB * 1024 * 1024) {
    videoUploadError.value = `ไฟล์ใหญ่เกิน ${MAX_MB} MB (ไฟล์นี้ ${(file.size/1024/1024).toFixed(1)} MB) — กรุณาบีบอัดก่อน`
    return
  }
  // ── Validate type
  if (!file.type.startsWith('video/')) {
    videoUploadError.value = 'รองรับเฉพาะไฟล์วิดีโอ (.mp4, .webm, .mov)'
    return
  }

  videoUploadError.value   = ''
  uploadingVideo.value     = true
  videoUploadProgress.value = 0

  try {
    const { data: { session } } = await supabase.auth.getSession()
    const token      = session?.access_token
    const baseUrl    = import.meta.env.VITE_SUPABASE_URL
    const ext        = file.name.split('.').pop() || 'mp4'
    const fileName   = `banner-video-${Date.now()}.${ext}`
    const uploadUrl  = `${baseUrl}/storage/v1/object/banners/${fileName}`

    await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      xhr.open('POST', uploadUrl)
      xhr.setRequestHeader('Authorization', `Bearer ${token}`)
      xhr.setRequestHeader('Content-Type', file.type || 'video/mp4')
      xhr.setRequestHeader('x-upsert', 'false')

      xhr.upload.addEventListener('progress', ev => {
        if (ev.lengthComputable)
          videoUploadProgress.value = Math.round((ev.loaded / ev.total) * 100)
      })
      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) resolve()
        else reject(new Error(`Upload failed (${xhr.status}): ${xhr.responseText}`))
      })
      xhr.addEventListener('error', () => reject(new Error('Network error')))
      xhr.send(file)
    })

    // Get public URL
    const { data: urlData } = supabase.storage.from('banners').getPublicUrl(fileName)
    form.value.image_url = urlData.publicUrl

  } catch (err) {
    videoUploadError.value = err.message
  } finally {
    uploadingVideo.value = false
  }
}

// ── Upload / Storage ───────────────────────────────────────────────
function onStorageSelect({ url }) {
  form.value.image_url = url
  showStorage.value = false
}
async function onCropped({ blob }) {
  showCropper.value = false
  uploading.value = true
  const name = `banner-${Date.now()}.png`
  const { data, error } = await supabase.storage
    .from('banners').upload(name, blob, { contentType: 'image/png', upsert: false })
  if (error) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: error.message })
  } else {
    const { data: urlData } = supabase.storage.from('banners').getPublicUrl(data.path)
    form.value.image_url = urlData.publicUrl
  }
  uploading.value = false
}

// ── Type helpers ───────────────────────────────────────────────────
const TYPE_OPTIONS = [
  { v: 'image',   icon: 'M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z', label: 'รูปภาพ' },
  { v: 'video',   icon: 'M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h1.5C5.496 19.5 6 18.996 6 18.375m-3.75.125 c0-1.036.84-1.875 1.875-1.875h.375m-2.25 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m0 0h16.5m0 0 c.621 0 1.125.504 1.125 1.125m-1.125-1.125V5.625m0 12.75h1.5m-1.5 0c-.621 0-1.125-.504-1.125-1.125M20.25 5.625c0-.621-.504-1.125-1.125-1.125H4.875c-.621 0-1.125.504-1.125 1.125m16.5 0v1.5c0 .621-.504 1.125-1.125 1.125M3.75 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h13.5m0 0 .621 0 1.125-.504 1.125-1.125M8.25 4.5h1.5m4.5 0h1.5m-9 8.25h7.5', label: 'วิดีโอไฟล์' },
  { v: 'youtube', icon: 'M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h-.008v.008H12V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM9.75 12h.008v.008H9.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm3.75.75h-.008v.008h.008v-.008zm-.375 0a.375.375 0 11.75 0 .375.375 0 01-.75 0z', label: 'YouTube' },
]
const LINK_OPTIONS = [
  { v: 'none',     label: 'ไม่มีลิงค์', desc: 'คลิกแล้วไม่ทำอะไร' },
  { v: 'internal', label: 'ภายในเว็บ',  desc: 'เปิดหน้าในเว็บเดิม' },
  { v: 'external', label: 'ลิงค์นอก',  desc: 'เปิดแท็บใหม่' },
]
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- ── Header ──────────────────────────────────────────────── -->
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
          </svg>
          จัดการแบนเนอร์
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">สไลด์โชว์บนหน้าแรก — รองรับรูปภาพ วิดีโอ และ YouTube</p>
      </div>
      <button @click="openAdd"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        เพิ่มแบนเนอร์
      </button>
    </div>

    <!-- ── Stats ────────────────────────────────────────────────── -->
    <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
      <div v-for="s in [
        { key:'total',  label:'ทั้งหมด',   val: stats.total,  color:'bg-slate-50 border-slate-200',    text:'text-slate-700' },
        { key:'active', label:'แสดงอยู่',   val: stats.active, color:'bg-emerald-50 border-emerald-200', text:'text-emerald-700' },
        { key:'hidden', label:'ซ่อนอยู่',   val: stats.hidden, color:'bg-slate-50 border-slate-200',    text:'text-slate-500' },
        { key:'pinned', label:'ปักหมุด',    val: stats.pinned, color:'bg-amber-50 border-amber-200',     text:'text-amber-700' },
        { key:'video',  label:'วิดีโอ',     val: stats.video,  color:'bg-violet-50 border-violet-200',   text:'text-violet-700' },
      ]" :key="s.key"
        :class="['rounded-2xl border p-4 text-center cursor-pointer transition-all', s.color,
          activeFilter===s.key ? 'ring-2 ring-primary shadow-sm' : 'hover:shadow-sm']"
        @click="activeFilter = activeFilter===s.key ? 'all' : s.key">
        <p :class="['text-2xl font-extrabold', s.text]">{{ s.val }}</p>
        <p class="text-xs text-slate-500 mt-0.5 font-medium">{{ s.label }}</p>
      </div>
    </div>

    <!-- ── Filter tabs ───────────────────────────────────────────── -->
    <div class="flex flex-wrap gap-2">
      <button v-for="tab in filterTabs" :key="tab.key"
        @click="activeFilter = tab.key"
        :class="['px-4 py-1.5 rounded-full text-sm font-bold transition-all border',
          activeFilter === tab.key
            ? 'bg-primary text-white border-primary shadow-md'
            : 'bg-white text-slate-500 border-slate-200 hover:border-primary/40 hover:text-primary']">
        {{ tab.label }}
        <span class="ml-1 opacity-70">
          ({{ tab.key==='all'?stats.total : tab.key==='active'?stats.active : tab.key==='hidden'?stats.hidden : tab.key==='pinned'?stats.pinned : stats.video }})
        </span>
      </button>
    </div>

    <!-- ── Loading skeleton ──────────────────────────────────────── -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
      <div v-for="i in 3" :key="i" class="rounded-2xl overflow-hidden">
        <div class="aspect-video bg-slate-200 animate-pulse"></div>
        <div class="p-4 bg-white space-y-2 border border-t-0 border-slate-100 rounded-b-2xl">
          <div class="h-4 bg-slate-100 rounded-lg w-3/4 animate-pulse"></div>
          <div class="h-3 bg-slate-100 rounded-lg w-1/2 animate-pulse"></div>
        </div>
      </div>
    </div>

    <!-- ── Empty ─────────────────────────────────────────────────── -->
    <div v-else-if="filteredBanners.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="w-16 h-16 rounded-2xl bg-primary-light flex items-center justify-center mb-4">
        <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z"/>
        </svg>
      </div>
      <p class="font-bold text-slate-600 text-lg mb-1">{{ activeFilter==='all' ? 'ยังไม่มีแบนเนอร์' : 'ไม่มีรายการในกลุ่มนี้' }}</p>
      <p class="text-sm text-slate-400 mb-6">{{ activeFilter==='all' ? 'เพิ่มแบนเนอร์แรกเพื่อแสดงบนหน้าเว็บ' : 'ลองเปลี่ยนตัวกรอง' }}</p>
      <button v-if="activeFilter==='all'" @click="openAdd"
        class="px-6 py-2.5 bg-primary text-white font-bold rounded-2xl shadow hover:bg-primary-dark transition-all">
        เพิ่มแบนเนอร์
      </button>
    </div>

    <!-- ── Banner Cards ──────────────────────────────────────────── -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
      <div v-for="(b, i) in filteredBanners" :key="b.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden hover:shadow-lg transition-all group">

        <!-- Thumbnail -->
        <div class="relative aspect-video bg-slate-900 overflow-hidden">
          <img v-if="b.banner_type === 'image' || b.banner_type === 'youtube'"
            :src="b.banner_type==='youtube' ? youtubeThumbnail(b.image_url) : b.image_url"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
            loading="lazy"/>
          <video v-else-if="b.banner_type === 'video'"
            :src="b.image_url" class="w-full h-full object-cover" muted loop playsinline/>

          <!-- Overlays -->
          <div class="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent"></div>

          <!-- Type badge top-left -->
          <div class="absolute top-2 left-2 flex gap-1.5">
            <!-- Pinned -->
            <span v-if="b.is_pinned"
              class="flex items-center gap-1 px-2 py-0.5 bg-amber-400 text-white text-[10px] font-bold rounded-full shadow">
              <svg class="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/>
              </svg>
              ปักหมุด
            </span>
            <!-- Type -->
            <span v-if="b.banner_type !== 'image'"
              class="flex items-center gap-1 px-2 py-0.5 bg-violet-500 text-white text-[10px] font-bold rounded-full shadow">
              <svg class="w-2.5 h-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round"
                  d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z"/>
              </svg>
              {{ b.banner_type === 'youtube' ? 'YouTube' : 'Video' }}
            </span>
          </div>

          <!-- Status badge top-right -->
          <div class="absolute top-2 right-2">
            <span :class="['flex items-center gap-1 px-2 py-0.5 text-[10px] font-bold rounded-full shadow',
              b.is_active ? 'bg-emerald-500 text-white' : 'bg-slate-600/80 text-white/80']">
              <span :class="['w-1.5 h-1.5 rounded-full', b.is_active ? 'bg-white' : 'bg-white/60']"></span>
              {{ b.is_active ? 'แสดง' : 'ซ่อน' }}
            </span>
          </div>

          <!-- Slide number bottom-left -->
          <span class="absolute bottom-2 left-2 w-6 h-6 bg-black/50 text-white text-[10px] font-extrabold rounded-full flex items-center justify-center">
            {{ i + 1 }}
          </span>

          <!-- Link indicator bottom-right -->
          <span v-if="b.link_type && b.link_type !== 'none'"
            class="absolute bottom-2 right-2 flex items-center gap-1 px-2 py-0.5 bg-blue-500/80 text-white text-[10px] font-bold rounded-full">
            <svg class="w-2.5 h-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round"
                :d="b.link_type==='external'
                  ? 'M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25'
                  : 'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244'"/>
            </svg>
            {{ b.link_type === 'external' ? 'ลิงค์นอก' : 'ภายในเว็บ' }}
          </span>
        </div>

        <!-- Info -->
        <div class="p-4 space-y-2">
          <p class="font-extrabold text-slate-800 truncate text-sm">{{ b.title || '(ไม่มีชื่อ)' }}</p>
          <p v-if="b.subtitle" class="text-xs text-slate-500 truncate">{{ b.subtitle }}</p>
          <p v-if="b.description" class="text-xs text-slate-400 line-clamp-2 leading-relaxed">{{ b.description }}</p>
          <p v-if="b.link_url" class="text-[11px] text-primary truncate flex items-center gap-1">
            <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/>
            </svg>
            {{ b.link_url }}
          </p>

          <!-- Action row -->
          <div class="flex items-center gap-1.5 pt-1">
            <!-- Toggle active -->
            <button @click="toggleActive(b)"
              :title="b.is_active ? 'ซ่อน' : 'แสดง'"
              :class="['p-1.5 rounded-xl transition-all',
                b.is_active ? 'bg-amber-50 text-amber-600 hover:bg-amber-100' : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-100']">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round"
                  :d="b.is_active
                    ? 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'
                    : 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'"/>
              </svg>
            </button>

            <!-- Toggle pin -->
            <button @click="togglePin(b)"
              :title="b.is_pinned ? 'เลิกปักหมุด' : 'ปักหมุด'"
              :class="['p-1.5 rounded-xl transition-all',
                b.is_pinned ? 'bg-amber-100 text-amber-600 hover:bg-amber-200' : 'bg-slate-50 text-slate-400 hover:bg-slate-100 hover:text-amber-500']">
              <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/>
              </svg>
            </button>

            <!-- Edit -->
            <button @click="openEdit(b)"
              class="p-1.5 bg-primary-light text-primary rounded-xl hover:bg-primary hover:text-white transition-all">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z"/>
              </svg>
            </button>

            <!-- Move up -->
            <button @click="moveUp(b)" :disabled="i===0"
              class="p-1.5 bg-slate-50 text-slate-500 rounded-xl hover:bg-slate-200 transition-all disabled:opacity-25">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
              </svg>
            </button>
            <!-- Move down -->
            <button @click="moveDown(b)" :disabled="i===filteredBanners.length-1"
              class="p-1.5 bg-slate-50 text-slate-500 rounded-xl hover:bg-slate-200 transition-all disabled:opacity-25">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
              </svg>
            </button>

            <!-- Delete -->
            <button @click="deleteBanner(b)"
              class="ml-auto p-1.5 bg-red-50 text-red-400 rounded-xl hover:bg-red-100 hover:text-red-600 transition-all">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════════════════
         MODAL ADD / EDIT
    ════════════════════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0 scale-95" enter-to-class="opacity-100 scale-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100 scale-100" leave-to-class="opacity-0 scale-95">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showModal = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-xl max-h-[92vh] flex flex-col overflow-hidden">

            <!-- Modal header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg">
                {{ form.id ? 'แก้ไขแบนเนอร์' : 'เพิ่มแบนเนอร์ใหม่' }}
              </h3>
              <button @click="showModal = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modal body (scrollable) -->
            <div class="flex-1 overflow-y-auto p-6 space-y-5">

              <!-- ─ Preview ─ -->
              <div v-if="form.image_url" class="relative aspect-video rounded-2xl overflow-hidden bg-slate-900 shadow-inner">
                <img v-if="form.banner_type === 'image' || form.banner_type === 'youtube'"
                  :src="form.banner_type==='youtube' ? youtubeThumbnail(form.image_url) : form.image_url"
                  class="w-full h-full object-cover"/>
                <video v-else-if="form.banner_type === 'video'"
                  :src="form.image_url" class="w-full h-full object-cover" muted loop playsinline autoplay/>
                <!-- overlay text -->
                <div v-if="form.title || form.subtitle"
                  class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent flex items-end p-4">
                  <div>
                    <p v-if="form.title" class="text-white font-extrabold text-base drop-shadow">{{ form.title }}</p>
                    <p v-if="form.subtitle" class="text-white/75 text-xs mt-0.5">{{ form.subtitle }}</p>
                  </div>
                </div>
                <div class="absolute top-2 right-2 px-2 py-0.5 bg-black/50 text-white text-[10px] font-bold rounded-full">ตัวอย่าง</div>
              </div>

              <!-- ─ Section 1: ประเภทสื่อ ─ -->
              <div>
                <label class="section-label">ประเภทสื่อ</label>
                <div class="grid grid-cols-3 gap-2 mt-2">
                  <button v-for="t in TYPE_OPTIONS" :key="t.v"
                    @click="form.banner_type = t.v"
                    :class="['flex flex-col items-center gap-1.5 p-3 rounded-2xl border-2 text-sm font-bold transition-all',
                      form.banner_type===t.v
                        ? 'border-primary bg-primary-light text-primary'
                        : 'border-slate-200 text-slate-500 hover:border-primary/40']">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" :d="t.icon"/>
                    </svg>
                    {{ t.label }}
                  </button>
                </div>
              </div>

              <!-- ─ Size recommendation ─ -->
              <div v-if="form.banner_type === 'image'"
                class="flex items-start gap-2.5 bg-blue-50 border border-blue-200 rounded-xl px-4 py-3">
                <svg class="w-4 h-4 text-blue-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
                </svg>
                <div class="text-xs">
                  <p class="font-bold text-blue-700">ขนาดแนะนำ ({{ currentRatioInfo.value }})</p>
                  <p class="text-blue-600 mt-0.5">{{ currentRatioInfo.size }} · ไม่เกิน 5 MB · JPG หรือ PNG</p>
                  <p class="text-blue-500 mt-0.5">เปลี่ยนสัดส่วนแบนเนอร์ได้ที่ ตั้งค่าเขต → ข้อมูลเขตพื้นที่</p>
                </div>
              </div>

              <!-- ─ Section 2: แหล่งสื่อ ─ -->
              <div class="space-y-3">
                <label class="section-label">
                  {{ form.banner_type === 'youtube' ? 'YouTube URL หรือ Video ID' : 'URL สื่อ' }}
                  <span class="text-red-400 ml-0.5">*</span>
                </label>

                <!-- URL input row -->
                <div class="flex gap-2">
                  <input v-model="form.image_url" type="text"
                    :placeholder="form.banner_type==='youtube' ? 'https://youtu.be/xxxxx หรือ Video ID' : 'https://...'"
                    :disabled="uploadingVideo"
                    class="flex-1 input-field disabled:opacity-50"/>

                  <!-- Image: Storage + Crop -->
                  <template v-if="form.banner_type === 'image'">
                    <button @click="showStorage = true" title="เลือกจาก Storage"
                      class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-all flex items-center gap-1">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776"/>
                      </svg>
                      Storage
                    </button>
                    <button @click="showCropper = true" :disabled="uploading" title="อัปโหลดและครอบรูป"
                      class="px-3 py-2 bg-primary hover:bg-primary-dark text-white text-xs font-bold rounded-xl transition-all disabled:opacity-50 flex items-center gap-1">
                      <svg v-if="uploading" class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                      </svg>
                      <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                      </svg>
                      {{ uploading ? '...' : 'อัปโหลด' }}
                    </button>
                  </template>

                  <!-- Video: Storage + Upload file -->
                  <template v-if="form.banner_type === 'video'">
                    <button @click="showStorage = true" title="เลือกจาก Storage"
                      class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-all flex items-center gap-1">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776"/>
                      </svg>
                      Storage
                    </button>
                    <button @click="triggerVideoUpload" :disabled="uploadingVideo" title="อัปโหลดไฟล์วิดีโอ"
                      class="px-3 py-2 bg-violet-600 hover:bg-violet-700 text-white text-xs font-bold rounded-xl transition-all disabled:opacity-50 flex items-center gap-1">
                      <svg v-if="uploadingVideo" class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                      </svg>
                      <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                      </svg>
                      {{ uploadingVideo ? 'กำลังอัปโหลด...' : 'อัปโหลด MP4' }}
                    </button>
                    <!-- hidden file input -->
                    <input ref="videoFileInput" type="file" accept="video/mp4,video/webm,video/quicktime"
                      class="hidden" @change="onVideoFileSelected"/>
                  </template>
                </div>

                <!-- ── Video upload progress bar ── -->
                <div v-if="uploadingVideo" class="space-y-1.5">
                  <div class="flex items-center justify-between text-xs">
                    <span class="font-bold text-violet-700 flex items-center gap-1.5">
                      <svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                      </svg>
                      กำลังอัปโหลดวิดีโอ...
                    </span>
                    <span class="font-extrabold text-violet-700">{{ videoUploadProgress }}%</span>
                  </div>
                  <div class="w-full bg-slate-200 rounded-full h-2 overflow-hidden">
                    <div class="h-2 rounded-full transition-all duration-300"
                      :style="`width:${videoUploadProgress}%; background: linear-gradient(90deg, var(--color-primary), #7c3aed)`"></div>
                  </div>
                  <p class="text-[10px] text-slate-400">กรุณารออย่าปิดหน้าต่างนี้</p>
                </div>

                <!-- ── Upload error ── -->
                <div v-if="videoUploadError"
                  class="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-xl text-xs text-red-600">
                  <svg class="w-4 h-4 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
                  </svg>
                  <span>{{ videoUploadError }}</span>
                  <button @click="videoUploadError=''" class="ml-auto text-red-400 hover:text-red-600">✕</button>
                </div>

                <!-- ── Video tips (แสดงเมื่อ type = video) ── -->
                <div v-if="form.banner_type === 'video'"
                  class="p-4 bg-violet-50 border border-violet-100 rounded-2xl space-y-2">
                  <p class="text-xs font-extrabold text-violet-700 flex items-center gap-1.5">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
                    </svg>
                    คำแนะนำสำหรับวิดีโอแบนเนอร์
                  </p>
                  <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-violet-800">
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>รูปแบบ:</strong> MP4 (H.264)</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>ขนาดแนะนำ:</strong> 1280×720 px</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>ขนาดไฟล์:</strong> ไม่เกิน 50 MB</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>ความยาว:</strong> 15–30 วินาที</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>Bitrate:</strong> 2–4 Mbps</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <span class="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0"></span>
                      <span><strong>เสียง:</strong> ไม่จำเป็น (เล่น mute)</span>
                    </div>
                  </div>
                  <p class="text-[11px] text-violet-600 border-t border-violet-100 pt-2 mt-1">
                    💡 บีบอัดด้วย <strong>HandBrake</strong> (ฟรี) เลือก preset "Web" ได้เลย
                    — หรือใช้ YouTube embed แทนเพื่อไม่กิน storage
                  </p>
                </div>

                <!-- YouTube hint -->
                <p v-if="form.banner_type==='youtube'" class="text-xs text-slate-400">
                  รองรับ: youtube.com/watch?v=... / youtu.be/... / youtube.com/embed/...
                </p>
              </div>

              <!-- ─ Section 3: ชื่อและคำอธิบาย ─ -->
              <div class="space-y-3">
                <label class="section-label">ข้อความ (ไม่บังคับ)</label>
                <input v-model="form.title" type="text" placeholder="หัวข้อแบนเนอร์"
                  class="input-field w-full"/>
                <input v-model="form.subtitle" type="text" placeholder="คำบรรยายสั้นๆ"
                  class="input-field w-full"/>
                <textarea v-model="form.description" rows="2"
                  placeholder="คำอธิบายเพิ่มเติม (แสดงใน tooltip หรือหน้า detail)"
                  class="input-field w-full resize-none"></textarea>
              </div>

              <!-- ─ Section 4: ลิงค์ ─ -->
              <div>
                <label class="section-label">ลิงค์เมื่อคลิก</label>
                <div class="grid grid-cols-3 gap-2 mt-2">
                  <button v-for="lt in LINK_OPTIONS" :key="lt.v"
                    @click="form.link_type = lt.v"
                    :class="['flex flex-col items-start p-3 rounded-2xl border-2 text-left transition-all',
                      form.link_type===lt.v
                        ? 'border-primary bg-primary-light'
                        : 'border-slate-200 hover:border-primary/40']">
                    <p :class="['text-sm font-bold', form.link_type===lt.v ? 'text-primary' : 'text-slate-700']">{{ lt.label }}</p>
                    <p class="text-[10px] text-slate-400 mt-0.5 leading-snug">{{ lt.desc }}</p>
                  </button>
                </div>
                <div v-if="form.link_type !== 'none'" class="mt-2 space-y-1">
                  <input v-model="form.link_url" type="text"
                    :placeholder="form.link_type==='internal' ? '#/page หรือ /หน้า' : 'https://...'"
                    class="input-field w-full"/>
                  <p v-if="form.link_type==='external'" class="text-xs text-slate-400">
                    จะเปิดในแท็บใหม่ — ใส่ URL เต็ม เช่น https://google.com
                  </p>
                  <p v-else class="text-xs text-slate-400">
                    ใส่ path ภายใน เช่น #/download หรือ #/news
                  </p>
                </div>
              </div>

              <!-- ─ Section 5: ตัวเลือก ─ -->
              <div class="grid grid-cols-2 gap-3">
                <!-- Active toggle -->
                <div class="p-3 rounded-2xl border border-slate-100 bg-slate-50 flex items-center justify-between">
                  <div>
                    <p class="text-sm font-bold text-slate-700">แสดง/ซ่อน</p>
                    <p class="text-xs text-slate-400">{{ form.is_active ? 'แสดงบนหน้าเว็บ' : 'ซ่อนไว้ก่อน' }}</p>
                  </div>
                  <button @click="form.is_active = !form.is_active"
                    :class="['relative w-12 h-6 rounded-full transition-colors flex-shrink-0',
                      form.is_active ? 'bg-emerald-500' : 'bg-slate-300']">
                    <span :class="['absolute w-5 h-5 bg-white rounded-full shadow-sm top-0.5 transition-all',
                      form.is_active ? 'left-6' : 'left-0.5']"></span>
                  </button>
                </div>
                <!-- Pinned toggle -->
                <div class="p-3 rounded-2xl border border-slate-100 bg-slate-50 flex items-center justify-between">
                  <div>
                    <p class="text-sm font-bold text-slate-700">ปักหมุด</p>
                    <p class="text-xs text-slate-400">{{ form.is_pinned ? 'แสดงก่อนเสมอ' : 'ลำดับปกติ' }}</p>
                  </div>
                  <button @click="form.is_pinned = !form.is_pinned"
                    :class="['relative w-12 h-6 rounded-full transition-colors flex-shrink-0',
                      form.is_pinned ? 'bg-amber-400' : 'bg-slate-300']">
                    <span :class="['absolute w-5 h-5 bg-white rounded-full shadow-sm top-0.5 transition-all',
                      form.is_pinned ? 'left-6' : 'left-0.5']"></span>
                  </button>
                </div>
                <!-- Sort order (spans 2 cols) -->
                <div class="col-span-2">
                  <label class="block text-xs font-bold text-slate-600 mb-1.5">ลำดับการแสดง (น้อยสุด = แสดงก่อน)</label>
                  <input v-model.number="form.sort_order" type="number" min="0"
                    class="input-field w-full"/>
                </div>
              </div>

            </div><!-- /body -->

            <!-- Modal footer -->
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 bg-slate-50/50 flex-shrink-0">
              <button @click="showModal = false"
                class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-100 transition-colors">
                ยกเลิก
              </button>
              <button @click="saveBanner" :disabled="saving"
                class="flex items-center gap-2 px-7 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
                <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 3.75H6.912a2.25 2.25 0 00-2.15 1.588L2.35 13.177a2.25 2.25 0 00-.1.661V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 00-2.15-1.588H15M2.25 13.5h3.86a2.25 2.25 0 012.012 1.244l.256.512a2.25 2.25 0 002.013 1.244h3.218a2.25 2.25 0 002.013-1.244l.256-.512a2.25 2.25 0 012.013-1.244h3.859M12 3v8.25m0 0l-3-3m3 3l3-3"/>
                </svg>
                {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Storage Browser ──────────────────────────────────────── -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showStorage"
          class="fixed inset-0 z-[150] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showStorage = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 flex items-center gap-2">
                <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776"/>
                </svg>
                เลือกไฟล์จาก Storage
              </h3>
              <button @click="showStorage = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto p-6">
              <StorageBrowser bucket="banners" title="ภาพ/วิดีโอแบนเนอร์" :selectable="true"
                @select="onStorageSelect"/>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Image Cropper ────────────────────────────────────────── -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="currentRatioInfo.ratio"
      :title="`ครอบรูปแบนเนอร์ (${currentRatioInfo.value}) — แนะนำ ${currentRatioInfo.size}`"
      @close="showCropper = false"
      @cropped="onCropped"/>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

.section-label {
  @apply block text-xs font-bold text-slate-600 uppercase tracking-wider;
}
.input-field {
  @apply px-3 py-2.5 border border-slate-200 rounded-xl text-sm
         focus:outline-none focus:ring-2
         bg-white transition-all;
  --tw-ring-color: var(--color-primary-ring);
}
.input-field:focus {
  border-color: var(--color-primary);
}
</style>
