<script setup>
/**
 * YoutubeCardGrid — การ์ดลิงก์ YouTube หน้าตาเดียวกับการ์ดข่าว
 * ใช้ได้ทั้งเซกชันหน้าแรกและบล็อกในหน้า CMS
 *
 * ทำไมใช้ flex-wrap แทน grid: grid จะดันการ์ดแถวสุดท้ายไปชิดซ้ายเสมอ
 * ส่วน flex-wrap + justify-center ทำให้แถวที่ไม่เต็มจัดกึ่งกลางเองอัตโนมัติ
 */
import { ref, computed, watch } from 'vue'
import { youtubeId, youtubeThumb, COL_WIDTH_CLASS } from '../composables/useYoutubeGrid'

const props = defineProps({
  items: { type: Array,  default: () => [] },  // [{ id, url, title, caption }]
  cols:  { type: Number, default: 4 },         // จำนวนคอลัมน์บนจอใหญ่
  rows:  { type: Number, default: 3 },         // จำนวนแถวต่อหน้า
})

const page = ref(1)
const perPage   = computed(() => Math.max(1, props.cols * props.rows))
const validItems = computed(() => props.items.filter(i => youtubeId(i.url)))
const totalPages = computed(() => Math.max(1, Math.ceil(validItems.value.length / perPage.value)))
const paged = computed(() =>
  validItems.value.slice((page.value - 1) * perPage.value, page.value * perPage.value)
)
const widthClass = computed(() => COL_WIDTH_CLASS[props.cols] || COL_WIDTH_CLASS[4])

// เปลี่ยนจำนวนคอลัมน์/แถวแล้วหน้าปัจจุบันอาจเกิน → ดึงกลับหน้าสุดท้าย
watch([perPage, () => validItems.value.length], () => {
  if (page.value > totalPages.value) page.value = totalPages.value
})

function watchUrl(item) {
  const id = youtubeId(item.url)
  return id ? `https://www.youtube.com/watch?v=${id}` : item.url
}
</script>

<template>
  <div v-if="validItems.length">
    <div class="flex flex-wrap justify-center gap-4">
      <a v-for="item in paged" :key="item.id || item.url"
        :href="watchUrl(item)" target="_blank" rel="noopener"
        :class="['group glass-card glass-card-hover overflow-hidden', widthClass]">

        <!-- ปกวิดีโอ + ปุ่มเล่น -->
        <div class="relative aspect-video bg-slate-900/5 overflow-hidden">
          <img :src="youtubeThumb(item.url)" :alt="item.title || 'วิดีโอ'" loading="lazy"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
          <div class="absolute inset-0 flex items-center justify-center">
            <span class="w-12 h-12 rounded-full bg-black/55 backdrop-blur-sm ring-1 ring-white/30 flex items-center justify-center group-hover:bg-red-600 group-hover:scale-110 transition-all">
              <svg class="w-5 h-5 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </span>
          </div>
          <span class="absolute top-2 right-2 text-[10px] font-bold px-2 py-0.5 rounded-full bg-black/60 text-white">YouTube</span>
        </div>

        <div class="p-4">
          <p class="font-extrabold text-slate-800 text-sm leading-snug line-clamp-2 group-hover:text-primary transition-colors">
            {{ item.title || 'วิดีโอ YouTube' }}
          </p>
          <p v-if="item.caption" class="text-xs text-slate-500 line-clamp-2 leading-relaxed mt-1">{{ item.caption }}</p>
        </div>
      </a>
    </div>

    <!-- Pagination — แสดงเมื่อเกิน 1 หน้าเท่านั้น -->
    <div v-if="totalPages > 1" class="flex items-center justify-center gap-2 mt-6">
      <button @click="page--" :disabled="page === 1" aria-label="หน้าก่อน"
        class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:border-primary/40 hover:text-primary transition-all disabled:opacity-30 disabled:hover:border-white/80">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
        </svg>
      </button>
      <button v-for="p in totalPages" :key="p" @click="page = p"
        :class="['w-9 h-9 rounded-xl text-sm font-bold border transition-all',
          page === p ? 'bg-primary text-white border-primary shadow-sm'
                     : 'border-white/80 bg-white/60 backdrop-blur text-slate-600 hover:border-primary/40']">
        {{ p }}
      </button>
      <button @click="page++" :disabled="page === totalPages" aria-label="หน้าถัดไป"
        class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:border-primary/40 hover:text-primary transition-all disabled:opacity-30 disabled:hover:border-white/80">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
        </svg>
      </button>
    </div>
  </div>
</template>
