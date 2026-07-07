<script setup>
import { onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const route = useRoute()
const { fetchConfig } = useAreaConfig()
onMounted(fetchConfig)

const header = usePageHeader(route.name, {
  icon:    route.meta.icon  || '📄',
  title:   route.meta.title || 'หน้านี้',
  subtitle: route.meta.desc  || 'หน้านี้อยู่ระหว่างการพัฒนา',
})

const contentTools = [
  { icon: '📄', label: 'PDF' },
  { icon: '📊', label: 'Slide' },
  { icon: '🎨', label: 'Canva' },
  { icon: '💻', label: 'HTML' },
  { icon: '🖼️', label: 'รูปภาพ' },
  { icon: '📝', label: 'ข้อความ' },
]
</script>

<template>
  <div class="font-sarabun min-h-[70vh]">

    <PageHero :title="header.title" :subtitle="header.subtitle"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType">
      <template #extra>
        <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white/15 text-white text-xs font-bold rounded-full mt-4">
          🚧 กำลังพัฒนา
        </span>
      </template>
    </PageHero>

    <div class="max-w-xl w-full mx-auto py-12 px-4">

      <!-- Content type tools preview -->
      <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-7">
        <p class="text-xs font-bold text-slate-400 uppercase tracking-widest text-center mb-5">เครื่องมือเพิ่มเนื้อหาที่รองรับ</p>
        <div class="grid grid-cols-3 sm:grid-cols-6 gap-3 mb-6">
          <div v-for="tool in contentTools" :key="tool.label"
            class="flex flex-col items-center gap-1.5 p-3 bg-slate-50 rounded-2xl border border-slate-100 hover:bg-blue-50 hover:border-blue-200 transition-colors cursor-default">
            <span class="text-2xl">{{ tool.icon }}</span>
            <span class="text-xs font-bold text-slate-600">{{ tool.label }}</span>
          </div>
        </div>

        <!-- Skeleton lines -->
        <div class="space-y-2.5 mb-6">
          <div class="h-3.5 bg-slate-100 rounded-full w-full animate-pulse"></div>
          <div class="h-3.5 bg-slate-100 rounded-full w-4/5 animate-pulse"></div>
          <div class="h-3.5 bg-slate-100 rounded-full w-3/5 animate-pulse"></div>
        </div>

        <div class="flex items-center gap-2 p-3 bg-blue-50 rounded-2xl border border-blue-100">
          <span class="text-lg flex-shrink-0">💡</span>
          <p class="text-xs text-blue-700 font-medium leading-snug">
            เนื้อหาในหน้านี้จะถูกจัดการผ่านระบบหลังบ้าน (Admin Dashboard) โดยผู้ดูแลระบบ
          </p>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
