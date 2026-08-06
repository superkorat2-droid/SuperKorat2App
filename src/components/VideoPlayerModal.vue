<script setup>
/**
 * VideoPlayerModal — เล่นคลิปในหน้าเดิม รองรับทั้ง YouTube และ Google Drive
 *
 * โครง modal ลอกจาก DriveFilePreviewModal (มือถือเด้งจากขอบล่าง หัว sticky)
 * แต่ต่างกัน 3 จุดที่สำคัญ:
 *   1. กรอบวิดีโอเป็น aspect-video ไม่ใช่ flex-1 เต็มจอ — ไม่งั้นคลิปจะมีแถบดำหนา
 *   2. iframe อยู่ใต้ v-if ทั้งชั้น เพื่อให้ DOM หายจริงตอนปิด
 *      ถ้าใช้ v-show หรือปล่อย src ค้างไว้ **เสียงจะเล่นต่อหลังปิดโมดัล**
 *   3. รองรับ ESC + ล็อกการเลื่อนพื้นหลัง (โมดัลตัวแรกของโปรเจคที่ทำ)
 */
import { computed, watch, onBeforeUnmount } from 'vue'
import { videoEmbedUrl, videoWatchUrl, categoryLabel, categoryColor,
         ownerTypeLabel, fmtViews } from '../composables/useVideos'

const props = defineProps({
  item: { type: Object, default: null },   // null = ปิด
})
const emit = defineEmits(['close'])

const src      = computed(() => (props.item ? videoEmbedUrl(props.item) : ''))
const watchUrl = computed(() => videoWatchUrl(props.item))
const sourceLabel = computed(() => (props.item?.source === 'drive' ? 'Google Drive' : 'YouTube'))

function onKey(e) { if (e.key === 'Escape') emit('close') }

watch(() => props.item, (v) => {
  if (v) {
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKey)
  } else {
    document.body.style.overflow = ''
    window.removeEventListener('keydown', onKey)
  }
})

// ต้องคืนค่าเสมอ ไม่งั้นกด back ขณะโมดัลเปิด หน้าเว็บจะเลื่อนไม่ได้ค้างถาวร
onBeforeUnmount(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onKey)
})
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0">
      <div v-if="item"
        class="fixed inset-0 z-[110] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/70 backdrop-blur-sm"
        @click.self="$emit('close')">
        <div class="glass-panel rounded-t-3xl sm:rounded-3xl w-full sm:max-w-5xl max-h-[95dvh] flex flex-col overflow-hidden">

          <div class="sticky top-0 flex items-center gap-3 px-4 sm:px-6 py-3 border-b border-slate-900/[0.06] bg-white/80 backdrop-blur flex-shrink-0">
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0', categoryColor(item.category)]">
              {{ categoryLabel(item.category) }}
            </span>
            <p class="flex-1 min-w-0 text-sm font-bold text-slate-800 truncate">{{ item.title }}</p>
            <button @click="$emit('close')" aria-label="ปิด"
              class="w-9 h-9 flex-shrink-0 flex items-center justify-center rounded-xl bg-slate-900/[0.06] hover:bg-slate-900/[0.12] text-slate-600 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="overflow-y-auto">
            <!-- aspect-video: ให้กรอบพอดีคลิป ไม่ยืดเต็มความสูงจนเกิดแถบดำ -->
            <div class="w-full aspect-video bg-black">
              <iframe :src="src" class="w-full h-full border-0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowfullscreen loading="lazy" :title="item.title"/>
            </div>

            <div class="px-4 sm:px-6 py-4 space-y-2">
              <h3 class="font-bold text-slate-800 leading-snug">{{ item.title }}</h3>

              <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500">
                <span v-if="item.school_name">🏫 {{ item.school_name }}</span>
                <span v-else-if="item.owner_name">{{ item.owner_name }}</span>
                <span>{{ ownerTypeLabel(item.owner_type) }}</span>
                <span v-if="item.academic_year">ปีการศึกษา {{ item.academic_year }}</span>
                <span>👁 {{ fmtViews(item.view_count) }} ครั้ง</span>
              </div>

              <p v-if="item.description" class="text-sm text-slate-600 whitespace-pre-line">{{ item.description }}</p>

              <!-- ต้องมีเสมอ: บางคลิปเจ้าของปิดการฝัง จะขึ้นกรอบว่างในโมดัล -->
              <a :href="watchUrl" target="_blank" rel="noopener"
                class="inline-flex items-center gap-1.5 text-xs font-bold text-primary hover:underline">
                เปิดใน {{ sourceLabel }} ↗
              </a>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
