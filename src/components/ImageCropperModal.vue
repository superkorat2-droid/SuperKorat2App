<script setup>
/**
 * ImageCropperModal
 * Props:
 *   show        — แสดง/ซ่อน modal
 *   aspectRatio — สัดส่วนการครอบ (1 = สี่เหลี่ยมจัตุรัส, NaN = อิสระ)
 *   title       — ชื่อหัว modal
 * Emits:
 *   close       — ปิด modal
 *   cropped     — { blob, dataUrl } ภาพที่ครอบแล้ว
 */
import { ref, watch, onUnmounted, nextTick } from 'vue'
import Cropper from 'cropperjs'
import 'cropperjs/dist/cropper.css'

const props = defineProps({
  show:           { type: Boolean, default: false },
  aspectRatio:    { type: Number,  default: 1 },
  title:          { type: String,  default: 'ครอบรูปภาพ' },
  outputMaxWidth: { type: Number,  default: 1024 },
  outputMaxHeight:{ type: Number,  default: 1024 },
  outputType:     { type: String,  default: 'image/png' },
  outputQuality:  { type: Number,  default: 0.95 },
})
const emit = defineEmits(['close', 'cropped'])

const fileInput  = ref(null)
const imgEl      = ref(null)
const previewEl  = ref(null)
const imageSrc   = ref(null)
const isDragging = ref(false)
const cropper    = ref(null)
const cropping   = ref(false)

// aspect ratio options
const ratioOptions = [
  { label: '1:1 (สี่เหลี่ยมจัตุรัส)', value: 1 },
  { label: '16:9 (แนวนอน)',           value: 16/9 },
  { label: '4:3',                      value: 4/3 },
  { label: 'อิสระ',                   value: NaN },
]
const currentRatio = ref(props.aspectRatio)

// ── init / destroy cropper ─────────────────────────────────────
function initCropper() {
  if (cropper.value) { cropper.value.destroy(); cropper.value = null }
  if (!imgEl.value) return
  cropper.value = new Cropper(imgEl.value, {
    aspectRatio:     currentRatio.value,
    viewMode:        1,
    dragMode:        'move',
    autoCropArea:    0.85,
    responsive:      true,
    restore:         false,
    guides:          true,
    center:          true,
    highlight:       false,
    cropBoxMovable:  true,
    cropBoxResizable:true,
    toggleDragModeOnDblclick: false,
    preview:         previewEl.value,
  })
}

function destroyCropper() {
  if (cropper.value) { cropper.value.destroy(); cropper.value = null }
  imageSrc.value = null
}

watch(() => props.show, (val) => {
  if (!val) destroyCropper()
})

watch(currentRatio, (val) => {
  if (cropper.value) cropper.value.setAspectRatio(val)
})

onUnmounted(destroyCropper)

// ── file handling ──────────────────────────────────────────────
function onFileChange(e) {
  const file = e.target.files?.[0]
  if (file) loadFile(file)
  e.target.value = ''
}

function onDrop(e) {
  isDragging.value = false
  const file = e.dataTransfer.files?.[0]
  if (file && file.type.startsWith('image/')) loadFile(file)
}

function loadFile(file) {
  const reader = new FileReader()
  reader.onload = async (e) => {
    imageSrc.value = e.target.result
    await nextTick()
    initCropper()
  }
  reader.readAsDataURL(file)
}

// ── crop & emit ────────────────────────────────────────────────
function doCrop() {
  if (!cropper.value) return
  cropping.value = true
  const canvas = cropper.value.getCroppedCanvas({
    maxWidth:  props.outputMaxWidth,
    maxHeight: props.outputMaxHeight,
    imageSmoothingEnabled: true,
    imageSmoothingQuality: 'high',
  })
  canvas.toBlob((blob) => {
    const dataUrl = canvas.toDataURL(props.outputType, props.outputQuality)
    emit('cropped', { blob, dataUrl })
    cropping.value = false
  }, props.outputType, props.outputQuality)
}

function close() {
  destroyCropper()
  emit('close')
}

// ── zoom controls ──────────────────────────────────────────────
function zoom(factor) { cropper.value?.zoom(factor) }
function rotate(deg)  { cropper.value?.rotate(deg) }
function reset()      { cropper.value?.reset() }
function flip(axis)   {
  if (!cropper.value) return
  const d = cropper.value.getData()
  if (axis === 'x') cropper.value.scaleX(-d.scaleX || -1)
  else              cropper.value.scaleY(-d.scaleY || -1)
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-200"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-150"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0">

      <div v-if="show"
        class="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
        @click.self="close">

        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden font-sarabun">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
            <h3 class="font-extrabold text-slate-800 text-lg">✂️ {{ title }}</h3>
            <button @click="close" class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors text-lg">✕</button>
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto">

            <!-- Drop zone (ยังไม่มีรูป) -->
            <div v-if="!imageSrc" class="p-6">
              <div
                @dragover.prevent="isDragging = true"
                @dragleave="isDragging = false"
                @drop.prevent="onDrop"
                @click="fileInput.click()"
                :class="[
                  'border-2 border-dashed rounded-2xl p-12 text-center cursor-pointer transition-all',
                  isDragging
                    ? 'border-blue-400 bg-blue-50'
                    : 'border-slate-200 hover:border-blue-300 hover:bg-slate-50'
                ]">
                <div class="text-5xl mb-3">🖼️</div>
                <p class="font-bold text-slate-700">วางรูปภาพที่นี่ หรือ</p>
                <p class="text-sm text-slate-400 mt-1">คลิกเพื่อเลือกไฟล์ (JPG, PNG, WEBP)</p>
                <button class="mt-4 px-5 py-2 bg-primary text-white text-sm font-bold rounded-xl hover:bg-primary-dark transition-colors">
                  📁 เลือกไฟล์
                </button>
              </div>
              <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFileChange"/>
            </div>

            <!-- Cropper area -->
            <div v-else class="p-4 space-y-3">

              <!-- Ratio selector -->
              <div class="flex flex-wrap gap-1.5">
                <button v-for="r in ratioOptions" :key="r.label"
                  @click="currentRatio = r.value"
                  :class="[
                    'px-3 py-1 text-xs font-bold rounded-lg transition-all border',
                    currentRatio === r.value || (isNaN(currentRatio) && isNaN(r.value))
                      ? 'bg-primary text-white border-primary'
                      : 'border-slate-200 text-slate-600 hover:border-primary hover:text-primary'
                  ]">
                  {{ r.label }}
                </button>
              </div>

              <!-- Main cropper + preview side by side -->
              <div class="flex gap-3">
                <!-- Cropper -->
                <div class="flex-1 bg-slate-900 rounded-2xl overflow-hidden" style="height:320px">
                  <img ref="imgEl" :src="imageSrc" class="block max-w-full" style="max-height:320px"/>
                </div>
                <!-- Preview -->
                <div class="flex-shrink-0 flex flex-col items-center gap-2">
                  <p class="text-xs font-bold text-slate-500">ตัวอย่าง</p>
                  <div ref="previewEl"
                    class="rounded-xl overflow-hidden border-2 border-slate-200 bg-slate-100"
                    style="width:80px;height:80px"></div>
                  <div ref="previewEl"
                    class="rounded-full overflow-hidden border-2 border-slate-200 bg-slate-100"
                    style="width:60px;height:60px"></div>
                </div>
              </div>

              <!-- Controls -->
              <div class="flex flex-wrap items-center gap-1.5">
                <span class="text-xs font-bold text-slate-400 mr-1">ซูม:</span>
                <button @click="zoom(0.1)"  class="ctrl-btn">🔍+</button>
                <button @click="zoom(-0.1)" class="ctrl-btn">🔍-</button>
                <span class="text-xs font-bold text-slate-400 mx-1">หมุน:</span>
                <button @click="rotate(-90)" class="ctrl-btn">↺ 90°</button>
                <button @click="rotate(90)"  class="ctrl-btn">↻ 90°</button>
                <span class="text-xs font-bold text-slate-400 mx-1">พลิก:</span>
                <button @click="flip('x')" class="ctrl-btn">↔️</button>
                <button @click="flip('y')" class="ctrl-btn">↕️</button>
                <button @click="reset" class="ctrl-btn ml-2">🔄 Reset</button>
                <button @click="imageSrc=null;destroyCropper()" class="ctrl-btn text-red-500">🗑️ เปลี่ยนรูป</button>
              </div>
            </div>

          </div>

          <!-- Footer -->
          <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
            <button @click="close" class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">
              ยกเลิก
            </button>
            <button v-if="imageSrc"
              @click="doCrop" :disabled="cropping"
              class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
              <svg v-if="cropping" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
              </svg>
              ✂️ ครอบและใช้ภาพนี้
            </button>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.ctrl-btn {
  @apply px-2.5 py-1 text-xs font-bold border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors text-slate-600;
}
</style>
