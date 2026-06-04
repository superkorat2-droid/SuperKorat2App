<script setup>
import { useAreaConfig } from '../composables/useAreaConfig'
const { config } = useAreaConfig()
</script>

<template>
  <div class="font-sarabun min-h-[60vh] flex items-center justify-center bg-slate-50 dark:bg-slate-950 px-4">
    <div class="text-center max-w-md">
      <div class="w-20 h-20 rounded-3xl gradient-primary flex items-center justify-center mx-auto mb-6 shadow-lg">
        <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round"
            d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
        </svg>
      </div>
      <h1 class="text-2xl font-extrabold text-slate-800 dark:text-slate-100 mb-2">
        กลุ่มนิเทศ ติดตามและประเมินผล
      </h1>
      <p class="text-slate-500 dark:text-slate-400 text-sm mb-1">
        {{ config?.area_name || 'สำนักงานเขตพื้นที่การศึกษา' }}
      </p>
      <p class="text-slate-400 dark:text-slate-500 text-xs mb-8">
        หน้านี้อยู่ระหว่างพัฒนา
      </p>
      <router-link to="/"
        class="inline-flex items-center gap-2 px-6 py-2.5 bg-primary text-white font-bold rounded-2xl text-sm hover:-translate-y-0.5 shadow-md transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>
        </svg>
        กลับหน้าแรก
      </router-link>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
