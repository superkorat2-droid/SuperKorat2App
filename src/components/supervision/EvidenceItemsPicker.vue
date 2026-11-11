<script setup>
/**
 * EvidenceItemsPicker — ผู้ตอบติ๊กรายการเอกสารหลักฐาน (ที่ผู้สร้างกำหนดใน settings.evidence_items)
 * ได้หลายรายการ และพิมพ์เพิ่มเองได้ถ้า allowCustom
 *
 * v-model = array ข้อความ (เก็บใน supervision_answers.evidence_items)
 * รายการที่ไม่อยู่ใน items = ผู้ตอบพิมพ์เอง → แสดงเป็นชิปลบได้
 * ใช้ร่วม: SupervisionFillView, SchoolSupervisionFillView, SupervisionAnswerEditModal
 */
import { ref, computed } from 'vue'

const props = defineProps({
  modelValue:  { type: Array,   default: () => [] },
  items:       { type: Array,   default: () => [] },
  allowCustom: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const selected = computed(() => props.modelValue || [])
const customs  = computed(() => selected.value.filter(v => !props.items.includes(v)))
const draft    = ref('')

function toggle(item) {
  emit('update:modelValue', selected.value.includes(item)
    ? selected.value.filter(v => v !== item)
    : [...selected.value, item])
}

function addCustom() {
  const v = draft.value.trim()
  draft.value = ''
  if (!v || selected.value.includes(v)) return
  emit('update:modelValue', [...selected.value, v])
}

function removeCustom(v) {
  emit('update:modelValue', selected.value.filter(x => x !== v))
}
</script>

<template>
  <div class="space-y-2">
    <div v-if="items.length" class="flex flex-wrap gap-2">
      <button v-for="item in items" :key="item" type="button" @click="toggle(item)"
        :class="['flex items-center gap-1.5 px-3 py-1.5 rounded-xl border-2 text-xs font-bold transition-all',
          selected.includes(item) ? 'border-primary text-primary' : 'border-slate-200 text-slate-500 hover:border-slate-300']"
        :style="selected.includes(item) ? { background: 'var(--color-primary-light)' } : null">
        <span :class="['w-3.5 h-3.5 rounded border-2 flex items-center justify-center flex-shrink-0',
          selected.includes(item) ? 'bg-primary border-primary' : 'border-slate-300']">
          <svg v-if="selected.includes(item)" class="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="4">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
          </svg>
        </span>
        {{ item }}
      </button>
    </div>

    <div v-if="customs.length" class="flex flex-wrap gap-2">
      <span v-for="v in customs" :key="v"
        class="flex items-center gap-1 pl-3 pr-1.5 py-1 rounded-xl bg-slate-100 text-slate-700 text-xs font-bold">
        {{ v }}
        <button type="button" @click="removeCustom(v)" aria-label="ลบ"
          class="w-4 h-4 flex items-center justify-center rounded-full text-slate-400 hover:text-red-500 hover:bg-white">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </span>
    </div>

    <div v-if="allowCustom" class="flex gap-2">
      <input v-model="draft" type="text" placeholder="เอกสารอื่น ๆ พิมพ์เพิ่มเอง..."
        @keydown.enter.prevent="addCustom"
        class="flex-1 min-w-0 px-3 py-1.5 border border-slate-200 rounded-xl text-xs focus:outline-none focus:border-primary"/>
      <button type="button" @click="addCustom" :disabled="!draft.trim()"
        class="px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 disabled:opacity-40">
        + เพิ่ม
      </button>
    </div>
  </div>
</template>
