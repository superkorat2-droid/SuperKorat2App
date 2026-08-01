<script setup>
/**
 * DriveCover — ภาพปกของไฟล์ Google Drive (จดหมายข่าว / หนังสือ / คู่มือ)
 *
 * ใช้ร่วมกันหลายที่ — อย่าทำสำเนา ไม่งั้นวันหนึ่งแก้ที่เดียวแล้วอีกหน้าจะเพี้ยน
 * (บทเรียนเดียวกับ extractFileId ที่เคยกระจายอยู่ 5 ไฟล์ ดู useGoogleDrive.js)
 *
 * เดิมทุกที่ฝัง iframe ของ Drive แล้วครอบ pointer-events-none ให้ดูเหมือนรูป
 * ซึ่งหนักมาก (12 ใบ = 439 คำขอ / 38 MB) เปลี่ยนมาเป็น <img> แล้วเหลือ 0.59 MB
 *
 * PDF หลายหน้า: Google คืน "หน้าแรก" มาเป็นภาพปกให้เอง ไม่ต้องเรนเดอร์ PDF เอง
 * ส่วนการอ่านทุกหน้าใช้ iframe /preview ในโมดัล ซึ่งเปิดทีละอันจึงไม่หนัก
 *
 * coverUrl = ปกที่ผู้ใช้อัปทับเอง ถ้าไม่ใส่จะใช้หน้าแรกจาก Drive
 * ถ้า Google เปลี่ยน endpoint วันไหน ภาพจะตกมาที่กรอบสำรอง — เสียความสวย
 * แต่ยังอ่านออกว่าเป็นเรื่องอะไรและกดเข้าไปดูได้ ไม่ใช่รูปแตก
 */
import { ref, computed, watch } from 'vue'
import { driveThumb } from '../composables/useGoogleDrive'

const props = defineProps({
  fileId:   { type: String, default: '' },
  coverUrl: { type: String, default: '' },   // ปกที่อัปทับเอง ชนะปกอัตโนมัติเสมอ
  title:    { type: String, default: '' },
  size:     { type: Number, default: 600 },  // ความกว้างที่ขอจาก Google (px)
})

const src = computed(() => props.coverUrl || driveThumb(props.fileId, props.size))

const failed = ref(false)
// การ์ดถูกใช้ซ้ำตอนกรอง/เปลี่ยนหน้า ถ้าไม่รีเซ็ตจะติดสถานะพังของใบก่อนหน้า
// ดู src (ไม่ใช่ fileId อย่างเดียว) — อัปปกใหม่ทับปกที่โหลดไม่ขึ้นแล้วต้องลองใหม่ด้วย
watch(src, () => { failed.value = false })
</script>

<template>
  <img v-if="src && !failed"
    :src="src" :alt="title || 'ภาพปก'"
    loading="lazy" decoding="async" @error="failed = true"
    class="w-full h-full object-cover object-top group-hover:scale-105 transition-transform duration-500"/>

  <div v-else
    class="w-full h-full flex flex-col items-center justify-center gap-1.5 p-3 text-center
           bg-gradient-to-br from-slate-100 to-slate-200">
    <svg class="w-10 h-10 text-slate-300 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round"
        d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/>
    </svg>
    <span class="block text-[10px] leading-snug text-slate-400 line-clamp-2">{{ title }}</span>
  </div>
</template>
