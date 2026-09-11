<script setup>
/**
 * LinkListEditor — ลิงก์แนบหลายลิงก์ (อัลบั้ม Drive, เอกสาร, คลิป)
 *
 * ใช้แทนการอัปไฟล์เอกสาร เพราะ PHP host ของเขตรับแค่รูปกับวิดีโอ ไม่รับ PDF
 * และลิงก์ไม่กินพื้นที่โฮสต์เลย — ครั้งไหนรูปเยอะมากก็แปะลิงก์อัลบั้มแทนได้
 */
import { linkKind, LINK_ICON } from '../../composables/useNithetVisits'

const props = defineProps({
  modelValue: { type: Array, required: true },   // [{ url, label, kind }] — แก้ array ตรง ๆ
})

const links = props.modelValue

function add() {
  links.push({ url: '', label: '', kind: 'other' })
}

function remove(i) {
  links.splice(i, 1)
}

// เดาชนิดให้เองตอนวางลิงก์ ผู้ใช้ไม่ต้องเลือก
function onUrl(i) {
  links[i].kind = linkKind(links[i].url)
}
</script>

<template>
  <div class="space-y-2">
    <label class="text-[11px] font-bold text-slate-500">ลิงก์แนบ (ไม่ใส่ก็ได้)</label>

    <div v-for="(l, i) in links" :key="i" class="flex gap-2 items-start">
      <span class="w-8 h-9 flex items-center justify-center text-lg flex-shrink-0">{{ LINK_ICON[l.kind] || '🔗' }}</span>
      <div class="flex-1 space-y-1.5">
        <input v-model="l.url" @input="onUrl(i)" type="url" placeholder="https://drive.google.com/..."
          class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
        <input v-model="l.label" type="text" placeholder="ชื่อลิงก์ เช่น อัลบั้มภาพกิจกรรม"
          class="w-full px-3 py-1.5 rounded-xl border border-slate-200 text-xs bg-white focus:outline-none focus:border-primary"/>
      </div>
      <button type="button" @click="remove(i)"
        class="w-8 h-9 rounded-lg text-red-500 hover:bg-red-50 flex-shrink-0" aria-label="ลบลิงก์">×</button>
    </div>

    <button type="button" @click="add"
      class="px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-dashed border-slate-300 text-slate-500
             hover:border-primary hover:text-primary transition-all">
      + เพิ่มลิงก์
    </button>
  </div>
</template>
