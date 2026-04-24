<script setup>
import { ref, computed } from 'vue'

const longUrl   = ref('')
const alias     = ref('')
const loading   = ref(false)
const result    = ref(null)
const copied    = ref(false)
const history   = ref([
  { slug: 'plan67',  target: 'https://drive.google.com/file/d/xxx/แผนนิเทศ2567',     short: 'nitet.go.th/s/plan67',  clicks: 142, date: '2025-03-01' },
  { slug: 'sarform', target: 'https://forms.gle/xxxxxxxx',                            short: 'nitet.go.th/s/sarform', clicks: 87,  date: '2025-02-15' },
  { slug: 'onet66',  target: 'https://www.niets.or.th/th/catalog/view/xxx',           short: 'nitet.go.th/s/onet66',  clicks: 55,  date: '2025-01-10' },
])

const isValidUrl = computed(() => {
  try { new URL(longUrl.value); return true } catch { return false }
})

async function shorten() {
  if (!isValidUrl.value) return
  loading.value = true
  await new Promise(r => setTimeout(r, 800)) // simulate API
  const slug = alias.value.trim() || Math.random().toString(36).slice(2, 7)
  result.value = {
    slug,
    short: `nitet.go.th/s/${slug}`,
    target: longUrl.value,
    date: new Date().toLocaleDateString('th-TH'),
  }
  loading.value = false
}

function copyShort() {
  if (!result.value) return
  navigator.clipboard.writeText(result.value.short).catch(() => {})
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

function reset() { longUrl.value = ''; alias.value = ''; result.value = null }
</script>

<template>
  <div class="font-sarabun text-slate-800 py-10">
    <div class="max-w-2xl mx-auto px-4">

      <!-- Header -->
      <div class="text-center mb-10">
        <div class="w-16 h-16 bg-indigo-100 rounded-2xl flex items-center justify-center text-3xl mx-auto mb-4">🔗</div>
        <p class="text-xs text-indigo-600 font-bold uppercase tracking-widest mb-1">URL Shortener</p>
        <h1 class="text-3xl font-extrabold text-slate-900">ย่อลิงค์</h1>
        <p class="text-slate-500 mt-2 text-sm">ย่อ URL ยาวให้สั้นและจำง่าย เหมาะสำหรับแชร์ใน LINE หรือ QR Code</p>
      </div>

      <!-- Input card -->
      <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 md:p-8 mb-6">
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">URL ต้นฉบับ <span class="text-red-500">*</span></label>
            <input v-model="longUrl" type="url"
              placeholder="https://drive.google.com/file/d/..."
              :class="['w-full px-4 py-3 rounded-xl border text-sm focus:outline-none focus:ring-2 transition-all',
                longUrl && !isValidUrl
                  ? 'border-red-300 focus:ring-red-200 bg-red-50'
                  : 'border-slate-200 focus:ring-blue-200 focus:border-blue-400 bg-white']"/>
            <p v-if="longUrl && !isValidUrl" class="text-xs text-red-500 mt-1">⚠ URL ไม่ถูกต้อง กรุณาขึ้นต้นด้วย https://</p>
          </div>

          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">
              ชื่อย่อ (Custom alias)
              <span class="text-slate-400 font-normal ml-1">— ไม่บังคับ</span>
            </label>
            <div class="flex items-center gap-0 rounded-xl border border-slate-200 focus-within:ring-2 focus-within:ring-blue-200 focus-within:border-blue-400 overflow-hidden bg-white transition-all">
              <span class="px-3 py-3 bg-slate-50 text-slate-500 text-sm border-r border-slate-200 flex-shrink-0">nitet.go.th/s/</span>
              <input v-model="alias" type="text" placeholder="plan67"
                class="flex-1 px-3 py-3 text-sm focus:outline-none bg-transparent"/>
            </div>
          </div>

          <button @click="shorten" :disabled="!isValidUrl || loading"
            :class="['w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold transition-all',
              isValidUrl && !loading
                ? 'bg-indigo-600 hover:bg-indigo-700 text-white shadow-md shadow-indigo-200 hover:-translate-y-0.5'
                : 'bg-slate-100 text-slate-400 cursor-not-allowed']">
            <svg v-if="loading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
            </svg>
            <span v-if="!loading">🔗 ย่อลิงค์</span>
            <span v-else>กำลังสร้าง...</span>
          </button>
        </div>

        <!-- Result -->
        <Transition enter-active-class="transition duration-300" enter-from-class="opacity-0 translate-y-2" enter-to-class="opacity-100 translate-y-0">
          <div v-if="result" class="mt-6 bg-indigo-50 border border-indigo-200 rounded-2xl p-5">
            <p class="text-xs font-bold text-indigo-600 uppercase tracking-wider mb-3">✅ สร้างลิงค์สำเร็จ</p>
            <div class="flex items-center gap-3 bg-white rounded-xl border border-indigo-100 px-4 py-3 mb-3">
              <span class="font-mono text-sm font-bold text-indigo-700 flex-1 truncate">{{ result.short }}</span>
              <button @click="copyShort"
                :class="['flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex-shrink-0',
                  copied ? 'bg-emerald-500 text-white' : 'bg-indigo-100 text-indigo-700 hover:bg-indigo-200']">
                {{ copied ? '✅ คัดลอกแล้ว' : '📋 คัดลอก' }}
              </button>
            </div>
            <p class="text-xs text-slate-500 truncate">→ {{ result.target }}</p>
            <button @click="reset" class="mt-4 text-xs font-bold text-indigo-600 hover:underline">+ ย่อลิงค์ใหม่</button>
          </div>
        </Transition>
      </div>

      <!-- History -->
      <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <h2 class="font-extrabold text-slate-800 mb-4 flex items-center gap-2">
          <span>📋</span> ลิงค์ล่าสุด
        </h2>
        <div class="space-y-3">
          <div v-for="h in history" :key="h.slug"
            class="flex items-center gap-3 p-3 bg-slate-50 rounded-xl hover:bg-indigo-50 transition-colors group">
            <div class="flex-1 min-w-0">
              <p class="font-bold text-sm text-indigo-700 font-mono">{{ h.short }}</p>
              <p class="text-xs text-slate-400 truncate mt-0.5">{{ h.target }}</p>
            </div>
            <div class="text-right flex-shrink-0">
              <p class="text-xs font-bold text-slate-600">{{ h.clicks }} คลิก</p>
              <p class="text-[10px] text-slate-400">{{ h.date }}</p>
            </div>
          </div>
        </div>
        <p class="text-center text-xs text-slate-400 mt-4 pt-4 border-t border-slate-100">
          * ระบบจริงต้องการ Backend API สำหรับจัดการลิงค์ย่อ
        </p>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
