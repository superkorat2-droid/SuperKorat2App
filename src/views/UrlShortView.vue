<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import QRCode from 'qrcode'
import Swal from 'sweetalert2'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHeaderPlain from '../components/PageHeaderPlain.vue'

const router = useRouter()
const { fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('urlShort', {
  icon: 'link', title: 'ย่อลิงก์', subtitle: 'ย่อ URL ยาวให้สั้นและจำง่าย เหมาะสำหรับแชร์ใน LINE หรือ QR Code',
  align: 'center',
})

const checkingAuth = ref(true)
const user          = ref(null)

const longUrl   = ref('')
const alias     = ref('')
const title     = ref('')
const loading   = ref(false)
const result    = ref(null)
const copied    = ref(false)

const history        = ref([])
const historyLoading = ref(false)

const BASE = `${location.origin}/#/s/`

const isValidUrl = computed(() => {
  try { new URL(longUrl.value); return true } catch { return false }
})

function randomSlug() {
  return Math.random().toString(36).slice(2, 7)
}

async function fetchHistory() {
  if (!user.value) return
  historyLoading.value = true
  const { data } = await supabase
    .from('short_urls')
    .select('*')
    .eq('created_by', user.value.id)
    .order('created_at', { ascending: false })
    .limit(10)
  history.value = data || []
  historyLoading.value = false
}

async function shorten() {
  if (!isValidUrl.value || !user.value) return
  loading.value = true

  let slug = alias.value.trim().toLowerCase()
  if (slug && !/^[a-z0-9_-]+$/.test(slug)) {
    loading.value = false
    return Swal.fire({ icon: 'warning', title: 'ชื่อย่อใช้ได้แค่ a-z, 0-9, - และ _', confirmButtonColor: '#4f46e5' })
  }

  const attempts = slug ? 1 : 5
  let row = null
  let lastError = null

  for (let i = 0; i < attempts; i++) {
    const candidate = slug || randomSlug()
    const { data, error } = await supabase
      .from('short_urls')
      .insert({
        slug: candidate,
        target_url: longUrl.value,
        title: title.value.trim() || null,
        created_by: user.value.id,
      })
      .select()
      .single()

    if (!error) { row = data; break }
    lastError = error
    if (error.code !== '23505') break // ไม่ใช่ slug ชนกัน เลิก retry
    if (slug) break // custom alias ชนกัน ไม่ต้อง retry ด้วยชื่ออื่น
  }

  loading.value = false

  if (!row) {
    return Swal.fire({
      icon: 'error',
      title: lastError?.code === '23505' ? 'ชื่อย่อนี้ถูกใช้ไปแล้ว' : 'สร้างลิงก์ไม่สำเร็จ',
      text: lastError?.code === '23505' ? 'กรุณาเลือกชื่อย่ออื่น' : 'ลองใหม่อีกครั้ง',
      confirmButtonColor: '#4f46e5',
    })
  }

  result.value = {
    slug: row.slug,
    short: BASE + row.slug,
    target: row.target_url,
    title: row.title,
  }
  history.value.unshift(row)
}

function copyShort() {
  if (!result.value) return
  navigator.clipboard.writeText(result.value.short).catch(() => {})
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

function reset() { longUrl.value = ''; alias.value = ''; title.value = ''; result.value = null }

function goToQr(shortLink) {
  router.push({ path: '/qrcode', query: { text: shortLink } })
}

const qrThumbs = ref({})
async function thumbFor(h) {
  if (qrThumbs.value[h.id]) return qrThumbs.value[h.id]
  const src = await QRCode.toDataURL(BASE + h.slug, { width: 160, margin: 1 })
  qrThumbs.value[h.id] = src
  return src
}

async function downloadHistoryQr(h) {
  const src = await thumbFor(h)
  const a = document.createElement('a')
  a.href = src
  a.download = `qrcode-${h.slug}.png`
  a.click()
}

onMounted(async () => {
  const { data: { session } } = await supabase.auth.getSession()
  user.value = session?.user || null
  checkingAuth.value = false
  if (user.value) await fetchHistory()
  for (const h of history.value) thumbFor(h)
})
</script>

<template>
  <div class="font-sarabun text-slate-800 py-10">
    <div class="max-w-2xl mx-auto px-4">

      <!-- Header -->
      <div v-if="!header.hidden" class="mb-10">
        <PageHeaderPlain :align="header.align" eyebrow="URL Shortener" :title="header.title" :subtitle="header.subtitle"
          :mode="header.mode" :icon="header.icon"
          :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"/>
      </div>

      <!-- ยังตรวจสอบสถานะ login -->
      <div v-if="checkingAuth" class="text-center text-slate-400 text-sm py-10">กำลังตรวจสอบสิทธิ์...</div>

      <!-- ยังไม่ login -->
      <div v-else-if="!user" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-8 text-center">
        <div class="text-4xl mb-3">🔒</div>
        <p class="font-bold text-slate-700 mb-1">ต้องเข้าสู่ระบบก่อนใช้งาน</p>
        <p class="text-sm text-slate-400 mb-5">เครื่องมือย่อลิงก์เปิดให้สำหรับครูและศึกษานิเทศก์ที่เป็นสมาชิกของระบบ</p>
        <router-link to="/login"
          class="inline-flex items-center gap-2 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-bold rounded-xl shadow-md transition-all">
          เข้าสู่ระบบ / สมัครสมาชิก
        </router-link>
      </div>

      <template v-else>
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
              ชื่อเรื่อง
              <span class="text-slate-400 font-normal ml-1">— ไม่บังคับ ใช้ช่วยให้จำว่าลิงก์นี้คืออะไร</span>
            </label>
            <input v-model="title" type="text" placeholder="เช่น แผนนิเทศ 2567"
              class="w-full px-4 py-3 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 bg-white transition-all"/>
          </div>

          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">
              ชื่อย่อ (Custom alias)
              <span class="text-slate-400 font-normal ml-1">— ไม่บังคับ</span>
            </label>
            <div class="flex items-center gap-0 rounded-xl border border-slate-200 focus-within:ring-2 focus-within:ring-blue-200 focus-within:border-blue-400 overflow-hidden bg-white transition-all">
              <span class="px-3 py-3 bg-slate-50 text-slate-500 text-sm border-r border-slate-200 flex-shrink-0 truncate max-w-[40%]">{{ BASE }}</span>
              <input v-model="alias" type="text" placeholder="plan67"
                class="flex-1 px-3 py-3 text-sm focus:outline-none bg-transparent min-w-0"/>
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
            <span v-if="!loading">🔗 ย่อลิงก์</span>
            <span v-else>กำลังสร้าง...</span>
          </button>
        </div>

        <!-- Result -->
        <Transition enter-active-class="transition duration-300" enter-from-class="opacity-0 translate-y-2" enter-to-class="opacity-100 translate-y-0">
          <div v-if="result" class="mt-6 bg-indigo-50 border border-indigo-200 rounded-2xl p-5">
            <p class="text-xs font-bold text-indigo-600 uppercase tracking-wider mb-3">✅ สร้างลิงก์สำเร็จ</p>
            <div class="flex items-center gap-3 bg-white rounded-xl border border-indigo-100 px-4 py-3 mb-3">
              <span class="font-mono text-sm font-bold text-indigo-700 flex-1 truncate">{{ result.short }}</span>
              <button @click="copyShort"
                :class="['flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex-shrink-0',
                  copied ? 'bg-emerald-500 text-white' : 'bg-indigo-100 text-indigo-700 hover:bg-indigo-200']">
                {{ copied ? '✅ คัดลอกแล้ว' : '📋 คัดลอก' }}
              </button>
            </div>
            <p v-if="result.title" class="text-xs font-bold text-slate-600 mb-1">{{ result.title }}</p>
            <p class="text-xs text-slate-500 truncate">→ {{ result.target }}</p>
            <div class="flex items-center gap-4 mt-4">
              <button @click="goToQr(result.short)" class="text-xs font-bold text-emerald-600 hover:underline">📱 สร้าง QR Code</button>
              <button @click="reset" class="text-xs font-bold text-indigo-600 hover:underline">+ ย่อลิงก์ใหม่</button>
            </div>
          </div>
        </Transition>
      </div>

      <!-- History -->
      <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <h2 class="font-extrabold text-slate-800 mb-4 flex items-center gap-2">
          <span>📋</span> ลิงก์ของฉัน
        </h2>
        <div v-if="historyLoading" class="space-y-2">
          <div v-for="i in 3" :key="i" class="h-16 bg-slate-100 rounded-xl animate-pulse"></div>
        </div>
        <p v-else-if="history.length === 0" class="text-center text-sm text-slate-400 py-6">ยังไม่มีลิงก์ที่สร้างไว้</p>
        <div v-else class="space-y-3">
          <div v-for="h in history" :key="h.id"
            class="flex items-center gap-3 p-3 bg-slate-50 rounded-xl hover:bg-indigo-50 transition-colors group">
            <img v-if="qrThumbs[h.id]" :src="qrThumbs[h.id]" class="w-12 h-12 rounded-lg border border-slate-200 flex-shrink-0"/>
            <div class="flex-1 min-w-0">
              <p v-if="h.title" class="font-bold text-xs text-slate-600 truncate">{{ h.title }}</p>
              <p class="font-bold text-sm text-indigo-700 font-mono truncate">{{ BASE }}{{ h.slug }}</p>
              <p class="text-xs text-slate-400 truncate mt-0.5">{{ h.target_url }}</p>
            </div>
            <div class="text-right flex-shrink-0 flex items-center gap-2">
              <div>
                <p class="text-xs font-bold text-slate-600">{{ h.click_count }} คลิก</p>
                <p class="text-[10px] text-slate-400">{{ new Date(h.created_at).toLocaleDateString('th-TH') }}</p>
              </div>
              <button @click="downloadHistoryQr(h)" title="ดาวน์โหลด QR"
                class="px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs hover:bg-emerald-50 hover:border-emerald-300 transition-all">
                📥
              </button>
            </div>
          </div>
        </div>
      </div>
      </template>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
