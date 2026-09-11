<script setup>
/**
 * VisitPhotoUploader — แนบรูปการนิเทศจากมือถือ
 *
 * ทุกไฟล์ผ่าน useImagePipeline ก่อนอัปเสมอ: หมุนตาม EXIF → ย่อ 1600px → JPEG
 * ทำให้รูป 8 MB จากมือถือเหลือราว 400 KB (PHP host รับไม่เกิน 5 MB)
 *
 * ครอบรูปได้เฉพาะรูปที่เพิ่งเลือกในรอบนี้ เพราะยังมีไฟล์อยู่ในเครื่อง —
 * รูปที่โหลดกลับมาจากฐานข้อมูลอยู่คนละโดเมน เอาเข้า canvas แล้วจะปนเปื้อนจน
 * บันทึกไม่ได้ ผู้ใช้ที่อยากแก้ให้ลบแล้วอัปใหม่แทน
 *
 * รูปใบแรกในลิสต์คือภาพปกอัตโนมัติ ไม่ต้องอัปปกแยก
 */
import { ref, computed, onBeforeUnmount } from 'vue'
import Swal from 'sweetalert2'
import ImageCropperModal from '../ImageCropperModal.vue'
import { prepareImage, shrinkLabel, ImageDecodeError } from '../../composables/useImagePipeline'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { supabase } from '../../supabase'

const props = defineProps({
  // [{ url, caption, w, h }] — แก้ array นี้ตรง ๆ แบบเดียวกับ ImageLinkGalleryEditor
  modelValue: { type: Array, required: true },
  category:   { type: String, default: 'nithet' },
  gc:         { type: Object, default: null },   // useUploadGc() จากหน้าแม่
})

const { uploadImage } = useExternalUpload()
const photos = props.modelValue

const busy       = ref(false)
// ตกไปใช้ Supabase แล้วในรอบนี้ (โฮสต์ของเขตตอบไม่ได้)
const fellBack   = ref(false)
const progress   = ref({ done: 0, total: 0 })
const lastShrink = ref('')
// blob URL ของรูปที่เพิ่งเลือกรอบนี้ — ใช้ครอบได้โดยไม่ติด CORS
const localSrc   = ref({})

const cropTarget  = ref(null)
const showCropper = computed(() => !!cropTarget.value)
const freeRatio   = Number.NaN

function isFresh(p) { return !!localSrc.value[p.url] }

// ทางสำรองเมื่อโฮสต์ของเขตใช้ไม่ได้ — bucket images มี policy ให้ ศน. อัป/ลบได้ครบ
// (deleteUploadedFile รู้จัก URL ทั้งสองแบบอยู่แล้ว ระบบเก็บกวาดจึงยังทำงานถูก)
async function uploadToBucket(blob) {
  const path = `nithet/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.jpg`
  const { error } = await supabase.storage.from('images').upload(path, blob, { contentType: 'image/jpeg' })
  if (error) throw new Error(error.message)
  return supabase.storage.from('images').getPublicUrl(path).data.publicUrl
}

async function uploadBlob(blob) {
  if (externalUploadEnabled && !fellBack.value) {
    try {
      return await uploadImage(blob, props.category)
    } catch (err) {
      // โฮสต์ของเขตล่ม หรือยังไม่ได้ตั้งความลับให้ media-upload (เช่นตอนรันในเครื่อง)
      // ศน. อยู่หน้างานบนมือถือ จะให้เสียงานที่กรอกมาทั้งหมดเพราะรูปไม่ได้ไม่ไหว
      // จำไว้ทั้งรอบ ไม่ลองใหม่ทีละไฟล์ ไม่งั้นอัป 10 รูปต้องรอ timeout 10 รอบ
      console.warn('[nithet] อัปขึ้นโฮสต์ของเขตไม่สำเร็จ ใช้ Supabase แทน:', err?.message || err)
      fellBack.value = true
    }
  }
  return await uploadToBucket(blob)
}

async function onPick(e) {
  const files = [...(e.target.files || [])]
  e.target.value = ''
  if (!files.length) return

  busy.value = true
  progress.value = { done: 0, total: files.length }
  const problems = []

  for (const file of files) {
    try {
      const { blob, w, h, before, after } = await prepareImage(file)
      const url = await uploadBlob(blob)
      photos.push({ url, caption: '', w, h })
      props.gc?.trackUploaded(url)
      localSrc.value[url] = URL.createObjectURL(blob)
      lastShrink.value = shrinkLabel(before, after)
    } catch (err) {
      problems.push(err instanceof ImageDecodeError ? err.message : `${file.name}: ${err.message}`)
    } finally {
      progress.value.done++
    }
  }

  busy.value = false
  if (problems.length) {
    Swal.fire({
      icon: 'warning',
      title: `มี ${problems.length} ไฟล์ที่ใช้ไม่ได้`,
      html: `<div style="text-align:left;white-space:pre-line;font-size:13px">${problems.join('\n\n')}</div>`,
    })
  }
}

function removeAt(i) {
  const gone = photos.splice(i, 1)[0]
  if (gone?.url) {
    props.gc?.trackReplaced(gone.url)
    if (localSrc.value[gone.url]) {
      URL.revokeObjectURL(localSrc.value[gone.url])
      delete localSrc.value[gone.url]
    }
  }
}

function move(i, dir) {
  const j = i + dir
  if (j < 0 || j >= photos.length) return
  const tmp = photos[i]
  photos[i] = photos[j]
  photos[j] = tmp
}

function openCrop(i) {
  const p = photos[i]
  if (!isFresh(p)) return
  cropTarget.value = { index: i, src: localSrc.value[p.url] }
}

async function onCropped(payload) {
  const t = cropTarget.value
  cropTarget.value = null
  if (!t) return
  busy.value = true
  try {
    const old = photos[t.index]
    const url = await uploadBlob(payload.blob)
    props.gc?.trackReplaced(old.url)      // ลบไฟล์เดิมตอนบันทึกสำเร็จ
    props.gc?.trackUploaded(url)
    if (localSrc.value[old.url]) {
      URL.revokeObjectURL(localSrc.value[old.url])
      delete localSrc.value[old.url]
    }
    localSrc.value[url] = URL.createObjectURL(payload.blob)
    // อ่านขนาดใหม่หลังครอบ เพื่อให้รายงานรู้ว่าแนวตั้งหรือแนวนอน
    const dim = await new Promise((res) => {
      const img = new Image()
      img.onload  = () => res({ w: img.naturalWidth, h: img.naturalHeight })
      img.onerror = () => res({ w: old.w, h: old.h })
      img.src = localSrc.value[url]
    })
    photos[t.index] = { url, caption: old.caption || '', w: dim.w, h: dim.h }
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'ครอบรูปไม่สำเร็จ', text: err.message })
  } finally {
    busy.value = false
  }
}

onBeforeUnmount(() => {
  Object.values(localSrc.value).forEach(u => URL.revokeObjectURL(u))
})
</script>

<template>
  <div class="space-y-3">
    <div class="flex flex-wrap items-center gap-2">
      <!-- capture="environment" = กดแล้วเปิดกล้องหลังบนมือถือได้เลย -->
      <label class="px-4 py-2.5 rounded-xl text-sm font-bold border-2 border-dashed border-slate-300 text-slate-600
                    hover:border-primary hover:text-primary transition-all cursor-pointer">
        {{ busy ? `กำลังอัป ${progress.done}/${progress.total}...` : '📷 เพิ่มรูป' }}
        <input type="file" accept="image/*" capture="environment" multiple class="hidden" :disabled="busy" @change="onPick"/>
      </label>
      <span v-if="photos.length" class="text-xs text-slate-500">
        {{ photos.length }} รูป · ใบแรกใช้เป็นภาพปก
      </span>
      <span v-if="lastShrink" class="text-xs text-emerald-600">ย่อแล้ว {{ lastShrink }}</span>
    </div>

    <p v-if="!externalUploadEnabled || fellBack"
      class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2">
      <template v-if="fellBack">
        ที่เก็บไฟล์ของเขตตอบไม่ได้ตอนนี้ — รูปรอบนี้เก็บสำรองไว้ใน Supabase ซึ่งมีพื้นที่จำกัด
        บันทึกงานได้ตามปกติ แต่ถ้าเจอบ่อยให้แจ้งผู้ดูแลระบบ
      </template>
      <template v-else>
        ยังไม่ได้ตั้งค่าที่เก็บไฟล์ของเขต — รูปจะถูกเก็บใน Supabase ซึ่งมีพื้นที่จำกัด
      </template>
    </p>

    <div v-if="photos.length" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
      <div v-for="(p, i) in photos" :key="p.url" class="glass-card overflow-hidden">
        <div class="relative aspect-[4/3] bg-slate-100">
          <img :src="localSrc[p.url] || p.url" :alt="p.caption || `รูปที่ ${i + 1}`"
            class="w-full h-full object-cover" loading="lazy"/>
          <span v-if="i === 0"
            class="absolute top-1.5 left-1.5 text-[10px] font-bold text-white bg-primary px-2 py-0.5 rounded-full">ปก</span>
        </div>

        <div class="p-2 space-y-1.5">
          <input v-model="p.caption" type="text" placeholder="คำบรรยาย (ไม่ใส่ก็ได้)"
            class="w-full px-2 py-1.5 rounded-lg border border-slate-200 text-xs bg-white focus:outline-none focus:border-primary"/>
          <div class="flex items-center gap-1">
            <button type="button" @click="move(i, -1)" :disabled="i === 0" title="เลื่อนซ้าย"
              class="w-7 h-7 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-30">←</button>
            <button type="button" @click="move(i, 1)" :disabled="i === photos.length - 1" title="เลื่อนขวา"
              class="w-7 h-7 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-30">→</button>
            <button v-if="isFresh(p)" type="button" @click="openCrop(i)" :disabled="busy"
              class="ml-auto px-2 py-1 rounded-lg text-[11px] font-bold text-primary hover:bg-slate-100">ครอบ</button>
            <button type="button" @click="removeAt(i)"
              :class="['px-2 py-1 rounded-lg text-[11px] font-bold text-red-500 hover:bg-red-50', isFresh(p) ? '' : 'ml-auto']">ลบ</button>
          </div>
        </div>
      </div>
    </div>

    <!-- ครอบแล้วต้องได้ JPEG 1600px ไม่ใช่ค่าเริ่มต้น PNG 1024 ที่ไฟล์ใหญ่กว่ามาก -->
    <ImageCropperModal
      :show="showCropper"
      :src="cropTarget?.src || ''"
      :aspect-ratio="freeRatio"
      title="ครอบรูป (ลากปรับได้อิสระ)"
      :output-max-width="1600"
      :output-max-height="1600"
      output-type="image/jpeg"
      :output-quality="0.82"
      @close="cropTarget = null"
      @cropped="onCropped"/>
  </div>
</template>
