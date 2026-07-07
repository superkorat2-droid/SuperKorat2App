<script setup>
import { ICON_MAP, ICON_LABELS, iconPath, isIconKey } from '../composables/useIcons.js'

defineProps({
  modelValue: { type: String, default: '' },
})
defineEmits(['update:modelValue'])
</script>

<template>
  <div class="border border-slate-200 rounded-xl overflow-hidden">
    <!-- selected preview -->
    <div class="flex items-center gap-3 px-3 py-2 bg-slate-50 border-b border-slate-200">
      <div class="w-8 h-8 flex items-center justify-center rounded-lg bg-white border border-slate-200">
        <svg v-if="isIconKey(modelValue)" class="w-5 h-5 text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(modelValue)"/>
        </svg>
        <span v-else class="text-lg">{{ modelValue || '📄' }}</span>
      </div>
      <span class="text-sm text-slate-600 font-medium">{{ ICON_LABELS[modelValue] || modelValue || 'ยังไม่ได้เลือก' }}</span>
    </div>
    <!-- icon grid -->
    <div class="grid grid-cols-9 gap-1 p-2 max-h-36 overflow-y-auto">
      <button v-for="(path, key) in ICON_MAP" :key="key" type="button"
        @click="$emit('update:modelValue', key)"
        :title="ICON_LABELS[key] || key"
        :class="['w-8 h-8 flex items-center justify-center rounded-lg transition-colors',
          modelValue === key ? 'bg-primary text-white' : 'hover:bg-slate-100 text-slate-600']">
        <svg class="w-4.5 h-4.5" style="width:18px;height:18px" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" :d="path"/>
        </svg>
      </button>
    </div>
  </div>
</template>
