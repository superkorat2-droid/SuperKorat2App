<script setup>
import { ref, computed } from 'vue'
import { supabase } from '../supabase'
import ImageCropperModal from './ImageCropperModal.vue'
import { useExternalUpload, externalUploadEnabled } from '../composables/useExternalUpload'
import { useInternalPages } from '../composables/useInternalPages'

// mutate โดยตรง (แบบเดียวกับ blocks.value[idx].url = url ใน AdminPageEditorView.vue)
const props = defineProps({
  gallery: { type: Object, required: true }, // { layout, title, items }
})

const { internalPages } = useInternalPages()

const LAYOUTS = [
  { value: 'card',      group: 'การ์ด/รายการ', label: 'การ์ดแนวนอน 2:1',        hint: 'ภาพเต็มการ์ด + ข้อความซ้อนล่าง เสมอ', ratio: 2/1, size: '1200×600 px (2:1)', caption: 'overlay-always' },
  { value: 'list',      group: 'การ์ด/รายการ', label: 'รายการแนวนอน',          hint: 'ภาพซ้าย + ข้อความขวา',              ratio: 1,   size: '400×400 px (1:1)',   caption: 'side' },

  { value: 'rect-half-3',       group: 'ผืนผ้าเตี้ย 8:3', label: 'ผืนผ้าเตี้ย 3 คอลัมน์',        hint: 'ภาพล้วน ไม่มีข้อความ',       ratio: 8/3, size: '1600×600 px (8:3)', caption: 'none' },
  { value: 'rect-half-4',       group: 'ผืนผ้าเตี้ย 8:3', label: 'ผืนผ้าเตี้ย 4 คอลัมน์',        hint: 'ภาพล้วน ไม่มีข้อความ',       ratio: 8/3, size: '1600×600 px (8:3)', caption: 'none' },
  { value: 'rect-half-caption', group: 'ผืนผ้าเตี้ย 8:3', label: 'ผืนผ้าเตี้ย 3 คอลัมน์ + ข้อความ', hint: 'ข้อความซ้อนบนภาพ (hover)', ratio: 8/3, size: '1600×600 px (8:3)', caption: 'overlay' },

  { value: 'rect-landscape',         group: 'สี่เหลี่ยมผืนผ้า', label: 'แนวนอน 3 คอลัมน์',           hint: 'ภาพล้วน ไม่มีข้อความ',       ratio: 4/3, size: '1200×900 px (4:3)', caption: 'none' },
  { value: 'rect-landscape-caption', group: 'สี่เหลี่ยมผืนผ้า', label: 'แนวนอน 3 คอลัมน์ + ข้อความ',  hint: 'ข้อความซ้อนบนภาพ (hover)', ratio: 4/3, size: '1200×900 px (4:3)', caption: 'overlay' },
  { value: 'rect-landscape-below',   group: 'สี่เหลี่ยมผืนผ้า', label: 'แนวนอน 4 คอลัมน์ + ข้อความ',  hint: 'ข้อความอยู่ใต้ภาพแบบการ์ด',  ratio: 4/3, size: '1200×900 px (4:3)', caption: 'below' },
  { value: 'rect-portrait',          group: 'สี่เหลี่ยมผืนผ้า', label: 'แนวตั้ง 4 คอลัมน์',          hint: 'ภาพล้วน ไม่มีข้อความ',       ratio: 3/4, size: '900×1200 px (3:4)', caption: 'none' },
]
const LAYOUT_GROUPS = ['การ์ด/รายการ', 'ผืนผ้าเตี้ย 8:3', 'สี่เหลี่ยมผืนผ้า']
const currentLayout = computed(() => LAYOUTS.find(l => l.value === props.gallery.layout) || LAYOUTS[0])

function newItem() {
  return { id: crypto.randomUUID(), image_url: '', title: '', caption: '', link_type: 'none', link_url: '' }
}
function addItem() {
  if (!Array.isArray(props.gallery.items)) props.gallery.items = []
  props.gallery.items.push(newItem())
}
function removeItem(i) { props.gallery.items.splice(i, 1) }
function moveUp(i) {
  if (i === 0) return
  ;[props.gallery.items[i - 1], props.gallery.items[i]] = [props.gallery.items[i], props.gallery.items[i - 1]]
}
function moveDown(i) {
  if (i === props.gallery.items.length - 1) return
  ;[props.gallery.items[i + 1], props.gallery.items[i]] = [props.gallery.items[i], props.gallery.items[i + 1]]
}

// ── อัปโหลดรูปต่อรายการ ──────────────────────────────────────────
const showCropper  = ref(false)
const cropIdx      = ref(null)
const uploading    = ref(false)
const uploadErr    = ref('')
const { uploadImage: uploadExternal } = useExternalUpload()

function openCropper(i) {
  cropIdx.value   = i
  uploadErr.value = ''
  showCropper.value = true
}
async function onCropped({ blob }) {
  uploading.value = true
  uploadErr.value = ''
  try {
    let url
    if (externalUploadEnabled) {
      url = await uploadExternal(blob, 'gallery')
    } else {
      const fileName = `gallery/img_${Date.now()}.png`
      const { error } = await supabase.storage.from('images').upload(fileName, blob, { contentType: 'image/png', upsert: false })
      if (error) throw error
      const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(fileName)
      url = publicUrl
    }
    props.gallery.items[cropIdx.value].image_url = url
    showCropper.value = false
  } catch (e) {
    uploadErr.value = e.message || 'อัปโหลดรูปไม่สำเร็จ'
  }
  uploading.value = false
}
</script>

<template>
  <div class="space-y-4">
    <div>
      <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">หัวข้อเซกชัน (ไม่บังคับ)</label>
      <input v-model="gallery.title" type="text" placeholder="เช่น ผลงานเด่น"
        class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
    </div>

    <!-- Layout picker พร้อมตัวอย่าง -->
    <div class="space-y-3">
      <label class="text-xs font-bold text-slate-500 uppercase tracking-wider block">รูปแบบการแสดงผล</label>

      <div v-for="group in LAYOUT_GROUPS" :key="group">
        <p class="text-[11px] font-bold text-slate-400 mb-1.5">{{ group }}</p>
        <div class="grid grid-cols-3 sm:grid-cols-4 gap-2 mb-2">
          <button v-for="l in LAYOUTS.filter(x => x.group === group)" :key="l.value" type="button" @click="gallery.layout = l.value" :title="l.hint"
            :class="['text-left p-2 rounded-xl border-2 transition-all',
              gallery.layout === l.value ? 'border-primary bg-primary/5' : 'border-slate-200 hover:border-slate-300']">
            <!-- Preview swatch -->
            <div v-if="l.value === 'list'" class="h-8 mb-1.5 flex flex-col gap-0.5 justify-center">
              <div v-for="n in 3" :key="n" class="flex-1 flex items-center gap-1">
                <div class="w-3 h-full rounded bg-slate-300 flex-shrink-0"></div>
                <div class="flex-1 h-1 bg-slate-200 rounded-sm"></div>
              </div>
            </div>
            <div v-else class="h-8 mb-1.5 flex items-end gap-0.5">
              <div v-for="n in 3" :key="n" class="flex-1 relative rounded-sm bg-slate-200 overflow-hidden" :style="{ aspectRatio: l.ratio }">
                <div v-if="l.caption === 'below' && n === 1" class="absolute inset-x-0 bottom-0 h-1 bg-slate-300"></div>
                <div v-if="(l.caption === 'overlay' || l.caption === 'overlay-always') && n === 1" class="absolute inset-x-0 bottom-0 h-1.5 bg-slate-400/60"></div>
              </div>
            </div>
            <p class="text-[11px] font-bold text-slate-700 leading-tight">{{ l.label }}</p>
          </button>
        </div>
      </div>

      <p class="text-xs text-slate-500 flex items-center gap-1.5">
        <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/></svg>
        แนะนำขนาดภาพสำหรับรูปแบบนี้: <b class="text-slate-700">{{ currentLayout.size }}</b>
      </p>
    </div>

    <!-- Items -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">รูปภาพ ({{ gallery.items?.length || 0 }})</label>
        <button @click="addItem" type="button" class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
          เพิ่มรูป
        </button>
      </div>

      <div v-if="!gallery.items?.length" class="text-center py-8 bg-slate-50 rounded-2xl text-sm text-slate-400">
        ยังไม่มีรูปภาพ กด "เพิ่มรูป" เพื่อเริ่มต้น
      </div>

      <div v-for="(item, i) in gallery.items" :key="item.id" class="flex gap-3 p-3 bg-slate-50 rounded-2xl border border-slate-100 mb-2">
        <div class="flex flex-col gap-0.5 flex-shrink-0">
          <button @click="moveUp(i)" :disabled="i === 0" type="button" class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
          </button>
          <button @click="moveDown(i)" :disabled="i === gallery.items.length - 1" type="button" class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
          </button>
        </div>

        <button @click="openCropper(i)" type="button" class="w-16 h-16 flex-shrink-0 bg-slate-200 rounded-xl overflow-hidden flex items-center justify-center hover:opacity-80 transition-opacity">
          <img v-if="item.image_url" :src="item.image_url" class="w-full h-full object-cover"/>
          <svg v-else class="w-6 h-6 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 12V4.5A2.25 2.25 0 015.25 2.25h13.5A2.25 2.25 0 0121 4.5V12M3 12v7.5A2.25 2.25 0 005.25 21.75h13.5A2.25 2.25 0 0021 19.5V12M3 12l4.5-4.5"/></svg>
        </button>

        <div class="flex-1 min-w-0 space-y-1.5">
          <input v-model="item.title" type="text" placeholder="หัวข้อ"
            class="w-full px-2.5 py-1.5 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
          <input v-model="item.caption" type="text" placeholder="คำอธิบายสั้น (ไม่บังคับ)"
            class="w-full px-2.5 py-1.5 text-xs border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
          <div class="flex gap-1.5">
            <select v-model="item.link_type" class="px-2 py-1.5 text-xs border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary">
              <option value="none">ไม่มีลิงก์</option>
              <option value="internal">ลิงก์ภายใน</option>
              <option value="external">ลิงก์ภายนอก</option>
            </select>
            <input v-if="item.link_type !== 'none'" v-model="item.link_url" type="text"
              :placeholder="item.link_type === 'internal' ? '/page/xxx' : 'https://...'"
              class="flex-1 px-2.5 py-1.5 text-xs border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
          </div>
          <!-- เลือกจากหน้าที่มีอยู่จริง กันพิมพ์ path เองแล้วผิด (เช่นลืม /page/ นำหน้า) -->
          <select v-if="item.link_type === 'internal'" @change="item.link_url = $event.target.value; $event.target.value = ''"
            class="w-full px-2.5 py-1.5 text-xs border border-slate-200 rounded-lg bg-white text-slate-500 focus:outline-none focus:border-primary">
            <option value="">— หรือเลือกจากหน้าที่มีอยู่ —</option>
            <option v-for="p in internalPages" :key="p.path" :value="p.path">{{ p.title }} ({{ p.path }})</option>
          </select>
        </div>

        <button @click="removeItem(i)" type="button" class="flex-shrink-0 text-slate-300 hover:text-red-500 self-start">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
        </button>
      </div>
    </div>

    <ImageCropperModal :show="showCropper" :aspect-ratio="currentLayout.ratio" :title="`ครอบรูปภาพ (${currentLayout.size})`"
      :output-max-width="1600" :output-max-height="1600" output-type="image/jpeg" :output-quality="0.85"
      @close="showCropper = false" @cropped="onCropped"/>
    <p v-if="uploadErr" class="text-xs text-red-500">{{ uploadErr }}</p>
  </div>
</template>
