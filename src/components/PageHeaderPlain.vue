<script setup>
import { computed } from 'vue'
import { iconPath, isIconKey } from '../composables/useIcons.js'

const props = defineProps({
  title:     { type: String, required: true },
  subtitle:  { type: String, default: '' },
  eyebrow:   { type: String, default: '' },
  mode:      { type: String, default: 'icon' },   // 'icon' | 'media'
  icon:      { type: String, default: '' },       // ICON_MAP key or emoji
  mediaUrl:  { type: String, default: '' },
  mediaType: { type: String, default: '' },        // 'image' | 'gif' | 'video'
  align:     { type: String, default: 'left' },    // 'left' | 'center'
})

const showMedia = computed(() => props.mode === 'media' && !!props.mediaUrl)
const showIcon  = computed(() => !showMedia.value && !!props.icon)
const isVideo   = computed(() => props.mediaType === 'video')
</script>

<template>
  <div :class="align === 'center' ? 'text-center' : 'text-left'">
    <div v-if="showMedia || showIcon" :class="['w-16 h-16 rounded-2xl overflow-hidden flex items-center justify-center mb-4',
      align === 'center' ? 'mx-auto' : '', !showMedia ? 'bg-primary-light' : 'bg-slate-100 dark:bg-slate-800']">
      <video v-if="showMedia && isVideo" :src="mediaUrl" class="w-full h-full object-cover" autoplay muted loop playsinline/>
      <img v-else-if="showMedia" :src="mediaUrl" class="w-full h-full object-cover" alt=""/>
      <svg v-else-if="isIconKey(icon)" class="w-7 h-7 text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(icon)"/>
      </svg>
      <span v-else class="text-3xl">{{ icon }}</span>
    </div>

    <p v-if="eyebrow" class="text-xs text-primary font-bold uppercase tracking-widest mb-1">{{ eyebrow }}</p>
    <h1 class="text-3xl font-extrabold text-slate-900 dark:text-slate-100">{{ title }}</h1>
    <p v-if="subtitle" class="text-slate-500 dark:text-slate-400 mt-2 text-sm">{{ subtitle }}</p>

    <slot name="extra"/>
  </div>
</template>
