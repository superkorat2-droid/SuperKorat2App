<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import MonthCalendar from '../components/calendar/MonthCalendar.vue'
import EventDetailModal from '../components/calendar/EventDetailModal.vue'
import { supabase } from '../supabase'
import { TYPE_LABEL, TYPE_COLOR, formatEventDateRange, formatResponsible } from '../composables/useNithetEventMeta'
import Swal from 'sweetalert2'
import { useHolidays, holidayMeta } from '../composables/useHolidays'

const { config, fetchConfig } = useAreaConfig()
onMounted(fetchConfig)
const header = usePageHeader('nithet', { icon: 'eye', title: 'กลุ่มนิเทศ ติดตามและประเมินผล', align: 'center' })

function groupLabel(key) { return config.value?.personnel_groups?.find(g => g.key === key)?.label || key }
function responsibleText(event) {
  return formatResponsible(event.responsible_names || [], event.responsible_group ? groupLabel(event.responsible_group) : '')
}

const { holidays, fetchHolidays } = useHolidays()
const events        = ref([])
const loadingEvents = ref(true)
const selectedEvent = ref(null)

// ── กิจกรรมที่กำลังจะถึง (เหมือน widget หน้าแรก) ───────────────────
const upcomingEvents = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return events.value
    .filter(e => e.end_date >= today)
    .sort((a, b) => a.start_date.localeCompare(b.start_date) || (a.start_time || '').localeCompare(b.start_time || ''))
})

// ── ปฏิทินทั้งหมด (ล่าสุด + ที่ผ่านมา สำหรับดูและตรวจสอบ) ───────────
const allViewMode    = ref('list')
const allTypeFilter  = ref('all')
const allCurrentYear  = ref(new Date().getFullYear())
const allCurrentMonth = ref(new Date().getMonth())

// ── ช่วงวันที่สำหรับกรอง/พิมพ์ ─────────────────────────────────────
// ค่าเริ่มต้น = เดือนปัจจุบัน (กรณีใช้บ่อยสุด: พิมพ์กำหนดการประจำเดือนให้ผู้บริหาร)
function ymd(d) { return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10) }
const _now = new Date()
const dateFrom = ref(ymd(new Date(_now.getFullYear(), _now.getMonth(), 1)))
const dateTo   = ref(ymd(new Date(_now.getFullYear(), _now.getMonth() + 1, 0)))
const useDateRange = ref(false)

function setRangeThisMonth() {
  const n = new Date()
  dateFrom.value = ymd(new Date(n.getFullYear(), n.getMonth(), 1))
  dateTo.value   = ymd(new Date(n.getFullYear(), n.getMonth() + 1, 0))
}
function setRangeNextMonth() {
  const n = new Date()
  dateFrom.value = ymd(new Date(n.getFullYear(), n.getMonth() + 1, 1))
  dateTo.value   = ymd(new Date(n.getFullYear(), n.getMonth() + 2, 0))
}
function setRangeThisTerm() {
  // ภาคเรียนไทยคร่าวๆ: พ.ค.–ต.ค. = ภาค 1, พ.ย.–เม.ย. = ภาค 2
  const n = new Date(), y = n.getFullYear(), m = n.getMonth()
  if (m >= 4 && m <= 9) { dateFrom.value = ymd(new Date(y, 4, 1));  dateTo.value = ymd(new Date(y, 10, 0)) }
  else                  { dateFrom.value = ymd(new Date(m <= 3 ? y - 1 : y, 10, 1)); dateTo.value = ymd(new Date(m <= 3 ? y : y + 1, 4, 0)) }
}

// กิจกรรมที่ "คาบเกี่ยว" ช่วงที่เลือก (ไม่ใช่ต้องอยู่ในช่วงทั้งก้อน)
function inRange(e) {
  return e.start_date <= dateTo.value && e.end_date >= dateFrom.value
}

const allFilteredEvents = computed(() =>
  (allTypeFilter.value === 'all' ? events.value : events.value.filter(e => e.type === allTypeFilter.value))
    .filter(e => !useDateRange.value || inRange(e))
)
const allSortedEvents = computed(() =>
  [...allFilteredEvents.value].sort((a, b) => b.start_date.localeCompare(a.start_date) || (b.start_time || '').localeCompare(a.start_time || ''))
)

function onSelectEvent(ev) { selectedEvent.value = ev }

// ── พิมพ์ตาราง A4 ─────────────────────────────────────────────────
// เอกสารสำหรับพิมพ์ teleport ไป #print-report-root ซึ่ง @media print ใน style.css
// จะซ่อนทุกอย่างอื่นในหน้าให้อัตโนมัติ (pattern เดียวกับ AdminNitetReportView)
// เรียงเก่า→ใหม่ ต่างจากรายการบนจอที่เรียงใหม่→เก่า เพราะเอกสารนำเสนออ่านตามลำดับเวลา
const printEvents = computed(() =>
  [...allFilteredEvents.value].sort((a, b) =>
    a.start_date.localeCompare(b.start_date) || (a.start_time || '').localeCompare(b.start_time || ''))
)
const printedAt = new Date().toLocaleDateString('th-TH', { day: 'numeric', month: 'long', year: 'numeric' })

// วันหยุดในช่วงเดียวกัน — ผู้บริหารต้องเห็นว่าช่วงไหนหยุด จะได้ไม่สงสัยว่าทำไมเว้นว่าง
const printHolidays = computed(() =>
  holidays.value
    .filter(h => !useDateRange.value || (h.start_date <= dateTo.value && h.end_date >= dateFrom.value))
    .sort((a, b) => a.start_date.localeCompare(b.start_date))
)

function printSchedule() {
  if (!printEvents.value.length) {
    Swal.fire({ icon: 'info', title: 'ไม่มีรายการให้พิมพ์', text: 'ลองปรับช่วงวันที่หรือประเภทกิจกรรม' })
    return
  }
  window.print()
}

onMounted(async () => {
  const { data } = await supabase.rpc('get_nithet_events_public')
  events.value = data || []
  await fetchHolidays()
  loadingEvents.value = false
})
</script>

<template>
  <div class="font-sarabun min-h-[60vh]">
    <PageHero v-if="!header.hidden" :title="header.title"
      :subtitle="header.subtitle || config?.area_name || 'สำนักงานเขตพื้นที่การศึกษา'"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align"/>

    <!-- แยกจาก hero เสมอ ไม่ว่าจะใช้ไอคอนหรือรูป/วิดีโอ -->
    <div class="max-w-4xl mx-auto px-4 py-8 space-y-10">

      <!-- Loading -->
      <div v-if="loadingEvents" class="flex justify-center py-16">
        <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
      </div>

      <template v-else>
        <!-- ══ SECTION 1: กิจกรรมที่กำลังจะถึง ══════════════════════ -->
        <section class="space-y-4">
          <h2 class="text-xl font-extrabold text-slate-800">กิจกรรมที่กำลังจะถึง</h2>

          <div v-if="upcomingEvents.length === 0"
            class="text-center py-16 glass-tile text-slate-400">
            <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5m-9-6h.008v.008H12v-.008z"/>
            </svg>
            <p class="font-medium">ยังไม่มีกำหนดการในขณะนี้</p>
          </div>

          <div v-else class="space-y-3">
            <button v-for="event in upcomingEvents" :key="event.id" @click="selectedEvent = event" type="button"
              class="w-full text-left glass-tile p-4 hover:shadow-md transition-shadow">
              <div class="flex flex-wrap items-center gap-2 mb-1.5">
                <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
                  {{ TYPE_LABEL[event.type] }}
                </span>
                <span class="text-xs text-slate-400">{{ formatEventDateRange(event) }}</span>
              </div>
              <h3 class="font-bold text-slate-800">{{ event.title }}</h3>
              <div class="flex flex-wrap gap-3 mt-1 text-xs text-slate-400">
                <span v-if="event.schools?.length">โรงเรียน: {{ event.schools.map(s => s.name).join(', ') }}</span>
                <span v-if="event.location">สถานที่: {{ event.location }}</span>
                <span v-if="event.responsible_group || event.responsible_names?.length">ผู้รับผิดชอบ: {{ responsibleText(event) }}</span>
              </div>
            </button>
          </div>
        </section>

        <!-- ══ SECTION 2: ปฏิทินทั้งหมด (ล่าสุด + ที่ผ่านมา) ═══════════ -->
        <section class="space-y-4">
          <div>
            <h2 class="text-xl font-extrabold text-slate-800">ปฏิทินทั้งหมด</h2>
            <p class="text-sm text-slate-400 mt-0.5">ดูและตรวจสอบกำหนดการทั้งหมด รวมกิจกรรมที่ผ่านมาแล้ว</p>
          </div>

          <!-- แถบช่วงวันที่ + พิมพ์ -->
          <div class="glass-card p-4 space-y-3">
            <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
              <label class="flex items-center gap-2 text-sm font-bold text-slate-700 cursor-pointer select-none">
                <input type="checkbox" v-model="useDateRange" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
                เลือกช่วงวันที่
              </label>
              <template v-if="useDateRange">
                <div class="flex items-center gap-2">
                  <input type="date" v-model="dateFrom"
                    class="px-3 py-1.5 text-sm bg-white/70 backdrop-blur border border-white/80 rounded-xl text-slate-700"/>
                  <span class="text-slate-400 text-sm">ถึง</span>
                  <input type="date" v-model="dateTo"
                    class="px-3 py-1.5 text-sm bg-white/70 backdrop-blur border border-white/80 rounded-xl text-slate-700"/>
                </div>
                <div class="flex flex-wrap gap-1.5">
                  <button @click="setRangeThisMonth" class="px-2.5 py-1 rounded-lg text-xs font-bold border border-white/80 bg-white/70 text-slate-600 hover:border-primary/40 hover:text-primary transition-all">เดือนนี้</button>
                  <button @click="setRangeNextMonth" class="px-2.5 py-1 rounded-lg text-xs font-bold border border-white/80 bg-white/70 text-slate-600 hover:border-primary/40 hover:text-primary transition-all">เดือนหน้า</button>
                  <button @click="setRangeThisTerm"  class="px-2.5 py-1 rounded-lg text-xs font-bold border border-white/80 bg-white/70 text-slate-600 hover:border-primary/40 hover:text-primary transition-all">ภาคเรียนนี้</button>
                </div>
              </template>
              <button @click="printSchedule"
                class="ml-auto inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold bg-primary text-white hover:-translate-y-0.5 shadow-sm transition-all">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.8">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247M6.34 18H5.25A2.25 2.25 0 013 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 011.913-.247m10.5 0a48.536 48.536 0 00-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5z"/>
                </svg>
                พิมพ์ตาราง A4
              </button>
            </div>
            <p class="text-xs text-slate-500">
              พิมพ์รายการตามตัวกรองที่เลือกอยู่ ({{ printEvents.length }} รายการ) เป็นตาราง A4 สำหรับนำเสนอ
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <select v-model="allTypeFilter"
              class="px-3 py-2 text-sm bg-white/70 backdrop-blur border border-white/80 rounded-xl font-medium text-slate-600">
              <option value="all">ทุกประเภท</option>
              <option v-for="(label, key) in TYPE_LABEL" :key="key" :value="key">{{ label }}</option>
            </select>
            <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl ml-auto">
              <button @click="allViewMode = 'list'"
                :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
                  allViewMode === 'list' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
                รายการ
              </button>
              <button @click="allViewMode = 'month'"
                :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
                  allViewMode === 'month' ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
                ปฏิทิน
              </button>
            </div>
          </div>

          <!-- Month view -->
          <MonthCalendar v-if="allViewMode === 'month'" :events="allFilteredEvents" :holidays="holidays" v-model:year="allCurrentYear" v-model:month="allCurrentMonth"
            @select-event="onSelectEvent"/>

          <!-- Empty -->
          <div v-else-if="allSortedEvents.length === 0"
            class="text-center py-16 glass-tile text-slate-400">
            <p class="font-medium">ไม่พบกำหนดการ</p>
          </div>

          <!-- List view -->
          <div v-else class="space-y-3">
            <button v-for="event in allSortedEvents" :key="event.id" @click="selectedEvent = event" type="button"
              class="w-full text-left glass-tile p-4 hover:shadow-md transition-shadow">
              <div class="flex flex-wrap items-center gap-2 mb-1.5">
                <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', TYPE_COLOR[event.type]?.bg, TYPE_COLOR[event.type]?.text]">
                  {{ TYPE_LABEL[event.type] }}
                </span>
                <span class="text-xs text-slate-400">{{ formatEventDateRange(event) }}</span>
              </div>
              <h3 class="font-bold text-slate-800">{{ event.title }}</h3>
              <div class="flex flex-wrap gap-3 mt-1 text-xs text-slate-400">
                <span v-if="event.schools?.length">โรงเรียน: {{ event.schools.map(s => s.name).join(', ') }}</span>
                <span v-if="event.location">สถานที่: {{ event.location }}</span>
                <span v-if="event.responsible_group || event.responsible_names?.length">ผู้รับผิดชอบ: {{ responsibleText(event) }}</span>
              </div>
            </button>
          </div>
        </section>
      </template>
    </div>

    <!-- Detail Modal (read-only) — ใช้ component ร่วมกับหน้าแรก -->
    <EventDetailModal :event="selectedEvent" @close="selectedEvent = null"/>

    <!-- ══════════ เอกสารสำหรับพิมพ์ (แสดงเฉพาะตอนสั่งพิมพ์) ══════════
         teleport ไป #print-report-root — @media print ใน style.css ซ่อนทุกอย่างอื่น
         (pattern เดียวกับ AdminNitetReportView) -->
    <Teleport to="body">
      <div id="print-report-root" style="padding: 1.4cm; font-family: 'Sarabun', sans-serif; color: #0f172a;">
        <div style="text-align:center; margin-bottom: 0.9cm;">
          <img v-if="config?.logo_url" :src="config.logo_url" style="width:56px; height:56px; object-fit:contain; margin:0 auto 8px;"/>
          <p style="font-weight:800; font-size:16px;">{{ config?.area_name || 'สำนักงานเขตพื้นที่การศึกษา' }}</p>
          <p style="font-size:13px; color:#475569;">{{ config?.area_type }} {{ config?.province }} {{ config?.area_number }}</p>
          <p style="font-weight:800; font-size:15px; margin-top:10px;">ปฏิทินนิเทศ ติดตามและประเมินผลการจัดการศึกษา</p>
          <p style="font-size:13px; color:#475569;">
            <template v-if="useDateRange">ระหว่างวันที่ {{ formatEventDateRange({ start_date: dateFrom, end_date: dateTo }) }}</template>
            <template v-else>กำหนดการทั้งหมด</template>
            <template v-if="allTypeFilter !== 'all'"> · เฉพาะ{{ TYPE_LABEL[allTypeFilter] }}</template>
          </p>
        </div>

        <table style="width:100%; border-collapse:collapse; font-size:12px;">
          <thead>
            <tr style="background:#f1f5f9;">
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center; width:32px;">ที่</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left; width:120px;">วัน/เดือน/ปี</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left; width:74px;">ประเภท</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left;">เรื่อง / กิจกรรม</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left;">โรงเรียน / สถานที่</th>
              <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left; width:130px;">ผู้รับผิดชอบ</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(e, i) in printEvents" :key="e.id" style="page-break-inside: avoid;">
              <td style="border:1px solid #cbd5e1; padding:5px 8px; text-align:center;">{{ i + 1 }}</td>
              <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ formatEventDateRange(e) }}</td>
              <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ TYPE_LABEL[e.type] }}</td>
              <td style="border:1px solid #cbd5e1; padding:5px 8px;">
                {{ e.title }}
                <span v-if="e.description" style="display:block; color:#64748b; font-size:11px;">{{ e.description }}</span>
              </td>
              <td style="border:1px solid #cbd5e1; padding:5px 8px;">
                <template v-if="e.schools?.length">{{ e.schools.map(s => s.name).join(', ') }}</template>
                <template v-else>{{ e.location || '-' }}</template>
              </td>
              <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ responsibleText(e) || '-' }}</td>
            </tr>
          </tbody>
        </table>

        <p style="font-size:11px; color:#64748b; margin-top:10px;">รวม {{ printEvents.length }} รายการ · พิมพ์เมื่อ {{ printedAt }}</p>

        <!-- วันหยุดในช่วงเดียวกัน -->
        <template v-if="printHolidays.length">
          <p style="font-weight:800; font-size:13px; margin-top:16px; margin-bottom:6px;">วันหยุดในช่วงนี้</p>
          <table style="width:100%; border-collapse:collapse; font-size:12px;">
            <thead>
              <tr style="background:#fef2f2;">
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left; width:150px;">วัน/เดือน/ปี</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">วันหยุด</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left; width:130px;">ประเภท</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="h in printHolidays" :key="h.id">
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ formatEventDateRange(h) }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ h.title }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ holidayMeta(h.type).label }}</td>
              </tr>
            </tbody>
          </table>
        </template>

        <div style="margin-top:1.6cm; text-align:center; font-size:13px;">
          <p>ลงชื่อ ....................................................</p>
          <p style="margin-top:6px;">( .................................................... )</p>
          <p style="margin-top:2px;">ผู้อำนวยการกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
