<script setup>
/**
 * SchoolNewsletterGrid — กริดจดหมายข่าวสำหรับเซกชันหน้าแรก
 *
 * ต่างจากหน้า /newsletters ตรงที่การ์ดเป็นลิงก์เปิด Drive ตรงๆ ไม่ใช่โมดัล
 * เพราะหน้าแรกควรพาไปดูของจริงเลย ไม่ควรมีโมดัลซ้อนบนหน้าที่ยาวมาก
 *
 * ภาพปกใช้ <img> ผ่าน DriveCover ไม่ใช่ iframe — วัดแล้วเบากว่า 64 เท่า
 */
import { computed } from 'vue'
import { COL_WIDTH_CLASS } from '../composables/useYoutubeGrid'
import { newsletterCatLabel, newsletterCatColor, newsletterDateLabel } from '../composables/useNewsletterMeta'
import { useRevealOnScroll } from '../composables/useRevealOnScroll'
import DriveCover from './DriveCover.vue'

const props = defineProps({
  items:   { type: Array,   default: () => [] },
  cols:    { type: Number,  default: 6 },
  loading: { type: Boolean, default: false },
  animate: { type: Boolean, default: true },
})

const { containerRef, revealed } = useRevealOnScroll()

const widthClass = computed(() => COL_WIDTH_CLASS[props.cols] || COL_WIDTH_CLASS[6])

// ถ้าปิดแอนิเมชันต้องไม่ใส่ .reveal-item เลย ไม่ใช่แค่ปล่อยให้ revealed เป็น true
// เพราะการ์ดจะเริ่มที่ opacity 0 หนึ่งเฟรมแล้วกระพริบ
const itemClass = computed(() => (props.animate ? 'reveal-item' : ''))

// การ์ดเยอะ ๆ ที่ใช้ backdrop-filter ทุกใบทำให้จอมือถือกระตุก (ดู style.css)
const surfaceClass = computed(() => (props.items.length > 20 ? 'glass-tile' : 'glass-card glass-card-hover'))
</script>

<template>
  <!-- โครงร่างระหว่างโหลด — กันหน้ากระตุกตอนข้อมูลมาถึง -->
  <div v-if="loading" class="flex flex-wrap justify-center gap-4">
    <div v-for="i in cols * 2" :key="i" :class="['glass-card overflow-hidden animate-pulse', widthClass]">
      <div class="aspect-[3/4] bg-slate-200/50"></div>
      <div class="p-2.5 space-y-1.5">
        <div class="h-3 bg-slate-200/60 rounded w-3/4"></div>
        <div class="h-2 bg-slate-200/60 rounded w-1/2"></div>
      </div>
    </div>
  </div>

  <div v-else ref="containerRef"
    :class="['flex flex-wrap justify-center gap-4', revealed ? 'is-revealed' : '']">
    <a v-for="(n, idx) in items" :key="n.id"
      :href="n.drive_url" target="_blank" rel="noopener"
      :style="{ '--i': idx }"
      :class="['group overflow-hidden', surfaceClass, widthClass, itemClass]">

      <div class="relative aspect-[3/4] overflow-hidden bg-slate-100">
        <DriveCover :file-id="n.file_id" :title="n.title" :size="400"/>

        <span :class="['absolute top-1.5 left-1.5 text-[9px] font-bold px-1.5 py-0.5 rounded-full',
                       newsletterCatColor(n.category)]">
          {{ newsletterCatLabel(n.category) }}
        </span>

        <!-- ป้ายบอกว่าคลิกได้ โผล่ตอนชี้ -->
        <div class="absolute inset-0 bg-black/0 group-hover:bg-black/25 transition-colors flex items-center justify-center">
          <span class="opacity-0 group-hover:opacity-100 transition-opacity text-[11px] font-bold text-white
                       px-2.5 py-1 rounded-full bg-black/55 backdrop-blur-sm">เปิดดู ↗</span>
        </div>
      </div>

      <div class="p-2.5">
        <!-- span ไม่ใช่ p — .glass-card p { color: revert !important } ล้างสีทิ้ง -->
        <span class="block text-xs font-bold text-slate-800 leading-snug line-clamp-2
                     group-hover:text-primary transition-colors">{{ n.title }}</span>
        <span class="block text-[10px] text-slate-400 mt-1 truncate">
          {{ n.schools?.name || 'สพป.' }}
          <template v-if="n.month || n.year"> · {{ newsletterDateLabel(n.month, n.year) }}</template>
        </span>
      </div>
    </a>
  </div>
</template>
