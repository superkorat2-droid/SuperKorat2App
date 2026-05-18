<script setup>
import { computed } from 'vue'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const hasWebsite = computed(() => !!props.school?.website_url)

const INFO_ITEMS = computed(() => [
  { label: 'รหัส DMC',       value: props.school?.dmc_code },
  { label: 'รหัสสถานศึกษา', value: props.school?.school_code },
  { label: 'ตำบล',           value: props.school?.subdistrict },
  { label: 'อำเภอ',          value: props.school?.district },
  { label: 'กลุ่มโรงเรียน', value: props.school?.school_group },
  { label: 'อีเมล',          value: props.school?.email },
  { label: 'ระยะทางถึง สพป.', value: props.school?.distance_km ? `${props.school.distance_km} กม.` : '-' },
])
</script>

<template>
  <div class="space-y-6 max-w-3xl">

    <!-- Welcome -->
    <div class="gradient-primary rounded-3xl p-6 md:p-8 text-white relative overflow-hidden">
      <div class="absolute -right-10 -top-10 w-40 h-40 rounded-full bg-white/5"></div>
      <div class="absolute -right-4 -bottom-8 w-28 h-28 rounded-full bg-white/5"></div>
      <div class="relative">
        <p class="text-white/60 text-xs font-bold uppercase tracking-widest mb-2">ยินดีต้อนรับ</p>
        <h1 class="text-xl md:text-2xl font-extrabold leading-snug mb-1">{{ school?.name }}</h1>
        <p class="text-white/60 text-sm">{{ school?.subdistrict }} · {{ school?.district }} · {{ school?.school_group }}</p>
      </div>
    </div>

    <!-- Quick actions -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
      <router-link to="/school/profile"
        class="group bg-white rounded-2xl border border-slate-100 shadow-sm p-5 hover:shadow-md hover:-translate-y-0.5 transition-all">
        <div class="w-10 h-10 rounded-xl bg-primary-light flex items-center justify-center mb-3 group-hover:bg-primary transition-colors">
          <svg class="w-5 h-5 text-primary group-hover:text-white transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z"/>
          </svg>
        </div>
        <p class="font-extrabold text-slate-800 text-sm">แก้ไขข้อมูลโรงเรียน</p>
        <p class="text-xs text-slate-400 mt-0.5">อัปเดตเว็บไซต์และข้อมูลติดต่อ</p>
      </router-link>

      <router-link to="/school/dmc"
        class="group bg-white rounded-2xl border border-slate-100 shadow-sm p-5 hover:shadow-md hover:-translate-y-0.5 transition-all">
        <div class="w-10 h-10 rounded-xl bg-emerald-100 flex items-center justify-center mb-3 group-hover:bg-emerald-500 transition-colors">
          <svg class="w-5 h-5 text-emerald-600 group-hover:text-white transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
          </svg>
        </div>
        <p class="font-extrabold text-slate-800 text-sm">อัปโหลดไฟล์ DMC</p>
        <p class="text-xs text-slate-400 mt-0.5">ส่งข้อมูล Excel/CSV ประจำภาคเรียน</p>
      </router-link>

      <a v-if="hasWebsite" :href="school.website_url" target="_blank" rel="noopener"
        class="group bg-white rounded-2xl border border-slate-100 shadow-sm p-5 hover:shadow-md hover:-translate-y-0.5 transition-all">
        <div class="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center mb-3 group-hover:bg-blue-500 transition-colors">
          <svg class="w-5 h-5 text-blue-600 group-hover:text-white transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253"/>
          </svg>
        </div>
        <p class="font-extrabold text-slate-800 text-sm">เว็บไซต์โรงเรียน</p>
        <p class="text-xs text-slate-400 mt-0.5 truncate">{{ school.website_url }}</p>
      </a>
      <router-link v-else to="/school/profile"
        class="group bg-amber-50 rounded-2xl border-2 border-dashed border-amber-200 p-5 hover:border-amber-400 transition-all">
        <div class="w-10 h-10 rounded-xl bg-amber-100 flex items-center justify-center mb-3">
          <svg class="w-5 h-5 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
          </svg>
        </div>
        <p class="font-extrabold text-amber-700 text-sm">ยังไม่มีเว็บไซต์</p>
        <p class="text-xs text-amber-500 mt-0.5">คลิกเพื่อเพิ่ม URL เว็บไซต์โรงเรียน</p>
      </router-link>
    </div>

    <!-- School info table -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div class="px-5 py-4 border-b border-slate-50">
        <h2 class="font-extrabold text-slate-800">ข้อมูลโรงเรียน</h2>
      </div>
      <div class="divide-y divide-slate-50">
        <div v-for="item in INFO_ITEMS" :key="item.label"
          class="flex items-center px-5 py-3 gap-4">
          <span class="text-xs font-bold text-slate-400 w-36 flex-shrink-0">{{ item.label }}</span>
          <span class="text-sm text-slate-700 font-medium">{{ item.value || '—' }}</span>
        </div>
        <div class="flex items-center px-5 py-3 gap-4">
          <span class="text-xs font-bold text-slate-400 w-36 flex-shrink-0">เว็บไซต์</span>
          <a v-if="hasWebsite" :href="school.website_url" target="_blank"
            class="text-sm text-primary font-medium hover:underline truncate">
            {{ school.website_url }}
          </a>
          <span v-else class="text-sm text-slate-400 italic">ยังไม่ได้กรอก</span>
        </div>
        <div class="flex items-center px-5 py-3 gap-4">
          <span class="text-xs font-bold text-slate-400 w-36 flex-shrink-0">พิกัด GPS</span>
          <span class="text-sm text-slate-700 font-medium font-mono text-xs">
            {{ school?.lat?.toFixed(6) }}, {{ school?.lng?.toFixed(6) }}
          </span>
        </div>
      </div>
    </div>

  </div>
</template>
