<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig, THEME_PRESETS } from '../../composables/useAreaConfig'

import ImageCropperModal from '../../components/ImageCropperModal.vue'
import StorageBrowser    from '../../components/StorageBrowser.vue'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'
import Swal from 'sweetalert2'

const { updateConfig, previewTheme, resetTheme, fetchConfig } = useAreaConfig()

const config       = ref({})
const saving       = ref(false)
const saved        = ref(false)
const loading      = ref(true)
const activeTab    = ref('general')
const showSchoolPass = ref(false)

const tabs = [
  { key: 'general',  icon: '🏛️', label: 'ข้อมูลเขตพื้นที่' },
  { key: 'brand',    icon: 'settings',  label: 'โลโก้และสี' },
  { key: 'contact',  icon: 'phone',     label: 'ข้อมูลติดต่อ' },
  { key: 'social',   icon: 'globe',     label: 'โซเชียลมีเดีย' },
  { key: 'footer',   icon: 'link',      label: 'ลิงก์ท้ายเว็บไซต์' },
  { key: 'storage',  icon: 'folder',    label: 'จัดการไฟล์' },
  { key: 'features', icon: 'wrench',    label: 'ฟีเจอร์' },
]

const areaTypes = ['สพป.', 'สพม.', 'สศศ.', 'สพปกษ.']

// ── Services config ───────────────────────────────────────────────
import { ICON_MAP, ICON_LABELS } from '../../composables/useIcons.js'

const DEFAULT_SERVICES = [
  { key:'nitet',    label:'กลุ่มนิเทศติดตามฯ',   icon:'eye',       type:'internal', url:'/nithet',    visible:true, order:1 },
  { key:'download', label:'ดาวน์โหลดเอกสาร',     icon:'download',  type:'internal', url:'/download',  visible:true, order:2 },
  { key:'qrcode',   label:'สร้าง QR Code',        icon:'qrcode',    type:'internal', url:'/qrcode',    visible:true, order:3 },
  { key:'urlshort', label:'ย่อลิงค์',             icon:'link',      type:'internal', url:'/url-short', visible:true, order:4 },
  { key:'sar',      label:'ระบบ SAR Online',       icon:'chart-bar', type:'external', url:'',           visible:true, order:5 },
  { key:'media',    label:'คลังสื่อนวัตกรรม',     icon:'beaker',    type:'external', url:'',           visible:true, order:6 },
  { key:'training', label:'ลงทะเบียนอบรม',        icon:'clipboard', type:'external', url:'',           visible:true, order:7 },
  { key:'contact',  label:'ติดต่อเรา',             icon:'phone',     type:'internal', url:'/contact',   visible:true, order:8 },
]

const services = ref([])
const savingServices = ref(false)

function moveServiceUp(i)   { if (i>0) { [services.value[i-1],services.value[i]]=[services.value[i],services.value[i-1]]; services.value.forEach((s,idx)=>s.order=idx+1) } }
function moveServiceDown(i) { if (i<services.value.length-1) { [services.value[i],services.value[i+1]]=[services.value[i+1],services.value[i]]; services.value.forEach((s,idx)=>s.order=idx+1) } }
function addService() {
  services.value.push({ key:'svc_'+Date.now(), label:'บริการใหม่', icon:'globe', type:'external', url:'', visible:true, order:services.value.length+1 })
}
function removeService(i) { services.value.splice(i,1); services.value.forEach((s,idx)=>s.order=idx+1) }
async function saveServices() {
  savingServices.value = true
  await updateConfig({ services: services.value })
  savingServices.value = false
  Swal.fire({ icon:'success', title:'บันทึกแล้ว', showConfirmButton:false, timer:800 })
}

const SYSTEM_ROUTES = [
  { route:'/nithet',    label:'กลุ่มนิเทศติดตามฯ' },
  { route:'/personnel', label:'ทำเนียบบุคลากร' },
  { route:'/schools',   label:'ทำเนียบโรงเรียน' },
  { route:'/news',      label:'ข่าวสาร' },
  { route:'/download',  label:'ดาวน์โหลด' },
  { route:'/url-short', label:'ย่อลิงค์' },
  { route:'/qrcode',    label:'QR Code' },
  { route:'/contact',   label:'ติดต่อเรา' },
]

// ── ลิงก์เพิ่มเติมท้ายเว็บไซต์ (footer คอลัมน์ที่ 5 admin กำหนดเอง) ──────
function moveFooterLinkUp(i)   { const l = config.value.footer_extra_links; if (i>0) { [l[i-1],l[i]]=[l[i],l[i-1]]; l.forEach((x,idx)=>x.order=idx+1) } }
function moveFooterLinkDown(i) { const l = config.value.footer_extra_links; if (i<l.length-1) { [l[i],l[i+1]]=[l[i+1],l[i]]; l.forEach((x,idx)=>x.order=idx+1) } }
function addFooterLink() {
  if (!config.value.footer_extra_links) config.value.footer_extra_links = []
  config.value.footer_extra_links.push({ label:'ลิงก์ใหม่', type:'internal', url:'', order: config.value.footer_extra_links.length+1 })
}
function removeFooterLink(i) {
  config.value.footer_extra_links.splice(i,1)
  config.value.footer_extra_links.forEach((x,idx)=>x.order=idx+1)
}

onMounted(async () => {
  const { data, error } = await supabase.from('area_config').select('*').eq('id', 1).single()
  if (!error && data) {
    config.value = { ...data }
    config.value.footer_extra_links = (data.footer_extra_links || []).map(l => ({ ...l }))
    services.value = (data.services || DEFAULT_SERVICES).map(s => ({ ...s }))
  }
  loading.value = false
})

// Preview สีแบบ live ขณะเลื่อน color picker (ยังไม่ save)
function onPrimaryChange(e) {
  config.value.primary_color = e.target.value
  previewTheme(config.value.primary_color, config.value.secondary_color)
}
function onSecondaryChange(e) {
  config.value.secondary_color = e.target.value
  previewTheme(config.value.primary_color, config.value.secondary_color)
}

async function save() {
  saving.value = true
  const { error } = await updateConfig({ ...config.value })
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    saved.value = true
    // force reload config cache
    await fetchConfig(true)
    setTimeout(() => { saved.value = false }, 2500)
  }
}

// ── Logo upload ────────────────────────────────────────────────
const showCropper   = ref(false)
const uploadingLogo = ref(false)

// ── Welcome popup image upload (ไม่ครอป กันภาพที่ออกแบบมาแล้วเพี้ยน + รองรับ GIF) ──
const { uploadFile: uploadPopupExternal } = useExternalUpload()
const popupFileInput   = ref(null)
const uploadingPopup   = ref(false)
const popupUploadError = ref('')

function triggerPopupUpload() { popupFileInput.value?.click() }

async function onPopupFileSelected(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  if (!/^image\//.test(file.type)) {
    popupUploadError.value = 'รองรับเฉพาะไฟล์รูปภาพ (รวม GIF)'
    return
  }
  if (file.size > 5 * 1024 * 1024) {
    popupUploadError.value = `ไฟล์ใหญ่เกิน 5 MB (ไฟล์นี้ ${(file.size/1024/1024).toFixed(1)} MB)`
    return
  }
  popupUploadError.value = ''
  uploadingPopup.value = true
  try {
    if (externalUploadEnabled) {
      config.value.welcome_popup_image_url = await uploadPopupExternal(file, 'welcome-popup')
    } else {
      const ext = file.name.split('.').pop() || 'png'
      const fileName = `welcome-popup-${Date.now()}.${ext}`
      const { data, error } = await supabase.storage.from('banners').upload(fileName, file, { contentType: file.type, upsert: false })
      if (error) throw error
      config.value.welcome_popup_image_url = supabase.storage.from('banners').getPublicUrl(data.path).data.publicUrl
    }
  } catch (err) {
    popupUploadError.value = err.message
  } finally {
    uploadingPopup.value = false
  }
}

async function clearPopupImage() {
  if (config.value.welcome_popup_image_url) await deleteUploadedFile(config.value.welcome_popup_image_url)
  config.value.welcome_popup_image_url = ''
}

// ดึงชื่อไฟล์จาก public URL
function extractFileName(url) {
  if (!url) return null
  try { return url.split('/logos/').pop().split('?')[0] } catch { return null }
}

// ลบไฟล์เก่าจาก Storage (ถ้ามี)
async function deleteOldLogo() {
  const oldName = extractFileName(config.value.logo_url)
  if (oldName) await supabase.storage.from('logos').remove([oldName])
}

async function onLogoCropped({ blob }) {
  showCropper.value = false
  uploadingLogo.value = true
  try {
    // ลบไฟล์เก่าก่อน
    await deleteOldLogo()
    // อัปโหลดใหม่
    const fileName = `logo-${Date.now()}.png`
    const { data, error } = await supabase.storage
      .from('logos')
      .upload(fileName, blob, { contentType: 'image/png', upsert: false })
    if (error) throw error
    const { data: urlData } = supabase.storage.from('logos').getPublicUrl(data.path)
    config.value.logo_url = urlData.publicUrl
    Swal.fire({ icon: 'success', title: 'อัปโหลดสำเร็จ', text: 'กด "บันทึกการตั้งค่า" เพื่อใช้งานโลโก้นี้', confirmButtonColor: '#3b82f6' })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: e.message, confirmButtonColor: '#3b82f6' })
  } finally {
    uploadingLogo.value = false
  }
}

async function removeLogo() {
  const res = await Swal.fire({
    title: 'ลบโลโก้?', icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก'
  })
  if (res.isConfirmed) {
    await deleteOldLogo()   // ลบไฟล์จริงใน Storage
    config.value.logo_url = ''
  }
}

// เลือกไฟล์จาก StorageBrowser มาใช้เป็นโลโก้
function onStorageSelect({ url }) {
  config.value.logo_url = url
  activeTab.value = 'brand'
  Swal.fire({ icon: 'success', title: 'เลือกโลโก้แล้ว', text: 'กด "บันทึกการตั้งค่า" เพื่อใช้งาน', confirmButtonColor: '#3b82f6' })
}

function applyPreset(preset) {
  config.value.primary_color   = preset.primary
  config.value.secondary_color = preset.secondary
  previewTheme(preset.primary, preset.secondary)
}

function isPresetActive(preset) {
  return config.value.primary_color === preset.primary &&
         config.value.secondary_color === preset.secondary
}

function resetToDefault() {
  Swal.fire({
    title: 'รีเซ็ตค่าตั้งต้น?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'รีเซ็ต', cancelButtonText: 'ยกเลิก'
  }).then(res => {
    if (res.isConfirmed) {
      config.value.primary_color   = '#1e3a5f'
      config.value.secondary_color = '#b8922a'
      previewTheme('#1e3a5f', '#b8922a')
    }
  })
}
</script>

<template>
  <div class="font-sarabun">

    <!-- Header -->
    <div class="flex items-center justify-between mb-6 flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-900 flex items-center gap-2">
          <SvgIcon name="settings" class="w-6 h-6 text-primary"/> ตั้งค่าเขตพื้นที่
        </h1>
        <p class="text-slate-500 text-sm mt-1">ปรับแต่งชื่อ โลโก้ สี และข้อมูลติดต่อ — เขตอื่นสามารถเปลี่ยนได้ที่นี่</p>
      </div>
      <button @click="save" :disabled="saving"
        :class="['flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-bold transition-all shadow-md',
          saved ? 'bg-emerald-600 text-white' : 'bg-blue-600 hover:bg-blue-700 text-white hover:-translate-y-0.5']">
        <SvgIcon v-if="!saving && !saved" name="document" class="w-4 h-4"/>
        <span>{{ saving ? 'กำลังบันทึก...' : saved ? 'บันทึกแล้ว' : 'บันทึกการตั้งค่า' }}</span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-20">
      <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600"></div>
    </div>

    <div v-else class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden">

      <!-- Tabs — flex-wrap บนมือถือ, scroll บน desktop -->
      <div class="flex flex-wrap border-b border-slate-100 bg-slate-50">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          :class="['flex items-center gap-1.5 px-4 py-3 text-sm font-bold transition-all border-b-2',
            activeTab === tab.key
              ? 'border-primary text-primary bg-white'
              : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-white']">
          <SvgIcon :name="tab.icon" class="w-4 h-4 flex-shrink-0"/>
          <span class="hidden sm:inline">{{ tab.label }}</span>
          <span class="sm:hidden text-xs">{{ tab.label.length > 6 ? tab.label.slice(0,6)+'…' : tab.label }}</span>
        </button>
      </div>

      <div class="p-6 md:p-8">

        <!-- ── Tab: ข้อมูลเขตพื้นที่ ─────────────────────────── -->
        <div v-if="activeTab === 'general'" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div class="md:col-span-2">
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">ชื่อเต็มกลุ่มนิเทศ / เขต *</label>
              <input v-model="config.area_name" type="text"
                placeholder="กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
              <p class="text-xs text-slate-400 mt-1">แสดงใน navbar, footer และหัวเอกสาร</p>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">ชื่อย่อ</label>
              <input v-model="config.area_name_short" type="text" placeholder="กลุ่มนิเทศฯ"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">ประเภทสำนักงาน</label>
              <select v-model="config.area_type"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 bg-white">
                <option v-for="t in areaTypes" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">จังหวัด</label>
              <input v-model="config.province" type="text" placeholder="กรุงเทพมหานคร"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">เลขเขต (ถ้ามี)</label>
              <input v-model="config.area_number" type="text" placeholder="เขต 1"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">Domain อีเมลโรงเรียน</label>
              <input v-model="config.school_email_domain" type="text" placeholder="@school.ac.th"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
              <p class="text-xs text-slate-400 mt-1">ใช้ตรวจสอบ email ของผู้แทนโรงเรียน</p>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                รหัสผ่าน Default โรงเรียน
                <span class="normal-case font-normal text-slate-400 ml-1">— ใช้เมื่อรีเซ็ต</span>
              </label>
              <div class="relative">
                <input v-model="config.default_school_password"
                  :type="showSchoolPass ? 'text' : 'password'"
                  placeholder="Korat2@2569"
                  class="w-full px-4 py-3 pr-11 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                <button type="button" @click="showSchoolPass = !showSchoolPass"
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                  <svg v-if="showSchoolPass" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
                  </svg>
                  <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                </button>
              </div>
              <p class="text-xs text-slate-400 mt-1">รหัสผ่านที่ใช้เมื่อกด "รีเซ็ต" หรือสร้าง account โรงเรียน</p>
            </div>

            <!-- Banner aspect ratio -->
            <div class="md:col-span-2 pt-2 border-t border-slate-100">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">สัดส่วนแบนเนอร์หน้าแรก</p>
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <label v-for="opt in [
                  { value:'21:9', label:'21:9', desc:'Cinematic', size:'1920×823px', recommended: true },
                  { value:'16:9', label:'16:9', desc:'มาตรฐาน',   size:'1920×1080px' },
                  { value:'3:1',  label:'3:1',  desc:'เว็บราชการ', size:'1500×500px' },
                  { value:'4:1',  label:'4:1',  desc:'แบนเนอร์บาง', size:'1200×300px' },
                ]" :key="opt.value"
                  :class="['relative cursor-pointer border-2 rounded-xl p-3 transition-all',
                    (config.banner_aspect_ratio || '21:9') === opt.value
                      ? 'border-primary bg-primary/5'
                      : 'border-slate-200 hover:border-slate-300']">
                  <input type="radio" v-model="config.banner_aspect_ratio" :value="opt.value" class="sr-only"/>
                  <!-- ratio preview -->
                  <div class="bg-slate-200 rounded mb-2 overflow-hidden"
                    :style="`aspect-ratio: ${opt.value.replace(':','/')}`">
                    <div class="w-full h-full bg-gradient-to-br from-primary/30 to-primary/10"/>
                  </div>
                  <p class="text-xs font-bold text-slate-700">{{ opt.label }}
                    <span v-if="opt.recommended" class="ml-1 text-[10px] bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded-full font-bold">แนะนำ</span>
                  </p>
                  <p class="text-[10px] text-slate-400">{{ opt.desc }}</p>
                  <p class="text-[10px] text-slate-400 font-mono">{{ opt.size }}</p>
                </label>
              </div>
            </div>

            <!-- Schools page -->
            <div class="md:col-span-2 pt-2 border-t border-slate-100">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">หน้าทำเนียบสถานศึกษา (/schools)</p>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">ชื่อหน้า (Title)</label>
                  <input v-model="config.schools_page_title" type="text" placeholder="ทำเนียบสถานศึกษา"
                    class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">คำอธิบาย (ปล่อยว่าง = ชื่อเขตอัตโนมัติ)</label>
                  <input v-model="config.schools_page_subtitle" type="text" placeholder="เช่น สังกัด สพป.นครราชสีมา เขต 2"
                    class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
              </div>
            </div>

            <!-- Tagline -->
            <div class="md:col-span-2">
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                แท็กไลน์ใต้ชื่อ
                <span class="normal-case font-normal text-slate-400 ml-1">— กำหนดได้เอง</span>
              </label>
              <input v-model="config.tagline" type="text"
                placeholder="เช่น  สพป.นครราชสีมา เขต 2  หรือ  พัฒนาการศึกษาสู่ความเป็นเลิศ"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
              <p class="text-xs text-slate-400 mt-1">
                แสดงใต้ชื่อหน่วยงานใน Navbar — หากว่างเว้นจะใช้ <span class="font-mono bg-slate-100 px-1 rounded">ประเภท + จังหวัด + เลขเขต</span> อัตโนมัติ
              </p>
            </div>
          </div>

          <!-- Preview -->
          <div class="bg-slate-50 rounded-2xl p-5 border border-slate-100">
            <p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">ตัวอย่าง Navbar</p>
            <div class="flex items-center gap-3 bg-white rounded-xl p-3 border border-slate-200 w-fit">
              <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                :style="`background-color: ${config.primary_color || '#2563eb'}`">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-extrabold text-slate-800">{{ config.area_name || 'ชื่อกลุ่มนิเทศฯ' }}</p>
                <p class="text-[10px] text-slate-400">
                  {{ config.tagline || (`${config.area_type || ''}${config.province ? ' '+config.province : ''}${config.area_number ? ' '+config.area_number : ''}`) || 'สำนักงานเขตพื้นที่การศึกษา' }}
                </p>
              </div>
            </div>
            <p class="text-[10px] mt-2" :class="config.tagline ? 'text-emerald-600 font-bold' : 'text-slate-400'">
              {{ config.tagline ? 'ใช้ tagline ที่กำหนดเอง' : 'ใช้ค่าอัตโนมัติ (ประเภท + จังหวัด + เลขเขต)' }}
            </p>
          </div>
        </div>

        <!-- ── Tab: โลโก้และสี ───────────────────────────────── -->
        <div v-if="activeTab === 'brand'" class="space-y-6">

          <!-- Preset themes -->
          <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-3">
              ธีมสำเร็จรูป
              <span class="normal-case font-normal text-slate-400 ml-1">— คลิกเพื่อนำไปใช้ทันที</span>
            </label>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <button
                v-for="preset in THEME_PRESETS"
                :key="preset.id"
                @click="applyPreset(preset)"
                :class="[
                  'relative flex items-center gap-4 p-4 rounded-2xl border-2 text-left transition-all',
                  isPresetActive(preset)
                    ? 'border-primary bg-primary-light shadow-md'
                    : 'border-slate-100 bg-white hover:border-slate-300 hover:shadow-sm'
                ]">
                <!-- Color swatches -->
                <div class="flex flex-col gap-1.5 flex-shrink-0">
                  <div class="w-7 h-7 rounded-lg shadow-sm" :style="`background:${preset.primary}`"></div>
                  <div class="w-7 h-7 rounded-lg shadow-sm" :style="`background:${preset.secondary}`"></div>
                </div>
                <!-- Text -->
                <div class="flex-1 min-w-0">
                  <p class="font-bold text-sm text-slate-800 truncate">{{ preset.name }}</p>
                  <p class="text-xs text-slate-400 leading-snug mt-0.5">{{ preset.desc }}</p>
                </div>
                <!-- Active badge -->
                <span v-if="isPresetActive(preset)"
                  class="absolute top-2.5 right-2.5 w-5 h-5 rounded-full flex items-center justify-center"
                  style="background-color: var(--color-primary)">
                  <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                  </svg>
                </span>
              </button>
            </div>
            <p class="text-xs text-slate-400 mt-2">กด "บันทึกการตั้งค่า" เพื่อใช้ธีมที่เลือกถาวร</p>
          </div>

          <div class="border-t border-slate-100"></div>

          <!-- Logo upload section -->
          <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-3">โลโก้เขตพื้นที่</label>
            <div class="flex items-start gap-5">

              <!-- Current logo preview -->
              <div class="flex-shrink-0">
                <div :class="[
                  'w-24 h-24 rounded-2xl border-2 border-dashed flex items-center justify-center overflow-hidden transition-all',
                  config.logo_url ? 'border-slate-200 bg-white' : 'border-slate-300 bg-slate-50'
                ]">
                  <img v-if="config.logo_url" :src="config.logo_url" class="w-full h-full object-contain p-1"/>
                  <SvgIcon v-else name="building" class="w-8 h-8 text-slate-300"/>
                </div>
                <p class="text-[10px] text-slate-400 text-center mt-1">ตัวอย่าง</p>
              </div>

              <!-- Actions -->
              <div class="flex-1 space-y-3">
                <button @click="showCropper = true" :disabled="uploadingLogo"
                  class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-xl transition-all shadow-sm disabled:opacity-50">
                  <svg v-if="uploadingLogo" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                  </svg>
                  <SvgIcon v-else name="folder" class="w-4 h-4 text-slate-400"/>
                  {{ uploadingLogo ? 'กำลังอัปโหลด...' : 'อัปโหลดและครอบโลโก้' }}
                </button>

                <div v-if="config.logo_url" class="flex items-center gap-2">
                  <button @click="removeLogo"
                    class="text-xs font-bold text-red-500 hover:text-red-600 px-3 py-1.5 border border-red-200 hover:border-red-300 rounded-lg transition-colors">
                    🗑️ ลบโลโก้
                  </button>
                  <span class="text-xs text-slate-400">หรือ</span>
                  <input v-model="config.logo_url" type="url" placeholder="วาง URL โลโก้โดยตรง"
                    class="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-200"/>
                </div>

                <p class="text-xs text-slate-400">แนะนำ: รูปสี่เหลี่ยมจัตุรัส PNG พื้นหลังโปร่งใส ขนาด 512×512px</p>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">สีหลัก (Primary)</label>
              <div class="flex items-center gap-3 border border-slate-200 rounded-xl p-3 bg-slate-50">
                <input v-model="config.primary_color" type="color" @input="onPrimaryChange" class="w-10 h-10 rounded-lg cursor-pointer border-0 bg-transparent"/>
                <div>
                  <p class="font-mono text-sm font-bold text-slate-700">{{ config.primary_color }}</p>
                  <div class="w-24 h-3 rounded-full mt-1" :style="`background:${config.primary_color}`"></div>
                </div>
              </div>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">สีรอง (Secondary)</label>
              <div class="flex items-center gap-3 border border-slate-200 rounded-xl p-3 bg-slate-50">
                <input v-model="config.secondary_color" type="color" @input="onSecondaryChange" class="w-10 h-10 rounded-lg cursor-pointer border-0 bg-transparent"/>
                <div>
                  <p class="font-mono text-sm font-bold text-slate-700">{{ config.secondary_color }}</p>
                  <div class="w-24 h-3 rounded-full mt-1" :style="`background:${config.secondary_color}`"></div>
                </div>
              </div>
            </div>
          </div>

          <!-- Color preview -->
          <div class="rounded-2xl overflow-hidden border border-slate-100">
            <div class="h-2" :style="`background: linear-gradient(to right, ${config.primary_color}, ${config.secondary_color})`"></div>
            <div class="p-5 bg-white">
              <div class="flex items-center gap-3">
                <div class="px-4 py-2 rounded-xl text-white text-sm font-bold" :style="`background:${config.primary_color}`">ปุ่มหลัก</div>
                <div class="px-4 py-2 rounded-xl text-white text-sm font-bold" :style="`background:${config.secondary_color}`">ปุ่มรอง</div>
              </div>
            </div>
          </div>

          <button @click="resetToDefault" class="text-sm font-bold text-slate-500 hover:text-red-500 transition-colors">
            🔄 รีเซ็ตสีเป็นค่าตั้งต้น
          </button>
        </div>

        <!-- ── Tab: ข้อมูลติดต่อ ─────────────────────────────── -->
        <div v-if="activeTab === 'contact'" class="space-y-4">
          <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">ที่อยู่สำนักงาน</label>
            <textarea v-model="config.contact_address" rows="3" placeholder="เลขที่ ... ถนน ... ตำบล ... อำเภอ ... จังหวัด ..."
              class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 resize-none"></textarea>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">📞 โทรศัพท์</label>
              <input v-model="config.contact_phone" type="text" placeholder="0X-XXXX-XXXX ต่อ XXX"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">📠 โทรสาร</label>
              <input v-model="config.contact_fax" type="text" placeholder="0X-XXXX-XXXX"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">📧 อีเมลหลัก</label>
              <input v-model="config.contact_email" type="email" placeholder="nithet@obec.go.th"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">🌐 เว็บไซต์</label>
              <input v-model="config.website_url" type="url" placeholder="https://..."
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
            </div>
          </div>
        </div>

        <!-- ── Tab: โซเชียล ─────────────────────────────────── -->
        <div v-if="activeTab === 'social'" class="space-y-4">
          <div v-for="s in [
            { key:'facebook_url', icon:'👍', label:'Facebook Page URL', ph:'https://facebook.com/...' },
            { key:'line_url',     icon:'💬', label:'LINE Official URL',  ph:'https://line.me/R/ti/p/@...' },
            { key:'youtube_url',  icon:'▶️', label:'YouTube Channel URL',ph:'https://youtube.com/...' },
          ]" :key="s.key">
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">{{ s.icon }} {{ s.label }}</label>
            <input v-model="config[s.key]" type="url" :placeholder="s.ph"
              class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
          </div>
        </div>

        <!-- ── Tab: ลิงก์ท้ายเว็บไซต์ ───────────────────────────────── -->
        <div v-if="activeTab === 'footer'" class="space-y-4">
          <div class="flex items-center gap-2 p-3.5 bg-blue-50 rounded-2xl border border-blue-100 text-sm text-blue-700">
            <SvgIcon name="link" class="w-4 h-4 flex-shrink-0"/>
            <span>คอลัมน์เพิ่มเติมท้ายเว็บไซต์ (footer) — ตั้งหัวข้อและสร้างลิงก์เองได้ ทั้งลิงก์ภายในเว็บ (route) และภายนอก (URL) ถ้าไม่มีลิงก์เลยคอลัมน์นี้จะไม่แสดง</span>
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1.5">หัวข้อคอลัมน์</label>
            <input v-model="config.footer_extra_title" type="text" placeholder="เช่น ลิงก์เพิ่มเติม, หน่วยงานที่เกี่ยวข้อง"
              class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
          </div>

          <div class="space-y-3">
            <div v-for="(link, i) in config.footer_extra_links" :key="i"
              class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex flex-wrap items-start gap-4">

              <!-- up/down -->
              <div class="flex flex-col gap-0.5 flex-shrink-0">
                <button @click="moveFooterLinkUp(i)" :disabled="i===0" type="button"
                  class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
                  </svg>
                </button>
                <button @click="moveFooterLinkDown(i)" :disabled="i===config.footer_extra_links.length-1" type="button"
                  class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                  </svg>
                </button>
              </div>

              <!-- fields -->
              <div class="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ชื่อลิงก์</label>
                  <input v-model="link.label" type="text"
                    class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ประเภท</label>
                  <select v-model="link.type"
                    class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="internal">ภายใน (route)</option>
                    <option value="external">ภายนอก (URL)</option>
                  </select>
                </div>
                <div>
                  <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                    {{ link.type === 'internal' ? 'Route' : 'URL ปลายทาง' }}
                  </label>
                  <input v-model="link.url" type="text"
                    :placeholder="link.type==='internal' ? '/personnel' : 'https://...'"
                    class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm font-mono focus:outline-none focus:border-primary"/>
                  <div v-if="link.type==='internal'" class="flex flex-wrap gap-1 mt-1.5">
                    <button v-for="r in SYSTEM_ROUTES" :key="r.route" type="button"
                      @click="link.url = r.route"
                      :class="['text-[9px] px-1.5 py-0.5 rounded-md transition-colors',
                        link.url===r.route ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                      {{ r.route }}
                    </button>
                  </div>
                </div>
              </div>

              <button @click="removeFooterLink(i)" type="button"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold rounded-xl bg-slate-50 text-slate-400 hover:text-red-500 hover:bg-red-50 transition-colors flex-shrink-0">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
                ลบ
              </button>
            </div>

            <p v-if="!config.footer_extra_links || config.footer_extra_links.length === 0" class="text-center text-slate-400 py-6">
              ยังไม่มีลิงก์ — กด "เพิ่มลิงก์" เพื่อเริ่มต้น
            </p>
          </div>

          <button @click="addFooterLink" type="button"
            class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
            <SvgIcon name="plus" class="w-4 h-4"/> เพิ่มลิงก์
          </button>
        </div>

        <!-- ── Tab: จัดการไฟล์ ───────────────────────────────── -->
        <div v-if="activeTab === 'storage'" class="space-y-4">
          <p class="text-sm text-slate-500">ไฟล์ที่อัปโหลดใน Storage bucket <code class="bg-slate-100 px-1.5 py-0.5 rounded text-xs font-mono">logos</code></p>
          <StorageBrowser
            bucket="logos"
            accept="image/*"
            title="ไฟล์โลโก้และรูปภาพ"
            :selectable="true"
            @select="onStorageSelect"
          />
        </div>

        <!-- ── Tab: ฟีเจอร์ ──────────────────────────────────── -->
        <div v-if="activeTab === 'features'" class="space-y-5">
          <p class="text-sm text-slate-500">เปิด/ปิดฟีเจอร์ต่าง ๆ ของเว็บไซต์สาธารณะ</p>

          <!-- Feature toggles -->
          <div class="space-y-3">
            <div v-for="feat in [
              { key:'allow_teacher_register', icon:'👩‍🏫', label:'อนุญาตให้สมัครสมาชิกได้เอง', desc:'ครูและบุคลากรสามารถลงทะเบียนด้วยตัวเองและรออนุมัติจาก admin' },
              { key:'show_public_stats',      icon:'📊', label:'แสดงสถิติสาธารณะ',              desc:'แสดงตัวเลขโรงเรียน ครู นักเรียน บนหน้าเว็บหลัก' },
              { key:'show_public_news',       icon:'📰', label:'แสดงข่าวสารสาธารณะ',            desc:'ข่าวที่ publish แล้วจะแสดงบนหน้าเว็บ' },
              { key:'show_public_works',      icon:'🏆', label:'แสดงผลงานสาธารณะ',             desc:'ผลงานที่อนุมัติแล้วจะแสดงบนหน้าเว็บ' },
            ]" :key="feat.key"
              class="flex items-start justify-between gap-4 p-4 bg-slate-50 rounded-2xl border border-slate-100 hover:bg-white hover:border-slate-200 transition-all">
              <div class="flex items-start gap-3">
                <span class="text-2xl flex-shrink-0">{{ feat.icon }}</span>
                <div>
                  <p class="font-bold text-sm text-slate-800">{{ feat.label }}</p>
                  <p class="text-xs text-slate-400 mt-0.5">{{ feat.desc }}</p>
                </div>
              </div>
              <button @click="config[feat.key] = !config[feat.key]"
                :class="['relative w-12 h-6 rounded-full transition-colors flex-shrink-0 mt-0.5',
                  config[feat.key] ? 'bg-blue-600' : 'bg-slate-300']">
                <span :class="['absolute w-5 h-5 bg-white rounded-full shadow-sm top-0.5 transition-all',
                  config[feat.key] ? 'left-6' : 'left-0.5']"></span>
              </button>
            </div>
          </div>

          <!-- ── รหัสสมัครสมาชิก ─────────────────────────────── -->
          <div class="border-t border-slate-100 pt-5 space-y-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="font-bold text-sm text-slate-800 flex items-center gap-1.5">
                  <SvgIcon name="settings" class="w-4 h-4 text-primary"/> รหัสลับสำหรับสมัครสมาชิก
                </p>
                <p class="text-xs text-slate-400 mt-0.5">ผู้สมัครต้องกรอกรหัสให้ถูกต้องก่อนสมัคร ป้องกันคนภายนอก</p>
              </div>
              <button @click="config.register_code_enabled = !config.register_code_enabled"
                :class="['relative w-12 h-6 rounded-full transition-colors flex-shrink-0',
                  config.register_code_enabled ? 'bg-blue-600' : 'bg-slate-300']">
                <span :class="['absolute w-5 h-5 bg-white rounded-full shadow-sm top-0.5 transition-all',
                  config.register_code_enabled ? 'left-6' : 'left-0.5']"></span>
              </button>
            </div>

            <div v-if="config.register_code_enabled" class="grid grid-cols-1 sm:grid-cols-2 gap-4 pl-2">
              <!-- รหัสครู -->
              <div class="bg-amber-50 border border-amber-200 rounded-2xl p-4">
                <label class="text-xs font-bold text-amber-700 uppercase tracking-wider block mb-2">
                  🧑‍🏫 รหัสสมัคร — ครู
                </label>
                <div class="flex gap-2">
                  <input v-model="config.register_code_teacher" type="text"
                    placeholder="เช่น KORAT2-TEACHER"
                    class="flex-1 px-3 py-2 border border-amber-300 rounded-xl text-sm font-mono focus:outline-none focus:border-amber-500 bg-white"/>
                  <button type="button"
                    @click="config.register_code_teacher = Math.random().toString(36).slice(2,8).toUpperCase()"
                    class="px-3 py-2 bg-amber-200 hover:bg-amber-300 text-amber-800 text-xs font-bold rounded-xl transition-colors"
                    title="สุ่มรหัส">
                    🎲
                  </button>
                </div>
                <p class="text-[10px] text-amber-600 mt-1">ปล่อยว่าง = ไม่ต้องใช้รหัสสำหรับครู</p>
              </div>

              <!-- รหัสบุคลากร -->
              <div class="bg-blue-50 border border-blue-200 rounded-2xl p-4">
                <label class="text-xs font-bold text-blue-700 uppercase tracking-wider block mb-2">
                  👥 รหัสสมัคร — บุคลากร
                </label>
                <div class="flex gap-2">
                  <input v-model="config.register_code_personnel" type="text"
                    placeholder="เช่น NITET-2568"
                    class="flex-1 px-3 py-2 border border-blue-300 rounded-xl text-sm font-mono focus:outline-none focus:border-blue-500 bg-white"/>
                  <button type="button"
                    @click="config.register_code_personnel = Math.random().toString(36).slice(2,8).toUpperCase()"
                    class="px-3 py-2 bg-blue-200 hover:bg-blue-300 text-blue-800 text-xs font-bold rounded-xl transition-colors"
                    title="สุ่มรหัส">
                    🎲
                  </button>
                </div>
                <p class="text-[10px] text-blue-600 mt-1">ปล่อยว่าง = ไม่ต้องใช้รหัสสำหรับบุคลากร</p>
              </div>
            </div>

            <div v-if="config.register_code_enabled" class="flex items-start gap-2 p-3 bg-slate-50 rounded-xl border border-slate-200 text-xs text-slate-500">
              <SvgIcon name="beaker" class="w-4 h-4 flex-shrink-0 text-slate-400"/>
              <span>แจ้งรหัสให้บุคลากรผ่าน Line กลุ่ม หรือวิธีที่ปลอดภัย อย่า post สาธารณะ</span>
            </div>
          </div>

          <!-- ── ป๊อปอัปต้อนรับก่อนเข้าเว็บ ─────────────────────── -->
          <div class="border-t border-slate-100 pt-5 space-y-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="font-bold text-sm text-slate-800 flex items-center gap-1.5">
                  <SvgIcon name="beaker" class="w-4 h-4 text-primary"/> ป๊อปอัปต้อนรับก่อนเข้าเว็บ
                </p>
                <p class="text-xs text-slate-400 mt-0.5">แสดงรูปป๊อปอัป 1 ครั้งต่อการเข้าชม (session) บนหน้าเว็บสาธารณะ</p>
              </div>
              <button @click="config.welcome_popup_enabled = !config.welcome_popup_enabled"
                :class="['relative w-12 h-6 rounded-full transition-colors flex-shrink-0',
                  config.welcome_popup_enabled ? 'bg-blue-600' : 'bg-slate-300']">
                <span :class="['absolute w-5 h-5 bg-white rounded-full shadow-sm top-0.5 transition-all',
                  config.welcome_popup_enabled ? 'left-6' : 'left-0.5']"></span>
              </button>
            </div>

            <div v-if="config.welcome_popup_enabled" class="space-y-3 pl-2">
              <div v-if="config.welcome_popup_image_url" class="rounded-xl overflow-hidden border border-slate-200 bg-slate-50 max-w-xs">
                <img :src="config.welcome_popup_image_url" class="w-full h-auto block"/>
              </div>
              <div class="flex flex-wrap gap-2">
                <button @click="triggerPopupUpload" type="button" :disabled="uploadingPopup"
                  class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors disabled:opacity-50">
                  {{ uploadingPopup ? 'กำลังอัปโหลด...' : (config.welcome_popup_image_url ? '🖼️ เปลี่ยนรูป' : '🖼️ อัปโหลดรูป (รองรับ GIF)') }}
                </button>
                <button v-if="config.welcome_popup_image_url" @click="clearPopupImage" type="button"
                  class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-500 text-xs font-bold rounded-xl transition-colors">
                  🗑️ ลบรูป
                </button>
              </div>
              <p v-if="popupUploadError" class="text-xs text-red-500">{{ popupUploadError }}</p>
              <div>
                <label class="text-xs font-bold text-slate-600 mb-1.5 block">ลิงก์เมื่อคลิกที่รูป (ไม่บังคับ)</label>
                <input v-model="config.welcome_popup_link_url" type="url" placeholder="https://..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>
              <p class="text-[10px] text-slate-400">ไฟล์ไม่เกิน 5MB · แนะนำภาพแนวตั้งหรือสี่เหลี่ยมจัตุรัส ไม่ครอปอัตโนมัติเพื่อรักษาลาย GIF/ดีไซน์เดิม</p>
            </div>
          </div>
        </div>

        <!-- ── Tab: บริการออนไลน์ ─────────────────────────────── -->
        <div v-if="activeTab === 'services'" class="space-y-4">
          <div class="flex items-center justify-between">
            <p class="text-sm text-slate-500">จัดการปุ่มบริการบนหน้าแรก — เพิ่ม/ลบ/เรียง/ซ่อน + ตั้ง URL</p>
            <div class="flex gap-2">
              <button @click="addService" type="button"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
                <SvgIcon name="plus" class="w-3.5 h-3.5"/> เพิ่มบริการ
              </button>
              <button @click="saveServices" :disabled="savingServices" type="button"
                class="px-3 py-1.5 text-xs font-bold bg-primary text-white rounded-xl disabled:opacity-50 transition-colors">
                {{ savingServices ? '...' : 'บันทึก' }}
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <div v-for="(svc, i) in services" :key="svc.key"
              class="bg-white rounded-2xl border border-slate-100 shadow-sm p-3 flex flex-wrap items-start gap-3">

              <!-- up/down -->
              <div class="flex flex-col gap-0.5 flex-shrink-0 mt-1">
                <button @click="moveServiceUp(i)" :disabled="i===0" type="button"
                  class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-100 disabled:opacity-20">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
                </button>
                <button @click="moveServiceDown(i)" :disabled="i===services.length-1" type="button"
                  class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-100 disabled:opacity-20">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
                </button>
              </div>

              <!-- icon preview -->
              <div class="w-10 h-10 rounded-xl flex-shrink-0 flex items-center justify-center"
                style="background:color-mix(in srgb,var(--color-primary) 12%,transparent)">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"
                  :style="{color:'var(--color-primary)'}">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="ICON_MAP[svc.icon] || ICON_MAP.globe"/>
                </svg>
              </div>

              <!-- fields -->
              <div class="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-2 gap-2">
                <!-- label -->
                <div>
                  <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">ชื่อปุ่ม</label>
                  <input v-model="svc.label" type="text"
                    class="mt-0.5 w-full px-2 py-1.5 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-primary"/>
                </div>
                <!-- icon picker -->
                <div>
                  <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Icon</label>
                  <select v-model="svc.icon"
                    class="mt-0.5 w-full px-2 py-1.5 border border-slate-200 rounded-lg text-sm bg-white focus:outline-none focus:border-primary">
                    <option v-for="(path, key) in ICON_MAP" :key="key" :value="key">
                      {{ ICON_LABELS[key] || key }}
                    </option>
                  </select>
                </div>
                <!-- type + url -->
                <div>
                  <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">ประเภท</label>
                  <select v-model="svc.type"
                    class="mt-0.5 w-full px-2 py-1.5 border border-slate-200 rounded-lg text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="internal">ภายใน (route)</option>
                    <option value="external">ภายนอก (URL)</option>
                  </select>
                </div>
                <div>
                  <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                    {{ svc.type === 'internal' ? 'Route' : 'URL' }}
                  </label>
                  <div class="relative mt-0.5">
                    <input v-model="svc.url" type="text"
                      :placeholder="svc.type==='internal' ? '/personnel' : 'https://...'"
                      class="w-full px-2 py-1.5 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:border-primary"/>
                    <!-- route suggestions -->
                    <datalist :id="'routes-'+i">
                      <option v-for="r in SYSTEM_ROUTES" :key="r.route" :value="r.route">{{ r.label }}</option>
                    </datalist>
                    <input v-if="svc.type==='internal'" v-model="svc.url" type="text" :list="'routes-'+i"
                      :placeholder="'/personnel'"
                      class="absolute inset-0 opacity-0 w-full"/>
                  </div>
                  <!-- route quick-select -->
                  <div v-if="svc.type==='internal'" class="flex flex-wrap gap-1 mt-1">
                    <button v-for="r in SYSTEM_ROUTES" :key="r.route" type="button"
                      @click="svc.url = r.route"
                      :class="['text-[9px] px-1.5 py-0.5 rounded transition-colors',
                        svc.url===r.route ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                      {{ r.route }}
                    </button>
                  </div>
                </div>
              </div>

              <!-- visible + delete -->
              <div class="flex flex-col gap-1.5 flex-shrink-0">
                <button @click="svc.visible = !svc.visible" type="button"
                  :class="['px-2.5 py-1 text-xs font-bold rounded-lg transition-colors',
                    svc.visible ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-400']">
                  {{ svc.visible ? '👁' : '🚫' }}
                </button>
                <button @click="removeService(i)" type="button"
                  class="px-2.5 py-1 text-xs font-bold rounded-lg bg-slate-50 text-slate-300 hover:text-red-400 hover:bg-red-50 transition-colors">
                  ✕
                </button>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>

  <!-- Logo Cropper Modal -->
  <ImageCropperModal
    :show="showCropper"
    :aspect-ratio="1"
    title="ครอบโลโก้เขตพื้นที่"
    @close="showCropper = false"
    @cropped="onLogoCropped"
  />

  <input ref="popupFileInput" type="file" accept="image/*" class="hidden" @change="onPopupFileSelected"/>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
input[type="color"] { -webkit-appearance: none; appearance: none; padding: 0; }
</style>
