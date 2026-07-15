<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'
import IconPicker from '../../components/IconPicker.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import StorageBrowser from '../../components/StorageBrowser.vue'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()

// หน้าสาธารณะที่ปรับ header ได้ — key ต้องตรงกับ route name ใน router/index.js เป๊ะ
const KNOWN_ROUTES = [
  { key: 'vision',         label: 'วิสัยทัศน์และพันธกิจ' },
  { key: 'org',            label: 'โครงสร้างการบริหาร' },
  { key: 'personnel',      label: 'ทำเนียบบุคลากร' },
  { key: 'curriculum',     label: 'พัฒนาหลักสูตรการศึกษา' },
  { key: 'supervisionEdu', label: 'นิเทศการศึกษา' },
  { key: 'evaluation',     label: 'วัดและประเมินผลการศึกษา' },
  { key: 'quality',        label: 'ประกันคุณภาพการศึกษา' },
  { key: 'research',       label: 'วิจัย สื่อ และเทคโนโลยี' },
  { key: 'secretariat',    label: 'ส่งเสริมพัฒนาระบบการบริหารจัดการ' },
  { key: 'schools',        label: 'ทำเนียบสถานศึกษา' },
  { key: 'principals',     label: 'ผู้บริหารสถานศึกษา' },
  { key: 'newsletters',    label: 'จดหมายข่าว' },
  { key: 'media',          label: 'คลังสื่อการเรียนรู้' },
  { key: 'studentStats',   label: 'ข้อมูลนักเรียน' },
  { key: 'news',           label: 'ข่าวสาร' },
  { key: 'educationNews',  label: 'ข่าวการศึกษา' },
  { key: 'nithet',         label: 'กลุ่มนิเทศ ติดตามและประเมินผล' },
  { key: 'school-documents', label: 'หนังสือถึงโรงเรียน' },
  { key: 'contact',        label: 'ติดต่อสอบถาม' },
  { key: 'download',       label: 'ดาวน์โหลดเอกสาร' },
  { key: 'urlShort',       label: 'ย่อลิงค์' },
  { key: 'qrcode',         label: 'สร้าง QR Code' },
]
function routeLabel(key) { return KNOWN_ROUTES.find(r => r.key === key)?.label || key }

// สัดส่วนกรอบรูป/วิดีโอ header (เหมือน pattern ที่ใช้กับแบนเนอร์)
const ASPECT_RATIOS = [
  { value: '21:9', label: '21:9 กว้างเตี้ย', ratio: 21/9 },
  { value: '16:9', label: '16:9 มาตรฐาน',    ratio: 16/9 },
  { value: '3:1',  label: '3:1 เว็บราชการ',   ratio: 3/1 },
  { value: '4:1',  label: '4:1 บางมาก',       ratio: 4/1 },
]
function ratioNumber(value) { return ASPECT_RATIOS.find(r => r.value === value)?.ratio || 21/9 }

const headers   = ref([])
const saving    = ref(false)
const addKey    = ref('')
const availableRoutes = computed(() => KNOWN_ROUTES.filter(r => !headers.value.some(h => h.key === r.key)))

function emptyHeader(key) {
  return { key, mode: 'icon', icon: '', title: '', subtitle: '', media_url: '', media_type: '', aspect_ratio: '21:9', align: '', hidden: false }
}

onMounted(async () => {
  await fetchConfig()
  headers.value = (config.value?.page_headers || []).map(h => ({ ...h }))
})

function addRoute() {
  if (!addKey.value) return
  headers.value.push(emptyHeader(addKey.value))
  addKey.value = ''
}
async function removeRoute(i) {
  const row = headers.value[i]
  if (row.media_url) await deleteUploadedFile(row.media_url)
  headers.value.splice(i, 1)
}

async function save() {
  saving.value = true
  const { error } = await updateConfig({ page_headers: headers.value })
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
  }
  saving.value = false
}

// ── Media upload (ใช้ pattern เดียวกับ AdminBannersView) ────────────
const { uploadImage: uploadCoverExternal, uploadFile: uploadRawExternal } = useExternalUpload()
const showCropper  = ref(false)
const showStorage  = ref(false)
const rawFileInput = ref(null)
const activeIndex  = ref(-1)
const rawUploadProgress = ref(0)
const rawUploadError    = ref('')
const uploadingRaw = ref(false)

const cropperRatio = computed(() => ratioNumber(headers.value[activeIndex.value]?.aspect_ratio))

function openCropper(i) { activeIndex.value = i; showCropper.value = true }
function openStorage(i) { activeIndex.value = i; showStorage.value = true }
function triggerRawUpload(i) { activeIndex.value = i; rawFileInput.value?.click() }

async function onCropped({ blob }) {
  showCropper.value = false
  if (activeIndex.value < 0) return
  const row = headers.value[activeIndex.value]
  try {
    if (externalUploadEnabled) {
      row.media_url = await uploadCoverExternal(blob, 'page-header')
    } else {
      const name = `page-header-${Date.now()}.jpg`
      const { data, error } = await supabase.storage.from('banners').upload(name, blob, { contentType: 'image/jpeg', upsert: false })
      if (error) throw error
      row.media_url = supabase.storage.from('banners').getPublicUrl(data.path).data.publicUrl
    }
    row.media_type = 'image'
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: err.message })
  }
}

function onStorageSelect({ url }) {
  if (activeIndex.value < 0) return
  headers.value[activeIndex.value].media_url  = url
  headers.value[activeIndex.value].media_type = /\.(mp4|webm|mov)$/i.test(url) ? 'video' : (/\.gif$/i.test(url) ? 'gif' : 'image')
  showStorage.value = false
}

async function onRawFileSelected(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file || activeIndex.value < 0) return
  const row = headers.value[activeIndex.value]

  const isVideo = file.type.startsWith('video/')
  const isGif   = file.type === 'image/gif'
  if (!isVideo && !isGif) {
    rawUploadError.value = 'รองรับเฉพาะไฟล์ GIF หรือวิดีโอ (.mp4, .webm, .mov)'
    return
  }
  const MAX_MB = isVideo ? 50 : 5
  if (file.size > MAX_MB * 1024 * 1024) {
    rawUploadError.value = `ไฟล์ใหญ่เกิน ${MAX_MB} MB (ไฟล์นี้ ${(file.size/1024/1024).toFixed(1)} MB)`
    return
  }

  rawUploadError.value = ''
  uploadingRaw.value = true
  rawUploadProgress.value = 0
  try {
    if (externalUploadEnabled) {
      row.media_url = await uploadRawExternal(file, 'page-header', p => { rawUploadProgress.value = p })
    } else {
      const ext = file.name.split('.').pop() || (isVideo ? 'mp4' : 'gif')
      const fileName = `page-header-${Date.now()}.${ext}`
      const { data: { session } } = await supabase.auth.getSession()
      const baseUrl = import.meta.env.VITE_SUPABASE_URL
      await new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest()
        xhr.open('POST', `${baseUrl}/storage/v1/object/banners/${fileName}`)
        xhr.setRequestHeader('Authorization', `Bearer ${session?.access_token}`)
        xhr.setRequestHeader('Content-Type', file.type)
        xhr.upload.addEventListener('progress', ev => { if (ev.lengthComputable) rawUploadProgress.value = Math.round((ev.loaded/ev.total)*100) })
        xhr.addEventListener('load', () => xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new Error(`Upload failed (${xhr.status})`)))
        xhr.addEventListener('error', () => reject(new Error('Network error')))
        xhr.send(file)
      })
      row.media_url = supabase.storage.from('banners').getPublicUrl(fileName).data.publicUrl
    }
    row.media_type = isVideo ? 'video' : 'gif'
  } catch (err) {
    rawUploadError.value = err.message
  } finally {
    uploadingRaw.value = false
  }
}

async function clearMedia(row) {
  if (row.media_url) await deleteUploadedFile(row.media_url)
  row.media_url = ''
  row.media_type = ''
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div>
      <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
        <SvgIcon name="page" class="w-6 h-6 text-primary"/> จัดการหัวข้อหน้า (Header)
      </h1>
      <p class="text-sm text-slate-500 mt-0.5">เลือกไอคอน SVG + ชื่อ (ค่าเริ่มต้น) หรืออัปโหลดรูป/วิดีโอ/GIF แทนสำหรับแต่ละหน้าสาธารณะ</p>
    </div>

    <!-- Add route -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
      <select v-model="addKey" class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/30">
        <option value="" disabled>-- เลือกหน้าที่จะปรับแต่ง --</option>
        <option v-for="r in availableRoutes" :key="r.key" :value="r.key">{{ r.label }}</option>
      </select>
      <button @click="addRoute" :disabled="!addKey"
        class="px-4 py-2 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-xl transition-all disabled:opacity-50">
        + เพิ่ม
      </button>
    </div>

    <!-- Empty -->
    <div v-if="headers.length === 0" class="flex flex-col items-center justify-center py-16 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <p class="font-bold text-slate-600 mb-1">ยังไม่มีหน้าที่ปรับแต่ง</p>
      <p class="text-sm text-slate-400">เลือกหน้าด้านบนแล้วกด "เพิ่ม" — หน้าที่ไม่ได้ตั้งค่าจะใช้ไอคอน/ชื่อเดิมตามปกติ</p>
    </div>

    <!-- Rows -->
    <div v-for="(row, i) in headers" :key="row.key" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 space-y-4">
      <div class="flex items-center justify-between">
        <h3 class="font-extrabold text-slate-800">{{ routeLabel(row.key) }}</h3>
        <button @click="removeRoute(i)" class="px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">
          🗑️ ลบ (กลับเป็นค่าเริ่มต้น)
        </button>
      </div>

      <!-- Mode toggle -->
      <div class="flex gap-2">
        <button @click="row.mode = 'icon'"
          :class="['flex-1 py-2 text-sm font-bold rounded-xl border-2 transition-all',
            row.mode === 'icon' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
          ใช้ไอคอน (ค่าเริ่มต้น)
        </button>
        <button @click="row.mode = 'media'"
          :class="['flex-1 py-2 text-sm font-bold rounded-xl border-2 transition-all',
            row.mode === 'media' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
          ใช้รูป/วิดีโอ/GIF
        </button>
      </div>

      <!-- Align + ซ่อน -->
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex gap-2">
          <button @click="row.align = 'left'"
            :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
              (row.align || 'center') === 'left' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
            ↤ ชิดซ้าย
          </button>
          <button @click="row.align = 'center'"
            :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
              (row.align || 'center') === 'center' ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
            ↔ กึ่งกลาง
          </button>
        </div>
        <label class="flex items-center gap-1.5 text-xs font-bold text-slate-600 cursor-pointer select-none">
          <input type="checkbox" v-model="row.hidden" class="w-4 h-4 rounded accent-primary"/>
          ซ่อนหัวข้อหน้านี้ทั้งหมด
        </label>
      </div>

      <!-- Icon mode -->
      <IconPicker v-if="row.mode === 'icon'" v-model="row.icon"/>

      <!-- Media mode -->
      <div v-else class="space-y-3">
        <!-- Aspect ratio picker -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1.5">สัดส่วนกรอบ</label>
          <div class="flex flex-wrap gap-2">
            <button v-for="r in ASPECT_RATIOS" :key="r.value" @click="row.aspect_ratio = r.value"
              :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-all',
                (row.aspect_ratio || '21:9') === r.value ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-500']">
              {{ r.label }}
            </button>
          </div>
        </div>

        <div v-if="row.media_url" class="rounded-xl overflow-hidden border border-slate-200 bg-slate-50 max-w-md"
          :style="`aspect-ratio:${row.aspect_ratio ? ratioNumber(row.aspect_ratio) : 21/9}`">
          <video v-if="row.media_type === 'video'" :src="row.media_url" class="w-full h-full object-cover" controls muted/>
          <img v-else :src="row.media_url" class="w-full h-full object-cover"/>
        </div>
        <div class="flex flex-wrap gap-2">
          <button @click="openCropper(i)" class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
            🖼️ อัปโหลดรูป (ครอปได้)
          </button>
          <button @click="triggerRawUpload(i)" class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
            🎬 อัปโหลดวิดีโอ/GIF (ไม่ครอป)
          </button>
          <button @click="openStorage(i)" class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
            🗂️ เลือกจาก Storage
          </button>
          <button v-if="row.media_url" @click="clearMedia(row)" class="px-3 py-2 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">
            ลบไฟล์นี้
          </button>
        </div>
        <div v-if="uploadingRaw && activeIndex === i" class="space-y-1">
          <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
            <div class="h-full transition-all" :style="`width:${rawUploadProgress}%; background: linear-gradient(90deg, var(--color-primary), var(--color-secondary))`"></div>
          </div>
          <p class="text-xs text-slate-400">{{ rawUploadProgress }}%</p>
        </div>
        <p v-if="rawUploadError && activeIndex === i" class="text-xs text-red-500 font-bold">{{ rawUploadError }}</p>
      </div>

      <!-- Title/subtitle override -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อหัวข้อ (ไม่บังคับ)</label>
          <input v-model="row.title" type="text" placeholder="ว่าง = ใช้ชื่อเดิมของหน้า"
            class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
        </div>
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">คำอธิบายย่อย (ไม่บังคับ)</label>
          <input v-model="row.subtitle" type="text" placeholder="ว่าง = ใช้คำอธิบายเดิมของหน้า"
            class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
        </div>
      </div>
    </div>

    <button @click="save" :disabled="saving"
      class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
      💾 บันทึกทั้งหมด
    </button>

    <!-- hidden raw file input -->
    <input ref="rawFileInput" type="file" accept="image/gif,video/mp4,video/webm,video/quicktime" class="hidden" @change="onRawFileSelected"/>

    <!-- Storage browser -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showStorage" class="fixed inset-0 z-[150] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm" @click.self="showStorage = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800">🗂️ เลือกไฟล์จาก Storage</h3>
              <button @click="showStorage = false" class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 text-lg">✕</button>
            </div>
            <div class="flex-1 overflow-y-auto p-6">
              <StorageBrowser bucket="banners" title="รูป/วิดีโอ Header" :selectable="true" @select="onStorageSelect"/>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Image cropper -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="cropperRatio"
      title="ครอบรูป Header"
      :output-max-width="1920"
      :output-max-height="1920"
      output-type="image/jpeg"
      :output-quality="0.85"
      @close="showCropper = false"
      @cropped="onCropped"/>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
