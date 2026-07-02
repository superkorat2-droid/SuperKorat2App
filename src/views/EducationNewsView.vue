<script setup>
import { ref, computed, onMounted } from 'vue'
import { useEducationNews } from '../composables/useEducationNews'

const { news, loading, error, fetchNews } = useEducationNews()

const searchQ = ref('')

const filtered = computed(() => {
  const q = searchQ.value.trim().toLowerCase()
  if (!q) return news.value
  return news.value.filter(item =>
    item.title.toLowerCase().includes(q) ||
    item.source.toLowerCase().includes(q)
  )
})

function fmtDate(d) {
  if (!d) return ''
  const date = new Date(d)
  if (isNaN(date.getTime())) return ''
  return date.toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

onMounted(() => { fetchNews() })
</script>

<template>
  <div class="font-sarabun text-slate-800 bg-slate-50 min-h-screen">

    <!-- Hero -->
    <section class="gradient-primary py-10 md:py-14">
      <div class="max-w-7xl mx-auto px-4 text-white">
        <p class="text-white/55 text-xs font-semibold uppercase tracking-[0.2em] mb-2">Education News</p>
        <h1 class="text-2xl md:text-3xl font-extrabold mb-1">ข่าวการศึกษา</h1>
        <p class="text-white/65 text-sm">ข่าวสารด้านการศึกษาจาก Google News</p>
      </div>
    </section>

    <!-- Content -->
    <section class="py-10">
      <div class="max-w-3xl mx-auto px-4">

        <!-- Search -->
        <div class="relative mb-6">
          <svg class="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none"
            fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
          </svg>
          <input v-model="searchQ" type="search"
            placeholder="ค้นหาข่าวหรือแหล่งข่าว..."
            class="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-slate-200 rounded-2xl
                   focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="space-y-3">
          <div v-for="i in 8" :key="i"
            class="h-16 bg-white rounded-2xl border border-slate-100 animate-pulse"/>
        </div>

        <!-- Error -->
        <div v-else-if="error"
          class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
          <svg class="w-10 h-10 mx-auto mb-3 opacity-40" fill="none" stroke="currentColor"
            viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
          </svg>
          <p class="font-medium">ไม่สามารถโหลดข่าวได้</p>
          <p class="text-sm mt-1 text-slate-400">{{ error }}</p>
          <button @click="fetchNews(true)"
            class="mt-4 px-5 py-2 text-sm font-bold text-primary border border-primary rounded-xl hover:bg-primary hover:text-white transition-all">
            ลองอีกครั้ง
          </button>
        </div>

        <!-- No search results -->
        <div v-else-if="filtered.length === 0 && searchQ"
          class="text-center py-12 text-slate-400 text-sm">
          ไม่พบข่าวที่ตรงกับ "{{ searchQ }}"
        </div>

        <!-- News list -->
        <ul v-else class="space-y-2">
          <li v-for="item in filtered" :key="item.link"
            class="group bg-white rounded-2xl border border-slate-100 shadow-sm
                   hover:border-primary/20 hover:shadow-md transition-all">
            <a :href="item.link" target="_blank" rel="noopener noreferrer"
              class="flex items-start gap-3 px-5 py-4">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-slate-800 group-hover:text-primary
                           transition-colors leading-snug line-clamp-2">
                  {{ item.title }}
                </p>
                <div class="flex items-center gap-2 mt-1.5 flex-wrap">
                  <span v-if="item.source"
                    class="text-xs bg-primary/10 text-primary font-medium px-2 py-0.5 rounded-lg">
                    {{ item.source }}
                  </span>
                  <span class="text-xs text-slate-400">{{ fmtDate(item.pubDate) }}</span>
                </div>
              </div>
              <svg class="w-4 h-4 text-slate-300 group-hover:text-primary flex-shrink-0 mt-0.5
                          transition-colors"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round"
                  d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
              </svg>
            </a>
          </li>
        </ul>

        <!-- Attribution -->
        <p v-if="!loading && !error && news.length" class="text-center text-xs text-slate-400 mt-8">
          ข้อมูลจาก
          <a href="https://news.google.com" target="_blank" rel="noopener"
            class="text-primary hover:underline">Google News</a>
          · อัปเดตทุก 15 นาที
        </p>

      </div>
    </section>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
