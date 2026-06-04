<script setup>
import { computed } from 'vue'
import { ICON_MAP } from '../composables/useIcons.js'

const props = defineProps({
  name:        { type: String, required: true },
  strokeWidth: { type: [String, Number], default: 1.5 },
})

const path = computed(() => ICON_MAP[props.name] || ICON_MAP['document'])
</script>

<template>
  <svg fill="none" stroke="currentColor" :stroke-width="strokeWidth" viewBox="0 0 24 24"
    aria-hidden="true" v-bind="$attrs">
    <path stroke-linecap="round" stroke-linejoin="round" :d="path"/>
  </svg>
</template>
