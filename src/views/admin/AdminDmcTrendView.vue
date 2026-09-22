<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { LEVEL_LABEL } from '../../composables/useDmcParser'

const router = useRouter()

const periods = ref([])
const uploads = ref([])
const schools = ref([])
const loading = ref(true)

const filterCluster = ref('all')

async function load() {
  loading.value = true
  const [{ data: p }, { data: u }, { data: sc }] = await Promise.all([
    supabase.from('dmc_periods').select('*').order('academic_year').order('semester'),
    supabase.from('dmc_school_uploads').select('period_id, school_id, total, summary'),
    supabase.from('schools').select('id, school_group'),
  ])
  periods.value = p || []
  uploads.value = u || []
  schools.value = sc || []
  loading.value = false
}
onMounted(load)

const clusterOptions = computed(() => {
  const set = new Set(schools.value.map(s => s.school_group).filter(Boolean))
  return [...set].sort()
})

function schoolOf(schoolId) { return schools.value.find(s => s.id === schoolId) }

function periodLabel(p) { return `${p.title || `${p.academic_year}/${p.semester}`}` }

// ── รวมยอดต่อรอบ (period) — กรองตามศูนย์เครือข่ายถ้าเลือกไว้ ──────────────
const periodSummaries = computed(() => {
  return periods.value.map(p => {
    let rows = uploads.value.filter(u => u.period_id === p.id)
    if (filterCluster.value !== 'all') {
      rows = rows.filter(u => schoolOf(u.school_id)?.school_group === filterCluster.value)
    }
    const byLevel = {}
    rows.forEach(u => {
      const lv = u.summary?.level || 'unknown'
      byLevel[lv] = (byLevel[lv] || 0) + (u.total || 0)
    })
    return {
      id: p.id,
      label: periodLabel(p),
      schools: rows.length,
      total: rows.reduce((s, u) => s + (u.total || 0), 0),
      byLevel,
    }
  })
})

const hasEnoughData = computed(() => periodSummaries.value.filter(p => p.schools > 0).length >= 2)
const latestSummary  = computed(() => [...periodSummaries.value].reverse().find(p => p.schools > 0))

const LEVEL_KEYS  = ['kindergarten', 'primary', 'extended', 'secondary']
const LEVEL_COLORS = { kindergarten: '#f97316', primary: '#3b82f6', extended: '#8b5cf6', secondary: '#10b981' }

const trendChartOpts = computed(() => ({
  chart: { type: 'line', height: 320, toolbar: { show: false } },
  stroke: { curve: 'smooth', width: 3 },
  markers: { size: 5 },
  colors: LEVEL_KEYS.map(k => LEVEL_COLORS[k]),
  xaxis: { categories: periodSummaries.value.map(p => p.label), labels: { style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
  legend: { position: 'top', fontFamily: 'Sarabun', labels: { colors: '#64748b' } },
  dataLabels: { enabled: false },
  tooltip: { y: { formatter: v => (v || 0).toLocaleString() + ' คน' } },
}))

const trendChartSeries = computed(() =>
  LEVEL_KEYS.map(k => ({
    name: LEVEL_LABEL[k],
    data: periodSummaries.value.map(p => p.byLevel[k] || 0),
  }))
)

const totalTrendSeries = computed(() => [
  { name: 'นักเรียนรวม', data: periodSummaries.value.map(p => p.total) },
])
const totalTrendOpts = computed(() => ({
  chart: { type: 'bar', height: 280, toolbar: { show: false } },
  plotOptions: { bar: { borderRadius: 4, columnWidth: '50%' } },
  colors: ['#2563eb'],
  xaxis: { categories: periodSummaries.value.map(p => p.label), labels: { style: { fontFamily: 'Sarabun', fontSize: '11px' } } },
  dataLabels: { enabled: true, style: { fontSize: '11px' }, formatter: v => v.toLocaleString() },
  tooltip: { y: { formatter: v => (v || 0).toLocaleString() + ' คน' } },
}))
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <button @click="router.push('/dashboard/dmc')"
          class="flex items-center gap-1 text-sm text-slate-400 hover:text-slate-600 mb-1">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
          </svg>
          กลับรายการรอบ
        </button>
        <h1 class="text-2xl font-extrabold text-slate-800">แนวโน้มนักเรียนย้อนหลัง</h1>
        <p class="text-sm text-slate-500 mt-0.5">เปรียบเทียบจำนวนนักเรียนข้ามภาคเรียน/ปีการศึกษา</p>
      </div>
      <select v-model="filterCluster" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
        <option value="all">ทุกศูนย์เครือข่าย</option>
        <option v-for="c in clusterOptions" :key="c" :value="c">{{ c }}</option>
      </select>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else-if="periods.length === 0">
      <div class="text-center py-16 glass-card text-slate-400">
        <p class="font-medium">ยังไม่มีรอบการเก็บข้อมูล DMC</p>
      </div>
    </template>

    <!-- รอบเดียว — แสดงตัวเลขสรุป ไม่มีแนวโน้มให้ดู -->
    <template v-else-if="!hasEnoughData">
      <div class="glass-card p-6 text-center">
        <p class="text-slate-500 text-sm mb-2">มีข้อมูลเพียงรอบเดียว — ต้องมีอย่างน้อย 2 รอบขึ้นไปจึงจะเห็นแนวโน้ม</p>
        <p v-if="latestSummary" class="text-3xl font-extrabold text-primary">{{ latestSummary.total.toLocaleString() }}</p>
        <p v-if="latestSummary" class="text-xs text-slate-400 mt-1">{{ latestSummary.label }} · {{ latestSummary.schools }} โรงเรียน</p>
      </div>
    </template>

    <template v-else>
      <div class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-4">จำนวนนักเรียนรวมต่อรอบ</h3>
        <apexchart type="bar" :height="280" :options="totalTrendOpts" :series="totalTrendSeries"/>
      </div>

      <div class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-4">แยกตามระดับ</h3>
        <apexchart type="line" :height="320" :options="trendChartOpts" :series="trendChartSeries"/>
      </div>

      <!-- ตารางสรุปต่อรอบ -->
      <div class="glass-card overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-50">
          <h3 class="font-bold text-slate-700">สรุปต่อรอบ</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead><tr class="bg-slate-50 text-slate-500 text-left">
              <th class="px-4 py-3 font-bold">รอบ</th>
              <th class="px-4 py-3 font-bold text-right">โรงเรียน</th>
              <th class="px-4 py-3 font-bold text-right">นักเรียนรวม</th>
              <th v-for="k in LEVEL_KEYS" :key="k" class="px-4 py-3 font-bold text-right">{{ LEVEL_LABEL[k] }}</th>
            </tr></thead>
            <tbody class="divide-y divide-slate-50">
              <tr v-for="p in periodSummaries" :key="p.id" class="hover:bg-slate-50 transition-colors">
                <td class="px-4 py-3 font-medium text-slate-700">{{ p.label }}</td>
                <td class="px-4 py-3 text-right">{{ p.schools }}</td>
                <td class="px-4 py-3 text-right font-bold text-slate-800">{{ p.total.toLocaleString() }}</td>
                <td v-for="k in LEVEL_KEYS" :key="k" class="px-4 py-3 text-right text-slate-500">
                  {{ (p.byLevel[k] || 0).toLocaleString() }}
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
