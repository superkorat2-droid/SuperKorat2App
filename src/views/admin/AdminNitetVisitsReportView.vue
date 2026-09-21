<script setup>
/**
 * AdminNitetVisitsReportView — พิมพ์บันทึกการนิเทศเป็น A4
 *
 * 2 โหมด
 *   • รายบันทึก  — 1 ครั้ง 1 แผ่น ใช้เป็นหลักฐานประกอบการเบิกจ่าย
 *   • หลายรายการ — ตารางสรุปตามช่วงเวลา/ผู้นิเทศ ใช้รายงานผู้บริหาร
 *
 * ท้ายเอกสาร "เว้นว่างไว้เฉย ๆ" ไม่พิมพ์ชื่อใครลงไป (ต่างจากรายงานอื่นในระบบ)
 * ตามที่ตกลงกันไว้ว่าเลี่ยง PDPA — ให้ผู้ลงนามเขียนชื่อ ตำแหน่ง และประทับตราเอง
 *
 * ภาพประกอบใช้ object-fit: contain ห้ามครอบ เพราะเอกสารราชการต้องเห็นภาพเต็มใบ
 * แนวตั้งจัด 3 ใบ/แถว แนวนอน 2 ใบ/แถว ดูจาก w/h ที่เก็บไว้ตอนอัป
 *
 * กติกาการพิมพ์เหมือนรายงานอื่น: ต้อง Teleport ไป body เพราะ style.css ใช้
 * selector `body > *:not(#print-report-root)` ถ้าฝังไว้ใน #app จะถูกซ่อนหายทั้งหน้า
 */
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import {
  VISIT_TYPES, typeLabel, visitTypeLabel, placeOf, isPortrait, fmtDateLong, linkKind, LINK_ICON,
} from '../../composables/useNithetVisits'

const route = useRoute()
const { config, fetchConfig } = useAreaConfig()

const rows     = ref([])
const schools  = ref({})
const people   = ref({})
const loading  = ref(true)

const mode      = ref('single')   // single | list
const singleId  = ref('')
const landscape = ref(false)
const printSignerNames = ref(true)   // พิมพ์ชื่อ-ตำแหน่งผู้ลงนามอัตโนมัติ (โหมดรายบันทึกเท่านั้น)

const fFrom     = ref('')
const fTo       = ref('')
const fSchool   = ref('all')
const fDistrict = ref('all')
const fCenter   = ref('all')
const fOwner    = ref('all')
const fType     = ref('all')
const includeDrafts = ref(false)   // ร่างไม่เข้ารายงานโดยปริยาย
const includeUnacknowledged = ref(false)   // ที่ยังไม่รับทราบไม่เข้ารายงานโดยปริยาย (Phase 3)

const personnelGroups = computed(() => config.value?.personnel_groups || [])
function groupLabel(key) { return personnelGroups.value.find(g => g.key === key)?.label || key || '' }

onMounted(async () => {
  await fetchConfig()

  const { data } = await supabase.from('nithet_visits')
    .select('*').order('visit_date', { ascending: false })
  rows.value = data || []

  const schoolIds = [...new Set(rows.value.map(r => r.school_id).filter(Boolean))]
  if (schoolIds.length) {
    const { data: ss } = await supabase.from('schools')
      .select('id, name, district, school_group').in('id', schoolIds)
    schools.value = Object.fromEntries((ss || []).map(s => [s.id, s]))
  }

  // ชื่อคนใช้ทั้งผู้บันทึก ผู้ร่วมนิเทศ และ ผอ.กลุ่มที่รับทราบ จึงต้องดึงทั้งสามชุด
  const ids = new Set()
  for (const r of rows.value) {
    if (r.created_by) ids.add(r.created_by)
    for (const id of r.co_supervisor_ids || []) ids.add(id)
    if (r.acknowledged_by) ids.add(r.acknowledged_by)
  }
  if (ids.size) {
    const { data: pp } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name, position').in('id', [...ids])
    people.value = Object.fromEntries((pp || []).map(p => [p.id, {
      name: (p.full_name || '').trim() ||
            [p.title, p.first_name, p.last_name].filter(Boolean).join(' ') || '—',
      position: p.position || '',
    }]))
  }

  // เปิดจากปุ่ม "พิมพ์" ในหน้ารายการ — เลือกบันทึกนั้นให้เลย
  if (route.query.id) {
    singleId.value = route.query.id
    mode.value = 'single'
  } else if (rows.value.length) {
    singleId.value = rows.value[0].id
  }

  loading.value = false
})

// กด "พิมพ์" ของบันทึกอีกใบขณะยังอยู่หน้านี้ = เปลี่ยนแค่ query
// เราเตอร์ใช้คอมโพเนนต์ตัวเดิม onMounted ไม่ทำงานซ้ำ ต้องตามดู query เอง
watch(() => route.query.id, id => {
  if (!id) return
  singleId.value = String(id)
  mode.value = 'single'
})

// @page ไม่รับ class ต้องฉีด <style> เอง แล้วเก็บกวาดตอนออกจากหน้า
//
// margin ต้องมาจาก @page ไม่ใช่ padding ของ #print-report-root — padding ของ container
// ใส่ครั้งเดียวตอนต้นเนื้อหาทั้งก้อน ไม่ได้ถูกใส่ซ้ำทุกครั้งที่ตัดหน้าพิมพ์ พอเนื้อหายาวจน
// ล้นไปหน้า 2 (เช่นบล็อกลายเซ็นท้ายเอกสาร) หน้าถัดไปเลยชิดขอบบนสุดแบบไม่มีระยะ (@page margin:0 เดิม)
// ย้าย margin มาไว้ที่ @page แทนจึงได้ระยะขอบเท่ากันทุกหน้า ไม่ว่าจะพิมพ์กี่หน้าก็ตาม
let pageStyleEl = null
watch(landscape, v => {
  if (!pageStyleEl) {
    pageStyleEl = document.createElement('style')
    document.head.appendChild(pageStyleEl)
  }
  pageStyleEl.textContent = `@media print { @page { size: A4${v ? ' landscape' : ''}; margin: 1.5cm; } }`
}, { immediate: true })
onUnmounted(() => { if (pageStyleEl) pageStyleEl.remove() })

function decorate(r) {
  const s = schools.value[r.school_id]
  return { ...r, school_name: s?.name, district: s?.district, school_group: s?.school_group }
}
const decorated = computed(() => rows.value.map(decorate))

const districts = computed(() => [...new Set(decorated.value.map(r => r.district).filter(Boolean))].sort())
const centers   = computed(() => [...new Set(decorated.value.map(r => r.school_group).filter(Boolean))].sort())
const schoolList = computed(() => {
  const seen = new Map()
  for (const r of decorated.value) if (r.school_id) seen.set(r.school_id, r.school_name || r.school_id)
  return [...seen].sort((a, b) => String(a[1]).localeCompare(String(b[1]), 'th'))
})
const owners = computed(() => {
  const seen = new Map()
  for (const r of decorated.value) if (r.created_by) seen.set(r.created_by, people.value[r.created_by]?.name || '—')
  return [...seen].sort((a, b) => String(a[1]).localeCompare(String(b[1]), 'th'))
})

const filtered = computed(() => decorated.value.filter(r =>
  (includeDrafts.value || r.status === 'final') &&
  (includeUnacknowledged.value || r.status === 'draft' || r.ack_status === 'acknowledged') &&
  (!fFrom.value || r.visit_date >= fFrom.value) &&
  (!fTo.value   || r.visit_date <= fTo.value) &&
  (fSchool.value   === 'all' || r.school_id === fSchool.value) &&
  (fDistrict.value === 'all' || r.district === fDistrict.value) &&
  (fCenter.value   === 'all' || r.school_group === fCenter.value) &&
  (fOwner.value    === 'all' || r.created_by === fOwner.value) &&
  (fType.value     === 'all' || r.visit_type === fType.value)
))

const single = computed(() => decorated.value.find(r => r.id === singleId.value) || null)

function ownerName(id) { return people.value[id]?.name || '' }
function coNames(r) { return (r.co_supervisor_ids || []).map(ownerName).filter(Boolean) }

// ผู้ลงนาม = เจ้าของบันทึก + ผู้ร่วมนิเทศ กันซ้ำ (co_supervisor_ids อาจมีตัวเองหลุดมาได้ในข้อมูลเก่า)
const signerIds = computed(() => {
  if (!single.value) return []
  return [...new Set([single.value.created_by, ...(single.value.co_supervisor_ids || [])].filter(Boolean))]
})
const showSignerNames = computed(() =>
  mode.value === 'single' && printSignerNames.value && signerIds.value.length > 0)

/**
 * จัดรูปเป็นแถว — แนวตั้ง 3 ใบ แนวนอน 2 ใบ และไม่ปนแนวกันในแถวเดียว
 * เพื่อให้ความสูงในแถวเท่ากัน ไม่เกิดช่องโหว่กลางหน้ากระดาษ
 */
function photoRows(photos) {
  const out = []
  let cur = null
  for (const p of photos || []) {
    const port = isPortrait(p)
    const cap = port ? 3 : 2
    if (!cur || cur.portrait !== port || cur.items.length >= cap) {
      cur = { portrait: port, items: [] }
      out.push(cur)
    }
    cur.items.push(p)
  }
  return out
}
function photoBoxStyle(row) {
  const cap = row.portrait ? 3 : 2
  // ลบ gap ออกจากความกว้างเอง เพราะ inline style ใช้ grid ไม่ได้ทุกเครื่องพิมพ์
  return `width:${(100 / cap).toFixed(2)}%; height:${row.portrait ? '7.2cm' : '6cm'};`
}

const scopeText = computed(() => {
  const bits = []
  if (fFrom.value || fTo.value) bits.push(`${fFrom.value ? fmtDateLong(fFrom.value) : 'เริ่มแรก'} – ${fTo.value ? fmtDateLong(fTo.value) : 'ปัจจุบัน'}`)
  if (fCenter.value !== 'all') bits.push(`ศูนย์เครือข่าย${fCenter.value}`)
  if (fDistrict.value !== 'all') bits.push(`อำเภอ${fDistrict.value}`)
  if (fSchool.value !== 'all') bits.push(schools.value[fSchool.value]?.name || '')
  if (fOwner.value !== 'all') bits.push(`ผู้นิเทศ: ${ownerName(fOwner.value)}`)
  if (fType.value !== 'all') bits.push(typeLabel(fType.value))
  if (includeDrafts.value) bits.push('รวมฉบับร่าง')
  if (includeUnacknowledged.value) bits.push('รวมที่ยังไม่รับทราบ')
  return bits.filter(Boolean).join(' · ') || 'ทั้งหมด'
})

const printedAt = new Date().toLocaleDateString('th-TH', { day: 'numeric', month: 'long', year: 'numeric' })
function doPrint() {
  // กัน Ctrl+P/เมนูเบราว์เซอร์เลี่ยงปุ่มที่ถูก disable ไว้
  if (!canPrintSingle.value) return
  window.print()
}

function resetFilter() {
  fFrom.value = fTo.value = ''
  fSchool.value = fDistrict.value = fCenter.value = fOwner.value = fType.value = 'all'
  includeDrafts.value = false
  includeUnacknowledged.value = false
}

// โหมดรายบันทึก: พิมพ์ได้ต่อเมื่อ ผอ.กลุ่มรับทราบแล้ว (ร่างไม่ต้องรับทราบ เพราะยังไม่เข้ารายงานอยู่แล้ว)
const canPrintSingle = computed(() =>
  mode.value !== 'single' || !single.value || single.value.status === 'draft' || single.value.ack_status === 'acknowledged')

const selCls = 'px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600'
const TD = 'border:1px solid #cbd5e1; padding:6px 8px; vertical-align:top;'
const TH = 'border:1px solid #cbd5e1; padding:6px 8px; background:#f1f5f9; text-align:left; white-space:nowrap;'
</script>

<template>
  <div class="font-sarabun space-y-5">
    <!-- ── แถบตั้งค่า (อยู่นอก #print-report-root จึงไม่ถูกพิมพ์) ── -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-2xl font-extrabold text-slate-800">🖨️ รายงานบันทึกการนิเทศ</h1>
      <div class="flex items-center gap-2">
        <label class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none">
          <input type="checkbox" v-model="landscape" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> แนวนอน
        </label>
        <label v-if="mode === 'single'" class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none">
          <input type="checkbox" v-model="printSignerNames" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> พิมพ์ชื่อผู้ลงนามอัตโนมัติ
        </label>
        <button @click="doPrint" :disabled="!canPrintSingle"
          :title="!canPrintSingle ? 'ต้องรอ ผอ.กลุ่มรับทราบก่อนถึงจะพิมพ์ได้' : ''"
          class="px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:translate-y-0">
          พิมพ์ / บันทึก PDF
        </button>
      </div>
    </div>

    <div class="glass-card p-4 space-y-3">
      <div class="flex flex-wrap gap-2">
        <button v-for="m in [['single','รายบันทึก (หลักฐานเบิก)'],['list','หลายรายการตามช่วงเวลา']]" :key="m[0]"
          @click="mode = m[0]"
          :class="['px-4 py-2 rounded-xl text-sm font-bold border-2 transition-colors',
                   mode === m[0] ? 'border-primary text-primary' : 'border-slate-200 text-slate-500']">
          {{ m[1] }}
        </button>
      </div>

      <!-- โหมดรายบันทึก -->
      <div v-if="mode === 'single'" class="flex flex-wrap items-center gap-2">
        <select v-model="singleId" :class="selCls + ' max-w-full'">
          <option v-for="r in decorated" :key="r.id" :value="r.id">
            {{ fmtDateLong(r.visit_date) }} · {{ placeOf(r) }} · {{ r.title || 'ไม่มีชื่อเรื่อง' }}{{ r.status === 'draft' ? ' (ร่าง)' : '' }}
          </option>
        </select>
        <span v-if="single?.status === 'draft'" class="text-xs font-bold text-amber-600">
          บันทึกนี้ยังเป็นร่าง ควรกดบันทึกสมบูรณ์ก่อนใช้เป็นหลักฐาน
        </span>
        <span v-else-if="!canPrintSingle" class="text-xs font-bold text-red-600">
          🔒 ยังไม่ได้รับการรับทราบจาก ผอ.กลุ่ม จึงพิมพ์ไม่ได้ —
          <RouterLink to="/dashboard/nithet-acknowledge" class="underline">ไปหน้ารับทราบ</RouterLink>
        </span>
      </div>

      <!-- โหมดหลายรายการ -->
      <template v-else>
        <div class="flex flex-wrap gap-2">
          <input type="date" v-model="fFrom" :class="selCls"/>
          <input type="date" v-model="fTo" :class="selCls"/>
          <select v-model="fCenter" :class="selCls">
            <option value="all">ทุกศูนย์เครือข่าย</option>
            <option v-for="c in centers" :key="c" :value="c">{{ c }}</option>
          </select>
          <select v-model="fDistrict" :class="selCls">
            <option value="all">ทุกอำเภอ</option>
            <option v-for="d in districts" :key="d" :value="d">{{ d }}</option>
          </select>
          <select v-model="fSchool" :class="selCls">
            <option value="all">ทุกโรงเรียน</option>
            <option v-for="[id, name] in schoolList" :key="id" :value="id">{{ name }}</option>
          </select>
          <select v-model="fOwner" :class="selCls">
            <option value="all">ผู้นิเทศทุกคน</option>
            <option v-for="[id, name] in owners" :key="id" :value="id">{{ name }}</option>
          </select>
          <select v-model="fType" :class="selCls">
            <option value="all">ทุกประเภท</option>
            <option v-for="t in VISIT_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
          <label class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none px-2">
            <input type="checkbox" v-model="includeDrafts" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> รวมฉบับร่าง
          </label>
          <label class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none px-2">
            <input type="checkbox" v-model="includeUnacknowledged" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> รวมที่ยังไม่รับทราบ
          </label>
          <button @click="resetFilter" class="px-3 py-2 rounded-xl text-sm text-slate-500 hover:bg-slate-100">ล้างตัวกรอง</button>
          <span class="text-sm text-slate-500 ml-auto self-center">พบ {{ filtered.length.toLocaleString() }} รายการ</span>
        </div>
      </template>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
    <p v-else-if="!decorated.length" class="text-center py-16 text-slate-400">ยังไม่มีบันทึกการนิเทศให้พิมพ์</p>

    <!-- ── ตัวรายงาน (ส่วนเดียวที่ถูกพิมพ์) ── -->
    <Teleport v-else to="body">
    <div id="print-report-root" style="font-family: 'Sarabun', sans-serif; color: #0f172a; background:#fff;">

      <div style="text-align:center; margin-bottom:16px;">
        <img v-if="config?.logo_url" :src="config.logo_url" style="width:60px; height:60px; object-fit:contain; margin:0 auto 8px;"/>
        <div style="font-size:20px; font-weight:800;">
          {{ mode === 'single' ? 'บันทึกผลการนิเทศ ติดตาม และประเมินผล' : 'รายงานผลการนิเทศ ติดตาม และประเมินผล' }}
        </div>
        <div style="font-size:15px; font-weight:700;">{{ config?.area_name || '' }}</div>
        <div style="font-size:13px; color:#475569;">{{ config?.area_type }} {{ config?.province }} {{ config?.area_number }}</div>
        <div v-if="mode === 'list'" style="font-size:12px; color:#475569; margin-top:6px;">
          ขอบเขตข้อมูล: {{ scopeText }} · รวม {{ filtered.length.toLocaleString() }} รายการ · พิมพ์เมื่อ {{ printedAt }}
        </div>
      </div>

      <!-- ══════════ โหมดรายบันทึก ══════════ -->
      <template v-if="mode === 'single'">
        <p v-if="!single" style="text-align:center; color:#64748b; padding:40px 0;">ยังไม่ได้เลือกบันทึก</p>
        <template v-else>
          <!-- เรื่อง/ประเด็น/เลขที่คำสั่ง — ยกขึ้นมาเด่นเป็นหัวเรื่องเอกสาร แทนที่จะฝังในตารางข้อมูลเหมือนเดิม -->
          <div style="margin-bottom:10px; padding-bottom:8px; border-bottom:2px solid #1e293b;">
            <div style="display:flex; align-items:baseline; justify-content:space-between; gap:12px; flex-wrap:wrap;">
              <div style="font-size:16px; font-weight:800;">{{ single.title || '(ยังไม่ได้ใส่เรื่อง)' }}</div>
              <div v-if="single.order_number" style="font-size:12px; color:#475569; white-space:nowrap;">
                ตามคำสั่งเลขที่ {{ single.order_number }}<template v-if="single.order_date"> ลงวันที่ {{ fmtDateLong(single.order_date) }}</template>
              </div>
            </div>
            <div v-if="(single.topics || []).length" style="font-size:12px; color:#475569; margin-top:2px;">
              {{ (single.topics || []).join(' · ') }}
            </div>
          </div>

          <table style="width:100%; border-collapse:collapse; font-size:13px;">
            <tbody>
              <tr>
                <th :style="TH" style="width:22%">โรงเรียน / สถานที่</th>
                <td :style="TD">
                  {{ placeOf(single) }}
                  <span v-if="single.district" style="color:#475569;"> · อำเภอ{{ single.district }}</span>
                  <span v-if="single.school_group" style="color:#475569;"> · {{ single.school_group }}</span>
                </td>
              </tr>
              <tr>
                <th :style="TH">วันที่นิเทศ</th>
                <td :style="TD">
                  {{ fmtDateLong(single.visit_date) }}
                  <span style="color:#475569;"> · {{ visitTypeLabel(single) }}</span>
                  <span v-if="single.academic_year" style="color:#475569;">
                    · ปีการศึกษา {{ single.academic_year }}{{ single.term ? ` ภาคเรียนที่ ${single.term}` : '' }}
                  </span>
                </td>
              </tr>
              <tr>
                <th :style="TH">ผู้นิเทศ</th>
                <td :style="TD">
                  {{ ownerName(single.created_by) || '—' }}
                  <span v-if="coNames(single).length"> · ผู้ร่วมนิเทศ: {{ coNames(single).join(', ') }}</span>
                  <span v-if="single.work_group" style="color:#475569;"> · {{ groupLabel(single.work_group) }}</span>
                </td>
              </tr>
              <tr v-if="single.receiver_name || single.receiver_position || single.receiver_count">
                <th :style="TH">ผู้รับการนิเทศ</th>
                <td :style="TD">
                  {{ single.receiver_name || '—' }}
                  <span v-if="single.receiver_position"> · {{ single.receiver_position }}</span>
                  <span v-if="single.receiver_count"> · รวม {{ single.receiver_count }} คน</span>
                </td>
              </tr>
            </tbody>
          </table>

          <div v-for="s in [
                ['สภาพที่พบ', single.summary],
                ['จุดเด่น', single.strengths],
                ['จุดที่ควรพัฒนา', single.issues],
                ['ข้อเสนอแนะ', single.suggestions],
              ]" :key="s[0]" style="margin-top:12px; page-break-inside:avoid;">
            <div style="font-weight:800; font-size:14px; margin-bottom:3px;">{{ s[0] }}</div>
            <div style="font-size:13px; line-height:1.65; white-space:pre-line; border:1px solid #e2e8f0; border-radius:4px; padding:8px 10px; min-height:1.4cm;">{{ s[1] || '—' }}</div>
          </div>

          <div v-if="single.followup_required" style="margin-top:12px; font-size:13px; page-break-inside:avoid;">
            <b>การติดตามผล:</b>&nbsp;
            <span v-if="single.followup_due">กำหนดติดตามภายใน {{ fmtDateLong(single.followup_due) }}</span>
            <span v-if="single.followup_note"> · {{ single.followup_note }}</span>
          </div>

          <div v-if="(single.links || []).length" style="margin-top:12px; font-size:12px; page-break-inside:avoid;">
            <b style="font-size:13px;">เอกสาร/สื่อที่เกี่ยวข้อง</b>
            <div v-for="(l, i) in single.links" :key="i" style="margin-top:3px; word-break:break-all;">
              {{ LINK_ICON[l.kind || linkKind(l.url)] }} {{ l.label || l.url }}
              <span v-if="l.label" style="color:#475569;"> — {{ l.url }}</span>
            </div>
          </div>

          <!-- ภาพประกอบ: ห้ามครอบ ต้องเห็นเต็มใบ -->
          <div v-if="(single.photos || []).length" style="margin-top:14px;">
            <div style="font-weight:800; font-size:14px; margin-bottom:6px;">ภาพประกอบการนิเทศ</div>
            <div v-for="(row, ri) in photoRows(single.photos)" :key="ri"
              style="display:flex; gap:6px; margin-bottom:6px; page-break-inside:avoid;">
              <div v-for="(p, pi) in row.items" :key="pi" :style="photoBoxStyle(row)">
                <img :src="p.url" :alt="p.caption || ''"
                  style="width:100%; height:100%; object-fit:contain; border:1px solid #e2e8f0; border-radius:4px; background:#fff;"/>
                <div v-if="p.caption" style="font-size:11px; color:#475569; text-align:center; margin-top:2px;">{{ p.caption }}</div>
              </div>
            </div>
          </div>

          <div style="font-size:11px; color:#64748b; margin-top:10px;">พิมพ์เมื่อ {{ printedAt }}</div>
        </template>
      </template>

      <!-- ══════════ โหมดหลายรายการ ══════════ -->
      <template v-else>
        <p v-if="!filtered.length" style="text-align:center; color:#64748b; padding:40px 0;">ไม่พบข้อมูลตามเงื่อนไขที่เลือก</p>
        <table v-else style="width:100%; border-collapse:collapse; font-size:12px;">
          <thead>
            <tr>
              <th :style="TH" style="width:34px; text-align:center;">ที่</th>
              <th :style="TH">วันที่</th>
              <th :style="TH" style="text-align:left;">โรงเรียน / สถานที่</th>
              <th :style="TH" style="text-align:left;">เรื่อง / ประเด็น</th>
              <th :style="TH">ประเภท</th>
              <th :style="TH" style="text-align:left;">ผู้นิเทศ</th>
              <th :style="TH" style="text-align:center;">ผู้รับ<br/>(คน)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(r, i) in filtered" :key="r.id">
              <td :style="TD" style="text-align:center;">{{ i + 1 }}</td>
              <td :style="TD" style="white-space:nowrap;">{{ fmtDateLong(r.visit_date) }}</td>
              <td :style="TD">
                {{ placeOf(r) }}
                <div v-if="r.district" style="color:#64748b; font-size:11px;">อำเภอ{{ r.district }}</div>
              </td>
              <td :style="TD">
                {{ r.title || '—' }}
                <div v-if="(r.topics || []).length" style="color:#64748b; font-size:11px;">{{ (r.topics || []).join(' · ') }}</div>
              </td>
              <td :style="TD" style="text-align:center; white-space:nowrap;">
                {{ visitTypeLabel(r) }}
                <div v-if="r.status === 'draft'" style="color:#b45309; font-size:11px;">(ร่าง)</div>
              </td>
              <td :style="TD">{{ ownerName(r.created_by) || '—' }}</td>
              <td :style="TD" style="text-align:center;">{{ r.receiver_count || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </template>

      <!-- ── ท้ายเอกสาร: เซ็นสดเสมอ (ไม่เก็บรูปลายเซ็นจริง ไม่มีประทับตรา) — แถวผู้นิเทศเรียบง่าย
           แค่เส้นว่าง+ชื่อในวงเล็บ ต่อด้วยผู้รับรองคนสุดท้ายคือ ผอ.กลุ่มที่กดรับทราบจริง
           (ชื่อ-ตำแหน่งเต็มพิมพ์ให้เสมอเพราะเป็นข้อเท็จจริงจากระบบ ไม่ใช่ตัวเลือกเหมือนแถวผู้นิเทศ) -->
      <div v-if="showSignerNames" style="margin-top:1.2cm; display:flex; flex-wrap:wrap; justify-content:center; gap:16px 24px; page-break-inside:avoid;">
        <div v-for="id in signerIds" :key="id" style="flex:0 0 4.6cm; text-align:center; font-size:13px;">
          <div>..............................................................</div>
          <div style="margin-top:8px; font-weight:700;">( {{ people[id]?.name || '—' }} )</div>
        </div>
      </div>
      <div v-else style="margin-top:1.2cm; display:flex; flex-wrap:wrap; justify-content:center; gap:16px 24px; page-break-inside:avoid;">
        <div style="flex:0 0 4.6cm; text-align:center; font-size:13px;">
          <div>..............................................................</div>
          <div style="margin-top:8px;">( .............................................................. )</div>
        </div>
        <div style="flex:0 0 4.6cm; text-align:center; font-size:13px;">
          <div>..............................................................</div>
          <div style="margin-top:8px;">( .............................................................. )</div>
        </div>
      </div>

      <div v-if="mode === 'single' && single?.acknowledged_by" style="margin-top:1cm; text-align:center; font-size:13px; page-break-inside:avoid;">
        <div style="width:6cm; margin:0 auto;">..............................................................</div>
        <div style="margin-top:8px; font-weight:700;">( {{ people[single.acknowledged_by]?.name || '—' }} )</div>
        <div style="margin-top:4px; color:#475569;">{{ people[single.acknowledged_by]?.position || '' }}</div>
      </div>

    </div>
    </Teleport>
  </div>
</template>
