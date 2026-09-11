<script setup>
/**
 * VisitCard — การ์ดบันทึกการนิเทศบนหน้าสาธารณะและหน้าแรก
 *
 * ปกใช้ "รูปแรกของบันทึก" อัตโนมัติ ไม่มีช่องอัปปกแยก
 * ไม่มีรูปเลย → แถบไล่สีตามประเภท + ไอคอน เพื่อให้กริดไม่มีช่องโหว่
 *
 * ปกครอบเป็น 16:9 เท่ากันหมดเพื่อความเป็นระเบียบของกริด
 * (หน้ารายละเอียดกับรายงาน A4 ถึงจะแสดงภาพเต็มไม่ครอบ)
 */
import { computed } from 'vue'
import { RouterLink } from 'vue-router'
import { coverOf, photoCount, placeOf, typeMeta, fmtDate } from '../../composables/useNithetVisits'

const props = defineProps({
  item: { type: Object, required: true },
})

const cover = computed(() => coverOf(props.item))
const meta  = computed(() => typeMeta(props.item.visit_type))
const shots = computed(() => photoCount(props.item))
const topics = computed(() => (props.item.topics || []).slice(0, 3))
</script>

<template>
  <RouterLink :to="`/nithet-visits/${item.id}`"
    class="glass-card glass-card-hover overflow-hidden flex flex-col group">
    <div class="relative aspect-video bg-slate-100 overflow-hidden">
      <img v-if="cover" :src="cover" :alt="item.title || placeOf(item)" loading="lazy"
        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
      <div v-else class="w-full h-full flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-200 text-4xl">
        {{ meta.icon }}
      </div>
      <span :class="['absolute top-2 left-2 text-[11px] font-bold px-2.5 py-0.5 rounded-full', meta.color]">
        {{ meta.icon }} {{ meta.label }}
      </span>
      <span v-if="shots > 1"
        class="absolute bottom-2 right-2 text-[11px] font-bold text-white bg-black/50 px-2 py-0.5 rounded-full">
        📷 {{ shots }}
      </span>
    </div>

    <div class="p-4 flex-1 flex flex-col gap-1.5">
      <span class="text-xs text-slate-400">{{ fmtDate(item.visit_date) }}</span>
      <span class="font-bold text-slate-800 leading-snug line-clamp-2">{{ item.title || placeOf(item) }}</span>
      <span class="text-xs text-slate-500 line-clamp-1">📍 {{ placeOf(item) }}</span>

      <div v-if="topics.length" class="flex flex-wrap gap-1 mt-0.5">
        <span v-for="t in topics" :key="t"
          class="text-[11px] text-slate-500 bg-slate-100 rounded-full px-2 py-0.5 truncate max-w-full">{{ t }}</span>
      </div>

      <span v-if="item.supervisor_name" class="text-xs text-slate-400 mt-auto pt-1.5 truncate">
        โดย {{ item.supervisor_name }}
      </span>
    </div>
  </RouterLink>
</template>
