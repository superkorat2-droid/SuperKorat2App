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
  size:      { type: String, default: 'lg' },      // 'lg' | 'md'
  align:     { type: String, default: 'center' },  // 'center' | 'left'
  maxWidth:  { type: String, default: '3xl' },     // tailwind max-w-* suffix, e.g. '3xl' | '6xl'
})

// media ต้องมี URL จริงถึงจะใช้ — ถ้า mode='media' แต่ยังไม่มีไฟล์ ให้ fallback ไปโหมด icon แทน (ไม่โชว์รูปพัง)
const showMedia = computed(() => props.mode === 'media' && !!props.mediaUrl)
const showIcon  = computed(() => !showMedia.value && !!props.icon)
const isVideo   = computed(() => props.mediaType === 'video')

// ต้องเป็น literal class ครบคำในไฟล์นี้ ไม่งั้น Tailwind JIT จะไม่สร้าง class ให้ (ต่อ string ไม่ได้)
const MAX_W_CLASS = { '3xl': 'max-w-3xl', '5xl': 'max-w-5xl', '6xl': 'max-w-6xl', '7xl': 'max-w-7xl' }
const containerMaxW = computed(() => MAX_W_CLASS[props.maxWidth] || 'max-w-3xl')
</script>

<template>
  <div class="relative overflow-hidden" :class="size === 'lg' ? 'min-h-[220px]' : 'min-h-[140px]'">

    <!-- Media background (image/gif/video) -->
    <template v-if="showMedia">
      <video v-if="isVideo" :src="mediaUrl" class="absolute inset-0 w-full h-full object-cover"
        autoplay muted loop playsinline/>
      <img v-else :src="mediaUrl" class="absolute inset-0 w-full h-full object-cover" alt=""/>
      <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/35 to-black/20"></div>
    </template>

    <!-- Flat gradient (default icon mode) -->
    <template v-else>
      <div class="absolute inset-0" style="background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%)"></div>
      <div class="absolute inset-0 opacity-10">
        <svg width="100%" height="100%"><defs><pattern id="page-hero-dots" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="12" cy="12" r="1" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#page-hero-dots)"/></svg>
      </div>
    </template>

    <div :class="[containerMaxW, 'relative mx-auto px-4 flex flex-col',
        size === 'lg' ? 'py-12' : 'py-8',
        align === 'left' ? 'items-start text-left' : 'items-center justify-center text-center']">
      <p v-if="eyebrow" class="text-xs text-white/70 font-bold uppercase tracking-widest mb-2">{{ eyebrow }}</p>

      <div v-if="showIcon" :class="[
        'inline-flex items-center justify-center rounded-2xl bg-white/15 backdrop-blur ring-2 ring-white/20 shadow-lg',
        size === 'lg' ? 'w-14 h-14 mb-5' : 'w-11 h-11 mb-3'
      ]">
        <svg v-if="isIconKey(icon)" :class="['text-white', size === 'lg' ? 'w-7 h-7' : 'w-5 h-5']" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(icon)"/>
        </svg>
        <span v-else :class="size === 'lg' ? 'text-2xl' : 'text-xl'">{{ icon }}</span>
      </div>

      <h1 :class="['font-extrabold text-white leading-tight', size === 'lg' ? 'text-2xl md:text-3xl' : 'text-xl md:text-2xl']">{{ title }}</h1>
      <p v-if="subtitle" class="text-white/70 text-sm mt-2 max-w-xl">{{ subtitle }}</p>

      <slot name="extra"/>
    </div>
  </div>
</template>
