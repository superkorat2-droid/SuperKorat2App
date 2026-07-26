<script setup>
/**
 * AdminAwardsDashboardView — แดชบอร์ดรางวัล + โหมดฉายขึ้นจอในห้องประชุม
 *
 * เรียลไทม์: ใช้ postgres_changes pattern เดียวกับ AdminSupervisionResultsView
 * และต้อง removeChannel ตอน unmount ไม่งั้น channel ค้างสะสมทุกครั้งที่เข้าหน้า
 */
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import BarChart from '../../components/awards/BarChart.vue'
import {
  OWNER_KINDS, AWARD_LEVELS, AWARD_RANKS,
  levelMeta, rankLabel, iconMeta, currentAcademicYear, fmtDate,
} from '../../composables/useAwards'

const rows      = ref([])
const loading   = ref(true)
const presenting = ref(false)
const justAdded = ref(null)     // toast เมื่อมีรางวัลใหม่เข้ามาระหว่างฉาย
const fYear     = ref('all')
const rootEl    = ref(null)
let channel = null
let toastTimer = null

async function load() {
  // ใช้ view สาธารณะ เพราะแดชบอร์ดสรุปเฉพาะรางวัลที่อนุมัติแล้ว
  // และ view นี้ join ศูนย์เครือข่าย/อำเภอมาให้ด้วย
  const { data } = await supabase.from('awards_public').select('*').order('created_at', { ascending: false })
  rows.value = data || []
  loading.value = false
}

onMounted(async () => {
  await load()
  channel = supabase
    .channel('awards_dashboard')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'awards' }, async payload => {
      await load()
      if (payload.eventType === 'INSERT') {
        justAdded.value = payload.new?.title || 'มีรายการใหม่'
        clearTimeout(toastTimer)
        toastTimer = setTimeout(() => { justAdded.value = null }, 6000)
      }
    })
    .subscribe()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
  clearTimeout(toastTimer)
})

const years = computed(() => [...new Set(rows.value.map(r => r.academic_year).filter(Boolean))].sort().reverse())
const items = computed(() => fYear.value === 'all' ? rows.value : rows.value.filter(r => r.academic_year === fYear.value))

const thisYear = currentAcademicYear()
const stats = computed(() => ({
  total:    items.value.length,
  thisYear: rows.value.filter(r => r.academic_year === thisYear).length,
  high:     items.value.filter(r => levelMeta(r.level).weight >= 4).length,   // ชาติขึ้นไป
  hours:    items.value.reduce((s, r) => s + Number(r.training_hours || 0), 0),
}))

function countBy(list, keyFn) {
  const m = new Map()
  for (const r of list) {
    const k = keyFn(r)
    if (k === null || k === undefined || k === '') continue
    m.set(k, (m.get(k) || 0) + 1)
  }
  return m
}

const byOwner = computed(() => {
  const m = countBy(items.value, r => r.owner_kind)
  return OWNER_KINDS.map(k => ({ label: k.label, value: m.get(k.value) || 0, bar: k.dot }))
    .filter(x => x.value > 0)
})

const byLevel = computed(() => {
  const m = countBy(items.value, r => r.level)
  return AWARD_LEVELS.map(l => ({ label: l.label, value: m.get(l.value) || 0, bar: l.bar }))
})

const byRank = computed(() => {
  const m = countBy(items.value, r => (r.award_rank === 'other' ? r.award_rank_other : r.award_rank))
  return [...m.entries()]
    .map(([k, v]) => ({ label: AWARD_RANKS.find(r => r.value === k)?.label || k, value: v, bar: 'bg-primary' }))
    .sort((a, b) => b.value - a.value).slice(0, 8)
})

const byGroup = computed(() => {
  const m = countBy(items.value, r => r.school_group)
  return [...m.entries()].map(([k, v]) => ({ label: `ศูนย์ ${k}`, value: v, bar: 'bg-sky-500' }))
    .sort((a, b) => b.value - a.value).slice(0, 8)
})

const byYear = computed(() => {
  const m = countBy(rows.value, r => r.academic_year)
  return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0]))
    .map(([k, v]) => ({ label: `ปี ${k}`, value: v, bar: 'bg-emerald-500' }))
})

const topOwners = computed(() => {
  const m = countBy(items.value, r => r.owner_label)
  return [...m.entries()].map(([k, v]) => ({ label: k, value: v }))
    .sort((a, b) => b.value - a.value).slice(0, 10)
})

const latest = computed(() => items.value.slice(0, 8))

async function togglePresent() {
  try {
    if (!document.fullscreenElement) {
      await rootEl.value?.requestFullscreen()
      presenting.value = true
    } else {
      await document.exitFullscreen()
      presenting.value = false
    }
  } catch {
    // บางเบราว์เซอร์/ค่าติดตั้งไม่อนุญาต — ยังใช้โหมดขยายตัวอักษรได้
    presenting.value = !presenting.value
  }
}
if (typeof document !== 'undefined') {
  document.addEventListener('fullscreenchange', () => { presenting.value = !!document.fullscreenElement })
}
</script>

<template>
  <div ref="rootEl" :class="['font-sarabun', presenting ? 'bg-slate-50 p-6 overflow-y-auto h-screen' : 'space-y-5']">

    <div :class="['flex flex-wrap items-center justify-between gap-3', presenting && 'mb-5']">
      <div>
        <h1 :class="['font-extrabold text-slate-800 flex items-center gap-2', presenting ? 'text-4xl' : 'text-2xl']">
          🏆 สถิติผลงานและรางวัล
        </h1>
        <span :class="['block text-slate-500 mt-0.5 flex items-center gap-2', presenting ? 'text-lg' : 'text-sm']">
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          ข้อมูลสด อัปเดตอัตโนมัติ
        </span>
      </div>
      <div class="flex items-center gap-2">
        <select v-model="fYear" :class="['rounded-xl border border-white/80 bg-white/70 backdrop-blur text-slate-600', presenting ? 'px-4 py-2.5 text-lg' : 'px-3 py-2 text-sm']">
          <option value="all">ทุกปีการศึกษา</option>
          <option v-for="y in years" :key="y" :value="y">ปีการศึกษา {{ y }}</option>
        </select>
        <button @click="togglePresent"
          :class="['font-bold rounded-2xl bg-primary text-white shadow-md hover:-translate-y-0.5 transition-all', presenting ? 'px-5 py-2.5 text-lg' : 'px-4 py-2 text-sm']">
          {{ presenting ? 'ออกจากโหมดฉาย' : 'ฉายขึ้นจอ' }}
        </button>
      </div>
    </div>

    <!-- toast รางวัลใหม่ -->
    <Transition enter-active-class="transition duration-300" enter-from-class="opacity-0 translate-y-2">
      <div v-if="justAdded"
        class="fixed bottom-6 right-6 z-50 glass-card px-5 py-3.5 shadow-xl border-l-4 border-emerald-500">
        <span class="block text-xs font-bold text-emerald-600">🎉 มีรางวัลใหม่เข้ามา</span>
        <span class="block font-bold text-slate-800 max-w-xs truncate">{{ justAdded }}</span>
      </div>
    </Transition>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <template v-else>
      <!-- ตัวเลขใหญ่ -->
      <div :class="['grid grid-cols-2 lg:grid-cols-4 gap-3', presenting && 'gap-5 mb-6']">
        <div v-for="s in [
          { label: 'รางวัลทั้งหมด', value: stats.total, cls: 'text-slate-800' },
          { label: `ปีการศึกษา ${thisYear}`, value: stats.thisYear, cls: 'text-emerald-600' },
          { label: 'ระดับชาติขึ้นไป', value: stats.high, cls: 'text-amber-600' },
          { label: 'ชั่วโมงอบรมรวม', value: stats.hours, cls: 'text-primary' },
        ]" :key="s.label" :class="['glass-card text-center', presenting ? 'p-8' : 'p-5']">
          <span :class="['block font-extrabold tabular-nums', s.cls, presenting ? 'text-6xl' : 'text-3xl']">
            {{ s.value.toLocaleString() }}
          </span>
          <span :class="['block text-slate-500 mt-1', presenting ? 'text-xl' : 'text-xs']">{{ s.label }}</span>
        </div>
      </div>

      <div :class="['grid gap-4', presenting ? 'grid-cols-2 gap-6' : 'grid-cols-1 lg:grid-cols-2']">
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">จำแนกตามผู้รับรางวัล</span>
          <BarChart :items="byOwner" :big="presenting"/>
        </div>
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">จำแนกตามระดับรางวัล</span>
          <BarChart :items="byLevel" :big="presenting"/>
        </div>
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">ชนิดรางวัลที่ได้มากที่สุด</span>
          <BarChart :items="byRank" :big="presenting"/>
        </div>
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">ศูนย์เครือข่ายที่ได้รางวัลมากที่สุด</span>
          <BarChart :items="byGroup" :big="presenting" empty-text="ยังไม่มีรางวัลที่ผูกกับโรงเรียน"/>
        </div>
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">แนวโน้มรายปีการศึกษา</span>
          <BarChart :items="byYear" :big="presenting"/>
        </div>
        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">อันดับผู้รับรางวัลสูงสุด</span>
          <ol v-if="topOwners.length" :class="presenting ? 'space-y-2.5' : 'space-y-1.5'">
            <li v-for="(o, i) in topOwners" :key="o.label" class="flex items-center gap-2">
              <span :class="['font-extrabold text-slate-300 tabular-nums w-6 text-right flex-shrink-0', presenting ? 'text-xl' : 'text-sm']">{{ i + 1 }}</span>
              <span :class="['font-bold text-slate-700 truncate flex-1', presenting ? 'text-lg' : 'text-sm']">{{ o.label }}</span>
              <span :class="['font-extrabold text-primary tabular-nums flex-shrink-0', presenting ? 'text-xl' : 'text-sm']">{{ o.value }}</span>
            </li>
          </ol>
          <span v-else class="block text-center text-xs text-slate-400 py-6">ยังไม่มีข้อมูล</span>
        </div>
      </div>

      <!-- รางวัลล่าสุด -->
      <div :class="['glass-card', presenting ? 'p-6 mt-6' : 'p-5']">
        <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">รางวัลล่าสุด</span>
        <div v-if="latest.length" :class="presenting ? 'space-y-3' : 'space-y-2'">
          <div v-for="a in latest" :key="a.id" class="flex items-center gap-3">
            <svg :class="['text-primary flex-shrink-0', presenting ? 'w-8 h-8' : 'w-5 h-5']" fill="none" stroke="currentColor" stroke-width="1.6" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" :d="iconMeta(a.icon).path"/>
            </svg>
            <div class="min-w-0 flex-1">
              <span :class="['block font-bold text-slate-800 truncate', presenting ? 'text-xl' : 'text-sm']">{{ a.title }}</span>
              <span :class="['block text-slate-500 truncate', presenting ? 'text-base' : 'text-xs']">
                {{ a.owner_label }} · {{ rankLabel(a) }} · {{ levelMeta(a.level).label }}
              </span>
            </div>
            <span :class="['text-slate-400 flex-shrink-0', presenting ? 'text-base' : 'text-xs']">{{ fmtDate(a.created_at) }}</span>
          </div>
        </div>
        <span v-else class="block text-center text-xs text-slate-400 py-6">ยังไม่มีข้อมูล</span>
      </div>
    </template>
  </div>
</template>
