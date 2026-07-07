<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHeaderPlain from '../components/PageHeaderPlain.vue'

const route = useRoute()
const { fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('qrcode', {
  icon: 'qrcode', title: 'สร้าง QR Code', subtitle: 'สร้าง QR Code จากข้อความหรือลิงค์ พร้อมปรับแต่งสี ขนาด และดาวน์โหลดได้ทันที',
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

async function buildDataUrl() {
  return QRCode.toDataURL(inputText.value, {
    width: size.value,
    margin: 2,
    errorCorrectionLevel: errorLevel.value,
    color: { dark: fgColor.value, light: bgColor.value },
  })
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

watch([fgColor, bgColor, size, errorLevel], async () => {
  if (generated.value) qrSrc.value = await buildDataUrl()
})

onMounted(() => {
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
      <div class="mb-10">
        <PageHeaderPlain align="center" eyebrow="QR Code Generator" :title="header.title" :subtitle="header.subtitle"
          :mode="header.mode" :icon="header.icon"
          :media-url="header.mediaUrl" :media-type="header.mediaType"/>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

        <!-- Left: Input panel -->
        <div class="space-y-5">

          <!-- Presets -->
          <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
            <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">เลือก Preset</p>
            <div class="grid grid-cols-2 gap-2">
              <button v-for="p in presets" :key="p.label" @click="usePreset(p.value)"
                class="flex items-center gap-2 px-3 py-2.5 bg-slate-50 hover:bg-emerald-50 border border-slate-100 hover:border-emerald-300 rounded-xl text-xs font-bold text-slate-700 hover:text-emerald-700 transition-all text-left">
                <span>{{ p.icon }}</span>{{ p.label }}
              </button>
            </div>
          </div>

          <!-- Input -->
          <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 space-y-4">
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
              <select v-model="errorLevel" class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 bg-white">
                <option v-for="e in errorLevels" :key="e.value" :value="e.value">{{ e.label }}</option>
              </select>
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
          <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 flex-1 flex flex-col items-center justify-center">
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
