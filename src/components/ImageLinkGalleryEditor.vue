<script setup>
import { ref, computed } from 'vue'
import { supabase } from '../supabase'
import ImageCropperModal from './ImageCropperModal.vue'
import { useExternalUpload, externalUploadEnabled } from '../composables/useExternalUpload'

// mutate โดยตรง (แบบเดียวกับ blocks.value[idx].url = url ใน AdminPageEditorView.vue)
const props = defineProps({
  gallery: { type: Object, required: true }, // { layout, title, items }
})

const LAYOUTS = [
  { value: 'card',      label: 'การ์ดกริด',      hint: 'รูป + หัวข้อ เหมาะแสดงรายการหลัก', ratio: 16/9, size: '1200×675 px (16:9)' },
  { value: 'mosaic',    label: 'กริดรูปล้วน',    hint: 'ไม่มีข้อความ เน้นภาพ สี่เหลี่ยมจัตุรัส', ratio: 1, size: '1000×1000 px (1:1)' },
  { value: 'rectangle', label: 'กริดผืนผ้า',    hint: 'ไม่มีข้อความ เน้นภาพ สี่เหลี่ยมผืนผ้า', ratio: 4/3, size: '1200×900 px (4:3)' },
  { value: 'list',      label: 'รายการแนวนอน',  hint: 'รูปเล็ก + ข้อความข้าง เหมาะมือถือ', ratio: 1, size: '400×400 px (1:1)' },
]
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
    <div>
      <label class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2 block">รูปแบบการแสดงผล</label>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <button v-for="l in LAYOUTS" :key="l.value" type="button" @click="gallery.layout = l.value"
          :class="['text-left p-3 rounded-2xl border-2 transition-all',
            gallery.layout === l.value ? 'border-primary bg-primary/5' : 'border-slate-200 hover:border-slate-300']">
          <!-- Preview swatch -->
          <div class="h-14 mb-2 flex items-center gap-1" >
            <template v-if="l.value === 'card'">
              <div v-for="n in 3" :key="n" class="flex-1 h-full rounded bg-slate-200 flex flex-col justify-end p-0.5">
                <div class="h-1.5 bg-slate-300 rounded-sm"></div>
              </div>
            </template>
            <template v-else-if="l.value === 'mosaic'">
              <div v-for="n in 4" :key="n" class="flex-1 aspect-square rounded bg-slate-200"></div>
            </template>
            <template v-else-if="l.value === 'rectangle'">
              <div v-for="n in 3" :key="n" class="flex-1 aspect-[4/3] rounded bg-slate-200"></div>
            </template>
            <template v-else>
              <div class="flex-1 h-full flex flex-col gap-1">
                <div v-for="n in 3" :key="n" class="flex-1 flex items-center gap-1">
                  <div class="w-4 h-full rounded bg-slate-300 flex-shrink-0"></div>
                  <div class="flex-1 h-1.5 bg-slate-200 rounded-sm"></div>
                </div>
              </div>
            </template>
          </div>
          <p class="text-xs font-bold text-slate-700">{{ l.label }}</p>
          <p class="text-[10px] text-slate-400">{{ l.hint }}</p>
        </button>
      </div>
      <p class="text-xs text-slate-500 mt-2 flex items-center gap-1.5">
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
