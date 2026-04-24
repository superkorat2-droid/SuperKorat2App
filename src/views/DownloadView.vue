<script setup>
import { ref, computed } from 'vue'

const searchQ = ref('')
const activeCategory = ref('all')

const categories = [
  { key: 'all',       label: 'ทั้งหมด',            icon: '📂' },
  { key: 'form',      label: 'แบบฟอร์มธุรการ',     icon: '📝' },
  { key: 'supervision',label: 'เอกสารนิเทศ',        icon: '🔍' },
  { key: 'curriculum',label: 'หลักสูตรและมาตรฐาน', icon: '📖' },
  { key: 'report',    label: 'รายงานและสถิติ',      icon: '📊' },
]

const files = ref([
  { id:1,  cat:'form',       title:'แบบคำร้องทั่วไป',                             type:'DOCX', size:'45 KB',  date:'2025-03-10', icon:'📝', dl:0 },
  { id:2,  cat:'form',       title:'แบบฟอร์มขอรับการนิเทศ',                        type:'PDF',  size:'62 KB',  date:'2025-02-15', icon:'📄', dl:0 },
  { id:3,  cat:'form',       title:'แบบฟอร์มธุรการ/หนังสือราชการ',                 type:'DOCX', size:'88 KB',  date:'2025-01-20', icon:'📝', dl:0 },
  { id:4,  cat:'supervision', title:'แบบบันทึก Classroom Observation',             type:'PDF',  size:'120 KB', date:'2025-03-01', icon:'🔍', dl:0 },
  { id:5,  cat:'supervision', title:'แบบรายงานผลการนิเทศ',                         type:'XLSX', size:'95 KB',  date:'2025-02-28', icon:'📊', dl:0 },
  { id:6,  cat:'supervision', title:'คู่มือการนิเทศ Coaching & Mentoring',          type:'PDF',  size:'2.1 MB', date:'2025-01-05', icon:'📖', dl:0 },
  { id:7,  cat:'supervision', title:'แผนการนิเทศ ปีการศึกษา 2567',                 type:'PDF',  size:'380 KB', date:'2024-11-01', icon:'📅', dl:0 },
  { id:8,  cat:'curriculum',  title:'ตัวชี้วัดและสาระการเรียนรู้แกนกลาง 2551/2560', type:'PDF',  size:'5.2 MB', date:'2024-10-01', icon:'📖', dl:0 },
  { id:9,  cat:'curriculum',  title:'คู่มือการจัดทำหลักสูตรสถานศึกษา',               type:'DOCX', size:'1.8 MB', date:'2024-09-15', icon:'📝', dl:0 },
  { id:10, cat:'curriculum',  title:'แนวทางการจัดการศึกษาปฐมวัย พ.ศ. 2560',         type:'PDF',  size:'3.4 MB', date:'2024-08-01', icon:'🧒', dl:0 },
  { id:11, cat:'report',      title:'รายงานผลการประเมิน O-NET ปี 2566',              type:'PDF',  size:'760 KB', date:'2024-06-01', icon:'📊', dl:0 },
  { id:12, cat:'report',      title:'รายงานผลการประเมิน NT ป.3 ปี 2566',             type:'PDF',  size:'540 KB', date:'2024-05-20', icon:'📊', dl:0 },
  { id:13, cat:'report',      title:'รายงานสรุปสถิติสถานศึกษา ปี 2566',              type:'XLSX', size:'220 KB', date:'2024-05-01', icon:'📈', dl:0 },
  { id:14, cat:'report',      title:'Annual Report กลุ่มนิเทศฯ ปีการศึกษา 2566',    type:'PDF',  size:'4.8 MB', date:'2024-04-01', icon:'📑', dl:0 },
])

const filtered = computed(() => {
  let list = files.value
  if (activeCategory.value !== 'all') list = list.filter(f => f.cat === activeCategory.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(f => f.title.toLowerCase().includes(q))
  return list
})

const typeColor = { PDF: 'bg-red-100 text-red-700', DOCX: 'bg-blue-100 text-blue-700', XLSX: 'bg-emerald-100 text-emerald-700' }

function download(file) {
  file.dl++
  alert(`กำลังดาวน์โหลด: ${file.title}\n(Demo — ยังไม่ได้เชื่อมไฟล์จริง)`)
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="font-sarabun text-slate-800 py-10">
    <div class="max-w-5xl mx-auto px-4">

      <!-- Header -->
      <div class="mb-10">
        <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Downloads</p>
        <h1 class="text-3xl font-extrabold text-slate-900">ดาวน์โหลดเอกสาร</h1>
        <p class="text-slate-500 mt-2">แบบฟอร์ม คู่มือ เอกสารราชการ และรายงานต่าง ๆ</p>
      </div>

      <!-- Search + stats -->
      <div class="flex flex-col sm:flex-row gap-3 mb-6">
        <div class="relative flex-1">
          <svg class="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0"/>
          </svg>
          <input v-model="searchQ" type="text" placeholder="ค้นหาเอกสาร..."
            class="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-300 focus:border-blue-400 bg-white"/>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-500 bg-white border border-slate-200 rounded-xl px-4 py-2.5 flex-shrink-0">
          <span class="font-bold text-blue-600">{{ filtered.length }}</span>
          <span>รายการ</span>
        </div>
      </div>

      <!-- Category tabs -->
      <div class="flex flex-wrap gap-2 mb-6">
        <button v-for="cat in categories" :key="cat.key"
          @click="activeCategory = cat.key"
          :class="['flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all border',
            activeCategory === cat.key
              ? 'bg-blue-600 text-white border-blue-600 shadow-md'
              : 'bg-white text-slate-600 border-slate-200 hover:border-blue-300 hover:text-blue-600']">
          {{ cat.icon }} {{ cat.label }}
        </button>
      </div>

      <!-- File list -->
      <div v-if="filtered.length === 0" class="text-center py-20 text-slate-400">
        <span class="text-5xl block mb-3">🔍</span>
        <p>ไม่พบเอกสารที่ค้นหา</p>
      </div>
      <div v-else class="space-y-3">
        <div v-for="file in filtered" :key="file.id"
          class="flex items-center gap-4 bg-white rounded-2xl border border-slate-100 p-4 shadow-sm hover:shadow-md hover:border-blue-200 transition-all group">
          <div class="w-12 h-12 bg-slate-50 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">
            {{ file.icon }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-bold text-slate-800 group-hover:text-blue-700 transition-colors leading-snug truncate">{{ file.title }}</p>
            <div class="flex items-center gap-3 mt-1 flex-wrap">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded font-mono', typeColor[file.type] || 'bg-slate-100 text-slate-600']">{{ file.type }}</span>
              <span class="text-xs text-slate-400">{{ file.size }}</span>
              <span class="text-xs text-slate-400">{{ formatDate(file.date) }}</span>
            </div>
          </div>
          <button @click="download(file)"
            class="flex items-center gap-1.5 bg-blue-50 hover:bg-blue-600 text-blue-600 hover:text-white text-xs font-bold px-4 py-2 rounded-xl transition-all flex-shrink-0 border border-blue-200 hover:border-blue-600">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
            </svg>
            ดาวน์โหลด
          </button>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
