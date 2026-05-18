<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

const schools  = ref([])
const stats    = ref([])
const loading  = ref(true)
const filterSchool = ref('')

async function fetchSchools() {
  const { data } = await supabase.from('schools').select('id, name, dmc_code').order('name')
  schools.value = data || []
}

async function fetchStats() {
  loading.value = true
  let q = supabase
    .from('enrollment_stats')
    .select('*, schools(name, dmc_code)')
    .order('academic_year', { ascending: true })
    .order('term', { ascending: true })
  if (filterSchool.value) q = q.eq('school_id', filterSchool.value)
  const { data } = await q
  stats.value = data || []
  loading.value = false
}

// กราฟ bar: จัดกลุ่มตาม academic_year + term
const periods = computed(() => {
  const map = {}
  for (const s of stats.value) {
    const key = `${s.academic_year}-${s.term}`
    if (!map[key]) map[key] = { key, year: s.academic_year, term: s.term, rows: [] }
    map[key].rows.push(s)
  }
  return Object.values(map).sort((a, b) => a.key.localeCompare(b.key))
})

const maxTotal = computed(() => {
  let max = 0
  for (const s of stats.value) if (s.total_students > max) max = s.total_students
  return max || 1
})

// สรุปรวมทุกโรง ต่อ period
const periodSummary = computed(() => {
  return periods.value.map(p => {
    const total  = p.rows.reduce((a, r) => a + r.total_students, 0)
    const male   = p.rows.reduce((a, r) => a + r.male_count, 0)
    const female = p.rows.reduce((a, r) => a + r.female_count, 0)
    const dis    = p.rows.reduce((a, r) => a + r.disadvantaged_count, 0)
    const schools_count = p.rows.length
    return { ...p, total, male, female, dis, schools_count }
  })
})

const maxPeriodTotal = computed(() => Math.max(...periodSummary.value.map(p => p.total), 1))

// trend line SVG (จากซ้ายไปขวา)
const trendPath = computed(() => {
  if (periodSummary.value.length < 2) return ''
  const pts = periodSummary.value.map((p, i) => {
    const x = (i / (periodSummary.value.length - 1)) * 580 + 10
    const y = 80 - (p.total / maxPeriodTotal.value) * 70
    return `${x},${y}`
  })
  return 'M ' + pts.join(' L ')
})

// รายโรง: จัดกลุ่มตาม school
const bySchool = computed(() => {
  const map = {}
  for (const s of stats.value) {
    if (!map[s.school_id]) map[s.school_id] = {
      id: s.school_id,
      name: s.schools?.name || '',
      dmc_code: s.schools?.dmc_code || '',
      records: [],
    }
    map[s.school_id].records.push(s)
  }
  return Object.values(map).sort((a, b) => b.records[b.records.length-1]?.total_students - a.records[a.records.length-1]?.total_students)
})

// สุขภาพเฉลี่ยรวม (ล่าสุดของแต่ละโรง)
const healthSummary = computed(() => {
  const rows = bySchool.value.map(s => s.records[s.records.length - 1]?.health_stats).filter(Boolean)
  if (!rows.length) return null
  const avg_weight = +(rows.reduce((a, r) => a + (r.avg_weight || 0), 0) / rows.length).toFixed(1)
  const avg_height = +(rows.reduce((a, r) => a + (r.avg_height || 0), 0) / rows.length).toFixed(1)
  const underweight = rows.reduce((a, r) => a + (r.underweight || 0), 0)
  const normal_     = rows.reduce((a, r) => a + (r.normal || 0), 0)
  const overweight  = rows.reduce((a, r) => a + (r.overweight || 0), 0)
  const obese       = rows.reduce((a, r) => a + (r.obese || 0), 0)
  return { avg_weight, avg_height, underweight, normal: normal_, overweight, obese }
})

function pct(val, total) { return total > 0 ? Math.round(val / total * 100) : 0 }

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

onMounted(async () => { await fetchSchools(); await fetchStats() })
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>
          </svg>
          สถิตินักเรียนย้อนหลัง
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">เปรียบเทียบจำนวนนักเรียนตามปีการศึกษา</p>
      </div>
      <select v-model="filterSchool" @change="fetchStats"
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="">ทุกโรงเรียน</option>
        <option v-for="s in schools" :key="s.id" :value="s.id">{{ s.name }}</option>
      </select>
    </div>

    <div v-if="loading" class="py-16 text-center text-slate-400">กำลังโหลด...</div>
    <div v-else-if="!stats.length" class="py-16 text-center text-slate-400">
      <p class="font-bold">ยังไม่มีข้อมูลสถิติ</p>
      <p class="text-sm mt-1">โรงเรียนต้องอัปโหลดสถิติในหน้า DMC ก่อน</p>
    </div>

    <template v-else>

      <!-- ── กราฟแนวโน้ม (SVG trend line + bars) ─────────────── -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
        <h2 class="font-extrabold text-slate-800 mb-1">แนวโน้มจำนวนนักเรียนรวม</h2>
        <p class="text-xs text-slate-400 mb-5">รวมทุกโรงเรียนที่อัปโหลดสถิติ</p>

        <!-- Bar + trend SVG -->
        <div class="relative">
          <!-- Bars -->
          <div class="flex items-end gap-3 h-32 mb-2">
            <div v-for="p in periodSummary" :key="p.key" class="flex-1 flex flex-col items-center gap-1">
              <!-- Stacked bar -->
              <div class="w-full rounded-t-lg overflow-hidden flex flex-col-reverse"
                :style="{ height: Math.round((p.total / maxPeriodTotal) * 112) + 'px' }">
                <div class="bg-blue-400 w-full transition-all"
                  :style="{ height: pct(p.male, p.total) + '%' }"></div>
                <div class="bg-pink-400 w-full transition-all"
                  :style="{ height: pct(p.female, p.total) + '%' }"></div>
              </div>
            </div>
          </div>

          <!-- Trend line SVG overlay -->
          <svg v-if="periodSummary.length >= 2"
            class="absolute top-0 left-0 w-full h-32 pointer-events-none" viewBox="0 0 600 90" preserveAspectRatio="none">
            <polyline :points="trendPath" fill="none" stroke="#f59e0b" stroke-width="2.5"
              stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="6 3"/>
            <circle v-for="(p, i) in periodSummary" :key="i"
              :cx="(i / (periodSummary.length - 1)) * 580 + 10"
              :cy="80 - (p.total / maxPeriodTotal) * 70"
              r="4" fill="#f59e0b" stroke="white" stroke-width="2"/>
          </svg>

          <!-- Labels -->
          <div class="flex gap-3">
            <div v-for="p in periodSummary" :key="p.key" class="flex-1 text-center">
              <p class="text-[10px] font-bold text-slate-600">{{ p.year }}/{{ p.term }}</p>
              <p class="text-xs font-extrabold text-primary">{{ p.total.toLocaleString() }}</p>
              <p class="text-[9px] text-slate-400">{{ p.schools_count }} โรง</p>
            </div>
          </div>
        </div>

        <!-- Legend -->
        <div class="flex gap-4 mt-3 text-xs text-slate-500">
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-blue-400 inline-block"></span>ชาย</span>
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-pink-400 inline-block"></span>หญิง</span>
          <span class="flex items-center gap-1">
            <svg class="w-4 h-3" viewBox="0 0 24 8"><polyline points="0,4 8,4 16,4 24,4" fill="none" stroke="#f59e0b" stroke-width="2.5" stroke-dasharray="4 2"/></svg>
            แนวโน้ม
          </span>
        </div>
      </div>

      <!-- ── สุขภาพรวม ───────────────────────────────────────── -->
      <div v-if="healthSummary" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
        <h2 class="font-extrabold text-slate-800 mb-4">สุขภาพนักเรียน (ค่าเฉลี่ยรวม)</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
          <div class="bg-slate-50 rounded-xl p-4 text-center">
            <p class="text-2xl font-extrabold text-slate-800">{{ healthSummary.avg_weight }}</p>
            <p class="text-xs text-slate-500">น้ำหนักเฉลี่ย (kg)</p>
          </div>
          <div class="bg-slate-50 rounded-xl p-4 text-center">
            <p class="text-2xl font-extrabold text-slate-800">{{ healthSummary.avg_height }}</p>
            <p class="text-xs text-slate-500">ส่วนสูงเฉลี่ย (cm)</p>
          </div>
          <div class="bg-amber-50 rounded-xl p-4 text-center">
            <p class="text-2xl font-extrabold text-amber-700">{{ (healthSummary.underweight + healthSummary.overweight + healthSummary.obese).toLocaleString() }}</p>
            <p class="text-xs text-slate-500">น้ำหนักผิดปกติ</p>
          </div>
          <div class="bg-emerald-50 rounded-xl p-4 text-center">
            <p class="text-2xl font-extrabold text-emerald-700">{{ healthSummary.normal.toLocaleString() }}</p>
            <p class="text-xs text-slate-500">น้ำหนักปกติ</p>
          </div>
        </div>
        <!-- BMI distribution bar -->
        <p class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-2">การกระจาย BMI</p>
        <div class="flex h-8 rounded-xl overflow-hidden text-[10px] font-bold text-white">
          <div v-for="(item, key) in {
            'ผอม': { val: healthSummary.underweight, color: 'bg-blue-400' },
            'ปกติ': { val: healthSummary.normal, color: 'bg-emerald-500' },
            'เกิน': { val: healthSummary.overweight, color: 'bg-amber-400' },
            'อ้วน': { val: healthSummary.obese, color: 'bg-red-400' },
          }" :key="key" :class="['flex items-center justify-center transition-all', item.color]"
            :style="{ width: pct(item.val, healthSummary.underweight + healthSummary.normal + healthSummary.overweight + healthSummary.obese) + '%' }">
            <span v-if="pct(item.val, healthSummary.underweight + healthSummary.normal + healthSummary.overweight + healthSummary.obese) > 8">
              {{ key }}
            </span>
          </div>
        </div>
        <div class="flex gap-3 mt-2 text-xs text-slate-500 flex-wrap">
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-blue-400 inline-block"></span>ผอม {{ healthSummary.underweight.toLocaleString() }}</span>
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block"></span>ปกติ {{ healthSummary.normal.toLocaleString() }}</span>
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-amber-400 inline-block"></span>เกิน {{ healthSummary.overweight.toLocaleString() }}</span>
          <span class="flex items-center gap-1"><span class="w-2.5 h-2.5 rounded-full bg-red-400 inline-block"></span>อ้วน {{ healthSummary.obese.toLocaleString() }}</span>
        </div>
      </div>

      <!-- ── รายโรงเรียน ────────────────────────────────────── -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50">
          <h2 class="font-extrabold text-slate-800">รายโรงเรียน</h2>
          <p class="text-xs text-slate-400 mt-0.5">เรียงตามจำนวนนักเรียนมากไปน้อย</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-100">
                <th class="px-4 py-3 text-left font-bold text-slate-500">โรงเรียน</th>
                <th v-for="p in periods" :key="p.key"
                  class="px-4 py-3 text-center font-bold text-slate-500 whitespace-nowrap">
                  ปี{{ p.year }}/{{ p.term }}
                </th>
                <th class="px-4 py-3 text-center font-bold text-slate-500">เทรนด์</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-50">
              <tr v-for="s in bySchool" :key="s.id" class="hover:bg-slate-50 transition-colors">
                <td class="px-4 py-3">
                  <p class="font-bold text-slate-800 text-xs">{{ s.name }}</p>
                  <p class="text-slate-400 font-mono text-[10px]">{{ s.dmc_code }}</p>
                </td>
                <td v-for="p in periods" :key="p.key" class="px-4 py-3 text-center">
                  <template v-if="s.records.find(r => r.academic_year === p.year && r.term === p.term)">
                    <span class="font-extrabold text-primary">
                      {{ s.records.find(r => r.academic_year === p.year && r.term === p.term).total_students.toLocaleString() }}
                    </span>
                  </template>
                  <span v-else class="text-slate-300">-</span>
                </td>
                <!-- Trend arrow -->
                <td class="px-4 py-3 text-center">
                  <template v-if="s.records.length >= 2">
                    <span v-if="s.records[s.records.length-1].total_students > s.records[s.records.length-2].total_students"
                      class="text-emerald-600 font-bold">↑</span>
                    <span v-else-if="s.records[s.records.length-1].total_students < s.records[s.records.length-2].total_students"
                      class="text-red-500 font-bold">↓</span>
                    <span v-else class="text-slate-400">→</span>
                  </template>
                  <span v-else class="text-slate-300">-</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
