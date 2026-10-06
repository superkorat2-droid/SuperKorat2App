<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHeaderPlain from '../components/PageHeaderPlain.vue'

const route = useRoute()
const { fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('qrcode', {
  icon: 'qrcode', title: 'สร้าง QR Code', subtitle: 'สร้าง QR Code จากข้อความหรือลิงก์ พร้อมปรับแต่งสี ขนาด และดาวน์โหลดได้ทันที',
  align: 'center',
})

const inputText  = ref('')
const fgColor    = ref('#1e3a8a')
const bgColor    = ref('#ffffff')
const size       = ref(300)
const errorLevel = ref('M')
const generated  = ref(false)
const qrSrc      = ref('')

const errorLevels = [
  { value: 'L', label: 'L — ต่ำ (7%)'  },
  { value: 'M', label: 'M — ปานกลาง (15%)' },
  { value: 'Q', label: 'Q — สูง (25%)'  },
  { value: 'H', label: 'H — สูงสุด (30%)' },
]

const presets = [
  { label: 'LINE Official', value: 'https://line.me/R/ti/p/@nithet', icon: '💬' },
  { label: 'Facebook Page', value: 'https://facebook.com/nithetgroup', icon: '👍' },
  { label: 'เว็บไซต์กลุ่ม', value: 'https://nithet.go.th', icon: '🌐' },
  { label: 'Google Form', value: 'https://forms.gle/example', icon: '📋' },
]

// โลโก้กลาง QR — อยู่ในหน่วยความจำของหน้านี้เท่านั้น ไม่อัปโหลด/ไม่เก็บ
const LOGO_MAX_EDGE = 256
const logoBitmap  = ref(null)   // ภาพโลโก้ที่ย่อแล้ว (canvas, คงความโปร่งใส)
const logoName    = ref('')
const logoScale   = ref(20)     // % ของด้าน QR (10–25)
const logoBg      = ref(true)   // พื้นรองหลังโลโก้
const logoError   = ref('')
const effectiveLevel = computed(() => (logoBitmap.value ? 'H' : errorLevel.value))

async function onLogoPick(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  logoError.value = ''
  try {
    const bmp = await createImageBitmap(file, { imageOrientation: 'from-image' })
    const k = Math.min(1, LOGO_MAX_EDGE / Math.max(bmp.width, bmp.height))
    const c = document.createElement('canvas')
    c.width = Math.max(1, Math.round(bmp.width * k))
    c.height = Math.max(1, Math.round(bmp.height * k))
    c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height)
    bmp.close?.()
    logoBitmap.value = c
    logoName.value = file.name
  } catch {
    logoError.value = 'อ่านไฟล์ภาพนี้ไม่ได้ (ไฟล์ HEIC ไม่รองรับ ให้ใช้ PNG/JPG/WebP)'
  }
}

function clearLogo() { logoBitmap.value = null; logoName.value = ''; logoError.value = '' }

// ── คลังโลโก้ที่บันทึกไว้ (เฉพาะผู้ล็อกอิน) ──────────────────────────
const me          = ref(null)   // { role, school_id }
const savedLogos  = ref([])
const saveScope   = ref('school')
const saveName    = ref('')
const saveMsg     = ref('')
const savingLogo  = ref(false)
const isAdmin     = computed(() => ['super_admin', 'admin'].includes(me.value?.role))
const canSaveSchool = computed(() => !!me.value?.school_id)
const canSave     = computed(() => canSaveSchool.value || isAdmin.value)

async function loadLibrary() {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) { me.value = null; savedLogos.value = []; return }
  const { data: prof } = await supabase.from('profiles').select('role, school_id').eq('id', session.user.id).maybeSingle()
  me.value = prof || null
  if (!me.value) return
  saveScope.value = me.value.school_id ? 'school' : 'area'
  const { data } = await supabase.from('qr_logos')
    .select('id, scope, school_id, name, image_data, is_default, schools(name)')
    .order('scope').order('created_at', { ascending: false })
  savedLogos.value = data || []
}

function scopeLabel(l) {
  return l.scope === 'area' ? 'เขต' : (l.schools?.name || 'โรงเรียน')
}

function useSavedLogo(l) {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => {
      const c = document.createElement('canvas')
      c.width = img.naturalWidth; c.height = img.naturalHeight
      c.getContext('2d').drawImage(img, 0, 0)
      logoBitmap.value = c
      logoName.value = l.name
      logoError.value = ''
      resolve()
    }
    img.onerror = () => { logoError.value = 'โหลดโลโก้ที่บันทึกไว้ไม่ได้'; resolve() }
    img.src = l.image_data
  })
}

async function saveCurrentLogo() {
  if (!logoBitmap.value || !saveName.value.trim()) return
  savingLogo.value = true
  saveMsg.value = ''
  const scope = saveScope.value
  const { error } = await supabase.from('qr_logos').insert({
    scope,
    school_id: scope === 'school' ? me.value.school_id : null,
    name: saveName.value.trim(),
    image_data: logoBitmap.value.toDataURL('image/png'),
  })
  savingLogo.value = false
  if (error) { saveMsg.value = 'บันทึกไม่สำเร็จ: ' + error.message; return }
  saveName.value = ''
  saveMsg.value = 'บันทึกโลโก้แล้ว'
  await loadLibrary()
}

async function setDefault(l) {
  // ล้างตัวเดิมของ scope เดียวกันก่อน (unique index ให้มีได้อันเดียว)
  let q = supabase.from('qr_logos').update({ is_default: false }).eq('scope', l.scope).eq('is_default', true)
  q = l.scope === 'school' ? q.eq('school_id', l.school_id) : q
  await q
  if (!l.is_default) await supabase.from('qr_logos').update({ is_default: true }).eq('id', l.id)
  await loadLibrary()
}

async function removeSaved(l) {
  if (!confirm(`ลบโลโก้ "${l.name}" ออกจากคลัง?`)) return
  await supabase.from('qr_logos').delete().eq('id', l.id)
  await loadLibrary()
}

function canManage(l) {
  return isAdmin.value || (l.scope === 'school' && l.school_id === me.value?.school_id)
}

async function buildDataUrl() {
  const opts = {
    width: size.value,
    margin: 2,
    errorCorrectionLevel: effectiveLevel.value,
    color: { dark: fgColor.value, light: bgColor.value },
  }
  if (!logoBitmap.value) return QRCode.toDataURL(inputText.value, opts)

  const canvas = document.createElement('canvas')
  await QRCode.toCanvas(canvas, inputText.value, opts)
  const ctx = canvas.getContext('2d')
  const W = canvas.width
  const box = W * Math.min(25, Math.max(10, logoScale.value)) / 100
  const lw = logoBitmap.value.width, lh = logoBitmap.value.height
  const k = box / Math.max(lw, lh)
  const w = lw * k, h = lh * k
  const x = (W - w) / 2, y = (W - h) / 2
  if (logoBg.value) {
    const pad = W * 0.015
    const r = Math.min(W * 0.03, 16)
    ctx.fillStyle = bgColor.value
    ctx.beginPath()
    ctx.roundRect(x - pad, y - pad, w + pad * 2, h + pad * 2, r)
    ctx.fill()
  }
  ctx.drawImage(logoBitmap.value, x, y, w, h)
  return canvas.toDataURL('image/png')
}

async function generate() {
  if (!inputText.value.trim()) return
  qrSrc.value = await buildDataUrl()
  generated.value = true
}

function usePreset(v) { inputText.value = v }

function downloadQR() {
  const a = document.createElement('a')
  a.href = qrSrc.value
  a.download = `qrcode-${Date.now()}.png`
  a.click()
}

watch([fgColor, bgColor, size, errorLevel, logoBitmap, logoScale, logoBg],async () => {
  if (generated.value) qrSrc.value = await buildDataUrl()
})

onMounted(async () => {
  await loadLibrary()
  // โลโก้เริ่มต้น: ของโรงเรียนตัวเองก่อน ไม่มีค่อยใช้ของเขต
  const def = savedLogos.value.find(l => l.is_default && l.scope === 'school' && l.school_id === me.value?.school_id)
    || savedLogos.value.find(l => l.is_default && l.scope === 'area')
  if (def) await useSavedLogo(def)
  if (route.query.text) {
    inputText.value = String(route.query.text)
    generate()
  }
})
</script>

<template>
  <div class="font-sarabun text-slate-800 py-10">
    <div class="max-w-3xl mx-auto px-4">

      <!-- Header -->
      <div v-if="!header.hidden" class="mb-10">
        <PageHeaderPlain :align="header.align" eyebrow="QR Code Generator" :title="header.title" :subtitle="header.subtitle"
          :mode="header.mode" :icon="header.icon"
          :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"/>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

        <!-- Left: Input panel -->
        <div class="space-y-5">

          <!-- Presets -->
          <div class="glass-card p-5">
            <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">เลือก Preset</p>
            <div class="grid grid-cols-2 gap-2">
              <button v-for="p in presets" :key="p.label" @click="usePreset(p.value)"
                class="flex items-center gap-2 px-3 py-2.5 bg-slate-50 hover:bg-emerald-50 border border-slate-100 hover:border-emerald-300 rounded-xl text-xs font-bold text-slate-700 hover:text-emerald-700 transition-all text-left">
                <span>{{ p.icon }}</span>{{ p.label }}
              </button>
            </div>
          </div>

          <!-- Input -->
          <div class="glass-card p-5 space-y-4">
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">ข้อความหรือ URL <span class="text-red-500">*</span></label>
              <textarea v-model="inputText" rows="3"
                placeholder="https://... หรือพิมพ์ข้อความ"
                class="w-full px-4 py-3 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400 resize-none"></textarea>
            </div>

            <!-- Color pickers -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1.5">สีหลัก</label>
                <div class="flex items-center gap-2 border border-slate-200 rounded-xl p-2 bg-slate-50">
                  <input v-model="fgColor" type="color" class="w-8 h-8 rounded-lg cursor-pointer border-0 bg-transparent"/>
                  <span class="text-xs font-mono text-slate-600">{{ fgColor }}</span>
                </div>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1.5">สีพื้นหลัง</label>
                <div class="flex items-center gap-2 border border-slate-200 rounded-xl p-2 bg-slate-50">
                  <input v-model="bgColor" type="color" class="w-8 h-8 rounded-lg cursor-pointer border-0 bg-transparent"/>
                  <span class="text-xs font-mono text-slate-600">{{ bgColor }}</span>
                </div>
              </div>
            </div>

            <!-- Size -->
            <div>
              <label class="block text-xs font-bold text-slate-600 mb-1.5">ขนาด: <span class="text-emerald-600">{{ size }}×{{ size }} px</span></label>
              <input v-model.number="size" type="range" min="100" max="600" step="50" class="w-full accent-emerald-600"/>
              <div class="flex justify-between text-[10px] text-slate-400 mt-0.5">
                <span>100px</span><span>600px</span>
              </div>
            </div>

            <!-- Error correction -->
            <div>
              <label class="block text-xs font-bold text-slate-600 mb-1.5">ระดับแก้ไขข้อผิดพลาด</label>
              <select v-model="errorLevel" :disabled="!!logoBitmap" class="w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 disabled:opacity-60">
                <option v-for="e in errorLevels" :key="e.value" :value="e.value">{{ e.label }}</option>
              </select>
              <p v-if="logoBitmap" class="text-[11px] text-emerald-600 mt-1">ใส่โลโก้อยู่ — ระบบใช้ระดับ H ให้อัตโนมัติเพื่อให้สแกนติด</p>
            </div>

            <!-- Logo -->
            <div>
              <label class="block text-xs font-bold text-slate-600 mb-1.5">โลโก้กลาง QR (ไม่บังคับ)</label>
              <div class="flex items-center gap-2">
                <label class="cursor-pointer px-3 py-2 bg-slate-50 hover:bg-emerald-50 border border-slate-200 hover:border-emerald-300 rounded-xl text-xs font-bold text-slate-700 transition-all">
                  📷 เลือกรูปโลโก้
                  <input type="file" accept="image/*" class="hidden" @change="onLogoPick"/>
                </label>
                <button v-if="logoBitmap" type="button" @click="clearLogo"
                  class="text-xs font-bold text-red-500 hover:text-red-600 px-2 py-2">ลบโลโก้</button>
                <span v-if="logoBitmap" class="text-[11px] text-slate-400 truncate">{{ logoName }}</span>
              </div>
              <p v-if="logoError" class="text-[11px] text-red-500 mt-1">{{ logoError }}</p>
              <template v-if="logoBitmap">
                <label class="block text-xs font-bold text-slate-600 mt-3 mb-1">ขนาดโลโก้: <span class="text-emerald-600">{{ logoScale }}%</span></label>
                <input v-model.number="logoScale" type="range" min="10" max="25" step="1" class="w-full accent-emerald-600"/>
                <label class="flex items-center gap-2 mt-2 text-xs text-slate-600 cursor-pointer">
                  <input v-model="logoBg" type="checkbox" class="accent-emerald-600"/> มีพื้นรองหลังโลโก้
                </label>
              </template>
              <p class="text-[11px] text-slate-400 mt-1">
                {{ me ? 'ย่อภาพอัตโนมัติ · จะเก็บไว้ก็ต่อเมื่อกด "บันทึกเข้าคลัง" เท่านั้น' : 'ย่อภาพอัตโนมัติ · ไม่อัปโหลดและไม่เก็บไฟล์ไว้ที่ใด (ล็อกอินเพื่อบันทึกโลโก้โรงเรียน/เขตไว้ใช้ซ้ำ)' }}
              </p>

              <!-- คลังโลโก้ (ผู้ล็อกอิน) -->
              <div v-if="me" class="mt-3 border border-slate-200 rounded-xl p-3 bg-slate-50/60 space-y-3">
                <p class="text-xs font-bold text-slate-600">🗂️ คลังโลโก้ของโรงเรียน/เขต</p>
                <p v-if="!savedLogos.length" class="text-[11px] text-slate-400">ยังไม่มีโลโก้ที่บันทึกไว้</p>
                <ul v-else class="space-y-1.5">
                  <li v-for="l in savedLogos" :key="l.id" class="flex items-center gap-2">
                    <button type="button" @click="useSavedLogo(l)" class="flex items-center gap-2 flex-1 min-w-0 text-left hover:bg-emerald-50 rounded-lg p-1 transition-all">
                      <img :src="l.image_data" class="w-9 h-9 object-contain bg-white rounded border border-slate-200 shrink-0" alt=""/>
                      <span class="min-w-0">
                        <span class="block text-xs font-bold text-slate-700 truncate">{{ l.name }}</span>
                        <span class="block text-[10px] text-slate-400 truncate">{{ scopeLabel(l) }}<template v-if="l.is_default"> · ⭐ ค่าเริ่มต้น</template></span>
                      </span>
                    </button>
                    <template v-if="canManage(l)">
                      <button type="button" @click="setDefault(l)" :title="l.is_default ? 'ยกเลิกค่าเริ่มต้น' : 'ตั้งเป็นค่าเริ่มต้น'" class="text-sm px-1">{{ l.is_default ? '⭐' : '☆' }}</button>
                      <button type="button" @click="removeSaved(l)" title="ลบ" class="text-xs text-red-500 hover:text-red-600 px-1">ลบ</button>
                    </template>
                  </li>
                </ul>

                <div v-if="logoBitmap && canSave" class="pt-2 border-t border-slate-200 space-y-2">
                  <p class="text-[11px] font-bold text-slate-500">บันทึกโลโก้ที่ใช้อยู่เข้าคลัง</p>
                  <input v-model="saveName" type="text" maxlength="100" placeholder="ชื่อโลโก้ เช่น ตราโรงเรียน"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-200"/>
                  <div class="flex gap-2">
                    <select v-model="saveScope" class="flex-1 px-2 py-2 border border-slate-200 bg-white rounded-xl text-xs">
                      <option v-if="canSaveSchool" value="school">ของโรงเรียนฉัน</option>
                      <option v-if="isAdmin" value="area">ของเขต (ทุกคนที่ล็อกอินใช้ได้)</option>
                    </select>
                    <button type="button" @click="saveCurrentLogo" :disabled="!saveName.trim() || savingLogo"
                      class="px-3 py-2 rounded-xl text-xs font-bold bg-emerald-600 text-white disabled:bg-slate-200 disabled:text-slate-400">
                      {{ savingLogo ? 'กำลังบันทึก…' : 'บันทึกเข้าคลัง' }}
                    </button>
                  </div>
                  <p v-if="saveMsg" class="text-[11px] text-emerald-600">{{ saveMsg }}</p>
                </div>
                <p v-else-if="logoBitmap && !canSave" class="text-[11px] text-slate-400">บัญชีนี้ยังไม่ผูกกับโรงเรียน จึงบันทึกเข้าคลังไม่ได้</p>
              </div>
            </div>

            <button @click="generate" :disabled="!inputText.trim()"
              :class="['w-full py-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center gap-2',
                inputText.trim()
                  ? 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-md shadow-emerald-200 hover:-translate-y-0.5'
                  : 'bg-slate-100 text-slate-400 cursor-not-allowed']">
              📱 สร้าง QR Code
            </button>
          </div>
        </div>

        <!-- Right: Preview panel -->
        <div class="flex flex-col gap-5">
          <div class="glass-card p-6 flex-1 flex flex-col items-center justify-center">
            <template v-if="generated && inputText.trim()">
              <img :src="qrSrc" :alt="inputText" class="rounded-xl shadow-md max-w-full" :style="`width:${Math.min(size, 280)}px`"/>
              <p class="text-xs text-slate-400 mt-4 text-center truncate max-w-full px-4">{{ inputText }}</p>
              <div class="flex gap-3 mt-5">
                <button @click="downloadQR"
                  class="flex items-center gap-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-bold px-5 py-2.5 rounded-xl shadow-md hover:-translate-y-0.5 transition-all">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                  </svg>
                  ดาวน์โหลด PNG
                </button>
                <button @click="generated = false; inputText = ''"
                  class="text-sm font-bold text-slate-500 hover:text-slate-700 px-4 py-2.5 rounded-xl border border-slate-200 hover:bg-slate-50 transition-all">
                  ล้าง
                </button>
              </div>
            </template>
            <template v-else>
              <div class="text-center py-10">
                <div class="w-32 h-32 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <svg class="w-12 h-12 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/>
                  </svg>
                </div>
                <p class="text-sm font-bold text-slate-400">QR Code จะแสดงที่นี่</p>
                <p class="text-xs text-slate-300 mt-1">กรอกข้อความแล้วกด "สร้าง QR Code"</p>
              </div>
            </template>
          </div>

          <!-- Tips -->
          <div class="bg-emerald-50 rounded-2xl border border-emerald-100 p-4">
            <p class="text-xs font-bold text-emerald-700 mb-2">💡 เคล็ดลับ</p>
            <ul class="text-xs text-emerald-700 space-y-1 leading-relaxed">
              <li>• ใช้ Error Level H สำหรับ QR Code ที่อาจเปรอะหรือพิมพ์บนวัสดุ</li>
              <li>• ขนาด 300px ขึ้นไปสแกนได้ง่ายกว่าขนาดเล็ก</li>
              <li>• สีหลักควรเข้มกว่าสีพื้นหลังเสมอ</li>
              <li>• โลโก้ไม่ควรใหญ่เกิน 25% และควรทดลองสแกนด้วยมือถือก่อนพิมพ์จริง</li>
            </ul>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
input[type="color"] { -webkit-appearance: none; appearance: none; padding: 0; }
</style>
