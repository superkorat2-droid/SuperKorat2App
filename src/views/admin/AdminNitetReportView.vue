<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { TYPE_LABEL, STATUS_LABEL, displayName, formatEventDateRange, formatResponsible } from '../../composables/useNithetEventMeta'

const { config: areaConfig, fetchConfig } = useAreaConfig()

function firstDayOfMonth() { const d = new Date(); d.setDate(1); return d.toISOString().slice(0,10) }
function today() { return new Date().toISOString().slice(0,10) }

const dateFrom    = ref(firstDayOfMonth())
const dateTo      = ref(today())
const schoolId    = ref('')
const typeFilter  = ref('all')

const events             = ref([])
const schools            = ref([])
const responsibleOptions = ref([])
const loading            = ref(true)
const reporterProfile    = ref(null)

const TYPES = ['school_visit', 'meeting', 'training', 'other']

function responsibleNamesFor(event) {
  return (event.responsible_ids || [])
    .map(id => responsibleOptions.value.find(p => p.id === id))
    .filter(Boolean)
    .map(displayName)
}
function groupLabel(key) {
  return areaConfig.value?.personnel_groups?.find(g => g.key === key)?.label || key
}
function responsibleText(event) {
  return formatResponsible(responsibleNamesFor(event), event.responsible_group ? groupLabel(event.responsible_group) : '') || '-'
}

async function load() {
  loading.value = true
  let query = supabase
    .from('nithet_events')
    .select('*, school:schools(id,name,district)')
    .lte('start_date', dateTo.value)
    .gte('end_date', dateFrom.value)
    .order('start_date', { ascending: true })
  if (typeFilter.value !== 'all') query = query.eq('type', typeFilter.value)
  if (schoolId.value) query = query.eq('school_id', schoolId.value)
  const { data, error } = await query
  if (!error) events.value = data || []
  loading.value = false
}

const groupedBySchool = computed(() => {
  const groups = new Map()
  for (const e of events.value) {
    const key = e.school_id || '__none__'
    if (!groups.has(key)) {
      groups.set(key, { key, name: e.school?.name || 'กิจกรรมอื่นๆ (ไม่ระบุโรงเรียน)', district: e.school?.district || '', events: [] })
    }
    groups.get(key).events.push(e)
  }
  const list = [...groups.values()]
  list.sort((a, b) => {
    if (a.key === '__none__') return 1
    if (b.key === '__none__') return -1
    return (a.district || '').localeCompare(b.district) || a.name.localeCompare(b.name)
  })
  return list
})

const districts = computed(() => [...new Set(schools.value.map(s => s.district))].filter(Boolean).sort())

function exportCSV() {
  const headers = ['โรงเรียน', 'วันที่', 'ประเภท', 'ชื่อกิจกรรม', 'ผู้รับผิดชอบ', 'สถานะ']
  const rows = []
  for (const group of groupedBySchool.value) {
    for (const e of group.events) {
      rows.push([group.name, formatEventDateRange(e), TYPE_LABEL[e.type], e.title, responsibleText(e), STATUS_LABEL[e.status]])
    }
  }
  const csv = [headers, ...rows]
    .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `nithet_report_${dateFrom.value}_${dateTo.value}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printReport() { window.print() }

const printedAt = computed(() => new Date().toLocaleDateString('th-TH', { year: 'numeric', month: 'long', day: 'numeric' }))

onMounted(async () => {
  await fetchConfig()
  const { data: sc } = await supabase.from('schools').select('id, name, district').order('district').order('name')
  schools.value = sc || []
  const { data: pp } = await supabase.from('profiles')
    .select('id, title, first_name, last_name, full_name, role, position_level')
    .in('role', ['supervisor','staff','super_admin','admin'])
    .order('first_name')
  responsibleOptions.value = pp || []

  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name, position_level').eq('id', user.id).single()
    reporterProfile.value = p
  }
  await load()
})
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="calendar" class="w-6 h-6 text-primary"/>
          รายงานผลการนิเทศ
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">สรุปกิจกรรมนิเทศติดตามแยกตามโรงเรียน สำหรับดูสรุปหรือพิมพ์เป็นเอกสาร</p>
      </div>
      <div class="flex gap-2">
        <button @click="exportCSV" type="button"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
          <SvgIcon name="download" class="w-4 h-4"/>
          Export CSV
        </button>
        <button @click="printReport" type="button"
          class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.32 0a1.125 1.125 0 01-1.12 1.227m-9.08-1.227a1.125 1.125 0 001.12 1.227m6.84-9.75H8.25a1.125 1.125 0 01-1.125-1.125v-2.25c0-.621.504-1.125 1.125-1.125h7.5c.621 0 1.125.504 1.125 1.125v2.25c0 .621-.504 1.125-1.125 1.125z"/>
          </svg>
          พิมพ์รายงาน / บันทึกเป็น PDF
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex flex-wrap items-end gap-3">
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1">ตั้งแต่วันที่</label>
        <input v-model="dateFrom" type="date" class="input-field"/>
      </div>
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1">ถึงวันที่</label>
        <input v-model="dateTo" type="date" class="input-field"/>
      </div>
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1">ประเภท</label>
        <select v-model="typeFilter" class="input-field">
          <option value="all">ทั้งหมด</option>
          <option v-for="t in TYPES" :key="t" :value="t">{{ TYPE_LABEL[t] }}</option>
        </select>
      </div>
      <div>
        <label class="block text-xs font-bold text-slate-600 mb-1">โรงเรียน</label>
        <select v-model="schoolId" class="input-field">
          <option value="">ทุกโรงเรียน</option>
          <optgroup v-for="dist in districts" :key="dist" :label="`อ.${dist}`">
            <option v-for="s in schools.filter(x => x.district === dist)" :key="s.id" :value="s.id">{{ s.name }}</option>
          </optgroup>
        </select>
      </div>
      <button @click="load" type="button"
        class="px-4 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 transition-all">
        ค้นหา
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <!-- Empty -->
    <div v-else-if="groupedBySchool.length === 0"
      class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
      <SvgIcon name="calendar" class="w-12 h-12 mx-auto mb-3 opacity-30"/>
      <p class="font-medium">ไม่พบข้อมูลในช่วงเวลาที่เลือก</p>
    </div>

    <!-- Grouped web view -->
    <div v-else class="space-y-4">
      <div v-for="group in groupedBySchool" :key="group.key"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div class="px-5 py-3 bg-slate-50 border-b border-slate-100 flex items-center justify-between">
          <h3 class="font-extrabold text-slate-800">
            {{ group.name }} <span v-if="group.district" class="text-slate-400 font-normal text-sm">(อ.{{ group.district }})</span>
          </h3>
          <span class="text-xs font-bold text-slate-400">{{ group.events.length }} รายการ</span>
        </div>
        <div class="divide-y divide-slate-50">
          <div v-for="e in group.events" :key="e.id" class="px-5 py-3 flex flex-wrap items-center justify-between gap-2">
            <div class="min-w-0">
              <p class="font-bold text-slate-700 text-sm truncate">{{ e.title }}</p>
              <p class="text-xs text-slate-400 mt-0.5">{{ formatEventDateRange(e) }} · {{ TYPE_LABEL[e.type] }} · {{ responsibleText(e) }}</p>
            </div>
            <span class="text-xs font-bold px-2.5 py-0.5 rounded-full flex-shrink-0"
              :class="e.status === 'done' ? 'bg-emerald-50 text-emerald-600' : e.status === 'cancelled' ? 'bg-red-50 text-red-500' : 'bg-blue-50 text-blue-600'">
              {{ STATUS_LABEL[e.status] }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- ══════════ Printable document (แสดงเฉพาะตอนพิมพ์) ══════════ -->
    <Teleport to="body">
      <div id="print-report-root" style="padding: 1.5cm; font-family: 'Sarabun', sans-serif; color: #0f172a;">
        <div style="text-align:center; margin-bottom: 1.2cm;">
          <img v-if="areaConfig?.logo_url" :src="areaConfig.logo_url" style="width:60px; height:60px; object-fit:contain; margin:0 auto 8px;"/>
          <p style="font-weight:800; font-size:16px;">{{ areaConfig?.area_name || 'สำนักงานเขตพื้นที่การศึกษา' }}</p>
          <p style="font-size:13px; color:#475569;">{{ areaConfig?.area_type }} {{ areaConfig?.province }} {{ areaConfig?.area_number }}</p>
          <p style="font-weight:800; font-size:15px; margin-top:10px;">รายงานผลการนิเทศติดตามการจัดการศึกษา</p>
          <p style="font-size:13px; color:#475569;">ระหว่างวันที่ {{ formatEventDateRange({start_date: dateFrom, end_date: dateTo}) }}</p>
        </div>

        <div v-for="(group, gi) in groupedBySchool" :key="group.key"
          :style="gi < groupedBySchool.length - 1 ? 'page-break-after: always;' : ''">
          <p style="font-weight:800; font-size:14px; margin-bottom:6px;">
            {{ gi + 1 }}. {{ group.name }} <span v-if="group.district" style="font-weight:400; color:#475569;">(อ.{{ group.district }})</span>
          </p>
          <table style="width:100%; border-collapse:collapse; font-size:12px; margin-bottom:14px;">
            <thead>
              <tr style="background:#f1f5f9;">
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">วันที่</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">ประเภท</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">เรื่อง</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">ผู้รับผิดชอบ</th>
                <th style="border:1px solid #cbd5e1; padding:5px 8px; text-align:left;">สถานะ</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="e in group.events" :key="e.id">
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ formatEventDateRange(e) }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ TYPE_LABEL[e.type] }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ e.title }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ responsibleText(e) }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 8px;">{{ STATUS_LABEL[e.status] }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div style="margin-top:1.5cm; display:flex; justify-content:space-around; text-align:center; font-size:13px;">
          <div>
            <p>ลงชื่อ ....................................................</p>
            <p style="margin-top:6px;">( {{ displayName(reporterProfile) }} )</p>
            <p>{{ reporterProfile?.position_level || 'ผู้รายงาน' }}</p>
          </div>
          <div>
            <p>ลงชื่อ ....................................................</p>
            <p style="margin-top:6px;">( .................................................... )</p>
            <p>ผู้บังคับบัญชา</p>
          </div>
        </div>
        <p style="text-align:right; font-size:11px; color:#94a3b8; margin-top:0.8cm;">พิมพ์เมื่อวันที่ {{ printedAt }}</p>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

.input-field {
  @apply px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none;
}
.input-field:focus {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-primary) 20%, transparent);
  outline: none;
}
</style>
