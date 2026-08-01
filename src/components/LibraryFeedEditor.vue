<script setup>
/**
 * LibraryFeedEditor — ตั้งค่าเซกชัน "คลังหนังสือและคู่มือ" ของหน้าแรก
 *
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน EmbedEditor / NewsletterFeedEditor
 * (parent ถือ state) โมดัลเป็น v-if จึงสร้างใหม่ทุกครั้งที่เปิด ไม่มีสถานะค้าง
 *
 * เซกชันนี้ดึงจากตาราง library_items อัตโนมัติ ตรงนี้จึงมีแต่ตัวกรองกับขนาดกริด
 */
import { computed } from 'vue'
import { COL_OPTIONS } from '../composables/useYoutubeGrid'
import { LIBRARY_KINDS, useGroupOptions } from '../composables/useLibraryOptions'
import { useAreaConfig } from '../composables/useAreaConfig'

const props = defineProps({
  modelValue: { type: Object, required: true },
})

const { config } = useAreaConfig()
const { groupOptions } = useGroupOptions(config)

// ค่าที่บันทึกไว้ก่อนมีฟิลด์เหล่านี้จะไม่มีคีย์ — เติมให้ก่อนผูก v-model
const cfg = props.modelValue
if (!cfg.cols) cfg.cols = 6
if (!cfg.rows) cfg.rows = 1
if (cfg.kind === undefined)      cfg.kind = ''
if (cfg.group_key === undefined) cfg.group_key = ''
if (cfg.link_text === undefined) cfg.link_text = 'ดูคลังหนังสือทั้งหมด'
if (cfg.animate === undefined)   cfg.animate = true

const total = computed(() => (Number(cfg.cols) || 6) * (Number(cfg.rows) || 1))
</script>

<template>
  <div class="space-y-4">
    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      ดึงรายการที่ <b>เผยแพร่แล้ว</b> จากคลังหนังสือมาแสดงอัตโนมัติ เรียงจากใหม่ไปเก่า
      ไม่ต้องมาเพิ่มเองทีละเล่ม · ศน. เพิ่มเล่มใหม่แล้วหน้าแรกเปลี่ยนตามทันที
    </div>

    <div class="grid sm:grid-cols-2 gap-3">
      <div>
        <label class="text-[11px] font-bold text-slate-500">เฉพาะประเภท</label>
        <select v-model="cfg.kind" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="">ทุกประเภท</option>
          <option v-for="k in LIBRARY_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
        </select>
      </div>
      <div>
        <label class="text-[11px] font-bold text-slate-500">เฉพาะกลุ่มงาน</label>
        <select v-model="cfg.group_key" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="">ทุกกลุ่มงาน</option>
          <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
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
      <span class="text-xs text-slate-500 pb-2.5">= แสดง <b class="text-primary">{{ total }}</b> เล่มล่าสุด</span>
    </div>

    <div>
      <label class="text-[11px] font-bold text-slate-500">ข้อความลิงก์ใต้กริด (ไปหน้าคลังหนังสือทั้งหมด)</label>
      <input v-model="cfg.link_text" type="text" placeholder="ดูคลังหนังสือทั้งหมด"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
      <input type="checkbox" v-model="cfg.animate" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
      ให้การ์ดค่อยๆ โผล่ทีละใบตอนเลื่อนมาถึง
    </label>

    <div class="rounded-2xl border border-slate-200 bg-slate-50 p-3 text-[11px] text-slate-600">
      การ์ดเป็น<b>ภาพปกล้วน</b> เอาเมาส์ไปชี้จึงขึ้นชื่อเรื่องกับผู้เผยแพร่ ·
      บนมือถือที่ไม่มีเมาส์จะแสดงรายละเอียดตลอดเพื่อให้อ่านออกว่าเล่มไหนคืออะไร
    </div>
  </div>
</template>
