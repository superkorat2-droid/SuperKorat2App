<script setup>
/**
 * LibraryGrid — กริดการ์ดคลังหนังสือ ใช้ทั้งหน้า /library และเซกชันหน้าแรก
 *
 * ใช้ flex-wrap ไม่ใช่ grid เพราะ grid จะดันการ์ดแถวสุดท้ายไปชิดซ้ายเสมอ
 * ส่วน flex-wrap + justify-center ทำให้แถวที่ไม่เต็มจัดกึ่งกลางเอง
 * (เหตุผลเดียวกับ YoutubeCardGrid / SchoolNewsletterGrid)
 */
import { computed } from 'vue'
import { COL_WIDTH_CLASS } from '../composables/useYoutubeGrid'
import { useRevealOnScroll } from '../composables/useRevealOnScroll'
import LibraryCard from './LibraryCard.vue'

const props = defineProps({
  items:   { type: Array,   default: () => [] },
  cols:    { type: Number,  default: 6 },
  rows:    { type: Number,  default: 2 },      // ใช้แค่จำนวนโครงร่างตอนโหลด
  loading: { type: Boolean, default: false },
  animate: { type: Boolean, default: true },
  groupLabelOf:   { type: Function, default: () => '' },
  publisherNameOf:{ type: Function, default: () => '' },
})
defineEmits(['open'])

const { containerRef, revealed } = useRevealOnScroll()

const widthClass = computed(() => COL_WIDTH_CLASS[props.cols] || COL_WIDTH_CLASS[6])
// ปิดแอนิเมชันต้องไม่ใส่ .reveal-item เลย ไม่ใช่แค่ให้ revealed เป็น true
// ไม่งั้นการ์ดจะเริ่มที่ opacity 0 หนึ่งเฟรมแล้วกระพริบ
const itemClass = computed(() => (props.animate ? 'reveal-item' : ''))
</script>

<template>
  <!-- โครงร่างระหว่างโหลด — กันหน้ากระตุกตอนข้อมูลมาถึง -->
  <div v-if="loading" class="flex flex-wrap justify-center gap-4">
    <div v-for="i in cols * rows" :key="i"
      :class="['glass-card overflow-hidden animate-pulse aspect-[3/4] bg-slate-200/50', widthClass]"></div>
  </div>

  <div v-else-if="!items.length" class="text-center py-12 text-slate-400 text-sm">
    ยังไม่มีรายการ
  </div>

  <div v-else ref="containerRef"
    :class="['flex flex-wrap justify-center gap-4', revealed ? 'is-revealed' : '']">
    <LibraryCard v-for="(it, idx) in items" :key="it.id"
      :item="it"
      :group-label="groupLabelOf(it)"
      :publisher-name="publisherNameOf(it)"
      :style="{ '--i': idx }"
      :class="[widthClass, itemClass]"
      @open="$emit('open', $event)"/>
  </div>
</template>
