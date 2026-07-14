<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'
import IconPicker from '../../components/IconPicker.vue'
import ImageLinkGalleryEditor from '../../components/ImageLinkGalleryEditor.vue'
import { BG_TYPES, BG_PRESETS, GRADIENT_PRESETS, getBgStyle } from '../../composables/useBgStyle'

const route  = useRoute()
const router = useRouter()

const page    = ref(null)
const blocks  = ref([])
const layout  = ref('narrow')
const saving  = ref(false)
const loading = ref(true)
const myProfile = ref(null)

// ── Page header — mode toggle (icon ใช้ page.nav_icon ตัวเดิม / media อัปโหลดใหม่) ──
const headerMode        = ref('icon')
const headerMediaUrl    = ref('')
const headerMediaType   = ref('')
const headerAspectRatio = ref('21:9')

const ASPECT_RATIOS = [
  { value: '21:9', label: '21:9 กว้างเตี้ย', ratio: 21/9 },
  { value: '16:9', label: '16:9 มาตรฐาน',    ratio: 16/9 },
  { value: '3:1',  label: '3:1 เว็บราชการ',   ratio: 3/1 },
  { value: '4:1',  label: '4:1 บางมาก',       ratio: 4/1 },
]
const headerCropRatio = computed(() => ASPECT_RATIOS.find(r => r.value === headerAspectRatio.value)?.ratio || 21/9)

const LAYOUT_OPTIONS = [
  { value: 'narrow', label: 'แคบ (768px)',  class: 'max-w-3xl' },
  { value: 'medium', label: 'กลาง (1024px)', class: 'max-w-5xl' },
  { value: 'wide',   label: 'กว้าง (1280px)', class: 'max-w-7xl' },
]

// permission: admin เต็ม, supervisor ต้องอยู่ใน assigned_users
const canEdit = computed(() => {
  if (!myProfile.value || !page.value) return false
  if (['super_admin','admin'].includes(myProfile.value.role)) return true
  return (page.value.assigned_users || []).includes(myProfile.value.id)
})

const BLOCK_TYPES = [
  { type: 'heading', label: 'หัวข้อ',    iconName: 'document'  },
  { type: 'text',    label: 'ข้อความ',   iconName: 'clipboard' },
  { type: 'image',   label: 'รูปภาพ',   iconName: 'folder'    },
  { type: 'embed',   label: 'Embed URL', iconName: 'globe'     },
  { type: 'html',    label: 'HTML',      iconName: 'beaker'    },
  { type: 'divider', label: 'เส้นแบ่ง', iconName: 'plus'      },
  { type: 'gallery',    label: 'ภาพลิงค์',        iconName: 'link'         },
  { type: 'media-text', label: 'ภาพ+ข้อความ',    iconName: 'presentation' },
  { type: 'button',     label: 'ปุ่ม CTA',        iconName: 'star'         },
  { type: 'accordion',  label: 'Accordion/FAQ',   iconName: 'clipboard'    },
]

function newBlock(type) {
  const base = { id: crypto.randomUUID(), type }
  switch (type) {
    case 'heading':     return { ...base, level: 'h2', text: '', size: '', align: 'left', color: '' }
    case 'text':        return { ...base, text: '' }
    case 'image':       return { ...base, url: '', caption: '', align: 'center' }
    case 'embed':       return { ...base, url: '', embed_type: 'youtube', aspect: '16/9' }
    case 'html':        return { ...base, code: '' }
    case 'divider':     return { ...base }
    case 'gallery':     return { ...base, layout: 'card', title: '', items: [] }
    case 'media-text':  return { ...base, url: '', side: 'left', heading: '', text: '' }
    case 'button':      return { ...base, text: '', link_type: 'internal', link_url: '', align: 'center' }
    case 'accordion':   return { ...base, items: [] }
    default:            return base
  }
}

function newAccordionItem() {
  return { id: crypto.randomUUID(), question: '', answer: '' }
}

onMounted(async () => {
  // โหลด profile + page พร้อมกัน
  const [{ data: { user } }, { data }] = await Promise.all([
    supabase.auth.getUser(),
    supabase.from('pages').select('*').eq('id', route.params.id).single(),
  ])
  if (!data) { router.push('/dashboard/pages'); return }
  page.value    = data
  blocks.value  = Array.isArray(data.blocks) ? data.blocks : []
  layout.value  = data.layout || 'narrow'
  headerMode.value        = data.header_mode || 'icon'
  headerMediaUrl.value    = data.header_media_url  || ''
  headerMediaType.value   = data.header_media_type || ''
  headerAspectRatio.value = data.header_aspect_ratio || '21:9'

  if (user) {
    const { data: profile } = await supabase.from('profiles').select('id, role').eq('id', user.id).single()
    myProfile.value = profile
  }
  loading.value = false
})

function addBlock(type) { blocks.value.push(newBlock(type)) }

function removeBlock(idx) { blocks.value.splice(idx, 1) }

function moveUp(idx) {
  if (idx === 0) return
  ;[blocks.value[idx - 1], blocks.value[idx]] = [blocks.value[idx], blocks.value[idx - 1]]
}

function moveDown(idx) {
  if (idx === blocks.value.length - 1) return
  ;[blocks.value[idx], blocks.value[idx + 1]] = [blocks.value[idx + 1], blocks.value[idx]]
}

async function save(publish = null) {
  if (!canEdit.value) return Swal.fire({ icon: 'error', title: 'ไม่มีสิทธิ์', text: 'คุณไม่ได้รับมอบหมายให้ดูแลหน้านี้' })
  saving.value = true
  const payload = {
    blocks: blocks.value, layout: layout.value,
    nav_icon: page.value.nav_icon,
    header_mode: headerMode.value, header_media_url: headerMediaUrl.value, header_media_type: headerMediaType.value,
    header_aspect_ratio: headerAspectRatio.value,
  }
  if (publish !== null) payload.is_published = publish
  const { error } = await supabase.from('pages').update(payload).eq('id', page.value.id)
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    if (publish !== null) page.value.is_published = publish
    Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 900 })
  }
}

// ── Embed type detection ──────────────────────────────────────────
function detectEmbedType(url) {
  if (!url) return 'iframe'
  if (/youtube\.com|youtu\.be/.test(url)) return 'youtube'
  if (/drive\.google\.com/.test(url))     return 'drive'
  if (/docs\.google\.com\/presentation/.test(url)) return 'slides'
  if (/canva\.com/.test(url))             return 'canva'
  return 'iframe'
}

const EMBED_LABELS = { youtube:'YouTube', drive:'Google Drive', slides:'Slides', canva:'Canva', iframe:'Iframe' }

// ── หัวข้อ: ขนาดตัวอักษร (แยกจาก level ซึ่งคุมแค่แท็ก h2/h3/h4 เพื่อ SEO) ──
const HEADING_SIZES = [
  { value: 'sm',  label: 'เล็ก',        class: 'text-lg'   },
  { value: 'md',  label: 'กลาง',        class: 'text-xl'   },
  { value: 'lg',  label: 'ใหญ่',        class: 'text-2xl'  },
  { value: 'xl',  label: 'ใหญ่มาก',    class: 'text-3xl'  },
  { value: '2xl', label: 'ใหญ่พิเศษ',  class: 'text-4xl'  },
]
const HEADING_DEFAULT_SIZE = { h2: 'lg', h3: 'md', h4: 'sm' }
function headingSizeClass(block) {
  const size = block.size || HEADING_DEFAULT_SIZE[block.level] || 'lg'
  return HEADING_SIZES.find(s => s.value === size)?.class || 'text-2xl'
}
const HEADING_COLOR_PRESETS = ['#0f172a', '#1e3a5f', '#b8922a', '#dc2626', '#2563eb', '#059669', '#7c3aed', '#ffffff']

// ── Image block upload ────────────────────────────────────────────
const showCropper   = ref(false)
const cropTargetIdx = ref(null)
const imgUploading  = ref(false)
const imgUploadErr  = ref('')

const { uploadImage: uploadImgExternal, uploadFile: uploadRawExternal } = useExternalUpload()

function openImgCropper(idx) {
  cropTargetIdx.value = idx
  imgUploadErr.value  = ''
  showCropper.value   = true
}

async function onImageCropped({ blob }) {
  imgUploading.value = true
  imgUploadErr.value = ''
  try {
    let url
    if (externalUploadEnabled) {
      url = await uploadImgExternal(blob, 'pages')
    } else {
      const fileName = `pages/img_${Date.now()}.png`
      const { error } = await supabase.storage
        .from('images')
        .upload(fileName, blob, { contentType: 'image/png', upsert: false })
      if (error) throw error
      const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(fileName)
      url = publicUrl
    }
    blocks.value[cropTargetIdx.value].url = url
    showCropper.value = false
  } catch (e) {
    imgUploadErr.value = e.message || 'อัปโหลดรูปไม่สำเร็จ'
  }
  imgUploading.value = false
}

// ── Header media upload (แยกจาก block image — ไม่ครอปสำหรับ gif/video เพื่อไม่ให้ animation หาย) ──
const showHeaderCropper  = ref(false)
const headerRawInput     = ref(null)
const headerUploading    = ref(false)
const headerUploadErr    = ref('')
const headerRawProgress  = ref(0)

async function onHeaderCropped({ blob }) {
  showHeaderCropper.value = false
  headerUploading.value = true
  headerUploadErr.value = ''
  try {
    if (externalUploadEnabled) {
      headerMediaUrl.value = await uploadImgExternal(blob, 'page-header')
    } else {
      const fileName = `pages/header_${Date.now()}.png`
      const { error } = await supabase.storage.from('images').upload(fileName, blob, { contentType: 'image/png', upsert: false })
      if (error) throw error
      headerMediaUrl.value = supabase.storage.from('images').getPublicUrl(fileName).data.publicUrl
    }
    headerMediaType.value = 'image'
  } catch (e) {
    headerUploadErr.value = e.message || 'อัปโหลดรูปไม่สำเร็จ'
  }
  headerUploading.value = false
}

function triggerHeaderRawUpload() { headerRawInput.value?.click() }

async function onHeaderRawFileSelected(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return

  const isVideo = file.type.startsWith('video/')
  const isGif   = file.type === 'image/gif'
  if (!isVideo && !isGif) { headerUploadErr.value = 'รองรับเฉพาะไฟล์ GIF หรือวิดีโอ (.mp4, .webm, .mov)'; return }
  const MAX_MB = isVideo ? 50 : 5
  if (file.size > MAX_MB * 1024 * 1024) { headerUploadErr.value = `ไฟล์ใหญ่เกิน ${MAX_MB} MB`; return }

  headerUploadErr.value = ''
  headerUploading.value = true
  headerRawProgress.value = 0
  try {
    if (externalUploadEnabled) {
      headerMediaUrl.value = await uploadRawExternal(file, 'page-header', p => { headerRawProgress.value = p })
    } else {
      const ext = file.name.split('.').pop() || (isVideo ? 'mp4' : 'gif')
      const fileName = `pages/header_${Date.now()}.${ext}`
      const { data: { session } } = await supabase.auth.getSession()
      const baseUrl = import.meta.env.VITE_SUPABASE_URL
      await new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest()
        xhr.open('POST', `${baseUrl}/storage/v1/object/images/${fileName}`)
        xhr.setRequestHeader('Authorization', `Bearer ${session?.access_token}`)
        xhr.setRequestHeader('Content-Type', file.type)
        xhr.upload.addEventListener('progress', ev => { if (ev.lengthComputable) headerRawProgress.value = Math.round((ev.loaded/ev.total)*100) })
        xhr.addEventListener('load', () => xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error(`Upload failed (${xhr.status})`)))
        xhr.addEventListener('error', () => reject(new Error('Network error')))
        xhr.send(file)
      })
      headerMediaUrl.value = supabase.storage.from('images').getPublicUrl(fileName).data.publicUrl
    }
    headerMediaType.value = isVideo ? 'video' : 'gif'
  } catch (e) {
    headerUploadErr.value = e.message
  } finally {
    headerUploading.value = false
  }
}

async function clearHeaderMedia() {
  if (headerMediaUrl.value) await deleteUploadedFile(headerMediaUrl.value)
  headerMediaUrl.value = ''
  headerMediaType.value = ''
}
</script>

<template>
  <div class="font-sarabun">

    <!-- Loading -->
    <div v-if="loading" class="space-y-3 animate-pulse">
      <div class="h-8 bg-slate-100 rounded-xl w-1/3"></div>
      <div class="h-40 bg-slate-100 rounded-2xl"></div>
    </div>

    <template v-else>

      <!-- No permission banner -->
      <div v-if="!canEdit" class="mb-5 flex items-center gap-3 p-4 bg-amber-50 border border-amber-200 rounded-2xl">
        <SvgIcon name="star" class="w-5 h-5 text-amber-500 flex-shrink-0"/>
        <div>
          <p class="text-sm font-bold text-amber-800">คุณมีสิทธิ์ดูเท่านั้น</p>
          <p class="text-xs text-amber-600 mt-0.5">หน้านี้ยังไม่ได้รับมอบหมายให้คุณ — ติดต่อ admin เพื่อขอสิทธิ์แก้ไข</p>
        </div>
      </div>

      <!-- Header -->
      <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <div class="flex items-center gap-3">
          <button @click="router.push('/dashboard/pages')"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 hover:bg-slate-50 transition-colors">
            <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>
            </svg>
          </button>
          <div>
            <h1 class="text-xl font-extrabold text-slate-800">{{ page.nav_icon }} {{ page.title }}</h1>
            <p class="text-xs text-slate-400 font-mono">/page/{{ page.slug }}</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span :class="['text-xs font-bold px-2.5 py-1 rounded-full',
            page.is_published ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
            {{ page.is_published ? '✅ เผยแพร่' : '⏸ ฉบับร่าง' }}
          </span>
          <!-- Layout selector -->
          <select v-if="canEdit" v-model="layout"
            class="px-2 py-1.5 border border-slate-200 rounded-xl text-xs bg-white text-slate-600 font-bold">
            <option v-for="o in LAYOUT_OPTIONS" :key="o.value" :value="o.value">📐 {{ o.label }}</option>
          </select>
          <button @click="save()" :disabled="saving"
            class="px-4 py-2 bg-slate-100 text-slate-700 font-bold text-sm rounded-xl hover:bg-slate-200 transition-colors disabled:opacity-50">
            {{ saving ? '...' : '💾 บันทึก' }}
          </button>
          <button @click="save(!page.is_published)" :disabled="saving"
            :class="['px-4 py-2 font-bold text-sm rounded-xl transition-colors disabled:opacity-50',
              page.is_published ? 'bg-amber-500 hover:bg-amber-600 text-white' : 'bg-emerald-600 hover:bg-emerald-700 text-white']">
            {{ page.is_published ? '⏸ ยกเลิกเผยแพร่' : '🚀 เผยแพร่' }}
          </button>
        </div>
      </div>

      <!-- Header (ไอคอน SVG+ชื่อ หรือ รูป/วิดีโอ/GIF ตรงหัวหน้าเว็บ) -->
      <div v-if="canEdit" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 mb-5 space-y-3">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Header หน้า</p>
        <div class="flex gap-2">
          <button @click="headerMode = 'icon'"
            :class="['flex-1 py-2 text-sm font-bold rounded-xl border-2 transition-all',
              headerMode === 'icon' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
            ใช้ไอคอน (ค่าเริ่มต้น)
          </button>
          <button @click="headerMode = 'media'"
            :class="['flex-1 py-2 text-sm font-bold rounded-xl border-2 transition-all',
              headerMode === 'media' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
            ใช้รูป/วิดีโอ/GIF
          </button>
        </div>

        <IconPicker v-if="headerMode === 'icon'" v-model="page.nav_icon"/>

        <div v-else class="space-y-3">
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1.5">สัดส่วนกรอบ</label>
            <div class="flex flex-wrap gap-2">
              <button v-for="r in ASPECT_RATIOS" :key="r.value" @click="headerAspectRatio = r.value"
                :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
                  headerAspectRatio === r.value ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
                {{ r.label }}
              </button>
            </div>
          </div>
          <div v-if="headerMediaUrl" class="rounded-xl overflow-hidden border border-slate-200 bg-slate-50 max-w-md" :style="`aspect-ratio:${headerCropRatio}`">
            <video v-if="headerMediaType === 'video'" :src="headerMediaUrl" class="w-full h-full object-cover" controls muted/>
            <img v-else :src="headerMediaUrl" class="w-full h-full object-cover"/>
          </div>
          <div class="flex flex-wrap gap-2">
            <button @click="showHeaderCropper = true" class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
              🖼️ อัปโหลดรูป (ครอปได้)
            </button>
            <button @click="triggerHeaderRawUpload" class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
              🎬 อัปโหลดวิดีโอ/GIF (ไม่ครอป)
            </button>
            <button v-if="headerMediaUrl" @click="clearHeaderMedia" class="px-3 py-2 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">
              ลบไฟล์นี้
            </button>
          </div>
          <div v-if="headerUploading" class="space-y-1">
            <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
              <div class="h-full transition-all" :style="`width:${headerRawProgress}%; background: linear-gradient(90deg, var(--color-primary), var(--color-secondary))`"></div>
            </div>
          </div>
          <p v-if="headerUploadErr" class="text-xs text-red-500 font-bold">{{ headerUploadErr }}</p>
        </div>

        <input ref="headerRawInput" type="file" accept="image/gif,video/mp4,video/webm,video/quicktime" class="hidden" @change="onHeaderRawFileSelected"/>
        <ImageCropperModal :show="showHeaderCropper" :aspect-ratio="headerCropRatio" title="ครอบรูป Header"
          :output-max-width="1920" :output-max-height="1920" output-type="image/jpeg" :output-quality="0.85"
          @close="showHeaderCropper = false" @cropped="onHeaderCropped"/>
      </div>

      <!-- Add block toolbar (แสดงเฉพาะมีสิทธิ์) -->
      <div v-if="canEdit" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-3 mb-5">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2.5">เพิ่ม Block</p>
        <div class="flex flex-wrap gap-2">
          <button v-for="bt in BLOCK_TYPES" :key="bt.type"
            @click="addBlock(bt.type)"
            class="flex items-center gap-1.5 px-3 py-1.5 bg-slate-50 hover:bg-primary-light hover:text-primary border border-slate-200 rounded-xl text-xs font-bold transition-colors">
            <SvgIcon :name="bt.iconName" class="w-3.5 h-3.5"/>
            {{ bt.label }}
          </button>
        </div>
      </div>

      <!-- Blocks list -->
      <div v-if="blocks.length === 0"
        class="text-center py-16 text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
        <p class="text-3xl mb-2">📭</p>
        <p class="text-sm font-bold">ยังไม่มีเนื้อหา — กด "+ เพิ่ม Block" ด้านบน</p>
      </div>

      <div class="space-y-3">
        <div v-for="(block, idx) in blocks" :key="block.id"
          class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">

          <!-- Block toolbar -->
          <div class="flex items-center gap-2 px-4 py-2 bg-slate-50 border-b border-slate-100">
            <span class="flex items-center gap-1.5 text-xs font-bold text-slate-500 uppercase tracking-wider">
              <SvgIcon :name="BLOCK_TYPES.find(b=>b.type===block.type)?.iconName || 'document'" class="w-3.5 h-3.5"/>
              {{ BLOCK_TYPES.find(b=>b.type===block.type)?.label }}
            </span>
            <div class="flex items-center gap-1 ml-auto">
              <button @click="moveUp(idx)" :disabled="idx===0"
                class="w-7 h-7 rounded-lg hover:bg-slate-200 flex items-center justify-center disabled:opacity-30 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
                </svg>
              </button>
              <button @click="moveDown(idx)" :disabled="idx===blocks.length-1"
                class="w-7 h-7 rounded-lg hover:bg-slate-200 flex items-center justify-center disabled:opacity-30 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                </svg>
              </button>
              <button @click="removeBlock(idx)"
                class="w-7 h-7 rounded-lg hover:bg-red-100 text-slate-400 hover:text-red-500 flex items-center justify-center transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Block content editor -->
          <div class="p-4">

            <!-- HEADING -->
            <template v-if="block.type === 'heading'">
              <div class="flex flex-wrap gap-2 mb-2">
                <select v-model="block.level"
                  class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white" title="ระดับหัวข้อ (สำหรับ SEO)">
                  <option value="h2">H2</option>
                  <option value="h3">H3</option>
                  <option value="h4">H4</option>
                </select>
                <select v-model="block.size"
                  class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white" title="ขนาดตัวอักษร">
                  <option value="">ขนาดอัตโนมัติ</option>
                  <option v-for="s in HEADING_SIZES" :key="s.value" :value="s.value">{{ s.label }}</option>
                </select>
                <select v-model="block.align" class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white" title="ตำแหน่ง">
                  <option value="left">ซ้าย</option>
                  <option value="center">กลาง</option>
                  <option value="right">ขวา</option>
                </select>
              </div>
              <input v-model="block.text" type="text" placeholder="ข้อความหัวข้อ..."
                :class="['w-full px-3 py-2 border border-slate-200 rounded-xl focus:outline-none focus:border-primary font-extrabold',
                  headingSizeClass(block),
                  block.align==='center' ? 'text-center' : block.align==='right' ? 'text-right' : 'text-left']"
                :style="block.color ? { color: block.color } : {}"/>
              <div class="flex items-center gap-2 mt-2">
                <span class="text-xs font-bold text-slate-400">สี:</span>
                <button v-for="c in HEADING_COLOR_PRESETS" :key="c" @click="block.color = c" type="button"
                  :class="['w-6 h-6 rounded-full border-2 transition-all hover:scale-110', block.color === c ? 'border-primary scale-110' : 'border-slate-200']"
                  :style="{ backgroundColor: c }"/>
                <label class="relative cursor-pointer">
                  <div class="w-6 h-6 rounded-full border-2 border-dashed border-slate-300 flex items-center justify-center">
                    <svg class="w-3 h-3 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
                  </div>
                  <input type="color" :value="block.color || '#0f172a'" @input="block.color = $event.target.value" class="absolute inset-0 opacity-0 cursor-pointer w-full h-full"/>
                </label>
                <button v-if="block.color" @click="block.color = ''" type="button" class="text-xs font-bold text-slate-400 hover:text-red-500">รีเซ็ต</button>
              </div>
            </template>

            <!-- TEXT -->
            <template v-else-if="block.type === 'text'">
              <textarea v-model="block.text" rows="4" placeholder="พิมพ์เนื้อหาที่นี่..."
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-y leading-relaxed"/>
            </template>

            <!-- IMAGE -->
            <template v-else-if="block.type === 'image'">
              <div class="flex gap-2 mb-2">
                <button @click="openImgCropper(idx)" :disabled="imgUploading && cropTargetIdx===idx"
                  class="flex items-center gap-1.5 px-3 py-1.5 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-50 flex-shrink-0">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                  </svg>
                  {{ imgUploading && cropTargetIdx===idx ? 'กำลังอัปโหลด...' : 'อัปโหลดรูป' }}
                </button>
                <input v-model="block.url" type="url" placeholder="หรือวาง URL รูปภาพ..."
                  class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
              </div>
              <p v-if="imgUploadErr && cropTargetIdx===idx" class="text-xs text-red-500 mb-2">{{ imgUploadErr }}</p>
              <div class="flex gap-2 mb-2">
                <input v-model="block.caption" type="text" placeholder="คำบรรยายใต้ภาพ (optional)"
                  class="flex-1 px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <select v-model="block.align"
                  class="px-2 py-1 border border-slate-200 rounded-xl text-xs bg-white">
                  <option value="left">ซ้าย</option>
                  <option value="center">กลาง</option>
                  <option value="right">ขวา</option>
                </select>
              </div>
              <img v-if="block.url" :src="block.url" :class="['max-h-48 rounded-xl border border-slate-200',
                block.align==='center' ? 'mx-auto' : block.align==='right' ? 'ml-auto' : '']"/>
            </template>

            <!-- EMBED -->
            <template v-else-if="block.type === 'embed'">
              <input v-model="block.url" @input="block.embed_type = detectEmbedType(block.url)"
                type="url" placeholder="วาง URL (YouTube, Google Slides, Canva, Drive...)"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono mb-2"/>
              <div class="flex gap-2 items-center">
                <span class="text-xs font-bold text-slate-500">ตรวจพบ:</span>
                <span class="text-xs font-bold px-2 py-0.5 bg-blue-100 text-blue-700 rounded-full">
                  {{ EMBED_LABELS[block.embed_type] || block.embed_type }}
                </span>
                <select v-model="block.aspect" class="ml-auto px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white">
                  <option value="16/9">16:9</option>
                  <option value="4/3">4:3</option>
                  <option value="1/1">1:1</option>
                </select>
              </div>
            </template>

            <!-- HTML -->
            <template v-else-if="block.type === 'html'">
              <textarea v-model="block.code" rows="6" placeholder="<div>HTML Code...</div>"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:border-primary resize-y bg-slate-50"/>
            </template>

            <!-- DIVIDER -->
            <template v-else-if="block.type === 'divider'">
              <div class="flex items-center gap-3 py-2">
                <div class="flex-1 h-px bg-slate-200"></div>
                <span class="text-xs text-slate-400">เส้นแบ่งส่วน</span>
                <div class="flex-1 h-px bg-slate-200"></div>
              </div>
            </template>

            <!-- GALLERY -->
            <template v-else-if="block.type === 'gallery'">
              <ImageLinkGalleryEditor :gallery="block"/>
            </template>

            <!-- MEDIA-TEXT -->
            <template v-else-if="block.type === 'media-text'">
              <div class="flex gap-2 mb-2">
                <button @click="openImgCropper(idx)" :disabled="imgUploading && cropTargetIdx===idx"
                  class="flex items-center gap-1.5 px-3 py-1.5 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-50 flex-shrink-0">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                  </svg>
                  {{ imgUploading && cropTargetIdx===idx ? 'กำลังอัปโหลด...' : 'อัปโหลดรูป' }}
                </button>
                <select v-model="block.side" class="px-2 py-1.5 border border-slate-200 rounded-xl text-xs bg-white">
                  <option value="left">ภาพซ้าย</option>
                  <option value="right">ภาพขวา</option>
                </select>
              </div>
              <p v-if="imgUploadErr && cropTargetIdx===idx" class="text-xs text-red-500 mb-2">{{ imgUploadErr }}</p>
              <img v-if="block.url" :src="block.url" class="max-h-32 rounded-xl border border-slate-200 mb-2"/>
              <input v-model="block.heading" type="text" placeholder="หัวข้อ"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm font-bold focus:outline-none focus:border-primary mb-2"/>
              <textarea v-model="block.text" rows="3" placeholder="เนื้อหา..."
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-y leading-relaxed"/>
            </template>

            <!-- BUTTON -->
            <template v-else-if="block.type === 'button'">
              <input v-model="block.text" type="text" placeholder="ข้อความปุ่ม เช่น สมัครเลย"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm font-bold focus:outline-none focus:border-primary mb-2"/>
              <div class="flex gap-2 mb-2">
                <select v-model="block.link_type" class="px-2 py-2 border border-slate-200 rounded-xl text-xs bg-white">
                  <option value="internal">ลิงก์ภายใน</option>
                  <option value="external">ลิงก์ภายนอก</option>
                </select>
                <input v-model="block.link_url" type="text"
                  :placeholder="block.link_type === 'internal' ? '/page/xxx' : 'https://...'"
                  class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
              </div>
              <select v-model="block.align" class="px-2 py-1 border border-slate-200 rounded-xl text-xs bg-white">
                <option value="left">ชิดซ้าย</option>
                <option value="center">กึ่งกลาง</option>
                <option value="right">ชิดขวา</option>
              </select>
            </template>

            <!-- ACCORDION -->
            <template v-else-if="block.type === 'accordion'">
              <div v-for="(item, ai) in block.items" :key="item.id" class="flex gap-2 p-3 bg-slate-50 rounded-xl border border-slate-100 mb-2">
                <div class="flex flex-col gap-0.5 flex-shrink-0">
                  <button @click="() => { if (ai>0) [block.items[ai-1], block.items[ai]] = [block.items[ai], block.items[ai-1]] }" :disabled="ai===0" type="button"
                    class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
                  </button>
                  <button @click="() => { if (ai<block.items.length-1) [block.items[ai+1], block.items[ai]] = [block.items[ai], block.items[ai+1]] }" :disabled="ai===block.items.length-1" type="button"
                    class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
                  </button>
                </div>
                <div class="flex-1 min-w-0 space-y-1.5">
                  <input v-model="item.question" type="text" placeholder="คำถาม"
                    class="w-full px-2.5 py-1.5 text-sm font-bold border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
                  <textarea v-model="item.answer" rows="2" placeholder="คำตอบ"
                    class="w-full px-2.5 py-1.5 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary resize-y"/>
                </div>
                <button @click="block.items.splice(ai,1)" type="button" class="flex-shrink-0 text-slate-300 hover:text-red-500 self-start">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                </button>
              </div>
              <button @click="block.items.push(newAccordionItem())" type="button"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
                เพิ่มคำถาม
              </button>
            </template>

            <!-- พื้นหลังบล็อก — ใช้ได้กับทุก block type -->
            <details class="mt-3 pt-3 border-t border-slate-100 group">
              <summary class="flex items-center gap-1.5 text-xs font-bold text-slate-500 cursor-pointer select-none">
                <svg class="w-3.5 h-3.5 transition-transform group-open:rotate-90" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
                🎨 พื้นหลังบล็อก
                <span v-if="block.bg_type" class="w-3 h-3 rounded-full border border-slate-300 ml-1" :style="getBgStyle(block)"></span>
              </summary>
              <div class="mt-2 space-y-2 pl-1">
                <div class="flex flex-wrap gap-1.5">
                  <button @click="block.bg_type = ''" type="button"
                    :class="['px-2.5 py-1 rounded-lg text-[11px] font-bold border-2 transition-all',
                      !block.bg_type ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500 hover:border-primary/50']">
                    ไม่มี
                  </button>
                  <button v-for="t in BG_TYPES" :key="t.value" @click="block.bg_type = t.value" type="button"
                    :class="['px-2.5 py-1 rounded-lg text-[11px] font-bold border-2 transition-all',
                      block.bg_type === t.value ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500 hover:border-primary/50']">
                    {{ t.label }}
                  </button>
                </div>

                <!-- Gradient สำเร็จรูป: กดแล้วตั้งทั้งสีและ type ให้ทันที ไม่ต้องเลือก type ก่อน -->
                <div class="flex flex-wrap gap-1">
                  <button v-for="gp in GRADIENT_PRESETS" :key="gp.label"
                    @click="block.bg = gp.bg; block.bg2 = gp.bg2; block.bg_type = gp.bg_type"
                    :title="gp.label" class="w-6 h-6 rounded-md border border-white shadow-sm hover:scale-110 transition-transform flex-shrink-0"
                    :style="`background: linear-gradient(to right, ${gp.bg}, ${gp.bg2})`"/>
                </div>
                <div v-if="block.bg_type" class="flex items-center gap-1.5 flex-wrap">
                  <span class="text-[10px] font-bold text-slate-400">สี 1:</span>
                  <button v-for="p in BG_PRESETS" :key="p.value" @click="block.bg = p.value" :title="p.label"
                    :class="['w-5 h-5 rounded-full border-2', block.bg === p.value ? 'border-primary' : 'border-slate-200']"
                    :style="{ backgroundColor: p.value }"/>
                  <input type="color" :value="block.bg || '#ffffff'" @input="block.bg = $event.target.value" class="w-5 h-5 rounded-full cursor-pointer border border-slate-200"/>
                </div>
                <div v-if="block.bg_type && block.bg_type !== 'solid'" class="flex items-center gap-1.5 flex-wrap">
                  <span class="text-[10px] font-bold text-slate-400">สี 2:</span>
                  <button v-for="p in BG_PRESETS" :key="p.value" @click="block.bg2 = p.value" :title="p.label"
                    :class="['w-5 h-5 rounded-full border-2', block.bg2 === p.value ? 'border-primary' : 'border-slate-200']"
                    :style="{ backgroundColor: p.value }"/>
                  <input type="color" :value="block.bg2 || '#f1f5f9'" @input="block.bg2 = $event.target.value" class="w-5 h-5 rounded-full cursor-pointer border border-slate-200"/>
                </div>
              </div>
            </details>

          </div>
        </div>
      </div>

      <!-- Bottom save (เฉพาะมีสิทธิ์) -->
      <div v-if="canEdit && blocks.length > 0" class="mt-6 flex justify-end gap-3">
        <button @click="save()" :disabled="saving"
          class="flex items-center gap-2 px-6 py-2.5 bg-primary text-white font-bold text-sm rounded-2xl hover:bg-primary-dark transition-colors disabled:opacity-50">
          <SvgIcon name="document" class="w-4 h-4"/>
          {{ saving ? 'กำลังบันทึก...' : 'บันทึกทั้งหมด' }}
        </button>
      </div>
    </template>

    <!-- Image Cropper -->
    <Teleport to="body">
      <ImageCropperModal
        :show="showCropper"
        :aspect-ratio="NaN"
        title="อัปโหลดรูปภาพ"
        :output-max-width="1600"
        :output-max-height="1200"
        @close="showCropper = false"
        @cropped="onImageCropped"
      />
    </Teleport>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
