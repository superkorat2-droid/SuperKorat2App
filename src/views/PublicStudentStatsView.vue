<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const { config } = useAreaConfig()
const loading = ref(true)
const data    = ref(null)
const error   = ref(null)

onMounted(async () => {
  const { data: d, error: e } = await supabase.rpc('get_dmc_public_stats')
  if (e || d?.error) { error.value = 'ยังไม่มีข้อมูลสถิตินักเรียนสาธารณะ'; loading.value = false; return }
  data.value    = d
  loading.value = false
})

const period     = computed(() => data.value?.period)
const vis        = computed(() => data.value?.visibility || {})
const allUploads = computed(() => data.value?.uploads || [])

const districts = computed(() => {
  const set = new Set()
  allUploads.value.forEach(u => { if (u.summary?.district) set.add(u.summary.district) })
  return [...set].sort()
})

const filterDistrict  = ref('all')
const filterSchool    = ref('all')
const searchQ         = ref('')

const schoolsInDistrict = computed(() => {
  if (filterDistrict.value === 'all') return allUploads.value
  return allUploads.value.filter(u => u.summary?.district === filterDistrict.value)
})

const filteredUploads = computed(() => {
  let list = allUploads.value
  if (filterDistrict.value !== 'all') list = list.filter(u => u.summary?.district === filterDistrict.value)
  if (filterSchool.value !== 'all')   list = list.filter(u => u.school_id === filterSchool.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(u => u.school_name?.toLowerCase().includes(q))
  }
  return list
})

const isFiltered = computed(() =>
  filterDistrict.value !== 'all' || filterSchool.value !== 'all' || searchQ.value.trim()
)

function resetFilter() { filterDistrict.value = 'all'; filterSchool.value = 'all'; searchQ.value = '' }
function onDistrictChange() { filterSchool.value = 'all' }

const totalStudents = computed(() => filteredUploads.value.reduce((s, u) => s + u.total, 0))
const genderMale    = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.gender?.male || 0), 0))
const genderFemale  = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.gender?.female || 0), 0))
const disadvCount   = computed(() => filteredUploads.value.reduce((s, u) => s + (u.summary?.disadvantaged?.count || 0), 0))
const disadvPct     = computed(() => totalStudents.value > 0 ? ((disadvCount.value / totalStudents.value) * 100).toFixed(1) : '0')

const bmiAgg = computed(() => {
  let u=0,n=0,o=0,ob=0
  filteredUploads.value.forEach(up => {
    const b=up.summary?.bmi||{}; u+=b.underweight||0; n+=b.normal||0; o+=b.overweight||0; ob+=b.obese||0
  })
  return { underweight:u, normal:n, overweight:o, obese:ob, total:u+n+o+ob }
})

const gradeAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    Object.entries(u.summary?.by_grade||{}).forEach(([g,d]) => {
      if (!map[g]) map[g] = { total:0, male:0, female:0 }
      map[g].total+=d.total||0; map[g].male+=d.male||0; map[g].female+=d.female||0
    })
  })
  return map
})

const guardianAgg = computed(() => {
  const map = {}
  filteredUploads.value.forEach(u => {
    Object.entries(u.summary?.guardian_relation||{}).forEach(([k,v]) => { map[k]=(map[k]||0)+v })
  })
  return Object.entries(map).sort((a,b)=>b[1]-a[1]).slice(0,8)
})

const gradeOpts = computed(() => ({
  chart: { type:'bar', height:240, toolbar:{show:false} },
  plotOptions: { bar: { borderRadius:4, columnWidth:'60%' } },
  colors: ['#3b82f6','#ec4899'],
  xaxis: { categories: Object.keys(gradeAgg.value), labels:{ style:{ fontFamily:'Sarabun', fontSize:'11px' } } },
  legend: { position:'top', fontFamily:'Sarabun' }, dataLabels:{enabled:false},
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const bmiOpts = computed(() => ({
  chart: { type:'donut', height:200 },
  labels: ['ต่ำกว่าเกณฑ์','ปกติ','น้ำหนักเกิน','อ้วน'],
  colors: ['#f97316','#10b981','#f59e0b','#ef4444'],
  legend: { position:'bottom', fontFamily:'Sarabun', fontSize:'11px' },
  plotOptions: { pie:{ donut:{ size:'65%' } } },
  dataLabels: { style:{ fontSize:'11px' } },
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const guardianOpts = computed(() => ({
  chart: { type:'bar', height:220, toolbar:{show:false} },
  plotOptions: { bar: { borderRadius:4, horizontal:true } },
  colors: ['#6366f1'],
  xaxis: { categories: guardianAgg.value.map(d=>d[0]), labels:{ style:{ fontFamily:'Sarabun', fontSize:'11px' } } },
  dataLabels: { enabled:true, style:{ fontSize:'11px' } }, legend:{ show:false },
  tooltip: { y:{ formatter: v => v.toLocaleString()+' คน' } },
}))

const schoolTableData = computed(() =>
  filteredUploads.value.map(u => ({
    id: u.school_id, name: u.school_name, total: u.total,
    male: u.summary?.gender?.male||0, female: u.summary?.gender?.female||0,
    disadv: u.summary?.disadvantaged?.count||0, disadvPct: u.summary?.disadvantaged?.pct||'0',
    bmiNormal: u.summary?.bmi?.normal||0,
  })).sort((a,b)=>b.total-a.total)
)

function formatDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'long', day:'numeric' })
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 min-h-screen">
    <div class="relative overflow-hidden"
      style="background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%)">
      <div class="absolute inset-0 opacity-10">
        <svg width="100%" height="100%"><defs><pattern id="dp-stats" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="12" cy="12" r="1" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#dp-stats)"/></svg>
      </div>
      <div class="relative max-w-5xl mx-auto px-4 py-10 md:py-14">
        <div class="flex flex-col md:flex-row items-start md:items-center gap-4">
          <div class="w-14 h-14 rounded-2xl bg-white/15 backdrop-blur ring-2 ring-white/20 flex items-center justify-center flex-shrink-0 shadow-lg">
            <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"/></svg>
          </div>
          <div class="flex-1">
            <h1 class="text-2xl md:text-3xl font-extrabold text-white mb-1">สารสนเทศนักเรียน</h1>
            <p class="text-white/60 text-sm">{{ config?.area_name }}</p>
            <p v-if="period" class="text-white/50 text-xs mt-0.5">{{ period.title }} · เผยแพร่ {{ formatDate(period.archived_at) }}</p>
          </div>
          <div v-if="data && !loading" class="flex gap-3 flex-wrap">
            <div class="bg-white/15 backdrop-blur rounded-2xl px-4 py-2.5 text-center">
              <p class="text-2xl font-extrabold text-white">{{ allUploads.length }}</p>
              <p class="text-white/60 text-xs">โรงเรียน</p>
            </div>
            <div class="bg-white/15 backdrop-blur rounded-2xl px-4 py-2.5 text-center">
              <p class="text-2xl font-extrabold text-white">{{ allUploads.reduce((s,u)=>s+u.total,0).toLocaleString() }}</p>
              <p class="text-white/60 text-xs">นักเรียนทั้งเขต</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-24"><div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/></div>
    <div v-else-if="error || !data" class="text-center py-24 text-slate-400">
      <p class="font-bold text-lg">{{ error || 'ยังไม่มีข้อมูลสถิติสาธารณะ' }}</p>
    </div>

    <div v-else class="max-w-5xl mx-auto px-4 py-6 space-y-5">
      <div class="text-xs text-slate-400 flex flex-wrap gap-3">
        <span>📅 ปีการศึกษา {{ period.academic_year }} ภาคเรียน {{ period.semester }}</span>
        <span>🏫 {{ data.total_schools }} โรงเรียน</span>
        <span>🕐 เผยแพร่ {{ formatDate(period.archived_at) }}</span>
      </div>

      <!-- Filter -->
      <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-4">
        <div class="flex flex-wrap items-center gap-3">
          <div class="relative flex-1 min-w-[200px]">
            <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/></svg>
            <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อโรงเรียน..."
              class="w-full pl-9 pr-4 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-700 focus:outline-none focus:border-primary"/>
          </div>
          <select v-model="filterDistrict" @change="onDistrictChange"
            class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-700 focus:outline-none focus:border-primary">
            <option value="all">ทุกอำเภอ</option>
            <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
          </select>
          <select v-model="filterSchool"
            class="px-3 py-2.5 border border-slate-200 dark:border-slate-600 rounded-xl text-sm bg-white dark:bg-slate-700 focus:outline-none focus:border-primary min-w-[180px]">
            <option value="all">ทุกโรงเรียน</option>
            <option v-for="u in schoolsInDistrict" :key="u.school_id" :value="u.school_id">{{ u.school_name }}</option>
          </select>
          <button v-if="isFiltered" @click="resetFilter" class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-red-500 transition-colors px-2 py-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            ล้าง
          </button>
        </div>
        <div v-if="isFiltered" class="mt-2 flex items-center gap-2">
          <div class="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"/>
          <p class="text-xs text-primary font-medium">กรองแล้ว: {{ filteredUploads.length }} โรงเรียน · {{ totalStudents.toLocaleString() }} นักเรียน</p>
        </div>
      </div>

      <!-- Stats cards -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div v-if="vis.total || vis.gender" class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-primary">{{ totalStudents.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">นักเรียนทั้งหมด</p>
        </div>
        <div v-if="vis.gender" class="bg-blue-50 dark:bg-blue-900/30 rounded-2xl border border-blue-100 dark:border-blue-800 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-blue-600">{{ genderMale.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">ชาย</p>
        </div>
        <div v-if="vis.gender" class="bg-pink-50 dark:bg-pink-900/30 rounded-2xl border border-pink-100 dark:border-pink-800 shadow-sm p-4 text-center">
          <p class="text-3xl font-extrabold text-pink-500">{{ genderFemale.toLocaleString() }}</p>
          <p class="text-xs text-slate-500 mt-1">หญิง</p>
        </div>
        <div v-if="vis.disadvantaged" :class="['rounded-2xl border shadow-sm p-4 text-center', Number(disadvPct)>50?'bg-red-50 dark:bg-red-900/20 border-red-200':'bg-amber-50 dark:bg-amber-900/20 border-amber-100']">
          <p :class="['text-3xl font-extrabold', Number(disadvPct)>50?'text-red-600':'text-amber-600']">{{ disadvPct }}%</p>
          <p class="text-xs text-slate-500 mt-1">เด็กยากจน {{ disadvCount.toLocaleString() }} คน</p>
        </div>
      </div>

      <!-- Grade chart -->
      <div v-if="vis.by_grade && Object.keys(gradeAgg).length > 0" class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-5">
        <h3 class="font-bold text-slate-700 dark:text-slate-200 mb-4">จำนวนนักเรียนแยกตามระดับชั้น</h3>
        <apexchart type="bar" :height="240" :options="gradeOpts"
          :series="[{ name:'ชาย', data:Object.values(gradeAgg).map(g=>g.male) },{ name:'หญิง', data:Object.values(gradeAgg).map(g=>g.female) }]"
          :key="`grade-${filteredUploads.length}`"/>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <div v-if="vis.bmi && bmiAgg.total > 0" class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-5">
          <h3 class="font-bold text-slate-700 dark:text-slate-200 mb-4">ภาวะโภชนาการ (BMI)</h3>
          <apexchart type="donut" :height="200" :options="bmiOpts" :series="[bmiAgg.underweight,bmiAgg.normal,bmiAgg.overweight,bmiAgg.obese]" :key="`bmi-${filteredUploads.length}`"/>
          <div class="mt-3 space-y-1.5">
            <div v-for="(item,i) in [{ label:'ต่ำกว่าเกณฑ์',val:bmiAgg.underweight,color:'text-orange-500' },{ label:'ปกติ',val:bmiAgg.normal,color:'text-emerald-500' },{ label:'น้ำหนักเกิน',val:bmiAgg.overweight,color:'text-amber-500' },{ label:'อ้วน',val:bmiAgg.obese,color:'text-red-500' }]" :key="i" class="flex items-center gap-2 text-xs">
              <span class="flex-1 text-slate-600 dark:text-slate-400">{{ item.label }}</span>
              <span :class="['font-bold', item.color]">{{ item.val.toLocaleString() }}</span>
              <span class="text-slate-400 w-12 text-right">{{ bmiAgg.total>0?((item.val/bmiAgg.total)*100).toFixed(1):0 }}%</span>
            </div>
          </div>
        </div>
        <div v-if="vis.guardian_relation && guardianAgg.length > 0" class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm p-5">
          <h3 class="font-bold text-slate-700 dark:text-slate-200 mb-4">ผู้ปกครอง (ความสัมพันธ์)</h3>
          <apexchart type="bar" :height="220" :options="guardianOpts" :series="[{ name:'จำนวน', data:guardianAgg.map(d=>d[1]) }]" :key="`guardian-${filteredUploads.length}`"/>
        </div>
      </div>

      <!-- School table -->
      <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50 dark:border-slate-700">
          <h3 class="font-bold text-slate-700 dark:text-slate-200">ข้อมูลรายโรงเรียน ({{ filteredUploads.length }} โรง)</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead><tr class="bg-slate-50 dark:bg-slate-900 text-slate-500 text-left">
              <th class="px-4 py-3 font-bold">#</th>
              <th class="px-4 py-3 font-bold">โรงเรียน</th>
              <th v-if="vis.total" class="px-4 py-3 font-bold text-right">รวม</th>
              <th v-if="vis.gender" class="px-4 py-3 font-bold text-right">ชาย</th>
              <th v-if="vis.gender" class="px-4 py-3 font-bold text-right">หญิง</th>
              <th v-if="vis.disadvantaged" class="px-4 py-3 font-bold text-right">ยากจน%</th>
              <th v-if="vis.bmi" class="px-4 py-3 font-bold text-right">BMI ปกติ%</th>
            </tr></thead>
            <tbody class="divide-y divide-slate-50 dark:divide-slate-700">
              <tr v-for="(s,i) in schoolTableData" :key="s.id" class="hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors cursor-pointer" @click="filterSchool=s.id;filterDistrict='all'">
                <td class="px-4 py-3 text-slate-400">{{ i+1 }}</td>
                <td class="px-4 py-3 font-medium text-slate-700 dark:text-slate-200">
                  <div class="flex items-center gap-2">{{ s.name }}<svg v-if="filterSchool===s.id" class="w-3.5 h-3.5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg></div>
                </td>
                <td v-if="vis.total" class="px-4 py-3 text-right font-bold text-slate-700 dark:text-slate-200">{{ s.total.toLocaleString() }}</td>
                <td v-if="vis.gender" class="px-4 py-3 text-right text-blue-600">{{ s.male.toLocaleString() }}</td>
                <td v-if="vis.gender" class="px-4 py-3 text-right text-pink-500">{{ s.female.toLocaleString() }}</td>
                <td v-if="vis.disadvantaged" class="px-4 py-3 text-right"><span :class="['font-bold',Number(s.disadvPct)>50?'text-red-500':'text-amber-600']">{{ s.disadvPct }}%</span></td>
                <td v-if="vis.bmi" class="px-4 py-3 text-right text-emerald-600 font-bold">{{ s.total>0?((s.bmiNormal/s.total)*100).toFixed(1):0 }}%</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <p class="text-center text-xs text-slate-300 dark:text-slate-600 pb-6">ข้อมูลจากระบบ DMC · {{ config?.area_name }}<span v-if="isFiltered"> · <button @click="resetFilter" class="text-primary hover:underline">ล้างตัวกรอง</button></span></p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
