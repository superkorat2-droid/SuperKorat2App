<script setup>
/**
 * VideoCard — การ์ดคลิป 16:9 กดแล้วเล่นในโมดัล
 *
 * เป็น <button> ไม่ใช่ <a> (ต่างจาก LibraryCard ที่ลิงก์ออกไป Drive)
 * เพราะกดแล้วต้องเล่นในหน้าเดิม ผู้ปกครองไม่หลุดออกจากเว็บ
 *
 * ภาพปกใช้ <img> เท่านั้น ห้าม iframe (หนักกว่า 64 เท่า — useGoogleDrive.js:40-54)
 * และ hqdefault ของ YouTube เป็น 4:3 จึงต้อง object-cover ให้ครอปแถบดำออกเอง
 */
import { ref, watch } from 'vue'
import { videoThumb, categoryLabel, categoryColor, fmtViews } from '../composables/useVideos'

const props = defineProps({
  item: { type: Object, required: true },
})
defineEmits(['play'])

const failed = ref(false)
// การ์ดถูก reuse ตอนกรอง ต้องรีเซ็ตสถานะภาพพัง ไม่งั้นค้างเป็นกรอบเปล่า
watch(() => props.item?.id, () => { failed.value = false })
</script>

<template>
  <button type="button" @click="$emit('play', item)"
    class="glass-card glass-card-hover overflow-hidden text-left group">
    <div class="relative aspect-video bg-slate-900 overflow-hidden">
      <img v-if="!failed && videoThumb(item)" :src="videoThumb(item)" :alt="item.title"
        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        loading="lazy" @error="failed = true"/>
      <div v-else class="w-full h-full flex items-center justify-center text-white/40 text-3xl">🎬</div>

      <span class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-black/30">
        <span class="w-12 h-12 rounded-full bg-white/90 flex items-center justify-center text-primary text-lg pl-1">▶</span>
      </span>

      <span v-if="item.duration_text"
        class="absolute bottom-1.5 right-1.5 text-[10px] font-bold text-white bg-black/70 px-1.5 py-0.5 rounded">
        {{ item.duration_text }}
      </span>
      <span v-if="item.is_featured"
        class="absolute top-1.5 left-1.5 text-[10px] font-bold text-white bg-amber-500 px-1.5 py-0.5 rounded-full">★ แนะนำ</span>
    </div>

    <div class="p-3 space-y-1.5">
      <span :class="['inline-block text-[10px] font-bold px-2 py-0.5 rounded-full', categoryColor(item.category)]">
        {{ categoryLabel(item.category) }}
      </span>
      <h3 class="text-sm font-bold text-slate-700 leading-snug line-clamp-2 group-hover:text-primary transition-colors">
        {{ item.title }}
      </h3>
      <div class="flex items-center gap-2 text-[11px] text-slate-400">
        <span class="truncate">{{ item.school_name || item.owner_name || '' }}</span>
        <span class="ml-auto flex-shrink-0">👁 {{ fmtViews(item.view_count) }}</span>
      </div>
    </div>
  </button>
</template>
