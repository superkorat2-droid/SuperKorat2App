<script setup>
/**
 * DriveFolderEditor — ตั้งค่าบล็อก/เซกชันโฟลเดอร์ Drive
 * ใช้ทั้งหน้าแรก (AdminHomeSectionsView) และหน้า CMS (AdminPageEditorView)
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน YoutubeGridEditor — parent ถือ state
 */
import { ref, computed, watch } from 'vue'
import { parseDriveUrl, useDriveFolder, fileKind, isFolder, driveFolderUrl } from '../../composables/useGoogleDrive'
import { COL_OPTIONS } from '../../composables/useYoutubeGrid'

const props = defineProps({
  modelValue: { type: Object, required: true },  // { url, folder_id, title, view, cols, rows, show_search, allow_subfolders }
})

const cfg = props.modelValue
if (!cfg.view)  cfg.view = 'grid'
if (!cfg.cols)  cfg.cols = 4
if (!cfg.rows)  cfg.rows = 3
if (cfg.show_search === undefined)      cfg.show_search = true
if (cfg.allow_subfolders === undefined) cfg.allow_subfolders = true

const parsed = computed(() => parseDriveUrl(cfg.url))
const isFolderLink = computed(() => parsed.value.id && parsed.value.kind !== 'file')

const { files, loading, error, fetchFolder } = useDriveFolder()
const tested = ref(false)

// วาง URL แล้วเก็บ id ทันที — ตัว renderer ใช้ folder_id ไม่ใช่ url ดิบ
watch(() => cfg.url, () => {
  cfg.folder_id = isFolderLink.value ? parsed.value.id : ''
  tested.value = false
})

async function testFolder() {
  if (!cfg.folder_id) return
  tested.value = true
  await fetchFolder(cfg.folder_id, { force: true })
}

const summary = computed(() => {
  const folders = files.value.filter(isFolder).length
  return { folders, files: files.value.length - folders }
})
</script>

<template>
  <div class="space-y-3">
    <!-- ลิงก์โฟลเดอร์ -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">ลิงก์โฟลเดอร์ Google Drive</label>
      <input v-model="cfg.url" placeholder="https://drive.google.com/drive/folders/..."
        :class="['w-full px-3 py-2 rounded-xl border text-sm bg-white focus:outline-none focus:border-primary',
          cfg.url && !isFolderLink ? 'border-red-300' : 'border-slate-200']"/>
      <p v-if="cfg.url && parsed.kind === 'file'" class="text-[11px] text-red-500 mt-1">
        นี่เป็นลิงก์ <b>ไฟล์เดี่ยว</b> ไม่ใช่โฟลเดอร์ — ถ้าต้องการฝังไฟล์เดียวให้ใช้บล็อก "Embed URL" แทน
      </p>
      <p v-else-if="cfg.url && !parsed.id" class="text-[11px] text-red-500 mt-1">ไม่พบรหัสโฟลเดอร์ในลิงก์นี้</p>
      <p v-else-if="isFolderLink" class="text-[11px] text-emerald-600 mt-1">✓ รหัสโฟลเดอร์: {{ cfg.folder_id }}</p>
    </div>

    <!-- ทดสอบการเข้าถึง -->
    <div v-if="isFolderLink" class="flex flex-wrap items-center gap-2">
      <button type="button" @click="testFolder" :disabled="loading"
        class="px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-primary hover:text-white transition-all disabled:opacity-50">
        {{ loading ? 'กำลังตรวจ…' : 'ทดสอบการเข้าถึง' }}
      </button>
      <a :href="driveFolderUrl(cfg.folder_id)" target="_blank" rel="noopener"
        class="text-xs font-bold text-slate-500 hover:text-primary">เปิดใน Drive →</a>

      <p v-if="tested && !loading && !error" class="text-xs font-bold text-emerald-600">
        ✓ อ่านได้ — {{ summary.folders }} โฟลเดอร์ · {{ summary.files }} ไฟล์
      </p>
      <p v-else-if="tested && error" class="text-xs font-bold text-red-500">{{ error }}</p>
    </div>

    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      โฟลเดอร์ต้องแชร์แบบ <b>"ทุกคนที่มีลิงก์ → ผู้อ่าน"</b> ไม่งั้นเว็บจะอ่านรายการไม่ได้
      · ไฟล์ข้างในต้องสืบทอดสิทธิ์นี้ด้วย ไม่งั้นกดดูแล้วจะไม่ขึ้น
      · เพิ่ม/ลบไฟล์ใน Drive แล้วเว็บจะตามภายใน ~10 นาที (cache กันเรียก Google ถี่เกิน)
    </div>

    <!-- ตัวเลือกการแสดงผล -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">หัวข้อ (เว้นว่างได้)</label>
      <input v-model="cfg.title" placeholder="เช่น เอกสารดาวน์โหลด"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <div class="flex flex-wrap items-center gap-x-5 gap-y-2">
      <div class="flex items-center gap-1.5">
        <span class="text-[11px] font-bold text-slate-500">มุมมองเริ่มต้น</span>
        <button v-for="v in [{k:'grid',l:'การ์ด'},{k:'list',l:'รายการ'}]" :key="v.k" type="button" @click="cfg.view = v.k"
          :class="['px-2.5 py-1 rounded-lg text-xs font-bold border-2 transition-all',
            cfg.view === v.k ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500 hover:border-primary/50']">
          {{ v.l }}
        </button>
      </div>

      <div class="flex items-center gap-1.5">
        <span class="text-[11px] font-bold text-slate-500">คอลัมน์</span>
        <button v-for="c in COL_OPTIONS" :key="c" type="button" @click="cfg.cols = c"
          :class="['w-8 h-8 rounded-lg text-xs font-bold border-2 transition-all',
            cfg.cols === c ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500 hover:border-primary/50']">
          {{ c }}
        </button>
      </div>

      <div class="flex items-center gap-1.5">
        <span class="text-[11px] font-bold text-slate-500">แถวต่อหน้า</span>
        <input type="number" min="1" max="10" :value="cfg.rows"
          @input="cfg.rows = Math.min(10, Math.max(1, +$event.target.value || 3))"
          class="w-16 px-2 py-1 border border-slate-200 rounded-lg text-sm text-center focus:outline-none focus:border-primary"/>
      </div>

      <!-- บอกผลลัพธ์จริงก่อนบันทึก — "คอลัมน์" มีผลเฉพาะมุมมองการ์ด
           มุมมองรายการ 1 แถว = 1 รายการ จึงได้เท่ากับจำนวนแถวพอดี -->
      <span class="text-[11px] text-slate-400 w-full sm:w-auto">
        = แสดงหน้าละ
        <b class="text-slate-600">{{ cfg.view === 'list' ? cfg.rows : cfg.cols * cfg.rows }}</b>
        รายการ
        <template v-if="cfg.view === 'list'">(รายการ 1 แถวต่อ 1 รายการ · คอลัมน์ไม่มีผล)</template>
        <template v-else>({{ cfg.cols }} คอลัมน์ × {{ cfg.rows }} แถว)</template>
      </span>
    </div>

    <div class="flex flex-wrap gap-x-5 gap-y-2">
      <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
        <input type="checkbox" v-model="cfg.show_search" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
        แสดงช่องค้นหาและตัวกรอง
      </label>
      <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
        <input type="checkbox" v-model="cfg.allow_subfolders" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
        ให้ผู้ชมเข้าโฟลเดอร์ย่อยได้
      </label>
    </div>
  </div>
</template>
