<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../supabase'

const route   = useRoute()
const notFound = ref(false)

onMounted(async () => {
  const { data, error } = await supabase.rpc('resolve_short_url', { p_slug: route.params.slug })
  if (error || !data) {
    notFound.value = true
    return
  }
  window.location.replace(data)
})
</script>

<template>
  <div class="font-sarabun min-h-[60vh] flex items-center justify-center px-4">
    <div v-if="notFound" class="text-center">
      <div class="text-5xl mb-4">🔗</div>
      <h1 class="text-xl font-extrabold text-slate-800 mb-2">ไม่พบลิงค์นี้</h1>
      <p class="text-sm text-slate-500">ลิงค์อาจถูกลบ ปิดใช้งาน หรือหมดอายุแล้ว</p>
      <router-link to="/" class="inline-block mt-5 text-indigo-600 font-bold text-sm hover:underline">← กลับหน้าแรก</router-link>
    </div>
    <div v-else class="text-center text-slate-400 text-sm">
      <svg class="w-8 h-8 animate-spin mx-auto mb-3 text-indigo-500" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
      </svg>
      กำลังนำไปยังลิงค์ปลายทาง...
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
