<script setup>
import { useRoute } from 'vue-router'
const route = useRoute()
</script>
<template>
  <div class="font-sarabun flex items-center justify-center min-h-[50vh]">
    <div class="text-center max-w-sm">
      <div class="text-6xl mb-4">{{ $route.meta.icon || '🔧' }}</div>
      <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-100 text-amber-700 text-xs font-bold rounded-full mb-3">🚧 กำลังพัฒนา</span>
      <h2 class="text-2xl font-extrabold text-slate-900 mb-2">{{ $route.meta.title || 'หน้านี้' }}</h2>
      <p class="text-slate-500 text-sm">หน้านี้อยู่ระหว่างการพัฒนา จะแล้วเสร็จเร็ว ๆ นี้</p>
    </div>
  </div>
</template>
<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
