<script setup>
import { onMounted } from 'vue'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('nithet', { icon: 'eye', title: 'กลุ่มนิเทศ ติดตามและประเมินผล' })
</script>

<template>
  <div class="font-sarabun min-h-[60vh] bg-slate-50 dark:bg-slate-950">
    <PageHero :title="header.title"
      :subtitle="header.subtitle || config?.area_name || 'สำนักงานเขตพื้นที่การศึกษา'"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType">
      <template #extra>
        <p class="text-white/50 text-xs mt-3 mb-2">หน้านี้อยู่ระหว่างพัฒนา</p>
        <router-link to="/"
          class="inline-flex items-center gap-2 px-6 py-2.5 bg-white/15 hover:bg-white/25 text-white font-bold rounded-2xl text-sm transition-all mt-2">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>
          </svg>
          กลับหน้าแรก
        </router-link>
      </template>
    </PageHero>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
