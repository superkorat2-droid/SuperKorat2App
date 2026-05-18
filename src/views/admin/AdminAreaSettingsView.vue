<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig, THEME_PRESETS } from '../../composables/useAreaConfig'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import StorageBrowser    from '../../components/StorageBrowser.vue'
import Swal from 'sweetalert2'

const { updateConfig, previewTheme, resetTheme, fetchConfig } = useAreaConfig()

const config  = ref({})
const saving  = ref(false)
const saved   = ref(false)
const loading = ref(true)
const activeTab = ref('general')

const tabs = [
  { key: 'general',  icon: '🏛️', label: 'ข้อมูลเขตพื้นที่' },
  { key: 'brand',    icon: '🎨', label: 'โลโก้และสี' },
  { key: 'contact',  icon: '📞', label: 'ข้อมูลติดต่อ' },
  { key: 'social',   icon: '🌐', label: 'โซเชียลมีเดีย' },
  { key: 'storage',  icon: '📁', label: 'จัดการไฟล์' },
  { key: 'features', icon: '⚙️', label: 'ฟีเจอร์' },
]

const areaTypes = ['สพป.', 'สพม.', 'สศศ.', 'สพปกษ.']

onMounted(async () => {
  const { data, error } = await supabase.from('area_config').select('*').eq('id', 1).single()
  if (!error && data) config.value = { ...data }
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
        <h1 class="text-2xl font-extrabold text-slate-900">⚙️ ตั้งค่าเขตพื้นที่</h1>
        <p class="text-slate-500 text-sm mt-1">ปรับแต่งชื่อ โลโก้ สี และข้อมูลติดต่อ — เขตอื่นสามารถเปลี่ยนได้ที่นี่</p>
      </div>
      <button @click="save" :disabled="saving"
        :class="['flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-bold transition-all shadow-md',
          saved ? 'bg-emerald-600 text-white' : 'bg-blue-600 hover:bg-blue-700 text-white hover:-translate-y-0.5']">
        <span v-if="saving">⏳ กำลังบันทึก...</span>
        <span v-else-if="saved">✅ บันทึกแล้ว</span>
        <span v-else>💾 บันทึกการตั้งค่า</span>
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
          <span>{{ tab.icon }}</span>
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
              {{ config.tagline ? '✅ ใช้ tagline ที่กำหนดเอง' : '⚙️ ใช้ค่าอัตโนมัติ (ประเภท + จังหวัด + เลขเขต)' }}
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
                  <span v-else class="text-3xl">🏢</span>
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
                  <span v-else>🖼️</span>
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
        <div v-if="activeTab === 'features'" class="space-y-4">
          <p class="text-sm text-slate-500 mb-4">เปิด/ปิดฟีเจอร์ต่าง ๆ ของเว็บไซต์สาธารณะ</p>
          <div class="space-y-3">
            <div v-for="feat in [
              { key:'allow_teacher_register', icon:'👩‍🏫', label:'อนุญาตให้ครูสมัครสมาชิกได้เอง', desc:'ครูสามารถลงทะเบียนด้วยตัวเองและรออนุมัติจาก admin' },
              { key:'show_public_stats',      icon:'📊', label:'แสดงสถิติสาธารณะ',               desc:'แสดงตัวเลขโรงเรียน ครู นักเรียน บนหน้าเว็บหลัก' },
              { key:'show_public_news',       icon:'📰', label:'แสดงข่าวสารสาธารณะ',             desc:'ข่าวที่ publish แล้วจะแสดงบนหน้าเว็บ' },
              { key:'show_public_works',      icon:'🏆', label:'แสดงผลงานสาธารณะ',              desc:'ผลงานที่อนุมัติแล้วจะแสดงบนหน้าเว็บ' },
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
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
input[type="color"] { -webkit-appearance: none; appearance: none; padding: 0; }
</style>
