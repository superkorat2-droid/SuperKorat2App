<script setup>
/**
 * ContentBlockEditor — block editor ของคลังสื่อ/ผลงาน
 *
 * สกัดจาก AdminMediaEditorView + SchoolMediaEditorView ที่มีโค้ดชุดนี้ซ้ำกันเกือบทั้งไฟล์
 * ตอนนี้ใช้ร่วมกัน 3 ที่: สื่อฝั่ง admin, สื่อฝั่งโรงเรียน, ผลงาน
 *
 * แก้ array ที่ส่งเข้ามาโดยตรง (pattern เดียวกับ ImageLinkGalleryEditor/YoutubeGridEditor)
 * `_key` ใช้เป็น :key เท่านั้น ต้องตัดออกก่อนบันทึกลง DB — ดู stripKeys()
 */
defineProps({
  blocks: { type: Array, required: true },
  title:  { type: String, default: 'เนื้อหา (Block Editor)' },
})

const BLOCK_TYPES = [
  { type:'heading',  label:'หัวข้อ',    icon:'H1' },
  { type:'text',     label:'ข้อความ',   icon:'¶'  },
  { type:'image',    label:'รูปภาพ',    icon:'🖼' },
  { type:'drive',    label:'Drive',     icon:'📄' },
  { type:'embed',    label:'Embed URL', icon:'🔗' },
  { type:'html',     label:'HTML',      icon:'<>' },
  { type:'divider',  label:'เส้นแบ่ง',  icon:'—'  },
]

const DEFAULTS = {
  heading: { type:'heading', text:'', level: 2 },
  text:    { type:'text', text:'' },
  image:   { type:'image', url:'', alt:'', caption:'' },
  drive:   { type:'drive', url:'', label:'' },
  embed:   { type:'embed', url:'', label:'' },
  html:    { type:'html', code:'' },
  divider: { type:'divider' },
}

function newKey() { return Date.now() + Math.random() }
</script>

<template>
  <div class="glass-card p-5 space-y-4">
    <h2 class="font-bold text-slate-700">{{ title }}</h2>

    <div class="space-y-3">
      <div v-for="(block, i) in blocks" :key="block._key"
        class="border border-slate-200 rounded-xl p-3 space-y-2 hover:border-primary/40 transition-colors">
        <div class="flex items-center justify-between gap-2">
          <span class="text-[10px] font-bold text-slate-400 uppercase bg-slate-100 px-2 py-0.5 rounded">{{ block.type }}</span>
          <div class="flex gap-1 flex-shrink-0">
            <button type="button" @click="i > 0 && blocks.splice(i - 1, 0, blocks.splice(i, 1)[0])" :disabled="i === 0"
              class="w-6 h-6 flex items-center justify-center text-slate-400 hover:bg-slate-100 rounded disabled:opacity-20" title="เลื่อนขึ้น">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
            </button>
            <button type="button" @click="i < blocks.length - 1 && blocks.splice(i + 1, 0, blocks.splice(i, 1)[0])" :disabled="i === blocks.length - 1"
              class="w-6 h-6 flex items-center justify-center text-slate-400 hover:bg-slate-100 rounded disabled:opacity-20" title="เลื่อนลง">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
            </button>
            <button type="button" @click="blocks.splice(i, 1)"
              class="w-6 h-6 flex items-center justify-center text-slate-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors" title="ลบ">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
        </div>

        <div v-if="block.type==='heading'" class="flex gap-2">
          <select v-model="block.level" class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white">
            <option :value="2">H2</option><option :value="3">H3</option><option :value="4">H4</option>
          </select>
          <input v-model="block.text" type="text" placeholder="หัวข้อ..." class="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-sm font-bold focus:outline-none focus:border-primary"/>
        </div>

        <textarea v-else-if="block.type==='text'" v-model="block.text" rows="3" placeholder="ข้อความ..."
          class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm resize-none focus:outline-none focus:border-primary"/>

        <div v-else-if="block.type==='image'" class="space-y-1.5">
          <input v-model="block.url" type="url" placeholder="URL รูปภาพ https://..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-primary"/>
          <input v-model="block.caption" type="text" placeholder="คำอธิบายรูป (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
        </div>

        <div v-else-if="block.type==='drive'" class="space-y-1.5">
          <div class="flex items-center gap-1.5 text-xs text-amber-600 bg-amber-50 rounded-lg px-3 py-2">
            <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"/></svg>
            ต้องตั้งค่า Google Drive เป็น "ทุกคนที่มีลิงก์" ก่อนวาง
          </div>
          <input v-model="block.url" type="url" placeholder="https://drive.google.com/file/d/..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:border-primary"/>
          <input v-model="block.label" type="text" placeholder="ชื่อที่แสดง (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
        </div>

        <div v-else-if="block.type==='embed'" class="space-y-1.5">
          <input v-model="block.url" type="url" placeholder="https://www.youtube.com/watch?v=... หรือ URL embed อื่นๆ" class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:border-primary"/>
          <input v-model="block.label" type="text" placeholder="ชื่อที่แสดง (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
        </div>

        <div v-else-if="block.type==='html'" class="space-y-1.5">
          <p class="text-[10px] text-slate-400">HTML ทั้งหมด (รวม &lt;!DOCTYPE&gt;) จะ render ใน iframe แยก</p>
          <textarea v-model="block.code" rows="6" placeholder="<!DOCTYPE html>..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-xs font-mono resize-y focus:outline-none focus:border-primary"/>
        </div>

        <div v-else-if="block.type==='divider'" class="py-1"><hr class="border-slate-200"/></div>
      </div>
    </div>

    <div class="flex flex-wrap gap-2 pt-2 border-t border-slate-100">
      <button v-for="bt in BLOCK_TYPES" :key="bt.type" type="button"
        @click="blocks.push({ ...DEFAULTS[bt.type], _key: newKey() })"
        class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-600 rounded-xl hover:bg-primary/10 hover:text-primary transition-colors">
        <span>{{ bt.icon }}</span> {{ bt.label }}
      </button>
    </div>
  </div>
</template>
