<script setup>
/**
 * LibraryCard — การ์ดหนังสือ/คู่มือ
 *
 * ภาพปกเต็มใบ ไม่มีตัวหนังสือบัง ชี้เมาส์แล้วค่อยไล่สีขึ้นมาพร้อมรายละเอียด
 * (การซ่อน/แสดงอยู่ในคลาส .lib-meta ที่ style.css เพราะต้องใช้ @media (hover)
 *  ซึ่งเขียนเป็นคลาส Tailwind ไม่ได้ — จอสัมผัสต้องเห็นรายละเอียดตลอด)
 *
 * คลิกแล้ว emit ให้ parent เปิดโมดัลอ่าน ไม่พาออกนอกเว็บ เพราะ PDF หลายหน้า
 * ต้องอ่านในตัวอ่านของ Google ที่เลื่อนหน้าได้
 */
import { computed } from 'vue'
import DriveCover from './DriveCover.vue'
import { kindLabel, kindColor } from '../composables/useLibraryOptions'

const props = defineProps({
  item:        { type: Object, required: true },
  groupLabel:  { type: String, default: '' },
  publisherName: { type: String, default: '' },
})
defineEmits(['open'])

const meta = computed(() => {
  const parts = []
  if (props.publisherName) parts.push(props.publisherName)
  if (props.groupLabel)    parts.push(props.groupLabel)
  if (props.item.year)     parts.push(String(props.item.year))   // เก็บเป็น พ.ศ. แล้ว ห้าม +543
  return parts.join(' · ')
})
</script>

<template>
  <button type="button" @click="$emit('open', item)"
    class="group relative block w-full text-left glass-card glass-card-hover overflow-hidden
           aspect-[3/4] focus:outline-none focus-visible:ring-2 focus-visible:ring-primary">

    <DriveCover :file-id="item.file_id" :cover-url="item.cover_url" :title="item.title" :size="500"/>

    <!-- ป้ายชนิด เห็นตลอด ตัวเล็ก ไม่รบกวนภาพ -->
    <span :class="['absolute top-1.5 left-1.5 text-[9px] font-bold px-1.5 py-0.5 rounded-full shadow-sm',
                   kindColor(item.kind)]">
      {{ kindLabel(item.kind) }}
    </span>

    <!-- รายละเอียด — ซ่อนตอนไม่ชี้เฉพาะเครื่องที่มีเมาส์ (ดู .lib-meta ใน style.css) -->
    <div class="lib-meta absolute inset-x-0 bottom-0 p-3 pt-10
                bg-gradient-to-t from-black/90 via-black/55 to-transparent pointer-events-none">
      <!-- span ไม่ใช่ p — .glass-card p { color: revert !important } ล้างสีขาวทิ้ง -->
      <span class="block text-white text-sm font-bold leading-snug line-clamp-3">{{ item.title }}</span>
      <span v-if="meta" class="block text-white/70 text-[10px] leading-snug mt-1 line-clamp-2">{{ meta }}</span>
    </div>
  </button>
</template>
