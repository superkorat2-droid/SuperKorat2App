<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { supabaseAdmin } from '../../supabaseAdmin'
import { useAreaConfig } from '../../composables/useAreaConfig'
import Swal from 'sweetalert2'

const { config, fetchConfig } = useAreaConfig()

const defaultPassword = computed(() =>
  config.value?.default_school_password || 'Korat2@2569'
)

const schools  = ref([])
const loading  = ref(true)
const searchQ  = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')

onMounted(() => { fetchConfig(); fetchSchools() })

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
    html: `<span class="text-sm">โรงเรียน: <b>${school.name}</b><br>รหัสผ่านจะถูกเปลี่ยนเป็น <b>${defaultPassword.value}</b></span>`,
    icon: 'question',
    showCancelButton: true,
    confirmButtonText: 'รีเซ็ต',
    cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#ef4444',
  })
  if (!result.isConfirmed) return

  if (!supabaseAdmin) {
    Swal.fire({ icon: 'error', title: 'ไม่พบ Service Key', text: 'กรุณาตั้งค่า VITE_SUPABASE_SERVICE_KEY ใน .env.local' })
    return
  }

  // ค้นหา user จาก email
  const { data: { users } } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 })
  let user = users?.find(u => u.email?.toLowerCase() === school.email?.toLowerCase())

  // ถ้ายังไม่มี account → สร้างใหม่
  if (!user) {
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email:            school.email,
      password:         defaultPassword.value,
      email_confirm:    true,
      user_metadata:    { full_name: school.name },
    })
    if (createErr) { Swal.fire({ icon: 'error', title: 'สร้าง account ไม่สำเร็จ', text: createErr.message }); return }
    user = created.user
    // สร้าง profile
    await supabase.from('profiles').upsert({
      id:         user.id,
      email:      school.email,
      full_name:  school.name,
      role:       'school',
      school_id:  school.id,
      is_approved:true,
      is_active:  true,
    }, { onConflict: 'id' })
    Swal.fire({ icon: 'success', title: 'สร้าง account และรีเซ็ตสำเร็จ', html: `Email: <b>${school.email}</b><br>Password: <b>${defaultPassword.value}</b>`, showConfirmButton: true })
    return
  }

  const { error } = await supabaseAdmin.auth.admin.updateUserById(user.id, { password: defaultPassword.value })
  if (error) {
    Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message })
  } else {
    Swal.fire({ icon: 'success', title: 'รีเซ็ตสำเร็จ', html: `Password: <b>${defaultPassword.value}</b>`, showConfirmButton: false, timer: 2000 })
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

// ─── Edit modal ───────────────────────────────────────────────────────────────
const editSchool  = ref(null)
const editSaving  = ref(false)

function openEdit(school) {
  editSchool.value = { ...school }
}
function closeEdit() { editSchool.value = null }

async function saveEdit() {
  if (!editSchool.value) return
  editSaving.value = true
  const { id, ...fields } = editSchool.value
  const payload = {
    name:         fields.name?.trim(),
    subdistrict:  fields.subdistrict?.trim() || null,
    district:     fields.district?.trim() || null,
    school_group: fields.school_group?.trim() || null,
    email:        fields.email?.trim() || null,
    phone:        fields.phone?.trim() || null,
    website_url:  fields.website_url?.trim() || null,
    distance_km:  fields.distance_km ? Number(fields.distance_km) : null,
    lat:          fields.lat ? Number(fields.lat) : null,
    lng:          fields.lng ? Number(fields.lng) : null,
    school_code:  fields.school_code?.trim() || null,
  }
  const { error } = await supabase.from('schools').update(payload).eq('id', id)
  editSaving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    closeEdit()
    fetchSchools()
    Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1200 })
  }
}

// เปิด Google Maps เพื่อคัดลอกพิกัด
function openMapsForGps(school) {
  const name = encodeURIComponent(school.name || '')
  window.open(`https://www.google.com/maps/search/${name}`, '_blank', 'noopener')
}
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
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 whitespace-nowrap">แก้ไข</th>
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
                <button @click="openEdit(s)"
                  class="px-2.5 py-1 text-[11px] font-bold text-primary border border-primary/30 rounded-lg hover:bg-primary/10 transition-colors">
                  แก้ไข
                </button>
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

  <!-- ── Edit Modal ───────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="editSchool"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden">

          <!-- Header -->
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h2 class="font-extrabold text-slate-800">แก้ไขข้อมูลโรงเรียน</h2>
              <p class="text-xs text-slate-400 mt-0.5 font-mono">{{ editSchool.dmc_code }}</p>
            </div>
            <button @click="closeEdit" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-5">

            <!-- ชื่อ + รหัส -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="sm:col-span-2">
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อโรงเรียน <span class="text-red-500">*</span></label>
                <input v-model="editSchool.name" type="text"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">รหัส DMC</label>
                <input v-model="editSchool.dmc_code" type="text" disabled
                  class="w-full px-3 py-2.5 border border-slate-100 bg-slate-50 rounded-xl text-sm font-mono text-slate-400"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">รหัสสถานศึกษา</label>
                <input v-model="editSchool.school_code" type="text"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>

            <!-- ที่อยู่ -->
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ตำบล</label>
                <input v-model="editSchool.subdistrict" type="text"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">อำเภอ</label>
                <input v-model="editSchool.district" type="text"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ศูนย์เครือข่าย</label>
                <input v-model="editSchool.school_group" type="text"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>

            <!-- ติดต่อ -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">อีเมล</label>
                <input v-model="editSchool.email" type="email"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">เบอร์โทรศัพท์</label>
                <input v-model="editSchool.phone" type="text" placeholder="0XX-XXX-XXXX"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div class="sm:col-span-2">
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">เว็บไซต์</label>
                <input v-model="editSchool.website_url" type="url" placeholder="https://..."
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>

            <!-- GPS + ระยะทาง -->
            <div class="bg-slate-50 rounded-2xl p-4 space-y-3">
              <div class="flex items-center justify-between">
                <p class="text-xs font-bold text-slate-600 uppercase tracking-wider">พิกัด GPS</p>
                <button @click="openMapsForGps(editSchool)" type="button"
                  class="flex items-center gap-1.5 text-xs text-emerald-600 font-bold hover:underline">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"/>
                  </svg>
                  ค้นหาใน Google Maps
                </button>
              </div>
              <div class="grid grid-cols-3 gap-3">
                <div>
                  <label class="block text-xs text-slate-500 mb-1">Latitude</label>
                  <input v-model="editSchool.lat" type="number" step="0.000001" placeholder="15.123456"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="block text-xs text-slate-500 mb-1">Longitude</label>
                  <input v-model="editSchool.lng" type="number" step="0.000001" placeholder="102.123456"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="block text-xs text-slate-500 mb-1">ระยะทาง (กม.)</label>
                  <input v-model="editSchool.distance_km" type="number" step="0.1" placeholder="0.0"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs focus:outline-none focus:border-primary"/>
                </div>
              </div>
              <p class="text-[10px] text-slate-400">กดปุ่ม "ค้นหาใน Google Maps" → คลิกขวาที่ตำแหน่งโรงเรียน → คัดลอกพิกัด</p>
            </div>
          </div>

          <!-- Footer -->
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="closeEdit" class="px-5 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors">
              ยกเลิก
            </button>
            <button @click="saveEdit" :disabled="editSaving"
              class="flex items-center gap-2 px-6 py-2.5 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              <svg v-if="editSaving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              {{ editSaving ? 'กำลังบันทึก...' : 'บันทึก' }}
            </button>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>

</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
