<script setup>
/**
 * VideoFeedEditor — ตั้งค่าเซกชัน "วีดิทัศน์การศึกษา" ของหน้าแรก
 *
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน LibraryFeedEditor (parent ถือ state)
 * โมดัลเป็น v-if จึงสร้างใหม่ทุกครั้งที่เปิด ไม่มีสถานะค้าง
 *
 * ดึงจากตาราง videos ที่อนุมัติแล้วอัตโนมัติ ตรงนี้จึงมีแต่ตัวกรองกับขนาดกริด
 */
import { computed } from 'vue'
import { COL_OPTIONS } from '../composables/useYoutubeGrid'
import { VIDEO_CATEGORIES, CURRENT_BE_YEAR } from '../composables/useVideos'

const props = defineProps({
  modelValue: { type: Object, required: true },
})

// ค่าที่บันทึกไว้ก่อนมีฟิลด์เหล่านี้จะไม่มีคีย์ — เติมให้ก่อนผูก v-model
const cfg = props.modelValue
if (!cfg.cols) cfg.cols = 4
if (!cfg.rows) cfg.rows = 1
if (cfg.category === undefined)      cfg.category = ''
if (cfg.academic_year === undefined) cfg.academic_year = ''
if (cfg.featured_only === undefined) cfg.featured_only = false
if (cfg.link_text === undefined)     cfg.link_text = 'ดูวีดิทัศน์ทั้งหมด'
if (cfg.animate === undefined)       cfg.animate = true

const total = computed(() => (Number(cfg.cols) || 4) * (Number(cfg.rows) || 1))
const yearOptions = computed(() => Array.from({ length: 6 }, (_, i) => CURRENT_BE_YEAR - i))
</script>

<template>
  <div class="space-y-4">
    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      ดึงคลิปที่ <b>อนุมัติแล้ว</b> มาแสดงอัตโนมัติ เรียงคลิปแนะนำก่อน แล้วตามลำดับและวันที่เผยแพร่ ·
      ผู้ดูแลอนุมัติคลิปใหม่แล้วหน้าแรกเปลี่ยนตามทันที
    </div>

    <div class="grid sm:grid-cols-2 gap-3">
      <div>
        <label class="text-[11px] font-bold text-slate-500">เฉพาะหมวดหมู่</label>
        <select v-model="cfg.category" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="">ทุกหมวดหมู่</option>
          <option v-for="c in VIDEO_CATEGORIES" :key="c.value" :value="c.value">{{ c.icon }} {{ c.label }}</option>
        </select>
      </div>
      <div>
        <label class="text-[11px] font-bold text-slate-500">เฉพาะปีการศึกษา</label>
        <select v-model="cfg.academic_year" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="">ทุกปี</option>
          <option v-for="y in yearOptions" :key="y" :value="y">ปีการศึกษา {{ y }}</option>
        </select>
      </div>
    </div>

    <div class="flex flex-wrap items-end gap-4">
      <div>
        <label class="text-[11px] font-bold text-slate-500">คอลัมน์ (จอใหญ่)</label>
        <select v-model.number="cfg.cols" class="w-32 px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option v-for="c in COL_OPTIONS" :key="c" :value="c">{{ c }} คอลัมน์</option>
        </select>
      </div>
      <div>
        <label class="text-[11px] font-bold text-slate-500">แถว</label>
        <select v-model.number="cfg.rows" class="w-28 px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option v-for="r in [1,2,3]" :key="r" :value="r">{{ r }} แถว</option>
        </select>
      </div>
      <span class="text-xs text-slate-500 pb-2.5">= แสดง <b class="text-primary">{{ total }}</b> คลิปล่าสุด</span>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.featured_only" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      แสดงเฉพาะคลิปที่ตั้งเป็น "แนะนำ" เท่านั้น
    </label>

    <div>
      <label class="text-[11px] font-bold text-slate-500">ข้อความลิงก์ใต้กริด (ไปหน้าวีดิทัศน์ทั้งหมด)</label>
      <input v-model="cfg.link_text" type="text" placeholder="ดูวีดิทัศน์ทั้งหมด"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.animate" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      ให้การ์ดค่อยๆ โผล่ทีละใบตอนเลื่อนมาถึง
    </label>

    <div class="rounded-2xl border border-slate-200 bg-slate-50 p-3 text-[11px] text-slate-600">
      การ์ดเป็นอัตราส่วน <b>16:9</b> กดแล้วเล่นในหน้าเดิมทันที รองรับทั้ง YouTube และ Google Drive
    </div>
  </div>
</template>
