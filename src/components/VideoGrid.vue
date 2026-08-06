<script setup>
/**
 * VideoGrid — กริดการ์ดวีดิทัศน์ ใช้ทั้งหน้า /videos และเซกชันหน้าแรก
 *
 * flex-wrap ไม่ใช่ grid ด้วยเหตุผลเดียวกับ LibraryGrid:
 * grid จะดันการ์ดแถวสุดท้ายไปชิดซ้ายเสมอ
 */
import { computed } from 'vue'
import { COL_WIDTH_CLASS } from '../composables/useYoutubeGrid'
import { useRevealOnScroll } from '../composables/useRevealOnScroll'
import VideoCard from './VideoCard.vue'

const props = defineProps({
  items:   { type: Array,   default: () => [] },
  cols:    { type: Number,  default: 4 },
  rows:    { type: Number,  default: 1 },      // ใช้แค่จำนวนโครงร่างตอนโหลด
  loading: { type: Boolean, default: false },
  animate: { type: Boolean, default: true },
  emptyText: { type: String, default: 'ยังไม่มีวีดิทัศน์' },
})
defineEmits(['play'])

const { containerRef, revealed } = useRevealOnScroll()

const widthClass = computed(() => COL_WIDTH_CLASS[props.cols] || COL_WIDTH_CLASS[4])
// ปิดแอนิเมชันต้องไม่ใส่ .reveal-item เลย ไม่งั้นการ์ดเริ่มที่ opacity 0 หนึ่งเฟรมแล้วกระพริบ
const itemClass = computed(() => (props.animate ? 'reveal-item' : ''))
</script>

<template>
  <div v-if="loading" class="flex flex-wrap justify-center gap-4">
    <div v-for="i in cols * rows" :key="i"
      :class="['glass-card overflow-hidden animate-pulse aspect-video bg-slate-200/50', widthClass]"></div>
  </div>

  <div v-else-if="!items.length" class="text-center py-12 text-slate-400 text-sm">
    {{ emptyText }}
  </div>

  <div v-else ref="containerRef"
    :class="['flex flex-wrap justify-center gap-4', revealed ? 'is-revealed' : '']">
    <VideoCard v-for="(it, idx) in items" :key="it.id"
      :item="it"
      :style="{ '--i': idx }"
      :class="[widthClass, itemClass]"
      @play="$emit('play', it)"/>
  </div>
</template>
