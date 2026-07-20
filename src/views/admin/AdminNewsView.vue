<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import StorageBrowser    from '../../components/StorageBrowser.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'

// ── Categories ───────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'all',         label: 'ทั้งหมด',               path: 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2' },
  { value: 'pr',          label: 'ประชาสัมพันธ์',           path: 'M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z' },
  { value: 'supervision', label: 'นิเทศการศึกษา',           path: 'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z' },
  { value: 'training',    label: 'อบรม/สัมมนา',             path: 'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25' },
  { value: 'policy',      label: 'นโยบาย/หนังสือเวียน',     path: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  { value: 'other',       label: 'ทั่วไป',                   path: 'M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z' },
]

// ── Embed type map ───────────────────────────────────────────────
const EMBED_TYPES = {
  youtube: { label: 'YouTube',        color: 'bg-red-100 text-red-700',       icon: 'M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z' },
  drive:   { label: 'Google Drive',   color: 'bg-blue-100 text-blue-700',     icon: 'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3' },
  slides:  { label: 'Google Slides',  color: 'bg-yellow-100 text-yellow-700', icon: 'M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5' },
  canva:   { label: 'Canva',          color: 'bg-purple-100 text-purple-700', icon: 'M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5' },
  pdf:     { label: 'PDF',            color: 'bg-orange-100 text-orange-700', icon: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  iframe:  { label: 'Embed อื่นๆ',    color: 'bg-slate-100 text-slate-600',   icon: 'M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5' },
}

// ── Embed detect / transform ─────────────────────────────────────
function detectEmbedType(url) {
  if (!url) return ''
  if (/youtube\.com\/watch|youtu\.be\//.test(url)) return 'youtube'
  if (/drive\.google\.com\/file/.test(url))         return 'drive'
  if (/docs\.google\.com\/presentation/.test(url))  return 'slides'
  if (/canva\.com\/design/.test(url))               return 'canva'
  if (/\.pdf(\?|$)/i.test(url) || /docs\.google\.com\/viewer/.test(url)) return 'pdf'
  if (url.startsWith('http'))                        return 'iframe'
  return ''
}

function youtubeThumbnail(url) {
  const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&?/]+)/)
  return m ? `https://img.youtube.com/vi/${m[1]}/mqdefault.jpg` : ''
}

// ── State ────────────────────────────────────────────────────────
const newsList        = ref([])
const currentUserId   = ref(null)
const currentRole     = ref(null)
const loading         = ref(true)
const saving          = ref(false)
const showModal       = ref(false)
const showStorage     = ref(false)
const showCropper     = ref(false)
const coverUploading  = ref(false)
const coverUploadErr  = ref('')
const showHtmlSection    = ref(false)
const showHtmlPreview    = ref(false)
const showCoverUrlInput  = ref(false)
const coverUrlDraft      = ref('')
const activeCategory  = ref('all')
const searchQ         = ref('')

const emptyForm = () => ({
  id:           null,
  category:     'pr',
  title:        '',
  excerpt:      '',
  content:      '',
  cover_url:    '',
  file_url:     '',
  embed_url:    '',
  embed_type:   '',
  html_code:    '',
  show_cover:   true,
  show_title:   true,
  is_pinned:    false,
  is_published: false,
  published_at: '',
})
const form = ref(emptyForm())

// Auto-detect embed type on URL change
watch(() => form.value.embed_url, (url) => {
  form.value.embed_type = detectEmbedType(url)
})

// ── Fetch ─────────────────────────────────────────────────────────
async function fetchNews() {
  loading.value = true
  const { data, error } = await supabase
    .from('news')
    .select('*')
    .order('is_pinned', { ascending: false })
    .order('created_at', { ascending: false })
  if (!error) newsList.value = data || []
  loading.value = false
}
onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  currentUserId.value = user?.id || null
  if (user) {
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    currentRole.value = profile?.role || null
  }
  await fetchNews()
})

const isAdmin = computed(() => ['super_admin','admin'].includes(currentRole.value))
function canEditNews(n) { return isAdmin.value || n.created_by === currentUserId.value }

// ── Computed ──────────────────────────────────────────────────────
const filtered = computed(() => {
  let list = newsList.value
  if (activeCategory.value !== 'all')
    list = list.filter(n => n.category === activeCategory.value)
  if (searchQ.value)
    list = list.filter(n => n.title.toLowerCase().includes(searchQ.value.toLowerCase()))
  return list
})

const catCounts = computed(() => {
  const counts = { all: newsList.value.length }
  CATEGORIES.slice(1).forEach(c => {
    counts[c.value] = newsList.value.filter(n => n.category === c.value).length
  })
  return counts
})

// ── Open modal ────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  coverUploadErr.value = ''
  showHtmlSection.value = false
  showHtmlPreview.value = false
  showCoverUrlInput.value = false
  coverUrlDraft.value = ''
  showModal.value = true
}
function openEdit(n) {
  form.value = {
    ...emptyForm(),
    ...n,
    show_cover:   n.show_cover  ?? true,
    show_title:   n.show_title  ?? true,
    embed_url:    n.embed_url   || '',
    embed_type:   n.embed_type  || '',
    html_code:    n.html_code   || '',
    published_at: n.published_at ? n.published_at.slice(0, 16) : '',
  }
  coverUploadErr.value = ''
  showHtmlSection.value = !!(n.html_code)
  showHtmlPreview.value = false
  showCoverUrlInput.value = false
  coverUrlDraft.value = ''
  showModal.value = true
}

// ── HTML preview (wrap in full document + auto-height script) ─────
function wrappedHtml(code) {
  if (!code) return ''
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; overflow: hidden; font-family: Sarabun, sans-serif; }
  </style>
</head>
<body>
${code}
<script>
  function report() {
    const h = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
    window.parent.postMessage({ type: 'iframeHeight', height: h }, '*');
  }
  window.addEventListener('load', report);
  try { new ResizeObserver(report).observe(document.body) } catch(e) {}
<\/script>
</body>
</html>`
}

// ── Cover upload from ImageCropperModal ───────────────────────────
const { uploadImage: uploadCoverExternal } = useExternalUpload()

async function onCoverCropped({ blob }) {
  coverUploading.value = true
  coverUploadErr.value = ''
  try {
    if (externalUploadEnabled) {
      form.value.cover_url = await uploadCoverExternal(blob, 'news')
    } else {
      const fileName = `news/cover_${Date.now()}.png`
      const { error } = await supabase.storage
        .from('images')
        .upload(fileName, blob, { contentType: 'image/png', upsert: false })
      if (error) throw error
      const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(fileName)
      form.value.cover_url = publicUrl
    }
    showCropper.value = false
  } catch (e) {
    coverUploadErr.value = e.message || 'อัปโหลดรูปปกไม่สำเร็จ'
  }
  coverUploading.value = false
}

// ── Save ──────────────────────────────────────────────────────────
async function saveNews() {
  if (!form.value.title.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อข่าว', confirmButtonColor: '#3b82f6' })

  saving.value = true
  const { data: { user } } = await supabase.auth.getUser()
  const payload = {
    category:     form.value.category,
    title:        form.value.title.trim(),
    excerpt:      form.value.excerpt.trim(),
    content:      form.value.content.trim(),
    cover_url:    form.value.cover_url.trim(),
    file_url:     form.value.file_url.trim(),
    embed_url:    form.value.embed_url.trim(),
    embed_type:   form.value.embed_type,
    html_code:    form.value.html_code.trim(),
    show_cover:   form.value.show_cover,
    show_title:   form.value.show_title,
    is_pinned:    form.value.is_pinned,
    is_published: form.value.is_published,
    published_at: form.value.is_published
      ? (form.value.published_at || new Date().toISOString())
      : null,
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('news').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('news').insert({ ...payload, created_by: user?.id || null }))
  }

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
    showModal.value = false
    await fetchNews()
  }
  saving.value = false
}

// ── Toggle publish ────────────────────────────────────────────────
async function togglePublish(n) {
  const is_published = !n.is_published
  const published_at = is_published ? new Date().toISOString() : null
  const { error } = await supabase.from('news').update({ is_published, published_at }).eq('id', n.id)
  if (!error) { n.is_published = is_published; n.published_at = published_at }
}

// ── Delete ────────────────────────────────────────────────────────
async function deleteNews(n) {
  const res = await Swal.fire({
    title: 'ลบข่าวนี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('news').delete().eq('id', n.id)
  await deleteUploadedFile(n.cover_url)
  newsList.value = newsList.value.filter(x => x.id !== n.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

// ── Storage select ────────────────────────────────────────────────
const storageTarget = ref('cover')
function pickStorage(target) {
  storageTarget.value = target
  showStorage.value = true
}
function onStorageSelect({ url }) {
  if (storageTarget.value === 'cover') form.value.cover_url = url
  else form.value.file_url = url
  showStorage.value = false
}

// ── Helpers ───────────────────────────────────────────────────────
function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' })
}
function getCatLabel(val) {
  return CATEGORIES.find(c => c.value === val)?.label || val
}
function getCatPath(val) {
  return (CATEGORIES.find(c => c.value === val) || CATEGORIES[5]).path
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- ── Header ─────────────────────────────────────────────────── -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
          </svg>
          จัดการข่าวสาร
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">ข่าวประชาสัมพันธ์ นิเทศ อบรม และหนังสือเวียน</p>
      </div>
      <button @click="openAdd"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        เพิ่มข่าวใหม่
      </button>
    </div>

    <!-- ── Filter tabs + search ────────────────────────────────────── -->
    <div class="flex flex-wrap gap-2 items-center">
      <button v-for="cat in CATEGORIES" :key="cat.value"
        @click="activeCategory = cat.value"
        :class="['flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-bold transition-all',
          activeCategory === cat.value
            ? 'bg-primary text-white shadow'
            : 'bg-white border border-slate-200 text-slate-600 hover:border-primary hover:text-primary']">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" :d="cat.path"/>
        </svg>
        {{ cat.label }}
        <span :class="['text-xs px-1.5 py-0.5 rounded-full',
          activeCategory === cat.value ? 'bg-white/30 text-white' : 'bg-slate-100 text-slate-500']">
          {{ catCounts[cat.value] || 0 }}
        </span>
      </button>
      <div class="ml-auto">
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อข่าว..."
          class="px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-48"/>
      </div>
    </div>

    <!-- ── Loading ─────────────────────────────────────────────────── -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 5" :key="i" class="h-20 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- ── Empty ───────────────────────────────────────────────────── -->
    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <svg class="w-12 h-12 text-slate-300 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
      </svg>
      <p class="font-bold text-slate-600 mb-1">ไม่มีข่าวสาร</p>
      <p class="text-sm text-slate-400">{{ searchQ ? 'ไม่พบข่าวที่ค้นหา' : 'เพิ่มข่าวแรกได้เลย' }}</p>
    </div>

    <!-- ── News table ──────────────────────────────────────────────── -->
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-slate-100 bg-slate-50">
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ข่าว</th>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider hidden md:table-cell">หมวดหมู่</th>
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider hidden lg:table-cell">วันที่</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden lg:table-cell">
              <span class="flex items-center justify-center gap-1">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                อ่าน
              </span>
            </th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">สถานะ</th>
            <th class="px-4 py-3 text-right text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <tr v-for="n in filtered" :key="n.id" class="hover:bg-slate-50 transition-colors">
            <!-- Title + cover -->
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                <div v-if="n.cover_url" class="w-12 h-10 rounded-lg overflow-hidden flex-shrink-0 bg-slate-100">
                  <img :src="n.cover_url" class="w-full h-full object-cover"/>
                </div>
                <div v-else class="w-12 h-10 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0">
                  <svg class="w-5 h-5 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" :d="getCatPath(n.category)"/>
                  </svg>
                </div>
                <div class="min-w-0">
                  <div class="flex items-center gap-1.5">
                    <svg v-if="n.is_pinned" class="w-3.5 h-3.5 text-amber-500 flex-shrink-0" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/>
                    </svg>
                    <!-- embed indicator -->
                    <span v-if="n.embed_type"
                      :class="['text-[10px] font-bold px-1.5 py-0.5 rounded-full flex-shrink-0', EMBED_TYPES[n.embed_type]?.color]">
                      {{ EMBED_TYPES[n.embed_type]?.label }}
                    </span>
                    <p class="font-bold text-slate-800 truncate max-w-[200px] md:max-w-[300px]">{{ n.title }}</p>
                  </div>
                  <p v-if="n.excerpt" class="text-xs text-slate-400 truncate max-w-[200px] md:max-w-[300px] mt-0.5">{{ n.excerpt }}</p>
                </div>
              </div>
            </td>
            <!-- Category -->
            <td class="px-4 py-3 hidden md:table-cell">
              <span class="inline-flex items-center gap-1.5 px-2 py-1 bg-slate-100 text-slate-600 rounded-lg text-xs font-bold">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="getCatPath(n.category)"/>
                </svg>
                {{ getCatLabel(n.category) }}
              </span>
            </td>
            <!-- Date -->
            <td class="px-4 py-3 text-xs text-slate-400 hidden lg:table-cell whitespace-nowrap">
              {{ n.published_at ? formatDate(n.published_at) : '—' }}
            </td>
            <!-- View count -->
            <td class="px-4 py-3 text-center hidden lg:table-cell">
              <span class="text-sm font-bold text-slate-600">{{ (n.view_count || 0).toLocaleString() }}</span>
            </td>
            <!-- Published badge -->
            <td class="px-4 py-3 text-center">
              <button @click="togglePublish(n)" :disabled="!canEditNews(n)"
                :class="['px-2.5 py-1 rounded-full text-xs font-bold transition-all',
                  !canEditNews(n) ? 'opacity-50 cursor-not-allowed' : '',
                  n.is_published ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                {{ n.is_published ? 'เผยแพร่' : 'ร่าง' }}
              </button>
            </td>
            <!-- Actions -->
            <td class="px-4 py-3 text-right">
              <div v-if="canEditNews(n)" class="flex items-center justify-end gap-1.5">
                <button @click="openEdit(n)"
                  class="p-1.5 bg-blue-50 text-blue-600 rounded-xl hover:bg-blue-100 transition-all">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"/>
                  </svg>
                </button>
                <button @click="deleteNews(n)"
                  class="p-1.5 bg-red-50 text-red-500 rounded-xl hover:bg-red-100 transition-all">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                  </svg>
                </button>
              </div>
              <span v-else class="text-xs text-slate-300">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- ══════════════════════════════════════════════════════════════
         MODAL ADD / EDIT
    ═══════════════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">

            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg flex items-center gap-2">
                <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round"
                    :d="form.id
                      ? 'M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z'
                      : 'M12 4.5v15m7.5-7.5h-15'"/>
                </svg>
                {{ form.id ? 'แก้ไขข่าว' : 'เพิ่มข่าวใหม่' }}
              </h3>
              <button @click="showModal = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Body (scrollable) -->
            <div class="flex-1 overflow-y-auto p-6 space-y-5">

              <!-- ① Category -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-2">หมวดหมู่ <span class="text-red-400">*</span></label>
                <div class="flex flex-wrap gap-2">
                  <button v-for="cat in CATEGORIES.slice(1)" :key="cat.value"
                    @click="form.category = cat.value"
                    :class="['flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
                      form.category === cat.value
                        ? 'border-primary bg-primary/5 text-primary'
                        : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" :d="cat.path"/>
                    </svg>
                    {{ cat.label }}
                  </button>
                </div>
              </div>

              <!-- ② Title -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อข่าว <span class="text-red-400">*</span></label>
                <input v-model="form.title" type="text" placeholder="ชื่อข่าวสาร..."
                  class="input-field w-full"/>
              </div>

              <!-- ③ Excerpt -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">เนื้อหาย่อ</label>
                <textarea v-model="form.excerpt" rows="2" placeholder="สรุปสั้น ๆ (แสดงบนการ์ดข่าว)..."
                  class="input-field w-full resize-none"/>
              </div>

              <!-- ④ Content -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">เนื้อหาเต็ม</label>
                <textarea v-model="form.content" rows="5" placeholder="รายละเอียดข่าวสาร..."
                  class="input-field w-full resize-y"/>
              </div>

              <!-- ══ DIVIDER ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">รูปปกและการแสดงผล</p>
              </div>

              <!-- ⑤ Cover image -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-2">รูปปก (แนะนำ 16:9)</label>

                <!-- Preview -->
                <div v-if="form.cover_url" class="relative rounded-2xl overflow-hidden mb-2 bg-slate-900 group"
                  style="aspect-ratio:16/9">
                  <img :src="form.cover_url" class="w-full h-full object-cover"/>
                  <!-- Action overlay -->
                  <div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all flex items-center justify-center gap-2 opacity-0 group-hover:opacity-100">
                    <button @click="showCropper = true"
                      class="flex items-center gap-1 px-3 py-1.5 bg-white text-slate-800 text-xs font-bold rounded-xl shadow hover:bg-primary hover:text-white transition-colors">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M7.5 3.75H6A2.25 2.25 0 003.75 6v1.5M16.5 3.75H18A2.25 2.25 0 0120.25 6v1.5m0 9V18A2.25 2.25 0 0118 20.25h-1.5m-9 0H6A2.25 2.25 0 013.75 18v-1.5M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                      </svg>
                      เปลี่ยนรูป
                    </button>
                    <button @click="form.cover_url = ''"
                      class="flex items-center gap-1 px-3 py-1.5 bg-red-500 text-white text-xs font-bold rounded-xl shadow hover:bg-red-600 transition-colors">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                      ลบ
                    </button>
                  </div>
                  <!-- Always-visible small buttons (for touch) -->
                  <div class="absolute top-2 right-2 flex gap-1 md:hidden">
                    <button @click="showCropper = true"
                      class="px-2 py-1 bg-white/90 text-slate-800 text-[10px] font-bold rounded-lg shadow">เปลี่ยน</button>
                    <button @click="form.cover_url = ''"
                      class="px-2 py-1 bg-red-500/90 text-white text-[10px] font-bold rounded-lg shadow">ลบ</button>
                  </div>
                </div>

                <!-- No cover placeholder -->
                <div v-else class="rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50 mb-2">
                  <!-- 3 ปุ่มเลือกวิธี -->
                  <div class="flex flex-col sm:flex-row items-center justify-center gap-3 py-6 px-4">
                    <!-- Upload + Crop -->
                    <button @click="showCropper = true; showCoverUrlInput = false" :disabled="coverUploading"
                      class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white text-xs font-bold rounded-xl transition-colors disabled:opacity-50 shadow">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                      </svg>
                      อัปโหลดและครอบภาพ
                    </button>
                    <span class="text-slate-300 text-xs font-bold">หรือ</span>
                    <!-- Pick from Storage -->
                    <button @click="pickStorage('cover'); showCoverUrlInput = false"
                      class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"/>
                      </svg>
                      เลือกจาก Storage
                    </button>
                    <span class="text-slate-300 text-xs font-bold">หรือ</span>
                    <!-- URL link -->
                    <button @click="showCoverUrlInput = !showCoverUrlInput; coverUrlDraft = ''"
                      :class="['flex items-center gap-2 px-4 py-2.5 text-xs font-bold rounded-xl transition-colors border-2',
                        showCoverUrlInput
                          ? 'border-primary bg-primary/5 text-primary'
                          : 'border-slate-200 bg-white hover:bg-slate-50 text-slate-600']">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/>
                      </svg>
                      ใส่ลิงก์ URL
                    </button>
                  </div>
                  <!-- URL input (แสดงเมื่อกด "ใส่ลิงก์ URL") -->
                  <div v-if="showCoverUrlInput" class="px-4 pb-4 flex gap-2">
                    <input v-model="coverUrlDraft" type="url"
                      placeholder="https://example.com/image.jpg"
                      class="flex-1 px-3 py-2 text-sm border border-slate-200 rounded-xl focus:outline-none focus:border-primary bg-white transition-colors"
                      @keydown.enter.prevent="form.cover_url = coverUrlDraft.trim(); showCoverUrlInput = false"/>
                    <button
                      @click="form.cover_url = coverUrlDraft.trim(); showCoverUrlInput = false"
                      :disabled="!coverUrlDraft.trim()"
                      class="px-4 py-2 bg-primary text-white text-xs font-bold rounded-xl disabled:opacity-40 hover:bg-primary-dark transition-colors">
                      ใช้
                    </button>
                    <button @click="showCoverUrlInput = false; coverUrlDraft = ''"
                      class="px-3 py-2 text-slate-400 hover:text-slate-600 transition-colors text-xs">
                      ยกเลิก
                    </button>
                  </div>
                </div>

                <!-- Uploading -->
                <div v-if="coverUploading" class="flex items-center gap-2 text-xs text-primary">
                  <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                  </svg>
                  กำลังอัปโหลดรูปปก...
                </div>
                <p v-if="coverUploadErr" class="text-xs text-red-500 mt-1">{{ coverUploadErr }}</p>
              </div>

              <!-- ⑥ Show cover / show title toggles -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">แสดงรูปปกในหน้าข่าว</label>
                  <button @click="form.show_cover = !form.show_cover"
                    :class="['w-full py-2 text-xs font-bold rounded-xl border-2 transition-all flex items-center justify-center gap-1.5',
                      form.show_cover
                        ? 'border-primary bg-primary/5 text-primary'
                        : 'border-slate-200 text-slate-400 bg-slate-50']">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round"
                        :d="form.show_cover
                          ? 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'
                          : 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'"/>
                    </svg>
                    {{ form.show_cover ? 'แสดงรูปปก' : 'ซ่อนรูปปก' }}
                  </button>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">แสดงชื่อข่าวในหน้าข่าว</label>
                  <button @click="form.show_title = !form.show_title"
                    :class="['w-full py-2 text-xs font-bold rounded-xl border-2 transition-all flex items-center justify-center gap-1.5',
                      form.show_title
                        ? 'border-primary bg-primary/5 text-primary'
                        : 'border-slate-200 text-slate-400 bg-slate-50']">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round"
                        :d="form.show_title
                          ? 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'
                          : 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'"/>
                    </svg>
                    {{ form.show_title ? 'แสดงชื่อข่าว' : 'ซ่อนชื่อข่าว' }}
                  </button>
                </div>
              </div>

              <!-- ══ DIVIDER ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">เนื้อหาแทรก (Embed)</p>
              </div>

              <!-- ⑦ Embed URL -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">
                  แทรก PDF / สไลด์ / Canva / YouTube
                </label>
                <input v-model="form.embed_url" type="url"
                  placeholder="วาง URL จาก Google Drive, Slides, Canva, YouTube, PDF..."
                  class="input-field w-full"/>

                <!-- Auto-detect badge -->
                <div v-if="form.embed_type" class="mt-2 flex items-center gap-2 flex-wrap">
                  <span :class="['inline-flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-full', EMBED_TYPES[form.embed_type]?.color]">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" :d="EMBED_TYPES[form.embed_type]?.icon"/>
                    </svg>
                    {{ EMBED_TYPES[form.embed_type]?.label }}
                  </span>
                  <span class="text-xs text-slate-400">ตรวจพบอัตโนมัติ</span>
                  <button @click="form.embed_url = ''; form.embed_type = ''"
                    class="ml-auto text-xs text-slate-400 hover:text-red-500 transition-colors">ล้าง</button>
                </div>

                <!-- YouTube thumbnail preview -->
                <div v-if="form.embed_type === 'youtube' && form.embed_url"
                  class="mt-2 rounded-xl overflow-hidden bg-slate-100 relative" style="aspect-ratio:16/9;max-height:130px">
                  <img :src="youtubeThumbnail(form.embed_url)" class="w-full h-full object-cover"/>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <div class="w-10 h-10 bg-red-600/90 rounded-full flex items-center justify-center shadow-lg">
                      <svg class="w-5 h-5 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z"/>
                      </svg>
                    </div>
                  </div>
                </div>

                <!-- Help chips -->
                <div class="flex flex-wrap gap-1.5 mt-2">
                  <span class="text-[10px] text-slate-400 font-bold mr-1">รองรับ:</span>
                  <span v-for="(v, k) in EMBED_TYPES" :key="k"
                    :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', v.color]">
                    {{ v.label }}
                  </span>
                </div>
              </div>

              <!-- ══ DIVIDER ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">HTML โค้ดแบบกำหนดเอง</p>
              </div>

              <!-- ⑧ HTML Code (Canva Code / Custom HTML+JS) -->
              <div>
                <!-- Toggle -->
                <button @click="showHtmlSection = !showHtmlSection; showHtmlPreview = false"
                  :class="['w-full flex items-center justify-between px-4 py-3 rounded-2xl border-2 text-sm font-bold transition-all',
                    showHtmlSection
                      ? 'border-violet-400 bg-violet-50 text-violet-700'
                      : 'border-slate-200 text-slate-500 hover:border-violet-300 hover:text-violet-600']">
                  <span class="flex items-center gap-2">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5"/>
                    </svg>
                    {{ showHtmlSection ? 'ใช้งาน HTML โค้ดแบบกำหนดเอง' : 'เพิ่ม HTML / JS โค้ด (Canva, Widget ฯลฯ)' }}
                  </span>
                  <svg class="w-4 h-4 transition-transform" :class="showHtmlSection ? 'rotate-180' : ''"
                    fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                  </svg>
                </button>

                <div v-if="showHtmlSection" class="mt-3 space-y-3">
                  <!-- Info box -->
                  <div class="flex gap-2 p-3 bg-violet-50 rounded-xl border border-violet-100 text-xs text-violet-700">
                    <svg class="w-4 h-4 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
                    </svg>
                    <span>วางโค้ดจาก <strong>Canva</strong>, <strong>Google Sites</strong>, <strong>Flourish</strong>, หรือ HTML+JS ใดก็ได้ — ทำงานในกล่อง sandbox แยกปลอดภัย</span>
                  </div>

                  <!-- Textarea -->
                  <textarea v-model="form.html_code" rows="8"
                    placeholder="&lt;!-- วางโค้ด HTML + JS ที่นี่ --&gt;
&lt;div style=&quot;...&quot;&gt;
  &lt;iframe src=&quot;...&quot;&gt;&lt;/iframe&gt;
&lt;/div&gt;"
                    class="input-field w-full resize-y font-mono text-xs"
                    style="line-height:1.6"/>

                  <!-- Preview toggle -->
                  <div class="flex items-center gap-2">
                    <button v-if="form.html_code.trim()"
                      @click="showHtmlPreview = !showHtmlPreview"
                      :class="['flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl border transition-all',
                        showHtmlPreview
                          ? 'bg-violet-600 text-white border-violet-600'
                          : 'border-violet-300 text-violet-600 hover:bg-violet-50']">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                      </svg>
                      {{ showHtmlPreview ? 'ปิดตัวอย่าง' : 'ดูตัวอย่าง' }}
                    </button>
                    <button v-if="form.html_code.trim()" @click="form.html_code = ''; showHtmlPreview = false"
                      class="flex items-center gap-1 text-xs text-slate-400 hover:text-red-500 transition-colors px-2 py-1.5">
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                      </svg>
                      ล้างโค้ด
                    </button>
                  </div>

                  <!-- Inline preview iframe -->
                  <div v-if="showHtmlPreview && form.html_code.trim()"
                    class="rounded-2xl overflow-hidden border-2 border-violet-200 bg-white shadow-sm">
                    <div class="flex items-center gap-2 px-3 py-2 bg-violet-50 border-b border-violet-100">
                      <div class="flex gap-1">
                        <div class="w-2.5 h-2.5 rounded-full bg-red-400"></div>
                        <div class="w-2.5 h-2.5 rounded-full bg-yellow-400"></div>
                        <div class="w-2.5 h-2.5 rounded-full bg-green-400"></div>
                      </div>
                      <span class="text-[10px] font-bold text-violet-500 ml-1">ตัวอย่าง (sandbox)</span>
                    </div>
                    <iframe
                      :srcdoc="wrappedHtml(form.html_code)"
                      sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
                      class="w-full border-none block"
                      style="min-height:300px;max-height:500px;height:400px"/>
                  </div>
                </div>
              </div>

              <!-- ══ DIVIDER ══ -->
              <div class="border-t border-slate-100 pt-1">
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">ไฟล์แนบและการตั้งค่า</p>
              </div>

              <!-- ⑧ File attachment -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ไฟล์แนบ / ลิงก์เพิ่มเติม</label>
                <div class="flex gap-2">
                  <input v-model="form.file_url" type="text" placeholder="URL ไฟล์แนบ (PDF, ฯลฯ) หรือลิงก์ภายนอก"
                    class="input-field flex-1"/>
                  <button @click="pickStorage('file')"
                    class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors flex-shrink-0">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"/>
                    </svg>
                  </button>
                </div>
              </div>

              <!-- ⑨ Published + Pinned -->
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">สถานะการเผยแพร่</label>
                  <button @click="form.is_published = !form.is_published"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_published ? 'border-emerald-400 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_published ? 'เผยแพร่' : 'บันทึกร่าง' }}
                  </button>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">ปักหมุด</label>
                  <button @click="form.is_pinned = !form.is_pinned"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_pinned ? 'border-amber-400 bg-amber-50 text-amber-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_pinned ? 'ปักหมุดแล้ว' : 'ไม่ปักหมุด' }}
                  </button>
                </div>
              </div>

              <!-- ⑩ Published date -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">วันเวลาเผยแพร่</label>
                <input v-model="form.published_at" type="datetime-local"
                  class="input-field w-full"/>
              </div>

            </div><!-- /body -->

            <!-- Footer -->
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false"
                class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">
                ยกเลิก
              </button>
              <button @click="saveNews" :disabled="saving || coverUploading"
                class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
                <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 3.75V16.5L12 14.25 7.5 16.5V3.75m9 0H18A2.25 2.25 0 0120.25 6v12A2.25 2.25 0 0118 20.25H6A2.25 2.25 0 013.75 18V6A2.25 2.25 0 016 3.75h1.5m9 0h-9"/>
                </svg>
                บันทึก
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ══════════════════════════════════════════════════════════════
         IMAGE CROPPER MODAL
    ═══════════════════════════════════════════════════════════════ -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="16/9"
      title="ครอบรูปปกข่าว (16:9)"
      @close="showCropper = false"
      @cropped="onCoverCropped"/>

    <!-- ══════════════════════════════════════════════════════════════
         STORAGE BROWSER MODAL
    ═══════════════════════════════════════════════════════════════ -->
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
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"/>
                </svg>
                เลือกไฟล์จาก Storage
              </h3>
              <button @click="showStorage = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto p-6">
              <StorageBrowser
                :bucket="storageTarget === 'cover' ? 'images' : 'documents'"
                :title="storageTarget === 'cover' ? 'รูปภาพ' : 'เอกสาร'"
                :selectable="true"
                @select="onStorageSelect"/>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

.input-field {
  @apply px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none;
}
.input-field:focus {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-primary) 20%, transparent);
  outline: none;
}
</style>
