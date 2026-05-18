<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

const schools     = ref([])
const students    = ref([])
const total       = ref(0)
const loading     = ref(false)

const filterSchool = ref('')
const filterYear   = ref('2568')
const filterTerm   = ref('1')
const filterGrade  = ref('')
const filterGender = ref('')
const filterDis    = ref(false)
const page         = ref(0)
const PAGE_SIZE    = 100

const YEAR_OPTIONS  = ['2568', '2567', '2566', '2565']
const TERM_OPTIONS  = [{ value: '', label: 'ทุกภาคเรียน' }, { value: '1', label: 'ภาคเรียนที่ 1' }, { value: '2', label: 'ภาคเรียนที่ 2' }]
const GENDER_OPTIONS = [{ value: '', label: 'ทุกเพศ' }, { value: 'ช', label: 'ชาย' }, { value: 'ญ', label: 'หญิง' }]

const grades = ['', 'ป.1','ป.2','ป.3','ป.4','ป.5','ป.6','ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']

async function fetchSchools() {
  const { data } = await supabase.from('schools').select('id, name, dmc_code').order('name')
  schools.value = data || []
}

async function fetchStudents() {
  loading.value = true
  const { data, error } = await supabase.rpc('get_students_admin', {
    p_school_id: filterSchool.value || null,
    p_year:      filterYear.value   || null,
    p_term:      filterTerm.value   || null,
    p_grade:     filterGrade.value  || null,
    p_gender:    filterGender.value || null,
    p_dis:       filterDis.value    || null,
    p_limit:     PAGE_SIZE,
    p_offset:    page.value * PAGE_SIZE,
  })
  loading.value = false
  if (error || !data) { students.value = []; total.value = 0; return }
  students.value = data.rows || []
  total.value    = data.total || 0
}

const totalPages = computed(() => Math.ceil(total.value / PAGE_SIZE))

async function search() { page.value = 0; await fetchStudents() }
async function prevPage() { if (page.value > 0) { page.value--; await fetchStudents() } }
async function nextPage() { if (page.value < totalPages.value - 1) { page.value++; await fetchStudents() } }

// Stats computed from current result (approximation)
const maleCount   = computed(() => students.value.filter(s => s.gender === 'ช').length)
const femaleCount = computed(() => students.value.filter(s => s.gender === 'ญ').length)
const disCount    = computed(() => students.value.filter(s => s.disadvantaged && s.disadvantaged !== '-').length)

function exportCSV() {
  const headers = ['รหัสโรงเรียน','ชื่อโรงเรียน','เลขบัตรปชช.','รหัสนักเรียน','ชั้น','ห้อง','เพศ','ชื่อ','นามสกุล','วันเกิด','อายุ','น้ำหนัก','ส่วนสูง','กลุ่มเลือด','ศาสนา','สัญชาติ','ความด้อยโอกาส','ปีการศึกษา','ภาคเรียน']
  const rows = students.value.map(s => [
    s.dmc_code, s.school_name, s.national_id, s.student_code, s.grade, s.room,
    s.gender, s.first_name, s.last_name, s.birth_date, s.age_years,
    s.weight, s.height, s.blood_type, s.religion, s.nationality,
    s.disadvantaged, s.academic_year, s.term,
  ].map(v => `"${String(v ?? '').replace(/"/g,'""')}"`).join(','))
  const csv  = [headers.join(','), ...rows].join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const a    = document.createElement('a')
  a.href     = URL.createObjectURL(blob)
  a.download = `students_${filterYear.value}_${filterTerm.value || 'all'}.csv`
  a.click()
}

function bmiClass(w, h) {
  if (!w || !h || h <= 0) return ''
  const bmi = w / Math.pow(h / 100, 2)
  if (bmi < 18.5) return 'text-blue-500'
  if (bmi < 23)   return 'text-emerald-600'
  if (bmi < 25)   return 'text-amber-500'
  return 'text-red-500'
}

function bmiLabel(w, h) {
  if (!w || !h || h <= 0) return '-'
  const bmi = w / Math.pow(h / 100, 2)
  return bmi.toFixed(1)
}

onMounted(async () => { await fetchSchools(); await fetchStudents() })
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197"/>
          </svg>
          ข้อมูลนักเรียน
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">รวมทุกโรงเรียน · พบ {{ total.toLocaleString() }} คน</p>
      </div>
      <button @click="exportCSV"
        class="flex items-center gap-2 px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-white text-sm font-bold rounded-xl transition-colors shadow-md">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/>
        </svg>
        Export CSV
      </button>
    </div>

    <!-- Stats cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div v-for="(item, i) in [
        { label: 'ทั้งหมด (หน้านี้)',  value: students.length, color: 'text-primary' },
        { label: 'ชาย',               value: maleCount,   color: 'text-blue-600' },
        { label: 'หญิง',              value: femaleCount,  color: 'text-pink-500' },
        { label: 'ด้อยโอกาส',         value: disCount,     color: 'text-amber-600' },
      ]" :key="i" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
        <p class="text-2xl font-extrabold" :class="item.color">{{ item.value.toLocaleString() }}</p>
        <p class="text-xs text-slate-500 mt-0.5">{{ item.label }}</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <select v-model="filterSchool"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="">ทุกโรงเรียน</option>
        <option v-for="s in schools" :key="s.id" :value="s.id">{{ s.name }}</option>
      </select>
      <select v-model="filterYear"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option v-for="y in YEAR_OPTIONS" :key="y" :value="y">ปี {{ y }}</option>
      </select>
      <select v-model="filterTerm"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option v-for="t in TERM_OPTIONS" :key="t.value" :value="t.value">{{ t.label }}</option>
      </select>
      <select v-model="filterGrade"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="">ทุกชั้น</option>
        <option v-for="g in grades.slice(1)" :key="g" :value="g">{{ g }}</option>
      </select>
      <select v-model="filterGender"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option v-for="g in GENDER_OPTIONS" :key="g.value" :value="g.value">{{ g.label }}</option>
      </select>
      <button @click="filterDis = !filterDis"
        :class="['flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border-2 transition-all',
          filterDis ? 'border-amber-500 bg-amber-50 text-amber-700' : 'border-slate-200 text-slate-500 bg-white']">
        ด้อยโอกาสเท่านั้น
      </button>
      <button @click="search"
        class="px-4 py-2 bg-primary text-white text-sm font-bold rounded-xl hover:bg-primary-dark transition-colors">
        ค้นหา
      </button>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div v-if="loading" class="p-8 text-center text-slate-400 text-sm">กำลังโหลด...</div>
      <div v-else-if="!students.length" class="p-8 text-center text-slate-400 text-sm">ไม่พบข้อมูล</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-100">
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">โรงเรียน</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">ชั้น/ห้อง</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500">ชื่อ-นามสกุล</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">เพศ</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">อายุ</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">น้ำหนัก/สูง</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500 whitespace-nowrap">BMI</th>
              <th class="px-3 py-3 text-left font-bold text-slate-500">ด้อยโอกาส</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="s in students" :key="s.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-3 py-2.5">
                <p class="font-bold text-slate-700 truncate max-w-[140px]">{{ s.school_name }}</p>
                <p class="text-slate-400 font-mono">{{ s.dmc_code }}</p>
              </td>
              <td class="px-3 py-2.5 whitespace-nowrap">
                <span class="font-bold text-slate-700">{{ s.grade }}</span>
                <span class="text-slate-400 ml-1">ห้อง {{ s.room }}</span>
              </td>
              <td class="px-3 py-2.5">
                <p class="font-bold text-slate-800">{{ s.prefix }}{{ s.first_name }} {{ s.last_name }}</p>
              </td>
              <td class="px-3 py-2.5">
                <span :class="['font-bold px-2 py-0.5 rounded-full text-[10px]',
                  s.gender === 'ช' ? 'bg-blue-100 text-blue-700' : 'bg-pink-100 text-pink-600']">
                  {{ s.gender === 'ช' ? 'ชาย' : 'หญิง' }}
                </span>
              </td>
              <td class="px-3 py-2.5 text-slate-600">{{ s.age_years || '-' }}</td>
              <td class="px-3 py-2.5 text-slate-600 whitespace-nowrap">
                {{ s.weight || '-' }} / {{ s.height || '-' }}
              </td>
              <td class="px-3 py-2.5 font-bold whitespace-nowrap" :class="bmiClass(s.weight, s.height)">
                {{ bmiLabel(s.weight, s.height) }}
              </td>
              <td class="px-3 py-2.5">
                <span v-if="s.disadvantaged && s.disadvantaged !== '-'"
                  class="text-[10px] font-bold px-2 py-0.5 bg-amber-100 text-amber-700 rounded-full">
                  {{ s.disadvantaged }}
                </span>
                <span v-else class="text-slate-300">-</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="flex items-center justify-between text-sm">
      <p class="text-slate-500">หน้า {{ page + 1 }} / {{ totalPages }} · ทั้งหมด {{ total.toLocaleString() }} คน</p>
      <div class="flex gap-2">
        <button @click="prevPage" :disabled="page === 0"
          class="px-4 py-2 border border-slate-200 rounded-xl font-bold text-slate-600 hover:bg-slate-50 disabled:opacity-40 transition-all">
          ← ก่อนหน้า
        </button>
        <button @click="nextPage" :disabled="page >= totalPages - 1"
          class="px-4 py-2 border border-slate-200 rounded-xl font-bold text-slate-600 hover:bg-slate-50 disabled:opacity-40 transition-all">
          ถัดไป →
        </button>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
