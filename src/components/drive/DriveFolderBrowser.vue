<script setup>
/**
 * DriveFolderBrowser — แสดงรายการไฟล์/โฟลเดอร์ใน Google Drive สาธารณะ
 * พร้อมค้นหา · กรองชนิด · เรียง · สลับ grid/list · เข้าโฟลเดอร์ย่อย · แบ่งหน้า
 *
 * ดึงข้อมูลผ่าน Edge Function `drive-list` (API key อยู่ฝั่งเซิร์ฟเวอร์เท่านั้น)
 */
import { ref, computed, watch, onMounted } from 'vue'
import { useDriveFolder, FILE_KINDS, fileKind, isFolder, formatSize, formatDate, driveFolderUrl } from '../../composables/useGoogleDrive'
import { COL_WIDTH_CLASS } from '../../composables/useYoutubeGrid'
import DriveFilePreviewModal from './DriveFilePreviewModal.vue'

const props = defineProps({
  folderId:   { type: String,  required: true },
  folderName: { type: String,  default: 'โฟลเดอร์' },
  view:       { type: String,  default: 'grid' },  // 'grid' | 'list'
  cols:       { type: Number,  default: 4 },
  rows:       { type: Number,  default: 2 },   // แถวต่อหน้า — มุมมองการ์ด
  rowsList:   { type: Number,  default: 10 },  // แถวต่อหน้า — มุมมองรายการ (1 แถว = 1 รายการ)
  showSearch: { type: Boolean, default: true },
  allowSubfolders: { type: Boolean, default: true },
})

const { files, loading, error, fetchFolder } = useDriveFolder()

// breadcrumb — ตัวแรกคือโฟลเดอร์ราก คลิกย้อนกลับได้
const trail = ref([])
const currentId = computed(() => trail.value[trail.value.length - 1]?.id || props.folderId)

const search   = ref('')
const kindFilter = ref('all')
const sortBy   = ref('name')     // 'name' | 'modified' | 'size'
const sortAsc  = ref(true)
const viewMode = ref(props.view)
const page     = ref(1)
const preview  = ref(null)

onMounted(() => {
  trail.value = [{ id: props.folderId, name: props.folderName }]
  fetchFolder(props.folderId)
})
// เปลี่ยนโฟลเดอร์ใน editor แล้วให้โหลดใหม่ทันที
watch(() => props.folderId, id => {
  trail.value = [{ id, name: props.folderName }]
  search.value = ''; kindFilter.value = 'all'; page.value = 1
  fetchFolder(id)
})

function openFolder(f) {
  if (!props.allowSubfolders) return
  trail.value.push({ id: f.id, name: f.name })
  search.value = ''; kindFilter.value = 'all'; page.value = 1
  fetchFolder(f.id)
}
function gotoTrail(i) {
  trail.value = trail.value.slice(0, i + 1)
  search.value = ''; kindFilter.value = 'all'; page.value = 1
  fetchFolder(trail.value[i].id)
}
function onItemClick(f) {
  if (isFolder(f)) openFolder(f)
  else preview.value = f
}

// ชนิดที่มีอยู่จริงในโฟลเดอร์นี้เท่านั้น — ไม่โชว์ตัวเลือกที่กดแล้วว่างเปล่า
const availableKinds = computed(() => {
  const keys = new Set(files.value.map(f => fileKind(f.mimeType).key))
  return FILE_KINDS.filter(k => keys.has(k.key))
})

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  let list = files.value
  if (kindFilter.value !== 'all') list = list.filter(f => fileKind(f.mimeType).key === kindFilter.value)
  if (q) {
    // แยกคำแล้วเช็คว่ามีครบทุกคำ (ไม่สนลำดับ) — พิมพ์สลับคำก็ยังเจอ
    const words = q.split(/\s+/)
    list = list.filter(f => { const n = (f.name || '').toLowerCase(); return words.every(w => n.includes(w)) })
  }
  const dir = sortAsc.value ? 1 : -1
  return [...list].sort((a, b) => {
    // โฟลเดอร์ขึ้นก่อนเสมอ ไม่ว่าจะเรียงแบบไหน
    if (isFolder(a) !== isFolder(b)) return isFolder(a) ? -1 : 1
    if (sortBy.value === 'modified') return dir * String(a.modifiedTime || '').localeCompare(String(b.modifiedTime || ''))
    if (sortBy.value === 'size')     return dir * ((Number(a.size) || 0) - (Number(b.size) || 0))
    return dir * (a.name || '').localeCompare(b.name || '', 'th', { numeric: true })
  })
})

/**
 * จำนวนต่อหน้า — แยกค่าตามมุมมอง เพราะจำนวนที่ "พอดีตา" ต่างกันมาก
 *   การ์ด  : 1 แถวมี cols ใบ  → cols x rows      (เช่น 6 x 2 = 12 ใบ)
 *   รายการ : 1 แถวมี 1 รายการ → rowsList          (เช่น 10 แถว)
 *
 * เดิมใช้ cols x rows กับทั้งสองมุมมอง มุมมองรายการเลยแสดงเกินที่ตั้งไว้หลายเท่า
 * ผูกกับ viewMode ไม่ใช่ props.view เพราะผู้ชมสลับมุมมองเองได้ระหว่างดู
 */
const perPage    = computed(() =>
  Math.max(1, viewMode.value === 'list' ? props.rowsList : props.cols * props.rows))
const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / perPage.value)))
const paged      = computed(() => filtered.value.slice((page.value - 1) * perPage.value, page.value * perPage.value))
const widthClass = computed(() => COL_WIDTH_CLASS[props.cols] || COL_WIDTH_CLASS[4])

watch([filtered, perPage], () => { if (page.value > totalPages.value) page.value = totalPages.value })
// สลับการ์ด/รายการ = จำนวนต่อหน้าเปลี่ยน กลับไปหน้าแรกเพื่อไม่ให้ผู้ชมงงว่าของหายไปไหน
watch(viewMode, () => { page.value = 1 })

function toggleSort(key) {
  if (sortBy.value === key) sortAsc.value = !sortAsc.value
  else { sortBy.value = key; sortAsc.value = true }
}
// thumbnailLink ของ Drive มี token อายุสั้น พังได้ → ซ่อนรูปแล้วโชว์ไอคอนแทน
function onThumbError(e) { e.target.style.display = 'none' }
</script>

<template>
  <div>
    <!-- Breadcrumb -->
    <div v-if="trail.length > 1" class="flex flex-wrap items-center gap-1 mb-3 text-sm">
      <template v-for="(t, i) in trail" :key="t.id">
        <button @click="gotoTrail(i)" :disabled="i === trail.length - 1"
          :class="['px-2 py-1 rounded-lg font-bold transition-colors truncate max-w-[45vw] sm:max-w-xs',
            i === trail.length - 1 ? 'text-slate-800' : 'text-primary hover:bg-primary/10']">
          {{ t.name }}
        </button>
        <span v-if="i < trail.length - 1" class="text-slate-400">/</span>
      </template>
    </div>

    <!-- แถบเครื่องมือ -->
    <div v-if="!loading && !error && files.length" class="flex flex-wrap items-center gap-2 mb-4">
      <div v-if="showSearch" class="relative flex-1 min-w-[180px]">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="search" type="text" placeholder="ค้นหาชื่อไฟล์หรือโฟลเดอร์…"
          class="w-full pl-9 pr-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <select v-model="kindFilter"
        class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm font-medium text-slate-600 focus:outline-none focus:border-primary">
        <option value="all">ทุกชนิด</option>
        <option v-for="k in availableKinds" :key="k.key" :value="k.key">{{ k.label }}</option>
      </select>

      <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl">
        <button v-for="s in [{k:'name',l:'ชื่อ'},{k:'modified',l:'วันที่'},{k:'size',l:'ขนาด'}]" :key="s.k"
          @click="toggleSort(s.k)"
          :class="['px-2.5 py-1 text-xs font-bold rounded-lg transition-colors',
            sortBy === s.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ s.l }}<span v-if="sortBy === s.k">{{ sortAsc ? ' ↑' : ' ↓' }}</span>
        </button>
      </div>

      <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl">
        <button @click="viewMode = 'grid'" title="มุมมองการ์ด"
          :class="['w-8 h-7 flex items-center justify-center rounded-lg transition-colors', viewMode === 'grid' ? 'bg-primary text-white' : 'text-slate-500']">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/></svg>
        </button>
        <button @click="viewMode = 'list'" title="มุมมองรายการ"
          :class="['w-8 h-7 flex items-center justify-center rounded-lg transition-colors', viewMode === 'list' ? 'bg-primary text-white' : 'text-slate-500']">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/></svg>
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex flex-wrap justify-center gap-4">
      <div v-for="i in Math.min(cols * rows, 8)" :key="i" :class="['glass-card h-40 animate-pulse', widthClass]"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="glass-card p-6 text-center">
      <p class="text-3xl mb-2">🔒</p>
      <p class="font-bold text-slate-700">{{ error }}</p>
      <p class="text-xs text-slate-500 mt-2">
        เปิดโฟลเดอร์ใน Google Drive → แชร์ → เปลี่ยนเป็น <b>"ทุกคนที่มีลิงก์"</b> สิทธิ์ <b>ผู้อ่าน</b>
      </p>
      <a :href="driveFolderUrl(currentId)" target="_blank" rel="noopener"
        class="inline-block mt-3 text-xs font-bold text-primary hover:underline">เปิดโฟลเดอร์ใน Drive →</a>
    </div>

    <!-- ว่างเปล่า -->
    <div v-else-if="!files.length" class="glass-card p-8 text-center text-slate-500">
      <p class="text-3xl mb-2">📂</p>
      <p class="font-medium">โฟลเดอร์นี้ยังไม่มีไฟล์</p>
    </div>

    <!-- ค้นหาไม่เจอ -->
    <div v-else-if="!filtered.length" class="glass-card p-8 text-center text-slate-500">
      <p class="font-medium">ไม่พบไฟล์ที่ตรงกับที่ค้นหา</p>
      <button @click="search = ''; kindFilter = 'all'" class="mt-2 text-sm font-bold text-primary hover:underline">ล้างตัวกรอง</button>
    </div>

    <template v-else>
      <!-- มุมมองการ์ด — flex-wrap ทำให้แถวสุดท้ายที่ไม่เต็มอยู่กึ่งกลางเอง -->
      <div v-if="viewMode === 'grid'" class="flex flex-wrap justify-center gap-4">
        <button v-for="f in paged" :key="f.id" @click="onItemClick(f)" type="button"
          :class="['group glass-card glass-card-hover overflow-hidden text-left', widthClass]">
          <div class="relative aspect-video bg-slate-900/5 flex items-center justify-center overflow-hidden">
            <img v-if="f.thumbnailLink" :src="f.thumbnailLink" :alt="f.name" loading="lazy" referrerpolicy="no-referrer"
              @error="onThumbError" class="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
            <span :class="['relative text-3xl font-black', fileKind(f.mimeType).color]">
              {{ isFolder(f) ? '📁' : '📄' }}
            </span>
            <span :class="['absolute top-2 right-2 text-[10px] font-bold px-2 py-0.5 rounded-full', fileKind(f.mimeType).bg, fileKind(f.mimeType).color]">
              {{ fileKind(f.mimeType).label }}
            </span>
          </div>
          <div class="p-3">
            <p class="font-bold text-slate-800 text-sm leading-snug line-clamp-2 group-hover:text-primary transition-colors">{{ f.name }}</p>
            <p class="text-[11px] text-slate-500 mt-1">
              <span v-if="formatSize(f.size)">{{ formatSize(f.size) }} · </span>{{ formatDate(f.modifiedTime) }}
            </p>
          </div>
        </button>
      </div>

      <!-- มุมมองรายการ — มือถือซ่อนขนาด/วันที่ เหลือไอคอน+ชื่อ -->
      <div v-else class="space-y-2">
        <button v-for="f in paged" :key="f.id" @click="onItemClick(f)" type="button"
          class="w-full flex items-center gap-3 glass-tile glass-card-hover px-3 py-2.5 text-left">
          <span :class="['w-9 h-9 flex-shrink-0 rounded-lg flex items-center justify-center text-lg', fileKind(f.mimeType).bg]">
            {{ isFolder(f) ? '📁' : '📄' }}
          </span>
          <span class="flex-1 min-w-0">
            <span class="block font-bold text-slate-800 text-sm truncate">{{ f.name }}</span>
            <span class="block sm:hidden text-[11px] text-slate-500">{{ fileKind(f.mimeType).label }}</span>
          </span>
          <span class="hidden sm:block text-xs text-slate-500 w-20 text-right flex-shrink-0">{{ formatSize(f.size) || '—' }}</span>
          <span class="hidden sm:block text-xs text-slate-500 w-24 text-right flex-shrink-0">{{ formatDate(f.modifiedTime) }}</span>
        </button>
      </div>

      <!-- แบ่งหน้า -->
      <div v-if="totalPages > 1" class="flex items-center justify-center gap-2 mt-6">
        <button @click="page--" :disabled="page === 1" aria-label="หน้าก่อน"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:border-primary/40 hover:text-primary transition-all disabled:opacity-30">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
        </button>
        <button v-for="p in totalPages" :key="p" @click="page = p"
          :class="['w-9 h-9 rounded-xl text-sm font-bold border transition-all',
            page === p ? 'bg-primary text-white border-primary shadow-sm' : 'border-white/80 bg-white/60 backdrop-blur text-slate-600 hover:border-primary/40']">
          {{ p }}
        </button>
        <button @click="page++" :disabled="page === totalPages" aria-label="หน้าถัดไป"
          class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:border-primary/40 hover:text-primary transition-all disabled:opacity-30">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
        </button>
      </div>

      <p class="text-center text-[11px] text-slate-500 mt-3">
        {{ filtered.length }} รายการ<span v-if="filtered.length !== files.length"> จากทั้งหมด {{ files.length }}</span>
      </p>
    </template>

    <DriveFilePreviewModal :file="preview" @close="preview = null"/>
  </div>
</template>
