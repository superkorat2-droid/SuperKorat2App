<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const schools  = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')

onMounted(fetchSchools)

async function fetchSchools() {
  loading.value = true
  const { data } = await supabase
    .from('schools')
    .select('*')
    .order('district')
    .order('school_group')
    .order('name')
  schools.value = data || []
  loading.value = false
}

const districts = computed(() => ['all', ...new Set(schools.value.map(s => s.district))])
const groups    = computed(() => {
  const src = filterDistrict.value === 'all'
    ? schools.value
    : schools.value.filter(s => s.district === filterDistrict.value)
  return ['all', ...new Set(src.map(s => s.school_group))]
})

const filtered = computed(() => {
  let list = schools.value
  if (filterDistrict.value !== 'all') list = list.filter(s => s.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(s => s.school_group === filterGroup.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(s =>
      s.name.toLowerCase().includes(q) ||
      s.dmc_code.includes(q) ||
      s.email.toLowerCase().includes(q)
    )
  }
  return list
})

// Reset password
async function resetPassword(school) {
  const result = await Swal.fire({
    title: 'รีเซ็ตรหัสผ่าน?',
    html: `<span class="text-sm">โรงเรียน: <b>${school.name}</b><br>รหัสผ่านจะถูกเปลี่ยนเป็น <b>Korat2@2569</b></span>`,
    icon: 'question',
    showCancelButton: true,
    confirmButtonText: 'รีเซ็ต',
    cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#ef4444',
  })
  if (!result.isConfirmed) return

  // find auth user by email, then update password
  const { data: { users }, error: listErr } = await supabase.auth.admin.listUsers()
  const user = users?.find(u => u.email === school.email)
  if (!user) { Swal.fire({ icon: 'error', title: 'ไม่พบ user', text: school.email }); return }

  const { error } = await supabase.auth.admin.updateUserById(user.id, { password: 'Korat2@2569' })
  if (error) {
    Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message })
  } else {
    Swal.fire({ icon: 'success', title: 'รีเซ็ตสำเร็จ', showConfirmButton: false, timer: 1200 })
  }
}

function exportCSV() {
  const header = ['dmc_code','name','subdistrict','district','school_group','email','website_url','distance_km','lat','lng']
  const rows = filtered.value.map(s => header.map(k => `"${(s[k] ?? '').toString().replace(/"/g,'""')}"`).join(','))
  const csv  = [header.join(','), ...rows].join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a'); a.href = URL.createObjectURL(blob)
  a.download = `schools_${new Date().toISOString().slice(0,10)}.csv`
  a.click()
}

const withWebsite = computed(() => schools.value.filter(s => s.website_url).length)
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75"/>
          </svg>
          ทำเนียบโรงเรียน
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">โรงเรียนทั้งหมด {{ schools.length }} แห่ง · มีเว็บไซต์ {{ withWebsite }} แห่ง</p>
      </div>
      <button @click="exportCSV"
        class="flex items-center gap-2 px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-white text-sm font-bold rounded-xl transition-colors shadow-md">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/>
        </svg>
        Export CSV
      </button>
    </div>

    <!-- Stats bar -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div v-for="(item, i) in [
        { label: 'โรงเรียนทั้งหมด', value: schools.length, color: 'text-primary' },
        { label: 'มีเว็บไซต์', value: withWebsite, color: 'text-emerald-600' },
        { label: 'ไม่มีเว็บไซต์', value: schools.length - withWebsite, color: 'text-amber-600' },
        { label: 'ผลการค้นหา', value: filtered.length, color: 'text-slate-700' },
      ]" :key="i" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
        <p class="text-2xl font-extrabold" :class="item.color">{{ item.value }}</p>
        <p class="text-xs text-slate-500 mt-0.5">{{ item.label }}</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน, DMC, อีเมล..."
        class="flex-1 min-w-[200px] px-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary transition-all bg-white"/>
      <select v-model="filterDistrict" @change="filterGroup='all'"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="all">ทุกอำเภอ</option>
        <option v-for="d in districts.slice(1)" :key="d" :value="d">{{ d }}</option>
      </select>
      <select v-model="filterGroup"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="all">ทุกกลุ่ม</option>
        <option v-for="g in groups.slice(1)" :key="g" :value="g">{{ g }}</option>
      </select>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div v-if="loading" class="p-8 text-center text-slate-400 text-sm">กำลังโหลด...</div>
      <div v-else-if="filtered.length === 0" class="p-8 text-center text-slate-400 text-sm">ไม่พบโรงเรียน</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-100">
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 whitespace-nowrap">DMC</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ชื่อโรงเรียน</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 whitespace-nowrap">อำเภอ</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 whitespace-nowrap">กลุ่ม</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">อีเมล</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">เว็บไซต์</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 whitespace-nowrap">รีเซ็ต Pass</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="s in filtered" :key="s.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3 font-mono text-xs text-slate-500 whitespace-nowrap">{{ s.dmc_code }}</td>
              <td class="px-4 py-3 font-bold text-slate-800 text-xs">{{ s.name }}</td>
              <td class="px-4 py-3 text-xs text-slate-600 whitespace-nowrap">{{ s.district }}</td>
              <td class="px-4 py-3 text-xs text-slate-600 whitespace-nowrap">{{ s.school_group }}</td>
              <td class="px-4 py-3 text-xs text-slate-500">{{ s.email }}</td>
              <td class="px-4 py-3">
                <a v-if="s.website_url" :href="s.website_url" target="_blank"
                  class="text-xs text-primary hover:underline truncate block max-w-[160px]">
                  {{ s.website_url }}
                </a>
                <span v-else class="text-xs text-slate-300 italic">ยังไม่มี</span>
              </td>
              <td class="px-4 py-3 text-center">
                <button @click="resetPassword(s)"
                  class="px-2.5 py-1 text-[11px] font-bold text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors">
                  รีเซ็ต
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
