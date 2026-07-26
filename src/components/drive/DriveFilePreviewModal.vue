<script setup>
/**
 * DriveFilePreviewModal — ดูไฟล์ Drive ในหน้าเว็บโดยไม่ต้องหลุดออกไป
 * โครง modal เดียวกับ EventDetailModal: มือถือเด้งจากขอบล่าง หัว sticky ปุ่มปิดไม่หลุดจอ
 */
import { computed } from 'vue'
import { drivePreviewUrl, driveViewUrl, fileKind, formatSize, formatDate } from '../../composables/useGoogleDrive'

const props = defineProps({
  file: { type: Object, default: null },   // null = ปิด
})
defineEmits(['close'])

const previewSrc = computed(() => drivePreviewUrl(props.file?.id))
const openSrc    = computed(() => props.file?.webViewLink || driveViewUrl(props.file?.id))
const kind       = computed(() => fileKind(props.file?.mimeType))
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0">
      <div v-if="file" class="fixed inset-0 z-[110] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm"
        @click.self="$emit('close')">
        <div class="glass-panel rounded-t-3xl sm:rounded-3xl w-full sm:max-w-4xl h-[92dvh] sm:h-[88dvh] flex flex-col overflow-hidden">

          <div class="sticky top-0 flex items-center gap-3 px-4 sm:px-6 py-3 border-b border-slate-900/[0.06] bg-white/80 backdrop-blur flex-shrink-0">
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0', kind.bg, kind.color]">{{ kind.label }}</span>
            <p class="flex-1 min-w-0 text-sm font-bold text-slate-800 truncate">{{ file.name }}</p>
            <a :href="openSrc" target="_blank" rel="noopener" title="เปิดใน Google Drive"
              class="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-primary hover:text-white transition-all flex-shrink-0">
              เปิดใน Drive
            </a>
            <button @click="$emit('close')" aria-label="ปิด"
              class="w-9 h-9 flex-shrink-0 flex items-center justify-center rounded-xl bg-slate-900/[0.06] hover:bg-slate-900/[0.12] text-slate-600 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Google เป็นคนวาด preview เอง รองรับ PDF/รูป/Docs/วิดีโอ -->
          <iframe :src="previewSrc" class="flex-1 w-full border-0 bg-slate-100" allow="autoplay" loading="lazy"/>

          <div class="flex items-center gap-3 px-4 sm:px-6 py-2.5 border-t border-slate-900/[0.06] bg-white/70 flex-shrink-0 text-xs text-slate-500">
            <span v-if="formatSize(file.size)">{{ formatSize(file.size) }}</span>
            <span v-if="file.modifiedTime">แก้ไข {{ formatDate(file.modifiedTime) }}</span>
            <a :href="openSrc" target="_blank" rel="noopener"
              class="sm:hidden ml-auto font-bold text-primary">เปิดใน Drive →</a>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
