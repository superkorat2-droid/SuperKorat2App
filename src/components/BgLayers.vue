<script setup>
/**
 * BgLayers — ชั้นพื้นหลังรูปภาพสำหรับ section หน้าแรก / บล็อกหน้า CMS
 *
 * ทำไมต้องเป็น component แยกแทนที่จะใส่ใน :style เดียว:
 *   ม่าน (overlay) อย่างเดียวทำใน background shorthand ได้ แต่ "เบลอภาพ" ทำไม่ได้ —
 *   `filter: blur()` บน element จะเบลอเนื้อหาข้างในไปด้วย จึงต้องแยกภาพเป็นชั้นของตัวเอง
 *
 * วิธีใช้: element แม่ต้องเป็น `relative overflow-hidden` และเนื้อหาข้างในต้อง
 * `relative` (หรือ z-10) ไม่งั้นชั้นนี้ซึ่ง absolute จะทับเนื้อหา
 */
import { computed } from 'vue'
import { isImageBg, bgImageLayerStyle, bgOverlayLayerStyle } from '../composables/useBgStyle'

const props = defineProps({
  cfg: { type: Object, required: true },   // section หรือ block ที่มี bg_* fields
})

const show         = computed(() => isImageBg(props.cfg))
const imageStyle   = computed(() => bgImageLayerStyle(props.cfg))
const overlayStyle = computed(() => bgOverlayLayerStyle(props.cfg))
</script>

<template>
  <template v-if="show">
    <!-- ชั้นรูป — will-change ช่วยให้ blur ไม่กระตุกตอนเลื่อนบนมือถือ -->
    <div class="absolute inset-0 pointer-events-none" :style="imageStyle" style="will-change: transform"></div>
    <!-- ชั้นม่าน — ตัวคุมว่าตัวหนังสือจะอ่านออกไหม -->
    <div class="absolute inset-0 pointer-events-none" :style="overlayStyle"></div>
  </template>
</template>
