<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useAreaConfig, DEFAULT_HOME_SECTIONS } from '../../composables/useAreaConfig'
import { BG_TYPES, BG_PRESETS, GRADIENT_PRESETS, getBgStyle, isDarkColor as isDark,
         BG_POSITIONS, OVERLAY_COLORS, IMAGE_PRESETS, IMAGE_DEFAULTS } from '../../composables/useBgStyle'
import ImageLinkGalleryEditor from '../../components/ImageLinkGalleryEditor.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { useUploadGc } from '../../composables/useUploadGc'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()

const sections       = ref([])
const saving         = ref(false)
const editingSection = ref(null) // section object ที่กำลังจัดการรูปภาพอยู่ (เฉพาะ key ขึ้นต้นด้วย image_gallery)

// ── พื้นหลังรูปภาพ ────────────────────────────────────────────────
const { uploadImage } = useExternalUpload()
const gc = useUploadGc()
const cropTarget = ref(null)   // section ที่กำลังเลือกรูปให้
const cropSrc    = ref('')
const uploadingBg = ref(false)
const saved      = ref(false)  // บันทึกไปแล้วในเซสชันนี้ (ใช้ตัดสินว่าจะเก็บกวาดตอนออกไหม)

function pickBgImage(sec, ev) {
  const file = ev.target.files?.[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = e => { cropSrc.value = e.target.result; cropTarget.value = sec }
  reader.readAsDataURL(file)
  ev.target.value = ''   // เลือกไฟล์เดิมซ้ำได้
}

async function onBgCropped({ blob }) {
  const sec = cropTarget.value
  cropSrc.value = ''; cropTarget.value = null
  if (!sec) return
  uploadingBg.value = true
  try {
    const url = await uploadImage(blob, 'section-bg')
    gc.trackReplaced(sec.bg_image)   // รูปเดิมเข้าคิวรอลบตอนบันทึกสำเร็จ
    gc.trackUploaded(url)
    sec.bg_image = url
    // ตั้งค่าเริ่มต้นให้อ่านออกทันทีถ้ายังไม่เคยตั้ง
    Object.entries(IMAGE_DEFAULTS).forEach(([k, v]) => { if (sec[k] === undefined) sec[k] = v })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: e.message })
  } finally {
    uploadingBg.value = false
  }
}

function removeBgImage(sec) {
  gc.trackReplaced(sec.bg_image)
  sec.bg_image = ''
}

function applyImagePreset(sec, p) {
  sec.bg_overlay = p.bg_overlay
  sec.bg_overlay_color = p.bg_overlay_color
  sec.bg_blur = p.bg_blur
  sec.bg_text = p.bg_text
}

// preset ที่ค่าปัจจุบันตรงเป๊ะ (ไว้ไฮไลต์ปุ่ม)
function activePreset(sec) {
  return IMAGE_PRESETS.find(p =>
    p.bg_overlay === sec.bg_overlay && p.bg_overlay_color === sec.bg_overlay_color &&
    p.bg_blur === sec.bg_blur && p.bg_text === sec.bg_text
  )?.key || ''
}

// style ตัวอย่างในการ์ด admin (ย่อส่วน — ไม่ใส่ blur จริงเพราะกรอบเล็กมาก)
function bgPreviewStyle(sec) {
  if (sec.bg_type !== 'image' || !sec.bg_image) return getBgStyle(sec)
  const c = OVERLAY_COLORS.find(c => c.value === (sec.bg_overlay_color || 'white'))
  const a = (sec.bg_overlay ?? IMAGE_DEFAULTS.bg_overlay) / 100
  const veil = c?.rgb ? `rgba(${c.rgb},${a})` : `color-mix(in srgb, var(--color-primary) ${(a*100)|0}%, transparent)`
  return {
    backgroundImage: `linear-gradient(${veil},${veil}), url("${sec.bg_image}")`,
    backgroundSize: 'cover',
    backgroundPosition: sec.bg_position || IMAGE_DEFAULTS.bg_position,
  }
}

// ออกจากหน้าโดยไม่บันทึก → ลบรูปที่เพิ่งอัปทิ้ง ไม่ให้ค้างกินพื้นที่
onUnmounted(() => { if (!saved.value) gc.discard() })

// ── Section icons ─────────────────────────────────────────────────
const SECTION_ICONS = {
  news:            'M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5',
  education_news:  'M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418',
  supervision_list:'M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z',
  services:        'M13.5 16.875h3.375m0 0h3.375m-3.375 0V13.5m0 3.375v3.375M6 10.5h2.25a2.25 2.25 0 002.25-2.25V6a2.25 2.25 0 00-2.25-2.25H6A2.25 2.25 0 003.75 6v2.25A2.25 2.25 0 006 10.5zm0 9.75h2.25A2.25 2.25 0 0010.5 18v-2.25a2.25 2.25 0 00-2.25-2.25H6a2.25 2.25 0 00-2.25 2.25V18A2.25 2.25 0 006 20.25zm9.75-9.75H18a2.25 2.25 0 002.25-2.25V6A2.25 2.25 0 0018 3.75h-2.25A2.25 2.25 0 0013.5 6v2.25a2.25 2.25 0 002.25 2.25z',
  image_gallery:   'M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 12V4.5A2.25 2.25 0 015.25 2.25h13.5A2.25 2.25 0 0121 4.5V12M3 12v7.5A2.25 2.25 0 005.25 21.75h13.5A2.25 2.25 0 0021 19.5V12M3 12l4.5-4.5',
  cta:             'M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18',
}

const SECTION_DESC = {
  news:            'การ์ดข่าวสาร 8 รายการล่าสุด',
  education_news:  'ข่าวการศึกษา 8 รายการล่าสุดจาก Google News RSS + ลิงก์ไปหน้า /education-news',
  supervision_list:'รายการแบบนิเทศ/สอบถามที่เปิดรับ + ดูสถานะโรงเรียน',
  services:        'สถิติเขต + เมนูบริการออนไลน์',
  image_gallery:   'ภาพลิงก์ — กำหนดรูปภาพ/ลิงก์ที่จะแสดงในหน้าแรกได้เอง',
  cta:             'แบนเนอร์เชิญชวน + ลิงก์หลัก',
}

// keys ของเซกชันภาพลิงก์ไม่คงที่ (image_gallery_<timestamp>) — ต้องเช็คด้วย prefix แทน exact match
function isGallerySection(sec) { return sec.key.startsWith('image_gallery') }
function sectionIcon(sec) { return isGallerySection(sec) ? SECTION_ICONS.image_gallery : (SECTION_ICONS[sec.key] || SECTION_ICONS.news) }
function sectionDesc(sec) { return isGallerySection(sec) ? SECTION_DESC.image_gallery : (SECTION_DESC[sec.key] || '') }

function addGallerySection() {
  const key = `image_gallery_${Date.now()}`
  sections.value.push({
    key, label: 'ภาพลิงก์', subtitle: 'Gallery', title: 'ภาพลิงก์', visible: true,
    bg: '#ffffff', bg2: '#f1f5f9', bg_type: 'none', order: sections.value.length + 1,
    gallery: { layout: 'card', title: '', items: [] },
  })
}

async function removeSection(i) {
  const res = await Swal.fire({
    title: 'ลบเซกชันนี้?', icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  gc.trackReplaced(sections.value[i]?.bg_image)   // รูปพื้นหลังของเซกชันที่ถูกลบ เข้าคิวรอลบด้วย
  sections.value.splice(i, 1)
}

onMounted(async () => {
  await fetchConfig()
  const raw = config.value?.home_sections
  if (!Array.isArray(raw) || raw.length === 0) {
    sections.value = DEFAULT_HOME_SECTIONS.map(s => ({ ...s }))
    return
  }
  // merge: เพิ่ม section ใหม่จาก DEFAULT ที่ยังไม่มีใน stored config
  const storedKeys = new Set(raw.map(s => s.key))
  const maxOrder   = Math.max(...raw.map(s => s.order || 0))
  const merged = [
    ...raw.map(s => {
      // JSON round-trip ตัดขาดจาก readonly(config) ของ useAreaConfig ทั้ง object รวมถึง field ซ้อนอย่าง gallery —
      // ถ้าใช้ { ...s } เฉยๆ (shallow) field ซ้อนจะยังอ้างอิง object เดิมที่เป็น readonly proxy อยู่ ทำให้แก้ไข/เพิ่มรูปในเซกชันภาพลิงก์ที่โหลดมาจาก DB ไม่ได้เลย (เงียบๆ ไม่มี error)
      // (ใช้ structuredClone ไม่ได้ — โยน error กับ Vue reactive Proxy โดยตรง)
      const plain = JSON.parse(JSON.stringify(s))
      const def = DEFAULT_HOME_SECTIONS.find(d => d.key === plain.key)
      const withSubtitle = { subtitle: def?.subtitle ?? '', ...plain }  // backfill subtitle
      // เซกชันภาพลิงก์เก่าที่อาจยังไม่มี field gallery (ข้อมูลก่อนอัปเดต) — เติมค่าว่างให้
      if (isGallerySection(withSubtitle) && !withSubtitle.gallery) {
        withSubtitle.gallery = { layout: 'card', title: '', items: [] }
      }
      return withSubtitle
    }),
    ...DEFAULT_HOME_SECTIONS
      .filter(s => !storedKeys.has(s.key))
      .map((s, i) => ({ ...s, order: maxOrder + i + 1 })),
  ]
  sections.value = merged.sort((a, b) => a.order - b.order)
})

// ── Reorder ───────────────────────────────────────────────────────
function moveUp(i) {
  if (i === 0) return
  const arr = [...sections.value]
  ;[arr[i - 1], arr[i]] = [arr[i], arr[i - 1]]
  arr.forEach((s, idx) => s.order = idx + 1)
  sections.value = arr
}
function moveDown(i) {
  if (i === sections.value.length - 1) return
  const arr = [...sections.value]
  ;[arr[i], arr[i + 1]] = [arr[i + 1], arr[i]]
  arr.forEach((s, idx) => s.order = idx + 1)
  sections.value = arr
}

// ── Save ──────────────────────────────────────────────────────────
async function save() {
  saving.value = true
  const payload = sections.value.map((s, i) => ({ ...s, order: i + 1 }))
  const { error } = await updateConfig({ home_sections: payload })
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    saved.value = true
    // ลบรูปเก่าบน server หลังบันทึกสำเร็จเท่านั้น — ส่งรายการรูปที่ยังใช้อยู่ไปด้วย
    // กันเคสรูปเดียวถูกใช้หลายเซกชันแล้วลบอันหนึ่งไปทำให้อีกอันรูปหาย
    const stillUsed = payload.map(s => s.bg_image).filter(Boolean)
    const removed = await gc.commit(stillUsed)
    Swal.fire({
      icon: 'success', title: 'บันทึกสำเร็จ',
      text: removed ? `ลบรูปพื้นหลังเดิมบนเซิร์ฟเวอร์ ${removed} ไฟล์` : '',
      showConfirmButton: false, timer: removed ? 1600 : 1000,
    })
  }
  saving.value = false
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/>
          </svg>
          จัดการ Section หน้าแรก
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">เปิด/ปิด เรียงลำดับ และเปลี่ยนสีพื้นหลังแต่ละ section</p>
      </div>
      <div class="flex flex-wrap gap-2">
      <button @click="addGallerySection" type="button"
        class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-white border-2 border-primary/30 text-primary rounded-2xl hover:bg-primary/5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มเซกชันภาพลิงก์
      </button>
      <button @click="save" :disabled="saving"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5 disabled:opacity-50">
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

    <!-- Info -->
    <div class="flex gap-2 p-3.5 bg-blue-50 rounded-2xl border border-blue-100 text-sm text-blue-700">
      <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
      </svg>
      <span>แบนเนอร์/Hero อยู่บนสุดเสมอ ส่วน section ด้านล่างเรียงตามลำดับที่กำหนดที่นี่</span>
    </div>

    <!-- Sections list -->
    <div class="space-y-3">
      <div v-for="(sec, i) in sections" :key="sec.key"
        :class="['bg-white rounded-2xl border-2 shadow-sm transition-all',
          sec.visible ? 'border-slate-100' : 'border-dashed border-slate-200 opacity-60']">

        <div class="p-4 flex flex-wrap items-start gap-4">

          <!-- Order number + arrows -->
          <div class="flex flex-col items-center gap-1 flex-shrink-0">
            <button @click="moveUp(i)" :disabled="i === 0"
              class="w-7 h-7 flex items-center justify-center rounded-lg border border-slate-200 hover:bg-slate-100 disabled:opacity-30 transition-colors">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
              </svg>
            </button>
            <span class="text-xs font-extrabold text-slate-400 w-7 text-center">{{ i + 1 }}</span>
            <button @click="moveDown(i)" :disabled="i === sections.length - 1"
              class="w-7 h-7 flex items-center justify-center rounded-lg border border-slate-200 hover:bg-slate-100 disabled:opacity-30 transition-colors">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
              </svg>
            </button>
          </div>

          <!-- Icon + Info -->
          <div class="flex items-center gap-3 flex-1 min-w-0">
            <div class="w-11 h-11 rounded-xl flex-shrink-0 flex items-center justify-center"
              :style="{ backgroundColor: sec.bg || '#f8fafc' }">
              <svg class="w-5 h-5" :class="isDark(sec.bg || '#f8fafc') ? 'text-white' : 'text-primary'"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" :d="sectionIcon(sec)"/>
              </svg>
            </div>
            <div>
              <p class="font-extrabold text-slate-800">{{ sec.label }}</p>
              <p class="text-xs text-slate-400">{{ sectionDesc(sec) }}</p>
            </div>
          </div>

          <!-- จัดการรูปภาพ / ลบ (เฉพาะเซกชันภาพลิงก์) -->
          <div v-if="isGallerySection(sec)" class="flex-shrink-0 flex items-center gap-2">
            <button @click="editingSection = sec" type="button"
              class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-primary/30 text-primary hover:bg-primary/5 transition-all">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 12V4.5A2.25 2.25 0 015.25 2.25h13.5A2.25 2.25 0 0121 4.5V12M3 12v7.5A2.25 2.25 0 005.25 21.75h13.5A2.25 2.25 0 0021 19.5V12M3 12l4.5-4.5"/>
              </svg>
              จัดการรูปภาพ ({{ sec.gallery?.items?.length || 0 }})
            </button>
            <button @click="removeSection(i)" type="button"
              class="p-1.5 rounded-xl text-slate-300 hover:text-red-500 hover:bg-red-50 transition-all" title="ลบเซกชันนี้">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/></svg>
            </button>
          </div>

          <!-- Visible toggle -->
          <div class="flex-shrink-0">
            <button @click="sec.visible = !sec.visible"
              :class="['flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-all',
                sec.visible
                  ? 'border-emerald-400 bg-emerald-50 text-emerald-700'
                  : 'border-slate-200 bg-slate-50 text-slate-400']">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round"
                  :d="sec.visible
                    ? 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'
                    : 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'"/>
              </svg>
              {{ sec.visible ? 'แสดง' : 'ซ่อน' }}
            </button>
          </div>
        </div>

        <!-- Section subtitle + title input -->
        <div class="px-4 pb-2 space-y-2">
          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">ข้อความเล็กด้านบน (ภาษาอังกฤษ)</p>
            <input v-model="sec.subtitle" type="text"
              :placeholder="sec.key === 'news' ? 'Latest News' : sec.key === 'services' ? 'E-Service Center' : ''"
              class="w-full px-3 py-2 text-sm border border-slate-200 rounded-xl focus:outline-none focus:border-primary transition-colors bg-slate-50 focus:bg-white"/>
          </div>
          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">ชื่อหลัก (ภาษาไทย)</p>
            <input v-model="sec.title" type="text"
              :placeholder="sec.key === 'news' ? 'เช่น ข่าวสารและประชาสัมพันธ์' : sec.key === 'services' ? 'เช่น บริการออนไลน์' : 'เช่น ระบบกลุ่มนิเทศ ติดตามและประเมินผล'"
              class="w-full px-3 py-2 text-sm border border-slate-200 rounded-xl focus:outline-none focus:border-primary transition-colors bg-slate-50 focus:bg-white"/>
          </div>
        </div>

        <!-- Gradient quick presets -->
        <div class="px-4 pb-3">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Gradient สำเร็จรูป</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="gp in GRADIENT_PRESETS" :key="gp.label"
              @click="sec.bg = gp.bg; sec.bg2 = gp.bg2; sec.bg_type = gp.bg_type"
              :title="gp.label"
              class="w-8 h-8 rounded-lg border-2 border-white shadow-sm hover:scale-110 transition-transform flex-shrink-0 overflow-hidden"
              :style="`background: linear-gradient(to right, ${gp.bg}, ${gp.bg2})`"/>
          </div>
        </div>

        <!-- BG Color picker — ซ่อนเมื่อเลือก "โปร่งใส" เพราะไม่มีสีให้เลือก -->
        <div v-if="sec.bg_type !== 'none' && sec.bg_type !== 'image'" class="px-4 pb-3">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">สีพื้นหลัง (สี 1)</p>
          <div class="flex flex-wrap items-center gap-2">
            <button v-for="preset in BG_PRESETS" :key="preset.value"
              @click="sec.bg = preset.value" :title="preset.label"
              :class="['w-8 h-8 rounded-full border-2 transition-all hover:scale-110 shadow-sm',
                sec.bg === preset.value ? 'border-primary scale-110 shadow-md' : 'border-slate-200']"
              :style="{ backgroundColor: preset.value }">
              <svg v-if="sec.bg === preset.value" class="w-4 h-4 mx-auto"
                :class="isDark(preset.value) ? 'text-white' : 'text-primary'"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
              </svg>
            </button>
            <div class="w-px h-6 bg-slate-200"></div>
            <label class="relative cursor-pointer group" title="เลือกสีกำหนดเอง">
              <div class="w-8 h-8 rounded-full border-2 border-dashed border-slate-300 group-hover:border-primary transition-colors flex items-center justify-center overflow-hidden"
                :style="{ backgroundColor: BG_PRESETS.some(p => p.value === sec.bg) ? 'transparent' : sec.bg }">
                <svg v-if="BG_PRESETS.some(p => p.value === sec.bg)"
                  class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
                </svg>
              </div>
              <input type="color" :value="sec.bg" @input="sec.bg = $event.target.value"
                class="absolute inset-0 opacity-0 cursor-pointer w-full h-full"/>
            </label>
            <div class="flex items-center gap-1.5 ml-1">
              <div class="w-5 h-5 rounded border border-slate-200 shadow-sm" :style="{ backgroundColor: sec.bg }"></div>
              <span class="text-xs font-mono text-slate-500">{{ sec.bg }}</span>
            </div>
          </div>
        </div>

        <!-- Gradient type selector -->
        <div class="px-4 pb-3">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">พื้นหลัง</p>
          <div class="flex flex-wrap gap-2">
            <button v-for="t in BG_TYPES" :key="t.value"
              @click="sec.bg_type = t.value"
              :class="['px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-all',
                (sec.bg_type || 'solid') === t.value
                  ? 'border-primary bg-primary text-white'
                  : 'border-slate-200 text-slate-600 hover:border-primary/50']">
              {{ t.label }}
            </button>
          </div>
        </div>

        <!-- ══ พื้นหลังรูปภาพ ══ -->
        <div v-if="sec.bg_type === 'image'" class="px-4 pb-4 space-y-3">

          <!-- อัปโหลด / ตัวอย่าง -->
          <div class="flex items-center gap-3">
            <div class="w-28 h-16 rounded-xl overflow-hidden flex-shrink-0 border border-slate-200 bg-slate-100"
              :style="sec.bg_image ? bgPreviewStyle(sec) : {}">
              <div v-if="!sec.bg_image" class="w-full h-full flex items-center justify-center text-slate-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 12V4.5A2.25 2.25 0 015.25 2.25h13.5A2.25 2.25 0 0121 4.5V12M3 12v7.5A2.25 2.25 0 005.25 21.75h13.5A2.25 2.25 0 0021 19.5V12"/>
                </svg>
              </div>
            </div>
            <div class="flex-1 min-w-0 space-y-1.5">
              <label class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-primary hover:text-white transition-all cursor-pointer">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 16.5V9.75m0 0l3 3m-3-3l-3 3M6.75 19.5a4.5 4.5 0 01-1.41-8.775 5.25 5.25 0 0110.233-2.33 3 3 0 013.758 3.848A3.752 3.752 0 0118 19.5H6.75z"/>
                </svg>
                {{ sec.bg_image ? 'เปลี่ยนรูป' : 'เลือกรูป' }}
                <input type="file" accept="image/*" class="hidden" @change="e => pickBgImage(sec, e)"/>
              </label>
              <button v-if="sec.bg_image" @click="removeBgImage(sec)"
                class="ml-2 text-xs font-bold text-slate-400 hover:text-red-500 transition-colors">ลบรูป</button>
              <p v-if="uploadingBg" class="text-[11px] text-primary font-bold">กำลังอัปโหลด…</p>
              <p v-else-if="!externalUploadEnabled" class="text-[11px] text-amber-600">
                ยังไม่ได้ตั้งค่า VITE_UPLOAD_API_URL — จะอัปโหลดไม่ได้
              </p>
              <p v-else class="text-[11px] text-slate-400">รูปถูกย่อเป็น 1920px JPEG ก่อนอัปขึ้นเซิร์ฟเวอร์</p>
            </div>
          </div>

          <template v-if="sec.bg_image">
            <!-- Preset สำเร็จรูป -->
            <div>
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">รูปแบบสำเร็จรูป</p>
              <div class="flex flex-wrap gap-1.5">
                <button v-for="p in IMAGE_PRESETS" :key="p.key"
                  @click="applyImagePreset(sec, p)" :title="p.desc"
                  :class="['px-2.5 py-1.5 rounded-lg text-[11px] font-bold border-2 transition-all',
                    activePreset(sec) === p.key ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                  {{ p.label }}
                </button>
              </div>
            </div>

            <!-- ปรับเอง -->
            <details class="group">
              <summary class="flex items-center gap-1.5 text-[11px] font-bold text-slate-500 cursor-pointer select-none">
                <svg class="w-3 h-3 transition-transform group-open:rotate-90" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
                ปรับเอง
              </summary>
              <div class="mt-2 space-y-3 pl-1">

                <!-- ม่าน -->
                <div>
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-[11px] font-bold text-slate-500">ความทึบของม่าน</span>
                    <span class="text-[11px] font-mono text-slate-400">{{ sec.bg_overlay ?? 60 }}%</span>
                  </div>
                  <input type="range" min="0" max="90" step="5"
                    :value="sec.bg_overlay ?? 60" @input="sec.bg_overlay = +$event.target.value"
                    class="w-full accent-[var(--color-primary)]"/>
                  <div class="flex gap-1.5 mt-1.5">
                    <button v-for="c in OVERLAY_COLORS" :key="c.value"
                      @click="sec.bg_overlay_color = c.value"
                      :class="['px-2 py-1 rounded-lg text-[11px] font-bold border-2 transition-all',
                        (sec.bg_overlay_color || 'white') === c.value ? 'border-primary text-primary' : 'border-slate-200 text-slate-500']">
                      {{ c.label }}
                    </button>
                  </div>
                </div>

                <!-- เบลอ -->
                <div>
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-[11px] font-bold text-slate-500">เบลอภาพ</span>
                    <span class="text-[11px] font-mono text-slate-400">{{ sec.bg_blur ?? 8 }}px</span>
                  </div>
                  <input type="range" min="0" max="24" step="2"
                    :value="sec.bg_blur ?? 8" @input="sec.bg_blur = +$event.target.value"
                    class="w-full accent-[var(--color-primary)]"/>
                </div>

                <!-- ตำแหน่งภาพ -->
                <div>
                  <p class="text-[11px] font-bold text-slate-500 mb-1.5">ตำแหน่งภาพ</p>
                  <div class="grid grid-cols-3 gap-1 w-[104px]">
                    <button v-for="pos in BG_POSITIONS" :key="pos.value"
                      @click="sec.bg_position = pos.value" :title="pos.value"
                      :class="['w-8 h-8 rounded-lg text-sm border-2 transition-all',
                        (sec.bg_position || 'center center') === pos.value ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-400 hover:border-primary/50']">
                      {{ pos.label }}
                    </button>
                  </div>
                </div>

                <!-- โทนตัวอักษร -->
                <div>
                  <p class="text-[11px] font-bold text-slate-500 mb-1.5">
                    โทนตัวอักษรบนภาพ
                    <span class="font-normal text-slate-400">(เฉพาะหัวข้อ/ข้อความนอกการ์ด)</span>
                  </p>
                  <div class="flex gap-1.5">
                    <button v-for="t in [{v:'dark',l:'เข้ม'},{v:'light',l:'สว่าง'}]" :key="t.v"
                      @click="sec.bg_text = t.v"
                      :class="['px-3 py-1 rounded-lg text-[11px] font-bold border-2 transition-all',
                        (sec.bg_text || 'dark') === t.v ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500']">
                      {{ t.l }}
                    </button>
                  </div>
                </div>
              </div>
            </details>
          </template>
        </div>

        <!-- สี 2 (ปลายทาง) — แสดงเมื่อเลือก gradient -->
        <div v-if="sec.bg_type && !['solid','none','image'].includes(sec.bg_type)" class="px-4 pb-4">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">สีปลายทาง (สี 2)</p>
          <div class="flex flex-wrap items-center gap-2">
            <button v-for="preset in BG_PRESETS" :key="preset.value"
              @click="sec.bg2 = preset.value" :title="preset.label"
              :class="['w-8 h-8 rounded-full border-2 transition-all hover:scale-110 shadow-sm',
                sec.bg2 === preset.value ? 'border-primary scale-110 shadow-md' : 'border-slate-200']"
              :style="{ backgroundColor: preset.value }">
              <svg v-if="sec.bg2 === preset.value" class="w-4 h-4 mx-auto"
                :class="isDark(preset.value) ? 'text-white' : 'text-primary'"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
              </svg>
            </button>
            <div class="w-px h-6 bg-slate-200"></div>
            <label class="relative cursor-pointer group" title="เลือกสีกำหนดเอง">
              <div class="w-8 h-8 rounded-full border-2 border-dashed border-slate-300 group-hover:border-primary transition-colors flex items-center justify-center overflow-hidden"
                :style="{ backgroundColor: BG_PRESETS.some(p => p.value === sec.bg2) ? 'transparent' : (sec.bg2 || '#f1f5f9') }">
                <svg v-if="!sec.bg2 || BG_PRESETS.some(p => p.value === sec.bg2)"
                  class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
                </svg>
              </div>
              <input type="color" :value="sec.bg2 || '#f1f5f9'" @input="sec.bg2 = $event.target.value"
                class="absolute inset-0 opacity-0 cursor-pointer w-full h-full"/>
            </label>
            <!-- Live preview gradient strip -->
            <div class="flex-1 min-w-[80px] h-5 rounded-lg border border-slate-200 shadow-sm"
              :style="getBgStyle(sec)"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Preview hint -->
    <div class="bg-slate-50 rounded-2xl border border-slate-200 p-4">
      <p class="text-xs font-bold text-slate-500 mb-3">ตัวอย่างลำดับ Section</p>
      <div class="flex flex-col gap-1.5">
        <!-- Banner fixed -->
        <div class="flex items-center gap-2 px-3 py-2 bg-slate-800 text-white text-xs font-bold rounded-xl">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
          </svg>
          แบนเนอร์ (คงที่)
        </div>
        <!-- Dynamic sections -->
        <template v-for="(sec, i) in sections" :key="sec.key">
          <div :class="['flex items-center gap-2 px-3 py-2 text-xs font-bold rounded-xl border transition-all',
            sec.visible ? 'border-transparent' : 'opacity-40 border-dashed border-slate-300']"
            :style="getBgStyle(sec)">
            <span class="text-slate-400 font-bold w-4">{{ i + 1 }}</span>
            <svg class="w-3.5 h-3.5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="sectionIcon(sec)"/>
            </svg>
            <span class="text-slate-700">{{ sec.label }}</span>
            <span v-if="!sec.visible" class="ml-auto text-slate-400 text-[10px]">ซ่อน</span>
          </div>
        </template>
      </div>
    </div>

    <!-- ══ MODAL: จัดการรูปภาพ (เซกชันภาพลิงก์ที่กำลังแก้ไข) ══════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="editingSection" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="glass-panel rounded-3xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">จัดการรูปภาพ — ภาพลิงก์หน้าแรก</h2>
              <button @click="editingSection = null" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>
            <div class="flex-1 overflow-y-auto px-6 py-5">
              <ImageLinkGalleryEditor :gallery="editingSection.gallery"/>
            </div>
            <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="editingSection = null" type="button" class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
                ปิด
              </button>
              <button @click="save" :disabled="saving" type="button" class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
                {{ saving ? 'กำลังบันทึก...' : 'บันทึกทั้งหมด' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ครอปรูปพื้นหลังเซกชัน — อิสระไม่บังคับสัดส่วน เพราะแต่ละเซกชันสูงไม่เท่ากัน
         ย่อเป็น 1920px JPEG q0.82 (~200-400KB) ให้โหลดเร็วและไม่ชนลิมิต 5MB ของ upload.php -->
    <ImageCropperModal
      v-if="cropSrc"
      :src="cropSrc"
      :aspect-ratio="NaN"
      :output-max-width="1920"
      :output-max-height="1920"
      output-type="image/jpeg"
      :output-quality="0.82"
      @close="cropSrc = ''; cropTarget = null"
      @cropped="onBgCropped"/>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
