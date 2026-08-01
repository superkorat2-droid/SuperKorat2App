<script setup>
/**
 * NewsletterFeedEditor — ตั้งค่าเซกชัน "จดหมายข่าวโรงเรียน" ของหน้าแรก
 *
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน EmbedEditor / DriveFolderEditor (parent ถือ state)
 * โมดัลเป็น v-if จึงสร้างใหม่ทุกครั้งที่เปิด ไม่มีสถานะค้าง
 *
 * เซกชันนี้ไม่ต้องกรอกเนื้อหาเอง — ดึงจากตาราง newsletters ที่โรงเรียนส่งเข้ามา
 * ตรงนี้จึงมีแต่ตัวกรองและขนาดกริด
 */
import { computed } from 'vue'
import { COL_OPTIONS } from '../composables/useYoutubeGrid'
import { NEWSLETTER_CATEGORIES } from '../composables/useNewsletterMeta'

const props = defineProps({
  modelValue: { type: Object, required: true },
})

// ค่าที่บันทึกไว้ก่อนมีฟิลด์เหล่านี้จะไม่มีคีย์ — เติมให้ก่อนผูก v-model
const cfg = props.modelValue
if (!cfg.cols)   cfg.cols = 6
if (!cfg.rows)   cfg.rows = 2
if (!cfg.scope)  cfg.scope = 'school'
if (cfg.category === undefined)  cfg.category = ''
if (cfg.link_text === undefined) cfg.link_text = 'จดหมายข่าวโรงเรียนทั้งหมด'
if (cfg.animate === undefined)   cfg.animate = true

const SCOPES = [
  { value: 'school', label: 'เฉพาะโรงเรียนในสังกัด', desc: 'ไม่รวมของ สพป.' },
  { value: 'area',   label: 'เฉพาะของ สพป.',         desc: 'ที่เขตเป็นคนออกเอง' },
  { value: 'all',    label: 'ทั้งหมด',                desc: 'รวมทุกแหล่ง' },
]

const total = computed(() => (Number(cfg.cols) || 6) * (Number(cfg.rows) || 2))
</script>

<template>
  <div class="space-y-4">

    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      เซกชันนี้ดึงจดหมายข่าวที่ <b>เผยแพร่แล้ว</b> มาแสดงอัตโนมัติ เรียงจากใหม่ไปเก่า
      ไม่ต้องมาเพิ่มเองทีละใบ · โรงเรียนส่งเข้ามาใหม่แล้วหน้าแรกเปลี่ยนตามทันที
    </div>

    <!-- แสดงของใคร -->
    <div>
      <span class="block text-[11px] font-bold text-slate-500 mb-1.5">แสดงจดหมายข่าวของ</span>
      <div class="grid sm:grid-cols-3 gap-2">
        <button v-for="s in SCOPES" :key="s.value" type="button" @click="cfg.scope = s.value"
          :class="['text-left px-3 py-2.5 rounded-2xl border-2 transition-all',
            cfg.scope === s.value ? 'border-primary bg-slate-50 shadow-sm' : 'border-slate-200 hover:border-slate-300']">
          <span :class="['block font-bold text-xs', cfg.scope === s.value ? 'text-primary' : 'text-slate-700']">
            {{ s.label }}
          </span>
          <span class="block text-[10px] text-slate-400 mt-0.5">{{ s.desc }}</span>
        </button>
      </div>
    </div>

    <!-- หมวด -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">เฉพาะหมวด</label>
      <select v-model="cfg.category"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="">ทุกหมวด</option>
        <option v-for="c in NEWSLETTER_CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
      </select>
    </div>

    <!-- ขนาดกริด -->
    <div class="flex flex-wrap items-end gap-4">
      <div>
        <label class="text-[11px] font-bold text-slate-500">คอลัมน์ (จอใหญ่)</label>
        <select v-model.number="cfg.cols"
          class="w-32 px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option v-for="c in COL_OPTIONS" :key="c" :value="c">{{ c }} คอลัมน์</option>
        </select>
      </div>
      <div>
        <label class="text-[11px] font-bold text-slate-500">แถว</label>
        <select v-model.number="cfg.rows"
          class="w-28 px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option v-for="r in [1,2,3,4]" :key="r" :value="r">{{ r }} แถว</option>
        </select>
      </div>
      <span class="text-xs text-slate-500 pb-2.5">= แสดง <b class="text-primary">{{ total }}</b> ใบล่าสุด</span>
    </div>

    <!-- ข้อความลิงก์ด้านล่าง -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">ข้อความลิงก์ใต้กริด (ไปหน้าจดหมายข่าวทั้งหมด)</label>
      <input v-model="cfg.link_text" type="text" placeholder="จดหมายข่าวโรงเรียนทั้งหมด"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.animate" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      ให้การ์ดค่อยๆ โผล่ทีละใบตอนเลื่อนมาถึง
    </label>

    <div class="rounded-2xl border border-slate-200 bg-slate-50 p-3 text-[11px] text-slate-600 space-y-1">
      <p class="font-bold text-slate-700">ถ้าภาพปกไม่ขึ้นเป็นกรอบไอคอนแทน</p>
      <p>
        ภาพปกดึงมาจาก Google Drive โดยตรง ไฟล์ต้องแชร์แบบ <b>“ทุกคนที่มีลิงก์”</b>
        ถ้าตั้งเป็นจำกัดสิทธิ์ ผู้ชมทั่วไปจะเห็นเป็นกรอบไอคอนพร้อมชื่อเรื่องแทน
      </p>
    </div>
  </div>
</template>
