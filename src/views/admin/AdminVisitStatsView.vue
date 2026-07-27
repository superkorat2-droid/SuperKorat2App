<script setup>
/**
 * AdminVisitStatsView — สถิติการเข้าชมเว็บไซต์ + รายงาน A4
 *
 * ข้อมูลทั้งหมดมาจาก RPC get_visit_stats ตัวเดียว (SECURITY DEFINER ที่เช็ค role
 * ในตัวมันเอง) — ตาราง visit_* ถูก REVOKE จาก anon/authenticated หมดแล้ว
 * หน้านี้จึง select ตรงไม่ได้และไม่ควรพยายาม
 *
 * ตัวเลข "ผู้ชมไม่ซ้ำ" ในช่วงที่เลือก นับหัวจริงจาก visit_events (ไม่ใช่ผลรวม
 * รายวันซึ่งจะนับคนเดิมซ้ำทุกวัน) จึงแม่นเท่าที่ยังเก็บ raw ไว้ — ปัจจุบัน 90 วัน
 *
 * โครงพิมพ์ A4 ใช้ของเดิมใน style.css ทั้งหมด ดู AdminAwardsReportView
 */
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import BarChart from '../../components/awards/BarChart.vue'

const { config, fetchConfig } = useAreaConfig()

const stats   = ref(null)
const loading = ref(true)
const errMsg  = ref('')
const me      = ref(null)
const landscape = ref(false)

/** ช่วงเวลาสำเร็จรูป — งานราชการมักถามเป็น "เดือนนี้/ปีนี้" มากกว่าวันที่เป๊ะ ๆ */
const RANGES = [
  { key: '7',    label: '7 วัน' },
  { key: '30',   label: '30 วัน' },
  { key: '90',   label: '90 วัน' },
  { key: 'month',label: 'เดือนนี้' },
  { key: 'year', label: 'ปีนี้' },
  { key: 'custom', label: 'กำหนดเอง' },
]
const rangeKey = ref('30')
const fFrom = ref('')
const fTo   = ref('')

function isoDay(d) {
  const p = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

/** คำนวณช่วงจริงจากปุ่มที่เลือก — ทำเป็น computed เพื่อให้ watch จับได้ที่เดียว */
const range = computed(() => {
  const today = new Date()
  if (rangeKey.value === 'custom') {
    return { from: fFrom.value || isoDay(today), to: fTo.value || isoDay(today) }
  }
  if (rangeKey.value === 'month') {
    return { from: isoDay(new Date(today.getFullYear(), today.getMonth(), 1)), to: isoDay(today) }
  }
  if (rangeKey.value === 'year') {
    return { from: isoDay(new Date(today.getFullYear(), 0, 1)), to: isoDay(today) }
  }
  const back = new Date(today)
  back.setDate(back.getDate() - (Number(rangeKey.value) - 1))
  return { from: isoDay(back), to: isoDay(today) }
})

async function load() {
  loading.value = true
  errMsg.value = ''
  const { data, error } = await supabase.rpc('get_visit_stats', {
    p_from: range.value.from, p_to: range.value.to, p_limit: 20,
  })
  if (error) { errMsg.value = error.message; stats.value = null }
  else stats.value = data
  loading.value = false
}

onMounted(async () => {
  fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('title, first_name, last_name, full_name, position, position_level').eq('id', user.id).single()
    me.value = p
  }
  await load()
})

watch(range, load)

// สลับแนวกระดาษด้วยการฉีด @page — วิธีเดียวกับรายงานผลงานและรางวัล
let pageStyleEl = null
watch(landscape, v => {
  if (!pageStyleEl) { pageStyleEl = document.createElement('style'); document.head.appendChild(pageStyleEl) }
  pageStyleEl.textContent = v ? '@media print { @page { size: A4 landscape; margin: 0 } }' : ''
})
onUnmounted(() => { if (pageStyleEl) pageStyleEl.remove() })

const summary  = computed(() => stats.value?.summary || {})
const trend    = computed(() => stats.value?.trend || [])
const topPages = computed(() => stats.value?.top_pages || [])
const devices  = computed(() => stats.value?.devices || {})

const deviceItems = computed(() => [
  // คลาสสีต้องเป็นสตริงเต็ม ห้ามประกอบจากตัวแปร ไม่งั้น Tailwind JIT purge ทิ้ง
  { label: 'มือถือ',        value: devices.value.mobile  || 0, bar: 'bg-emerald-500' },
  { label: 'แท็บเล็ต',      value: devices.value.tablet  || 0, bar: 'bg-amber-500'   },
  { label: 'คอมพิวเตอร์',   value: devices.value.desktop || 0, bar: 'bg-sky-500'     },
])
const deviceTotal = computed(() => deviceItems.value.reduce((s, d) => s + d.value, 0))

const topPageItems = computed(() => topPages.value.slice(0, 10).map(p => ({
  label: p.title || p.path, value: p.views, bar: 'bg-primary',
})))

/** สูงสุดของกราฟแนวโน้ม — ใช้กำหนดความสูงแท่ง */
const trendMax = computed(() => Math.max(1, ...trend.value.map(t => t.views || 0)))
function trendHeight(v) { return Math.max(2, Math.round(((v || 0) / trendMax.value) * 100)) }

/** วันที่แบบไทยสั้น ๆ สำหรับแกนกราฟ (2026-07-27 → 27/7) */
function shortDay(iso) {
  const [, m, d] = String(iso).split('-')
  return `${Number(d)}/${Number(m)}`
}
function thaiDate(iso) {
  if (!iso) return '-'
  const [y, m, d] = String(iso).split('-').map(Number)
  const M = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.']
  return `${d} ${M[m - 1]} ${y + 543}`
}
function num(v) { return (Number(v) || 0).toLocaleString('th-TH') }
function pctOf(v, total) { return total ? Math.round((v / total) * 100) : 0 }

/** แสดงกี่วันบนกราฟ — เกิน 45 วันแท่งจะบางจนอ่านไม่ออก ให้ย่อเป็นราย 7 วันแทน */
const trendShown = computed(() => {
  if (trend.value.length <= 45) return trend.value
  const out = []
  for (let i = 0; i < trend.value.length; i += 7) {
    const chunk = trend.value.slice(i, i + 7)
    out.push({
      day: chunk[0].day,
      views:   chunk.reduce((s, c) => s + (c.views || 0), 0),
      uniques: chunk.reduce((s, c) => s + (c.uniques || 0), 0),
      weekly: true,
    })
  }
  return out
})

const printedAt = computed(() => {
  const d = new Date()
  return `${thaiDate(isoDay(d))} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')} น.`
})
const reporterName = computed(() => {
  const p = me.value
  if (!p) return ''
  return `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim() || p.full_name || ''
})
const rangeText = computed(() => `${thaiDate(range.value.from)} – ${thaiDate(range.value.to)}`)

function doPrint() { window.print() }
const btnCls = 'px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-all'
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-2xl font-extrabold text-slate-800">สถิติการเข้าชมเว็บไซต์</h1>
      <p class="text-sm text-slate-500">
        เก็บเองในระบบ ไม่ผ่านบริการภายนอก · ไม่เก็บ IP และไม่ใช้คุกกี้
      </p>
    </div>

    <!-- ── ตัวกรองช่วงเวลา ── -->
    <div class="glass-card p-4 flex flex-wrap items-center gap-3">
      <span class="text-[11px] font-bold text-slate-400 uppercase tracking-widest">ช่วงเวลา</span>
      <div class="flex flex-wrap gap-1.5">
        <button v-for="r in RANGES" :key="r.key" @click="rangeKey = r.key"
          :class="[btnCls, rangeKey === r.key
            ? 'border-primary bg-primary text-white'
            : 'border-slate-200 text-slate-500 hover:border-primary/50']">
          {{ r.label }}
        </button>
      </div>

      <div v-if="rangeKey === 'custom'" class="flex items-center gap-2">
        <input type="date" v-model="fFrom" class="px-3 py-1.5 rounded-xl border border-slate-200 text-sm"/>
        <span class="text-slate-400 text-sm">ถึง</span>
        <input type="date" v-model="fTo" class="px-3 py-1.5 rounded-xl border border-slate-200 text-sm"/>
      </div>

      <span class="text-xs text-slate-400 ml-auto">{{ rangeText }}</span>

      <div class="flex items-center gap-2">
        <label class="flex items-center gap-1.5 text-xs font-bold text-slate-500 cursor-pointer select-none">
          <input type="checkbox" v-model="landscape" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
          แนวนอน
        </label>
        <button @click="doPrint"
          class="px-4 py-1.5 rounded-xl text-xs font-bold bg-primary text-white hover:opacity-90 transition-opacity">
          พิมพ์ A4
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <div v-else-if="errMsg" class="glass-card p-8 text-center">
      <span class="block text-3xl mb-2">🔒</span>
      <span class="block text-sm font-bold text-slate-600">{{ errMsg }}</span>
    </div>

    <template v-else>
      <!-- ── การ์ดตัวเลข ── -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div v-for="c in [
          { label: 'เข้าชมในช่วงนี้', value: summary.views,       sub: 'ครั้ง',  cls: 'text-primary' },
          { label: 'ผู้ชมไม่ซ้ำ',      value: summary.uniques,     sub: 'คน',    cls: 'text-emerald-600' },
          { label: 'วันนี้',           value: summary.today_views, sub: `ผู้ชมไม่ซ้ำ ${num(summary.today_uniques)} คน`, cls: 'text-amber-600' },
          { label: 'รวมทั้งหมด',       value: summary.total_views, sub: `เก็บมาแล้ว ${num(summary.days_tracked)} วัน`,   cls: 'text-slate-700' },
        ]" :key="c.label" class="glass-card p-4">
          <span class="block text-[11px] font-bold text-slate-400 uppercase tracking-widest">{{ c.label }}</span>
          <span :class="['block text-3xl font-extrabold tabular-nums mt-1', c.cls]">{{ num(c.value) }}</span>
          <span class="block text-[11px] text-slate-400 mt-0.5">{{ c.sub }}</span>
        </div>
      </div>

      <!-- ── กราฟแนวโน้ม ── -->
      <div class="glass-card p-5">
        <div class="flex items-baseline gap-2 mb-4">
          <h2 class="font-bold text-slate-700">แนวโน้มการเข้าชม</h2>
          <span class="text-[11px] text-slate-400">
            {{ trendShown.length && trendShown[0].weekly ? 'ย่อเป็นราย 7 วัน' : 'รายวัน' }} · สูงสุด {{ num(trendMax) }} ครั้ง
          </span>
        </div>

        <div v-if="trend.length" class="flex items-end gap-[3px] h-40">
          <div v-for="t in trendShown" :key="t.day" class="flex-1 group relative flex flex-col justify-end h-full">
            <!-- ห้ามใช้ bg-primary/80 — `primary` ไม่ใช่สีใน theme ของ Tailwind แต่เป็น
                 คลาสเขียนมือใน style.css คลาสที่มี /<เลข> จึงไม่มีอยู่จริงและได้แท่งใส
                 ใช้ opacity- ซึ่งเป็นยูทิลิตี้มาตรฐานแทน -->
            <div class="w-full rounded-t bg-primary opacity-80 group-hover:opacity-100 transition-opacity"
              :style="{ height: trendHeight(t.views) + '%' }"/>
            <!-- ทูลทิปแบบ CSS ล้วน ไม่ต้องพึ่ง library -->
            <span class="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:block
                         whitespace-nowrap rounded-lg bg-slate-800 px-2 py-1 text-[10px] font-bold text-white shadow-lg z-10">
              {{ thaiDate(t.day) }} · {{ num(t.views) }} ครั้ง · {{ num(t.uniques) }} คน
            </span>
          </div>
        </div>
        <p v-else class="text-center text-xs text-slate-400 py-10">ยังไม่มีข้อมูลในช่วงนี้</p>

        <div v-if="trendShown.length" class="flex justify-between text-[10px] text-slate-400 mt-1.5">
          <span>{{ shortDay(trendShown[0].day) }}</span>
          <span>{{ shortDay(trendShown[trendShown.length - 1].day) }}</span>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- ── อุปกรณ์ ── -->
        <div class="glass-card p-5">
          <h2 class="font-bold text-slate-700 mb-4">อุปกรณ์ที่ใช้เข้าชม</h2>
          <BarChart :items="deviceItems" empty-text="ยังไม่มีข้อมูลในช่วงนี้"/>
          <div v-if="deviceTotal" class="flex flex-wrap gap-x-4 gap-y-1 mt-4 pt-3 border-t border-slate-100">
            <span v-for="d in deviceItems" :key="d.label" class="text-[11px] text-slate-500">
              {{ d.label }} <b class="text-slate-700">{{ pctOf(d.value, deviceTotal) }}%</b>
            </span>
          </div>
        </div>

        <!-- ── หน้ายอดนิยม (กราฟ) ── -->
        <div class="glass-card p-5">
          <h2 class="font-bold text-slate-700 mb-4">10 หน้าที่คนเปิดมากที่สุด</h2>
          <BarChart :items="topPageItems" empty-text="ยังไม่มีข้อมูลในช่วงนี้"/>
        </div>
      </div>

      <!-- ── ตารางหน้ายอดนิยมแบบเต็ม ── -->
      <div v-if="topPages.length" class="glass-card p-5">
        <h2 class="font-bold text-slate-700 mb-3">รายละเอียดรายหน้า</h2>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-[11px] font-bold text-slate-400 uppercase tracking-wider border-b border-slate-200">
                <th class="py-2 pr-3 w-10">#</th>
                <th class="py-2 pr-3">หน้า</th>
                <th class="py-2 pr-3 text-right w-24">เข้าชม</th>
                <th class="py-2 text-right w-24">ผู้ชมไม่ซ้ำ</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in topPages" :key="p.path" class="border-b border-slate-50 last:border-0">
                <td class="py-2 pr-3 text-slate-400 tabular-nums">{{ i + 1 }}</td>
                <td class="py-2 pr-3 min-w-0">
                  <a :href="'#' + p.path" target="_blank" rel="noopener"
                    class="font-bold text-slate-700 hover:text-primary transition-colors">
                    {{ p.title || p.path }}
                  </a>
                  <span class="block text-[11px] text-slate-400 truncate">{{ p.path }}</span>
                </td>
                <td class="py-2 pr-3 text-right font-bold tabular-nums text-slate-700">{{ num(p.views) }}</td>
                <td class="py-2 text-right tabular-nums text-slate-500">{{ num(p.uniques) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ── รายงาน A4 (ส่วนเดียวที่ถูกพิมพ์) ──
           ต้อง Teleport ไป body เพราะ @media print ใน style.css ใช้ selector
           `body > *:not(#print-report-root)` ถ้าปล่อยไว้ลึกใน #app ตัว #app จะถูกซ่อน
           พารายงานหายไปด้วย และ navbar จะติดไปในกระดาษแทน -->
      <Teleport to="body">
      <div id="print-report-root" style="padding: 1.5cm; font-family: 'Sarabun', sans-serif; color: #0f172a; background:#fff;">
        <div style="text-align:center; margin-bottom:18px;">
          <img v-if="config?.logo_url" :src="config.logo_url" style="width:60px; height:60px; object-fit:contain; margin:0 auto 8px;"/>
          <div style="font-size:20px; font-weight:800;">รายงานสถิติการเข้าชมเว็บไซต์</div>
          <div style="font-size:15px; font-weight:700;">{{ config?.area_name || '' }}</div>
          <div style="font-size:12px; color:#475569; margin-top:6px;">ระหว่างวันที่ {{ rangeText }}</div>
          <div style="font-size:12px; color:#475569;">พิมพ์เมื่อ {{ printedAt }}</div>
        </div>

        <table style="width:100%; border-collapse:collapse; font-size:13px; margin-bottom:16px;">
          <tbody>
            <tr>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; background:#f8fafc; width:40%;">จำนวนการเข้าชมในช่วงรายงาน</td>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; font-weight:700;">{{ num(summary.views) }} ครั้ง</td>
            </tr>
            <tr>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; background:#f8fafc;">ผู้เข้าชมไม่ซ้ำ</td>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; font-weight:700;">{{ num(summary.uniques) }} คน</td>
            </tr>
            <tr>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; background:#f8fafc;">จำนวนการเข้าชมสะสมทั้งหมด</td>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; font-weight:700;">
                {{ num(summary.total_views) }} ครั้ง
                <span v-if="summary.first_day" style="font-weight:400; color:#475569;">
                  (เริ่มเก็บ {{ thaiDate(summary.first_day) }})
                </span>
              </td>
            </tr>
            <tr>
              <td style="border:1px solid #cbd5e1; padding:8px 10px; background:#f8fafc;">อุปกรณ์ที่ใช้เข้าชม</td>
              <td style="border:1px solid #cbd5e1; padding:8px 10px;">
                มือถือ {{ num(devices.mobile) }} ({{ pctOf(devices.mobile, deviceTotal) }}%) ·
                แท็บเล็ต {{ num(devices.tablet) }} ({{ pctOf(devices.tablet, deviceTotal) }}%) ·
                คอมพิวเตอร์ {{ num(devices.desktop) }} ({{ pctOf(devices.desktop, deviceTotal) }}%)
              </td>
            </tr>
          </tbody>
        </table>

        <div style="font-size:14px; font-weight:800; margin-bottom:6px;">หน้าที่มีผู้เข้าชมมากที่สุด</div>
        <p v-if="!topPages.length" style="text-align:center; color:#64748b; padding:24px 0;">ไม่มีข้อมูลในช่วงที่เลือก</p>
        <table v-else style="width:100%; border-collapse:collapse; font-size:13px;">
          <thead>
            <tr style="background:#f1f5f9;">
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center; width:40px;">ที่</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left;">ชื่อหน้า</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left;">ที่อยู่</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center; width:80px;">เข้าชม</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center; width:90px;">ผู้ชมไม่ซ้ำ</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(p, i) in topPages" :key="p.path">
              <td style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ i + 1 }}</td>
              <td style="border:1px solid #cbd5e1; padding:6px 8px;">{{ p.title || '-' }}</td>
              <td style="border:1px solid #cbd5e1; padding:6px 8px;">{{ p.path }}</td>
              <td style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ num(p.views) }}</td>
              <td style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ num(p.uniques) }}</td>
            </tr>
          </tbody>
        </table>

        <div style="margin-top:14px; font-size:11px; color:#64748b;">
          หมายเหตุ: ระบบเก็บสถิติเองภายในเว็บไซต์ ไม่ได้ใช้บริการวิเคราะห์ภายนอก
          ไม่มีการเก็บหมายเลขไอพีและไม่ใช้คุกกี้ · ไม่นับการเข้าชมจากโปรแกรมอัตโนมัติ
          (bot) และไม่นับหน้าระบบหลังบ้าน · เปิดหน้าเดิมซ้ำภายใน 30 นาทีนับเป็นครั้งเดียว
        </div>

        <div style="margin-top:40px; display:flex; justify-content:space-around; text-align:center; font-size:13px;">
          <div>
            <p>ลงชื่อ ....................................................</p>
            <p style="margin-top:4px;">( {{ reporterName || '....................................................' }} )</p>
            <p>{{ me?.position_level || me?.position || 'ผู้รายงาน' }}</p>
          </div>
          <div>
            <p>ลงชื่อ ....................................................</p>
            <p style="margin-top:4px;">( .................................................... )</p>
            <p>ผู้อำนวยการสำนักงานเขตพื้นที่การศึกษา</p>
          </div>
        </div>
      </div>
      </Teleport>
    </template>
  </div>
</template>
