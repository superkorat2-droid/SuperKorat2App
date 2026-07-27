<script setup>
/**
 * YoutubeGridEditor — จัดการรายการวิดีโอ + จำนวนคอลัมน์/แถว
 * ใช้ทั้งเซกชันหน้าแรก (AdminHomeSectionsView) และบล็อกหน้า CMS (AdminPageEditorView)
 *
 * แก้ object ที่ส่งเข้ามาโดยตรง (เหมือน ImageLinkGalleryEditor) — parent ถือ state
 */
import { computed } from 'vue'
import { youtubeId, youtubeThumb, COL_OPTIONS } from '../composables/useYoutubeGrid'

const props = defineProps({
  modelValue: { type: Object, required: true },  // { title, cols, rows, items: [] }
  // เซกชันหน้าแรกมีช่อง "ชื่อหลัก" ของตัวเองอยู่แล้ว ถ้าโชว์อีกช่องจะซ้ำซ้อนและงง
  // บล็อกในหน้า CMS ไม่มีหัวข้อให้ จึงต้องเปิดเฉพาะที่นั่น (แบบเดียวกับบล็อกภาพลิงก์/Drive)
  showTitle:  { type: Boolean, default: false },
})

const cfg = props.modelValue
if (!Array.isArray(cfg.items)) cfg.items = []
if (!cfg.cols) cfg.cols = 4
if (!cfg.rows) cfg.rows = 3

const perPage = computed(() => (cfg.cols || 4) * (cfg.rows || 3))
const validCount = computed(() => cfg.items.filter(i => youtubeId(i.url)).length)

function addItem() {
  cfg.items.push({ id: `yt_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`, url: '', title: '', caption: '' })
}
function removeItem(i) { cfg.items.splice(i, 1) }
function moveUp(i)   { if (i > 0) cfg.items.splice(i - 1, 0, cfg.items.splice(i, 1)[0]) }
function moveDown(i) { if (i < cfg.items.length - 1) cfg.items.splice(i + 1, 0, cfg.items.splice(i, 1)[0]) }
</script>

<template>
  <div class="space-y-3">
    <!-- หัวข้อใหญ่ของบล็อก -->
    <div v-if="showTitle">
      <label class="text-[11px] font-bold text-slate-500">หัวข้อ (เว้นว่างได้)</label>
      <input v-model="cfg.title" placeholder="เช่น วิดีโอแนะนำ"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <!-- คอลัมน์ / แถว -->
    <div class="flex flex-wrap items-center gap-x-5 gap-y-2">
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
      <p class="text-[11px] text-slate-500">
        แสดงหน้าละ <b>{{ perPage }}</b> การ์ด · มี {{ validCount }} วิดีโอ
        <span v-if="validCount > perPage"> → {{ Math.ceil(validCount / perPage) }} หน้า</span>
      </p>
    </div>

    <!-- รายการวิดีโอ -->
    <div v-if="!cfg.items.length" class="text-center py-6 text-sm text-slate-400 border-2 border-dashed border-slate-200 rounded-xl">
      ยังไม่มีวิดีโอ — กด "เพิ่มวิดีโอ" แล้ววางลิงก์ YouTube
    </div>

    <div v-for="(item, i) in cfg.items" :key="item.id || i"
      class="flex gap-3 p-2.5 border border-slate-200 rounded-xl bg-white/60">
      <!-- ปกวิดีโอ -->
      <div class="w-24 h-[54px] flex-shrink-0 rounded-lg overflow-hidden bg-slate-100 flex items-center justify-center">
        <img v-if="youtubeId(item.url)" :src="youtubeThumb(item.url)" class="w-full h-full object-cover" alt=""/>
        <span v-else class="text-[10px] text-slate-400 text-center px-1">ยังไม่มีลิงก์</span>
      </div>

      <div class="flex-1 min-w-0 space-y-1.5">
        <input v-model="item.url" placeholder="วางลิงก์ YouTube (watch / youtu.be / shorts)"
          :class="['w-full px-2.5 py-1.5 text-sm border rounded-lg bg-white focus:outline-none focus:border-primary',
            item.url && !youtubeId(item.url) ? 'border-red-300' : 'border-slate-200']"/>
        <p v-if="item.url && !youtubeId(item.url)" class="text-[11px] text-red-500">ไม่ใช่ลิงก์ YouTube ที่ถูกต้อง</p>
        <input v-model="item.title" placeholder="ชื่อวิดีโอที่จะแสดงบนการ์ด"
          class="w-full px-2.5 py-1.5 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
        <input v-model="item.caption" placeholder="คำอธิบายสั้น (ถ้ามี)"
          class="w-full px-2.5 py-1.5 text-xs border border-slate-200 rounded-lg bg-white text-slate-500 focus:outline-none focus:border-primary"/>
      </div>

      <div class="flex flex-col gap-1 flex-shrink-0">
        <button type="button" @click="moveUp(i)" :disabled="i === 0" title="เลื่อนขึ้น"
          class="w-7 h-7 rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-30">↑</button>
        <button type="button" @click="moveDown(i)" :disabled="i === cfg.items.length - 1" title="เลื่อนลง"
          class="w-7 h-7 rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-30">↓</button>
        <button type="button" @click="removeItem(i)" title="ลบ"
          class="w-7 h-7 rounded-lg text-slate-400 hover:bg-red-50 hover:text-red-500">✕</button>
      </div>
    </div>

    <button type="button" @click="addItem"
      class="w-full py-2 rounded-xl text-sm font-bold border-2 border-dashed border-slate-300 text-slate-500 hover:border-primary hover:text-primary transition-all">
      + เพิ่มวิดีโอ
    </button>
  </div>
</template>
