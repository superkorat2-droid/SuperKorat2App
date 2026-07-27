<script setup>
// การ์ดข่าวมาตรฐาน — เดิมโค้ดชุดนี้ถูก copy-paste อยู่ใน HomeView และ NewsView
// แบบเหมือนกันเกือบทุกบรรทัด ต่างกันแค่ที่มาของป้ายหมวดหมู่และป้าย "ไฟล์"
// จึงรับ label/class ของหมวดหมู่มาเป็น prop ให้แต่ละหน้าคำนวณเอง
defineProps({
  news:          { type: Object,  required: true },
  categoryLabel: { type: String,  default: '' },
  categoryClass: { type: String,  default: 'bg-slate-100 text-slate-600' },
  showFileBadge: { type: Boolean, default: false },
  dateText:      { type: String,  default: '' },
})
</script>

<template>
  <div class="group glass-card glass-card-hover overflow-hidden cursor-pointer">

    <!-- Cover image -->
    <div class="relative aspect-video bg-slate-100/60 overflow-hidden ring-1 ring-inset ring-slate-900/[0.06]">
      <img v-if="news.cover_url" :src="news.cover_url" :alt="news.title"
        class="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-500"/>
      <div v-else class="w-full h-full flex items-center justify-center gradient-primary opacity-80">
        <svg class="w-10 h-10 text-white/50" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
        </svg>
      </div>

      <!-- ปักหมุด -->
      <div v-if="news.is_pinned" class="absolute top-2 left-2">
        <span class="flex items-center gap-1 px-2 py-0.5 bg-amber-400 text-white text-[10px] font-bold rounded-full shadow">
          <svg class="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24"><path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/></svg>
          ปักหมุด
        </span>
      </div>

      <!-- หมวดหมู่ -->
      <div class="absolute bottom-2 left-2">
        <span :class="['text-[10px] font-bold px-2.5 py-0.5 rounded-full shadow-sm', categoryClass]">
          {{ categoryLabel }}
        </span>
      </div>

      <!-- มีไฟล์แนบ -->
      <div v-if="showFileBadge && (news.links?.length || news.file_url)" class="absolute top-2 right-2">
        <span class="flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 bg-white/90 text-slate-600 rounded-full shadow-sm">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13"/>
          </svg>
          ไฟล์
        </span>
      </div>
    </div>

    <!-- Content -->
    <div class="p-4">
      <p class="font-extrabold text-slate-800 text-sm leading-snug line-clamp-2 group-hover:text-primary transition-colors duration-200 mb-2">
        {{ news.title }}
      </p>
      <p v-if="news.excerpt" class="text-xs text-slate-500 line-clamp-2 leading-relaxed mb-3">
        {{ news.excerpt }}
      </p>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2.5">
          <span class="text-[11px] text-slate-500">{{ dateText }}</span>
          <span class="flex items-center gap-0.5 text-[11px] text-slate-500">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            {{ news.view_count || 0 }}
          </span>
        </div>
        <span class="text-[11px] font-bold text-primary flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          อ่านต่อ
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>
          </svg>
        </span>
      </div>
    </div>
  </div>
</template>
