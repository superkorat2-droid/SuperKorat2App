<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const visible = ref(false)
const progress = ref(0) // 0..1

const RADIUS = 20
const CIRC = 2 * Math.PI * RADIUS

function onScroll() {
  const scrollTop = window.scrollY || document.documentElement.scrollTop
  const docHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight
  progress.value = docHeight > 0 ? Math.min(scrollTop / docHeight, 1) : 0
  visible.value = scrollTop > 400
}

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

onMounted(() => window.addEventListener('scroll', onScroll, { passive: true }))
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<template>
  <Transition enter-active-class="transition duration-300 ease-out" enter-from-class="opacity-0 translate-y-3 scale-90"
    leave-active-class="transition duration-200 ease-in" leave-to-class="opacity-0 translate-y-3 scale-90">
    <button v-if="visible" @click="scrollToTop" aria-label="เลื่อนขึ้นด้านบน"
      class="fixed bottom-5 right-4 sm:bottom-7 sm:right-7 z-40 w-12 h-12 rounded-full bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm shadow-lg hover:shadow-xl flex items-center justify-center group hover:scale-105 active:scale-95 transition-all">
      <svg class="absolute inset-0 w-full h-full -rotate-90" viewBox="0 0 48 48">
        <circle cx="24" cy="24" :r="RADIUS" fill="none" stroke="currentColor" stroke-width="2.5"
          class="text-slate-200 dark:text-slate-700"/>
        <circle cx="24" cy="24" :r="RADIUS" fill="none" stroke="url(#scrollTopGradient)" stroke-width="2.5"
          stroke-linecap="round" :stroke-dasharray="CIRC" :stroke-dashoffset="CIRC * (1 - progress)"
          class="transition-[stroke-dashoffset] duration-150"/>
        <defs>
          <linearGradient id="scrollTopGradient" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="var(--color-primary)"/>
            <stop offset="100%" stop-color="var(--color-secondary)"/>
          </linearGradient>
        </defs>
      </svg>
      <svg class="w-4 h-4 text-[var(--color-primary)] dark:text-white group-hover:-translate-y-0.5 transition-transform" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
      </svg>
    </button>
  </Transition>
</template>
