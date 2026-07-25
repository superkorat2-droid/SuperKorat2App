<script setup>
/**
 * EventDetailModal — รายละเอียดกิจกรรมนิเทศแบบอ่านอย่างเดียว
 * สกัดจาก GroupNitetView เพื่อให้หน้าแรกใช้ modal ตัวเดียวกัน (เดิมหน้าแรกคลิกแล้วเด้งไป /nithet)
 */
import { computed } from 'vue'
import { TYPE_LABEL, TYPE_COLOR, formatEventDateRange, formatResponsible } from '../../composables/useNithetEventMeta'
import { useAreaConfig } from '../../composables/useAreaConfig'

const props = defineProps({
  event: { type: Object, default: null },   // null = ปิด
})
defineEmits(['close'])

const { config } = useAreaConfig()
const personnelGroups = computed(() => config.value?.personnel_groups || [])
function groupLabel(key) { return personnelGroups.value.find(g => g.key === key)?.label || key }

const responsibleText = computed(() => {
  const e = props.event
  if (!e) return ''
  return formatResponsible(e.responsible_names || [], e.responsible_group ? groupLabel(e.responsible_group) : '')
})
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0 scale-95"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0 scale-95">
      <div v-if="event" class="fixed inset-0 z-[100] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/50 backdrop-blur-sm"
        @click.self="$emit('close')">
        <!-- มือถือ: เด้งจากล่าง เต็มความกว้าง สูงไม่เกิน 88% ของจอ
             เนื้อหายาวแค่ไหนก็เลื่อนได้ ส่วนหัว (ที่มีปุ่มปิด) sticky ไว้เสมอ -->
        <div class="glass-panel rounded-t-3xl sm:rounded-3xl w-full sm:max-w-md max-h-[88dvh] flex flex-col overflow-hidden">
          <div class="sticky top-0 flex items-center justify-between px-6 py-4 border-b border-slate-900/[0.06] bg-white/80 backdrop-blur flex-shrink-0">
            <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
              {{ TYPE_LABEL[event.type] }}
            </span>
            <button @click="$emit('close')" aria-label="ปิด"
              class="w-9 h-9 flex-shrink-0 flex items-center justify-center rounded-xl bg-slate-900/[0.06] hover:bg-slate-900/[0.12] text-slate-600 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
          <div class="px-6 py-5 space-y-3 overflow-y-auto">
            <h2 class="text-lg font-extrabold text-slate-900 leading-snug">{{ event.title }}</h2>
            <p v-if="event.description" class="text-sm text-slate-600">{{ event.description }}</p>
            <div class="border-t border-slate-900/[0.06] pt-3 space-y-2 text-sm text-slate-600">
              <p>📅 {{ formatEventDateRange(event) }}</p>
              <p v-for="s in (event.schools || [])" :key="s.id">🏫 {{ s.name }} <span class="text-slate-400">(อ.{{ s.district }})</span></p>
              <p v-if="event.location">📍 {{ event.location }}</p>
              <p v-if="event.responsible_group || event.responsible_names?.length">👤 {{ responsibleText }}</p>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
