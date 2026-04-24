<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import StorageBrowser from '../../components/StorageBrowser.vue'

// ── Bucket definitions ───────────────────────────────────────────
const BUCKETS = [
  { id: 'logos',     label: 'โลโก้และตรา',      icon: '🏷️', accept: 'image/*',                                          color: 'blue',   limit: 5   },
  { id: 'banners',   label: 'ภาพแบนเนอร์',      icon: '🖼️', accept: 'image/*,video/*',                                  color: 'purple', limit: 50  },
  { id: 'images',    label: 'ภาพประกอบข่าว',    icon: '📸', accept: 'image/*',                                          color: 'emerald',limit: 100 },
  { id: 'documents', label: 'เอกสารและไฟล์',    icon: '📁', accept: '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip',       color: 'amber',  limit: 200 },
]

// Supabase free plan = 1 GB = 1024 MB
const TOTAL_LIMIT_MB = 1024

// ── State ────────────────────────────────────────────────────────
const activeBucket  = ref('logos')
const bucketStats   = ref({})   // { bucketId: { count, sizeBytes } }
const loadingStats  = ref(true)

// ── Load stats ───────────────────────────────────────────────────
async function loadAllStats() {
  loadingStats.value = true
  const results = {}
  await Promise.all(
    BUCKETS.map(async (b) => {
      try {
        // list ทุกไฟล์ (limit สูง ๆ เพื่อรวม size)
        const { data } = await supabase.storage.from(b.id).list('', {
          limit: 1000, offset: 0,
          sortBy: { column: 'created_at', order: 'desc' }
        })
        const files = (data || []).filter(f => f.name !== '.emptyFolderPlaceholder')
        const sizeBytes = files.reduce((s, f) => s + (f.metadata?.size || 0), 0)
        results[b.id] = { count: files.length, sizeBytes }
      } catch {
        results[b.id] = { count: 0, sizeBytes: 0 }
      }
    })
  )
  bucketStats.value = results
  loadingStats.value = false
}

onMounted(loadAllStats)

// ── Computed ──────────────────────────────────────────────────────
const totalUsedBytes = computed(() =>
  Object.values(bucketStats.value).reduce((s, b) => s + b.sizeBytes, 0)
)
const totalUsedMB    = computed(() => totalUsedBytes.value / 1048576)
const totalUsedPct   = computed(() => Math.min((totalUsedMB.value / TOTAL_LIMIT_MB) * 100, 100))
const totalFiles     = computed(() => Object.values(bucketStats.value).reduce((s, b) => s + b.count, 0))

function bucketUsedMB(id)  { return (bucketStats.value[id]?.sizeBytes || 0) / 1048576 }
function bucketCount(id)   { return bucketStats.value[id]?.count || 0 }
function bucketPct(b)      { return Math.min((bucketUsedMB(b.id) / b.limit) * 100, 100) }

// ── Color helpers ─────────────────────────────────────────────────
const COLOR = {
  blue:    { bg: 'bg-blue-500',    light: 'bg-blue-50',    border: 'border-blue-200',    text: 'text-blue-700',    ring: 'ring-blue-400',    track: 'bg-blue-100'    },
  purple:  { bg: 'bg-purple-500',  light: 'bg-purple-50',  border: 'border-purple-200',  text: 'text-purple-700',  ring: 'ring-purple-400',  track: 'bg-purple-100'  },
  emerald: { bg: 'bg-emerald-500', light: 'bg-emerald-50', border: 'border-emerald-200', text: 'text-emerald-700', ring: 'ring-emerald-400', track: 'bg-emerald-100' },
  amber:   { bg: 'bg-amber-500',   light: 'bg-amber-50',   border: 'border-amber-200',   text: 'text-amber-700',   ring: 'ring-amber-400',   track: 'bg-amber-100'   },
}

function statusColor(pct) {
  if (pct >= 90) return 'bg-red-500'
  if (pct >= 70) return 'bg-amber-500'
  return null  // ใช้สีของ bucket
}

// ── Format ────────────────────────────────────────────────────────
function fmt(mb) {
  if (mb < 0.001) return '0 KB'
  if (mb < 1)     return (mb * 1024).toFixed(1) + ' KB'
  if (mb < 1024)  return mb.toFixed(2) + ' MB'
  return (mb / 1024).toFixed(2) + ' GB'
}

const current = () => BUCKETS.find(b => b.id === activeBucket.value)
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- ── Header ──────────────────────────────────────────────── -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">🗄️ พื้นที่จัดเก็บไฟล์</h1>
        <p class="text-sm text-slate-500 mt-0.5">ภาพรวมการใช้งาน Supabase Storage</p>
      </div>
      <button @click="loadAllStats" :disabled="loadingStats"
        class="flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-50 transition-colors disabled:opacity-50">
        <svg v-if="loadingStats" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
        </svg>
        <span v-else>🔄</span>
        รีเฟรช
      </button>
    </div>

    <!-- ── Overall usage card ───────────────────────────────────── -->
    <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
      <div class="flex flex-wrap items-start justify-between gap-4 mb-5">
        <div>
          <p class="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">พื้นที่ใช้งานรวม (Free Plan)</p>
          <div class="flex items-end gap-2">
            <span class="text-4xl font-extrabold text-slate-800">
              <template v-if="loadingStats"><span class="animate-pulse text-slate-300">—</span></template>
              <template v-else>{{ fmt(totalUsedMB) }}</template>
            </span>
            <span class="text-slate-400 text-sm mb-1">/ {{ fmt(TOTAL_LIMIT_MB) }}</span>
          </div>
          <p class="text-xs text-slate-400 mt-1">{{ totalFiles.toLocaleString() }} ไฟล์ทั้งหมด</p>
        </div>

        <!-- Donut-style percentage -->
        <div class="relative w-24 h-24 flex-shrink-0">
          <svg class="w-24 h-24 -rotate-90" viewBox="0 0 36 36">
            <!-- Track -->
            <circle cx="18" cy="18" r="15.9" fill="none" stroke="#e2e8f0" stroke-width="3.5"/>
            <!-- Progress -->
            <circle cx="18" cy="18" r="15.9" fill="none"
              :stroke="totalUsedPct >= 90 ? '#ef4444' : totalUsedPct >= 70 ? '#f59e0b' : '#3b82f6'"
              stroke-width="3.5"
              stroke-linecap="round"
              :stroke-dasharray="`${loadingStats ? 0 : totalUsedPct} 100`"
              class="transition-all duration-1000"/>
          </svg>
          <div class="absolute inset-0 flex flex-col items-center justify-center">
            <span class="text-lg font-extrabold text-slate-800 leading-none">
              {{ loadingStats ? '…' : totalUsedPct.toFixed(1) + '%' }}
            </span>
            <span class="text-[9px] text-slate-400 font-bold mt-0.5">ใช้แล้ว</span>
          </div>
        </div>
      </div>

      <!-- Overall progress bar -->
      <div class="space-y-1.5">
        <div class="flex justify-between text-xs text-slate-500 font-bold">
          <span>0</span>
          <span>{{ fmt(TOTAL_LIMIT_MB / 2) }}</span>
          <span>{{ fmt(TOTAL_LIMIT_MB) }}</span>
        </div>
        <div class="w-full h-4 bg-slate-100 rounded-full overflow-hidden">
          <div
            class="h-full rounded-full transition-all duration-1000 relative"
            :class="totalUsedPct >= 90 ? 'bg-red-500' : totalUsedPct >= 70 ? 'bg-amber-500' : 'bg-blue-500'"
            :style="{ width: (loadingStats ? 0 : totalUsedPct) + '%' }">
            <!-- Shimmer -->
            <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent animate-shimmer"></div>
          </div>
        </div>
        <div class="flex justify-between text-xs font-bold"
          :class="totalUsedPct >= 90 ? 'text-red-600' : totalUsedPct >= 70 ? 'text-amber-600' : 'text-blue-600'">
          <span>{{ loadingStats ? '—' : fmt(totalUsedMB) }} ใช้แล้ว</span>
          <span>{{ loadingStats ? '—' : fmt(TOTAL_LIMIT_MB - totalUsedMB) }} ว่าง</span>
        </div>
      </div>

      <!-- Warning -->
      <div v-if="!loadingStats && totalUsedPct >= 80"
        :class="['mt-4 flex items-center gap-2 px-4 py-3 rounded-2xl text-sm font-bold',
          totalUsedPct >= 90 ? 'bg-red-50 text-red-700 border border-red-200' : 'bg-amber-50 text-amber-700 border border-amber-200']">
        <span class="text-xl">{{ totalUsedPct >= 90 ? '🚨' : '⚠️' }}</span>
        {{ totalUsedPct >= 90 ? 'พื้นที่เกือบเต็ม! ควรลบไฟล์ที่ไม่ใช้ หรืออัปเกรดแผน' : 'พื้นที่เหลือน้อย — ควรจัดการไฟล์เก่า' }}
      </div>
    </div>

    <!-- ── Per-bucket stat cards ─────────────────────────────────── -->
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      <button v-for="b in BUCKETS" :key="b.id"
        @click="activeBucket = b.id"
        :class="[
          'text-left p-5 rounded-2xl border-2 transition-all hover:shadow-md',
          activeBucket === b.id
            ? COLOR[b.color].light + ' ' + COLOR[b.color].border + ' shadow-md ring-2 ' + COLOR[b.color].ring
            : 'bg-white border-slate-100 hover:border-slate-200'
        ]">

        <!-- Icon + label -->
        <div class="flex items-center gap-3 mb-4">
          <div :class="['w-10 h-10 rounded-xl flex items-center justify-center text-xl',
            activeBucket === b.id ? COLOR[b.color].light : 'bg-slate-100']">
            {{ b.icon }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-extrabold text-sm text-slate-800 truncate">{{ b.label }}</p>
            <p class="text-[10px] text-slate-400 font-mono">{{ b.id }}/</p>
          </div>
        </div>

        <!-- Stats row -->
        <div class="flex justify-between items-center mb-2">
          <div>
            <p :class="['text-xl font-extrabold', COLOR[b.color].text]">
              <template v-if="loadingStats"><span class="animate-pulse text-slate-300 text-base">กำลังโหลด...</span></template>
              <template v-else>{{ fmt(bucketUsedMB(b.id)) }}</template>
            </p>
            <p class="text-[10px] text-slate-400 font-bold">{{ bucketCount(b.id) }} ไฟล์ / จำกัด {{ fmt(b.limit) }}</p>
          </div>
          <div class="text-right">
            <p :class="['text-lg font-extrabold', bucketPct(b) >= 90 ? 'text-red-600' : bucketPct(b) >= 70 ? 'text-amber-600' : COLOR[b.color].text]">
              {{ loadingStats ? '—' : bucketPct(b).toFixed(1) + '%' }}
            </p>
          </div>
        </div>

        <!-- Mini progress bar -->
        <div :class="['w-full h-2.5 rounded-full overflow-hidden', COLOR[b.color].track]">
          <div class="h-full rounded-full transition-all duration-1000"
            :class="statusColor(bucketPct(b)) || COLOR[b.color].bg"
            :style="{ width: (loadingStats ? 0 : bucketPct(b)) + '%' }">
          </div>
        </div>
        <div class="flex justify-between mt-1">
          <span class="text-[9px] text-slate-400">0</span>
          <span class="text-[9px] text-slate-400">{{ fmt(b.limit) }}</span>
        </div>
      </button>
    </div>

    <!-- ── Active bucket label bar ───────────────────────────────── -->
    <div :class="['flex items-center justify-between gap-3 px-5 py-3 rounded-2xl border',
      COLOR[current().color].light, COLOR[current().color].border]">
      <div class="flex items-center gap-3">
        <span class="text-2xl">{{ current().icon }}</span>
        <div>
          <p :class="['font-extrabold text-sm', COLOR[current().color].text]">{{ current().label }}</p>
          <p class="text-xs text-slate-400">
            ใช้ <span class="font-bold">{{ fmt(bucketUsedMB(activeBucket)) }}</span>
            จาก <span class="font-bold">{{ fmt(current().limit) }}</span>
            · <span class="font-bold">{{ bucketCount(activeBucket) }}</span> ไฟล์
          </p>
        </div>
      </div>
      <span :class="['text-xs font-bold px-3 py-1 rounded-full', COLOR[current().color].bg, 'text-white']">
        {{ loadingStats ? '—' : bucketPct(current()).toFixed(1) + '%' }}
      </span>
    </div>

    <!-- ── StorageBrowser ─────────────────────────────────────────── -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
      <StorageBrowser
        :key="activeBucket"
        :bucket="activeBucket"
        :accept="current().accept"
        :title="current().label"
        :selectable="false"
        @refresh="loadAllStats"/>
    </div>

    <!-- ── Tips ──────────────────────────────────────────────────── -->
    <div class="bg-slate-50 border border-slate-200 rounded-2xl p-4 text-xs text-slate-500 space-y-1.5">
      <p class="font-bold text-slate-600">📌 วิธีใช้งาน</p>
      <p>• คลิกการ์ด bucket ด้านบนเพื่อสลับดูไฟล์ในแต่ละพื้นที่</p>
      <p>• ⬆️ <span class="font-bold">อัปโหลด</span> — เพิ่มไฟล์ใหม่ · 📋 <span class="font-bold">คัดลอก URL</span> — นำไปใส่ข่าว/เอกสาร</p>
      <p>• 🗑️ <span class="font-bold">ลบ</span> — ลบไฟล์ถาวร (ไม่สามารถกู้คืนได้) และจะช่วยเพิ่มพื้นที่ว่าง</p>
      <p>• Free Plan มีพื้นที่รวม <span class="font-bold">1 GB</span> หากต้องการเพิ่มสามารถอัปเกรดแผนใน Supabase Dashboard</p>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

@keyframes shimmer {
  0%   { transform: translateX(-100%) }
  100% { transform: translateX(200%) }
}
.animate-shimmer {
  animation: shimmer 2s infinite;
}
</style>
