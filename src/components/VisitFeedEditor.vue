<script setup>
/**
 * VisitFeedEditor — ตั้งค่าเซกชัน "บันทึกการนิเทศ" ของหน้าแรก
 *
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน VideoFeedEditor (parent ถือ state)
 *
 * ดึงจาก view nithet_visits_public อัตโนมัติ — เห็นเฉพาะบันทึกที่ ศน. เลือกเปิด
 * เผยแพร่เองและกรอกสมบูรณ์แล้ว ตรงนี้จึงมีแต่ตัวกรองกับขนาดกริด
 */
import { computed } from 'vue'
import { COL_OPTIONS } from '../composables/useYoutubeGrid'
import { VISIT_TYPES, currentAcademicYear } from '../composables/useNithetVisits'

const props = defineProps({
  modelValue: { type: Object, required: true },
})

// ค่าที่บันทึกไว้ก่อนมีฟิลด์เหล่านี้จะไม่มีคีย์ — เติมให้ก่อนผูก v-model
const cfg = props.modelValue
if (!cfg.cols) cfg.cols = 4
if (!cfg.rows) cfg.rows = 1
if (cfg.visit_type === undefined)    cfg.visit_type = ''
if (cfg.academic_year === undefined) cfg.academic_year = ''
if (cfg.photos_only === undefined)   cfg.photos_only = true
if (cfg.link_text === undefined)     cfg.link_text = 'ดูบันทึกการนิเทศทั้งหมด'
if (cfg.animate === undefined)       cfg.animate = true

const total = computed(() => (Number(cfg.cols) || 4) * (Number(cfg.rows) || 1))
const thisYear = currentAcademicYear()
const yearOptions = computed(() => Array.from({ length: 6 }, (_, i) => thisYear - i))
</script>

<template>
  <div class="space-y-4">
    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      ดึงเฉพาะบันทึกที่ <b>ศึกษานิเทศก์เปิดเผยแพร่เอง</b> และกรอกสมบูรณ์แล้ว เรียงวันที่ล่าสุดก่อน ·
      หน้าสาธารณะไม่แสดงจุดที่ควรพัฒนา ข้อเสนอแนะ และข้อมูลผู้รับการนิเทศ
    </div>

    <div class="grid sm:grid-cols-2 gap-3">
      <div>
        <label class="text-[11px] font-bold text-slate-500">เฉพาะประเภท</label>
        <select v-model="cfg.visit_type" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="">ทุกประเภท</option>
          <option v-for="t in VISIT_TYPES" :key="t.value" :value="t.value">{{ t.icon }} {{ t.label }}</option>
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
      <span class="text-xs text-slate-500 pb-2.5">= แสดง <b class="text-primary">{{ total }}</b> บันทึกล่าสุด</span>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.photos_only" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      แสดงเฉพาะบันทึกที่มีรูป (แนะนำ — บันทึกที่ไม่มีรูปจะได้แค่ไอคอนแทนภาพปก)
    </label>

    <div>
      <label class="text-[11px] font-bold text-slate-500">ข้อความลิงก์ใต้กริด (ไปหน้าบันทึกทั้งหมด)</label>
      <input v-model="cfg.link_text" type="text" placeholder="ดูบันทึกการนิเทศทั้งหมด"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.animate" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      ให้การ์ดค่อยๆ โผล่ทีละใบตอนเลื่อนมาถึง
    </label>

    <div class="rounded-2xl border border-slate-200 bg-slate-50 p-3 text-[11px] text-slate-600">
      ภาพปกใช้ <b>รูปแรกของบันทึก</b> อัตโนมัติ ไม่ต้องอัปปกแยก · กดการ์ดแล้วไปหน้ารายละเอียดที่ส่งลิงก์ต่อได้
    </div>
  </div>
</template>
