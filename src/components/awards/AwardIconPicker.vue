<script setup>
/** AwardIconPicker — เลือกไอคอนรางวัลแบบปุ่มกริด (pattern เดียวกับปุ่มเลือกประเภทผลงาน) */
import { AWARD_ICONS } from '../../composables/useAwards'

defineProps({ modelValue: { type: String, default: 'trophy' } })
defineEmits(['update:modelValue'])
</script>

<template>
  <div class="grid grid-cols-4 sm:grid-cols-8 gap-1.5">
    <button v-for="ic in AWARD_ICONS" :key="ic.value" type="button"
      @click="$emit('update:modelValue', ic.value)" :title="ic.label"
      :class="['flex flex-col items-center gap-1 px-1 py-2 rounded-xl border-2 transition-all',
        modelValue === ic.value
          ? 'border-primary bg-primary/5 text-primary'
          : 'border-slate-200 text-slate-400 hover:border-primary/40 hover:text-slate-600']">
      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.6" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" :d="ic.path"/>
      </svg>
      <span class="text-[9px] font-bold leading-tight text-center">{{ ic.label }}</span>
    </button>
  </div>
</template>
