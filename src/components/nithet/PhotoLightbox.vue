<script setup>
/**
 * PhotoLightbox — ดูภาพเต็มใบ ไม่ครอบ
 *
 * แกลเลอรีในหน้ารายละเอียดครอบเป็น 4:3 ให้เป็นระเบียบ พอกดดูต้องเห็นของจริงครบ
 * จึงใช้ object-contain ที่นี่ (กติกาเดียวกับรายงาน A4)
 *
 * โครง ESC + ล็อกการเลื่อนพื้นหลัง ลอกจาก VideoPlayerModal
 * เพิ่มปุ่มลูกศรซ้าย/ขวาเพราะบันทึกหนึ่งครั้งมักมี 5-10 รูป
 */
import { computed, watch, onBeforeUnmount } from 'vue'

const props = defineProps({
  photos: { type: Array, default: () => [] },
  index:  { type: Number, default: -1 },   // -1 = ปิด
})
const emit = defineEmits(['close', 'update:index'])

const open    = computed(() => props.index >= 0 && props.index < props.photos.length)
const current = computed(() => (open.value ? props.photos[props.index] : null))

function step(d) {
  if (!props.photos.length) return
  const n = props.photos.length
  emit('update:index', (props.index + d + n) % n)
}

function onKey(e) {
  if (e.key === 'Escape') emit('close')
  else if (e.key === 'ArrowRight') step(1)
  else if (e.key === 'ArrowLeft') step(-1)
}

watch(open, v => {
  if (v) {
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKey)
  } else {
    document.body.style.overflow = ''
    window.removeEventListener('keydown', onKey)
  }
})

// ต้องคืนค่าเสมอ ไม่งั้นกด back ขณะเปิดอยู่ หน้าเว็บจะเลื่อนไม่ได้ถาวร
onBeforeUnmount(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onKey)
})
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0">
      <div v-if="open" class="fixed inset-0 z-[110] bg-black/85 backdrop-blur-sm flex flex-col"
        @click.self="$emit('close')">

        <div class="flex items-center gap-3 px-4 py-3 text-white/80 flex-shrink-0">
          <span class="text-sm font-bold tabular-nums">{{ index + 1 }} / {{ photos.length }}</span>
          <button @click="$emit('close')" aria-label="ปิด"
            class="ml-auto w-9 h-9 flex items-center justify-center rounded-xl bg-white/10 hover:bg-white/20 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <div class="flex-1 min-h-0 flex items-center gap-2 px-2 pb-2" @click.self="$emit('close')">
          <button v-if="photos.length > 1" @click="step(-1)" aria-label="รูปก่อนหน้า"
            class="w-10 h-10 flex-shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
            </svg>
          </button>

          <img v-if="current" :src="current.url" :alt="current.caption || ''"
            class="flex-1 min-w-0 max-h-full object-contain select-none"/>

          <button v-if="photos.length > 1" @click="step(1)" aria-label="รูปถัดไป"
            class="w-10 h-10 flex-shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
            </svg>
          </button>
        </div>

        <p v-if="current?.caption" class="flex-shrink-0 text-center text-sm text-white/80 px-4 pb-4">
          {{ current.caption }}
        </p>
      </div>
    </Transition>
  </Teleport>
</template>
