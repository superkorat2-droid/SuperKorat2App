<script setup>
/**
 * AdminNitetDashboardView — แดชบอร์ดการนิเทศสำหรับ ผอ.เขต / ผอ.กลุ่ม
 *
 * ตอบ 3 คำถามที่ผู้บริหารถามบ่อยที่สุด
 *   1. ไปครบทุกโรงหรือยัง — ตารางความครอบคลุมรายอำเภอ/ศูนย์เครือข่าย
 *   2. เดือนนี้ไปมากน้อยกว่าปีก่อนไหม — แท่งคู่ 12 เดือน
 *   3. ใครไปเท่าไร — อันดับ ศน.
 *
 * สรุปฝั่ง client ทั้งหมด ไม่ต้องมี RPC เพราะปีละ ~300 แถวเป็นข้อมูลจิ๋ว
 *
 * ความครอบคลุม "นับร่างด้วย" ตั้งใจ — ไปมาจริงแล้วแต่ยังกรอกไม่ครบก็ถือว่าไปแล้ว
 * (ต่างจากรายงาน A4 ที่ไม่เอาร่าง เพราะใช้เป็นหลักฐานเบิกจ่าย)
 *
 * บันทึกที่ไม่ได้เลือกโรงเรียน (เป็นวิทยากร/ประชุมนอกสถานที่) ไม่เข้าสถิติรายโรง
 * แต่ยังนับในตัวเลขรวมและกราฟรายเดือน
 */
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import BarChart from '../../components/awards/BarChart.vue'
import MonthTrendChart from '../../components/nithet/MonthTrendChart.vue'
import { useAreaConfig } from '../../composables/useAreaConfig'
import {
  VISIT_TYPES, typeLabel, currentAcademicYear, fmtDate, placeOf,
} from '../../composables/useNithetVisits'

const { config, fetchConfig } = useAreaConfig()

const rows     = ref([])
const schools  = ref([])
const people   = ref({})
const loading  = ref(true)
const presenting = ref(false)
const rootEl   = ref(null)
let channel = null

const thisYear = currentAcademicYear()
const fYear  = ref(thisYear)
const fGroup = ref('all')      // กลุ่มงานผู้บันทึก
const fType  = ref('all')
const coverBy = ref('district')   // district | school_group
const openGroup = ref('')          // กลุ่มที่กางดูรายโรงอยู่

const personnelGroups = computed(() => config.value?.personnel_groups || [])
function groupLabel(key) { return personnelGroups.value.find(g => g.key === key)?.label || key || 'ไม่ระบุกลุ่มงาน' }

async function load() {
  const [{ data: vs }, { data: sc }] = await Promise.all([
    supabase.from('nithet_visits').select('*').order('visit_date', { ascending: false }),
    supabase.from('schools').select('id, name, district, school_group').order('name'),
  ])
  rows.value = vs || []
  schools.value = sc || []

  const ids = [...new Set(rows.value.map(r => r.created_by).filter(Boolean))]
  if (ids.length) {
    const { data: pp } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name').in('id', ids)
    people.value = Object.fromEntries((pp || []).map(p => [p.id,
      (p.full_name || '').trim() || [p.title, p.first_name, p.last_name].filter(Boolean).join(' ') || '—']))
  }
  loading.value = false
}

onMounted(async () => {
  await fetchConfig()
  await load()
  channel = supabase.channel('nithet_visits_dashboard')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'nithet_visits' }, load)
    .subscribe()
})
// ไม่ removeChannel = channel ค้างสะสมทุกครั้งที่เข้าหน้า
onUnmounted(() => { if (channel) supabase.removeChannel(channel) })

const years = computed(() => {
  const ys = new Set(rows.value.map(r => r.academic_year).filter(Boolean))
  ys.add(thisYear)
  return [...ys].sort((a, b) => b - a)
})

/** แถวในขอบเขตที่กรองอยู่ (ยังไม่กรองปี ใช้ตอนเทียบปีก่อน) */
function inScope(r) {
  return (fGroup.value === 'all' || r.work_group === fGroup.value) &&
         (fType.value  === 'all' || r.visit_type === fType.value)
}
const items = computed(() => rows.value.filter(r => inScope(r) && r.academic_year === fYear.value))

const schoolById = computed(() => Object.fromEntries(schools.value.map(s => [s.id, s])))

const stats = computed(() => {
  const withSchool = items.value.filter(r => r.school_id)
  return {
    total:     items.value.length,
    schools:   new Set(withSchool.map(r => r.school_id)).size,
    receivers: items.value.reduce((s, r) => s + Number(r.receiver_count || 0), 0),
    followup:  items.value.filter(r => r.followup_status === 'open').length,
  }
})

// ── ความครอบคลุม ───────────────────────────────────────────
const visitedIds = computed(() => new Set(items.value.filter(r => r.school_id).map(r => r.school_id)))

const coverage = computed(() => {
  const key = coverBy.value
  const m = new Map()
  for (const s of schools.value) {
    const g = s[key] || 'ไม่ระบุ'
    if (!m.has(g)) m.set(g, [])
    m.get(g).push(s)
  }
  return [...m.entries()].map(([name, list]) => {
    const done = list.filter(s => visitedIds.value.has(s.id))
    return {
      name,
      total: list.length,
      done: done.length,
      pct: Math.round(done.length / list.length * 100),
      schools: list.map(s => ({ ...s, visited: visitedIds.value.has(s.id) }))
        .sort((a, b) => Number(b.visited) - Number(a.visited) || String(a.name).localeCompare(String(b.name), 'th')),
    }
  }).sort((a, b) => b.pct - a.pct || String(a.name).localeCompare(String(b.name), 'th'))
})

const coverTotal = computed(() => ({
  done: visitedIds.value.size,
  total: schools.value.length,
  pct: schools.value.length ? Math.round(visitedIds.value.size / schools.value.length * 100) : 0,
}))

// ── แนวโน้มรายเดือน (เรียงตามปีการศึกษา พ.ค. → เม.ย.) ──────
const ACADEMIC_MONTHS = [5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3, 4]
function monthSeries(year) {
  const counts = new Array(12).fill(0)
  for (const r of rows.value) {
    if (!inScope(r) || r.academic_year !== year || !r.visit_date) continue
    const mo = Number(String(r.visit_date).slice(5, 7))
    const i = ACADEMIC_MONTHS.indexOf(mo)
    if (i >= 0) counts[i]++
  }
  return counts
}
const trendCurrent  = computed(() => monthSeries(fYear.value))
const trendPrevious = computed(() => monthSeries(fYear.value - 1))

// ── กราฟแท่งอื่น ๆ ─────────────────────────────────────────
function countBy(list, keyFn) {
  const m = new Map()
  for (const r of list) {
    const k = keyFn(r)
    if (k === null || k === undefined || k === '') continue
    m.set(k, (m.get(k) || 0) + 1)
  }
  return m
}

const byType = computed(() => {
  const m = countBy(items.value, r => r.visit_type)
  return VISIT_TYPES.map(t => ({ label: t.label, value: m.get(t.value) || 0, bar: 'bg-primary' }))
    .filter(x => x.value > 0)
})

const bySupervisor = computed(() => {
  const m = countBy(items.value, r => r.created_by)
  return [...m.entries()].map(([k, v]) => ({ label: people.value[k] || '—', value: v }))
    .sort((a, b) => b.value - a.value).slice(0, 10)
})

const byWorkGroup = computed(() => {
  const m = countBy(items.value, r => r.work_group)
  return [...m.entries()].map(([k, v]) => ({ label: groupLabel(k), value: v, bar: 'bg-sky-500' }))
    .sort((a, b) => b.value - a.value)
})

const topTopics = computed(() => {
  const m = new Map()
  for (const r of items.value) for (const t of r.topics || []) m.set(t, (m.get(t) || 0) + 1)
  return [...m.entries()].map(([k, v]) => ({ label: k, value: v, bar: 'bg-emerald-500' }))
    .sort((a, b) => b.value - a.value).slice(0, 8)
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
    // บางเบราว์เซอร์ไม่อนุญาต fullscreen — ยังใช้โหมดตัวอักษรใหญ่ได้
    presenting.value = !presenting.value
  }
}
if (typeof document !== 'undefined') {
  document.addEventListener('fullscreenchange', () => { presenting.value = !!document.fullscreenElement })
}

const selCls = computed(() => ['rounded-xl border border-white/80 bg-white/70 backdrop-blur text-slate-600',
  presenting.value ? 'px-4 py-2.5 text-lg' : 'px-3 py-2 text-sm'])
</script>

<template>
  <div ref="rootEl" :class="['font-sarabun', presenting ? 'bg-slate-50 p-6 overflow-y-auto h-screen' : 'space-y-5']">

    <div :class="['flex flex-wrap items-center justify-between gap-3', presenting && 'mb-5']">
      <div>
        <h1 :class="['font-extrabold text-slate-800 flex items-center gap-2', presenting ? 'text-4xl' : 'text-2xl']">
          📊 แดชบอร์ดการนิเทศ
        </h1>
        <span :class="['block text-slate-500 mt-0.5 flex items-center gap-2', presenting ? 'text-lg' : 'text-sm']">
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          ข้อมูลสด อัปเดตอัตโนมัติ
        </span>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="fYear" :class="selCls">
          <option v-for="y in years" :key="y" :value="y">ปีการศึกษา {{ y }}</option>
        </select>
        <select v-model="fGroup" :class="selCls">
          <option value="all">ทุกกลุ่มงาน</option>
          <option v-for="g in personnelGroups" :key="g.key" :value="g.key">{{ g.label }}</option>
        </select>
        <select v-model="fType" :class="selCls">
          <option value="all">ทุกประเภท</option>
          <option v-for="t in VISIT_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
        </select>
        <button @click="togglePresent"
          :class="['font-bold rounded-2xl bg-primary text-white shadow-md hover:-translate-y-0.5 transition-all', presenting ? 'px-5 py-2.5 text-lg' : 'px-4 py-2 text-sm']">
          {{ presenting ? 'ออกจากโหมดฉาย' : 'ฉายขึ้นจอ' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <template v-else>
      <!-- ตัวเลขใหญ่ -->
      <div :class="['grid grid-cols-2 lg:grid-cols-4 gap-3', presenting && 'gap-5 mb-6']">
        <div v-for="s in [
          { label: 'ครั้งที่ออกนิเทศ', value: stats.total, cls: 'text-slate-800' },
          { label: `ไปแล้ว ${coverTotal.done} จาก ${coverTotal.total} โรง`, value: coverTotal.pct, suffix: '%', cls: 'text-emerald-600' },
          { label: 'ผู้รับการนิเทศรวม (คน)', value: stats.receivers, cls: 'text-primary' },
          { label: 'ข้อเสนอแนะที่รอติดตาม', value: stats.followup, cls: 'text-amber-600' },
        ]" :key="s.label" :class="['glass-card text-center', presenting ? 'p-8' : 'p-5']">
          <span :class="['block font-extrabold tabular-nums', s.cls, presenting ? 'text-6xl' : 'text-3xl']">
            {{ s.value.toLocaleString() }}<span v-if="s.suffix" :class="presenting ? 'text-4xl' : 'text-xl'">{{ s.suffix }}</span>
          </span>
          <span :class="['block text-slate-500 mt-1', presenting ? 'text-xl' : 'text-xs']">{{ s.label }}</span>
        </div>
      </div>

      <!-- ความครอบคลุม -->
      <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
        <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
          <span :class="['font-bold text-slate-700', presenting ? 'text-2xl' : 'text-sm']">
            ความครอบคลุมการนิเทศ ปีการศึกษา {{ fYear }}
          </span>
          <div class="flex gap-1">
            <button v-for="c in [['district','รายอำเภอ'],['school_group','รายศูนย์เครือข่าย']]" :key="c[0]"
              @click="coverBy = c[0]; openGroup = ''"
              :class="['px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-colors',
                       coverBy === c[0] ? 'border-primary text-primary' : 'border-slate-200 text-slate-500']">
              {{ c[1] }}
            </button>
          </div>
        </div>

        <p :class="['text-slate-500 mb-3', presenting ? 'text-base' : 'text-xs']">
          นับรวมฉบับร่างด้วย เพราะไปมาจริงแล้วแม้ยังกรอกไม่ครบ · กดที่แถวเพื่อดูรายชื่อโรงเรียน
        </p>

        <div class="space-y-2">
          <div v-for="g in coverage" :key="g.name">
            <button type="button" @click="openGroup = openGroup === g.name ? '' : g.name"
              class="w-full text-left">
              <div class="flex items-baseline justify-between gap-2 mb-1">
                <span :class="['font-bold text-slate-600 truncate', presenting ? 'text-lg' : 'text-xs']">{{ g.name }}</span>
                <span :class="['font-extrabold tabular-nums flex-shrink-0', g.pct === 100 ? 'text-emerald-600' : 'text-slate-800', presenting ? 'text-xl' : 'text-sm']">
                  {{ g.done }}/{{ g.total }} ({{ g.pct }}%)
                </span>
              </div>
              <div :class="['w-full rounded-full bg-slate-900/[0.06] overflow-hidden', presenting ? 'h-4' : 'h-2.5']">
                <div :class="['h-full rounded-full transition-all duration-700', g.pct === 100 ? 'bg-emerald-500' : 'bg-primary']"
                  :style="{ width: g.pct + '%' }"/>
              </div>
            </button>
            <div v-if="openGroup === g.name" class="flex flex-wrap gap-1.5 mt-2 mb-3">
              <span v-for="s in g.schools" :key="s.id"
                :class="['px-2 py-1 rounded-lg text-[11px] font-bold',
                         s.visited ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-400']">
                {{ s.visited ? '✓' : '·' }} {{ s.name }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div :class="['grid gap-4', presenting ? 'grid-cols-2 gap-6' : 'grid-cols-1 lg:grid-cols-2']">
        <div :class="['glass-card lg:col-span-2', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">
            แนวโน้มรายเดือน เทียบปีการศึกษา {{ fYear - 1 }}
          </span>
          <MonthTrendChart :current="trendCurrent" :previous="trendPrevious"
            :current-label="`ปี ${fYear}`" :previous-label="`ปี ${fYear - 1}`" :big="presenting"/>
        </div>

        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">จำแนกตามประเภทการนิเทศ</span>
          <BarChart :items="byType" :big="presenting"/>
        </div>

        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">จำแนกตามกลุ่มงาน</span>
          <BarChart :items="byWorkGroup" :big="presenting" empty-text="ยังไม่มีบันทึกที่ระบุกลุ่มงาน"/>
        </div>

        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">ประเด็นที่นิเทศบ่อยที่สุด</span>
          <BarChart :items="topTopics" :big="presenting" empty-text="ยังไม่มีการระบุประเด็น"/>
        </div>

        <div :class="['glass-card', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">ศึกษานิเทศก์ที่ออกนิเทศมากที่สุด</span>
          <ol v-if="bySupervisor.length" :class="presenting ? 'space-y-2.5' : 'space-y-1.5'">
            <li v-for="(o, i) in bySupervisor" :key="o.label" class="flex items-center gap-2">
              <span :class="['font-extrabold text-slate-300 tabular-nums w-6 text-right flex-shrink-0', presenting ? 'text-xl' : 'text-sm']">{{ i + 1 }}</span>
              <span :class="['font-bold text-slate-700 truncate flex-1', presenting ? 'text-lg' : 'text-sm']">{{ o.label }}</span>
              <span :class="['font-extrabold text-primary tabular-nums flex-shrink-0', presenting ? 'text-xl' : 'text-sm']">{{ o.value }}</span>
            </li>
          </ol>
          <span v-else class="block text-center text-xs text-slate-400 py-6">ยังไม่มีข้อมูล</span>
        </div>

        <div :class="['glass-card lg:col-span-2', presenting ? 'p-6' : 'p-5']">
          <span :class="['block font-bold text-slate-700 mb-3', presenting ? 'text-2xl' : 'text-sm']">บันทึกล่าสุด</span>
          <ul v-if="latest.length" class="divide-y divide-slate-100">
            <li v-for="r in latest" :key="r.id" class="py-2 flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
              <span :class="['text-slate-400 tabular-nums flex-shrink-0', presenting ? 'text-base' : 'text-xs']">{{ fmtDate(r.visit_date) }}</span>
              <span :class="['font-bold text-slate-700', presenting ? 'text-lg' : 'text-sm']">{{ placeOf({ ...r, school_name: schoolById[r.school_id]?.name }) }}</span>
              <span :class="['text-slate-500 truncate', presenting ? 'text-base' : 'text-xs']">{{ r.title }}</span>
              <span :class="['ml-auto text-slate-400 flex-shrink-0', presenting ? 'text-base' : 'text-xs']">
                {{ typeLabel(r.visit_type) }} · {{ people[r.created_by] || '—' }}
              </span>
            </li>
          </ul>
          <span v-else class="block text-center text-xs text-slate-400 py-6">ยังไม่มีบันทึกในปีการศึกษานี้</span>
        </div>
      </div>
    </template>
  </div>
</template>
