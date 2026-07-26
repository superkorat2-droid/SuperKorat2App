<script setup>
/**
 * AdminAwardsReportView — รายงานผลงานและรางวัล พิมพ์เป็น A4
 *
 * ใช้โครงพิมพ์ที่มีอยู่แล้วใน style.css (@media print):
 *   @page { size: A4 } · ซ่อนทุกอย่างที่ไม่ใช่ #print-report-root ·
 *   thead ซ้ำทุกหน้า · tr ไม่ถูกตัดครึ่ง · การ์ดกระจกกลายเป็นกล่องขอบเรียบ
 * จึงไม่ต้องเขียน CSS พิมพ์ใหม่ นอกจากการสลับแนวกระดาษ
 *
 * "ศูนย์เครือข่าย" มาจาก schools.school_group ที่มีข้อมูลอยู่แล้ว (ไม่ต้องเพิ่มฟิลด์)
 * ดึงผ่าน view awards_public ที่ join มาให้
 *
 * ไม่ทำ PDF ฝั่ง server — ใช้ window.print() แล้วผู้ใช้เลือก "บันทึกเป็น PDF" เอง
 * ได้ผลเท่ากันแต่ไม่ต้องเพิ่ม dependency และฟอนต์ไทยไม่เพี้ยน
 */
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import {
  OWNER_KINDS, AWARD_LEVELS, REPORT_GROUP_BY,
  ownerKindMeta, levelMeta, rankLabel, fmtDate,
} from '../../composables/useAwards'

const { config, fetchConfig } = useAreaConfig()

const rows    = ref([])
const schools = ref([])
const loading = ref(true)
const me      = ref(null)

const fGroupCenter = ref('all')   // ศูนย์เครือข่าย
const fDistrict    = ref('all')
const fSchool      = ref('all')
const fKind        = ref('all')
const fLevel       = ref('all')
const fYear        = ref('all')
const fFrom        = ref('')
const fTo          = ref('')

const groupBy = ref('school_group')
const mode    = ref('summary')     // summary | detail
const landscape = ref(false)

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('title, first_name, last_name, full_name, position, position_level').eq('id', user.id).single()
    me.value = p
  }
  const [{ data: aw }, { data: sc }] = await Promise.all([
    supabase.from('awards_public').select('*').order('awarded_date', { ascending: false }),
    supabase.from('schools').select('id, name, school_group, district').order('name'),
  ])
  rows.value = aw || []
  schools.value = sc || []
  loading.value = false
})

// ── สลับแนวกระดาษ: @page ไม่รับ class จึงต้องฉีด <style> เข้าไปเอง ──
let pageStyleEl = null
watch(landscape, v => {
  if (!pageStyleEl) {
    pageStyleEl = document.createElement('style')
    document.head.appendChild(pageStyleEl)
  }
  pageStyleEl.textContent = v ? '@media print { @page { size: A4 landscape; margin: 0 } }' : ''
})
onUnmounted(() => { if (pageStyleEl) pageStyleEl.remove() })

const centers   = computed(() => [...new Set(schools.value.map(s => s.school_group).filter(Boolean))].sort())
const districts = computed(() => [...new Set(schools.value.map(s => s.district).filter(Boolean))].sort())
const years     = computed(() => [...new Set(rows.value.map(r => r.academic_year).filter(Boolean))].sort().reverse())
const schoolsInScope = computed(() => schools.value.filter(s =>
  (fGroupCenter.value === 'all' || s.school_group === fGroupCenter.value) &&
  (fDistrict.value === 'all' || s.district === fDistrict.value)))

const filtered = computed(() => rows.value.filter(r =>
  (fGroupCenter.value === 'all' || r.school_group === fGroupCenter.value) &&
  (fDistrict.value === 'all' || r.school_district === fDistrict.value) &&
  (fSchool.value === 'all' || r.school_id === fSchool.value) &&
  (fKind.value === 'all' || r.owner_kind === fKind.value) &&
  (fLevel.value === 'all' || r.level === fLevel.value) &&
  (fYear.value === 'all' || r.academic_year === fYear.value) &&
  (!fFrom.value || (r.awarded_date && r.awarded_date >= fFrom.value)) &&
  (!fTo.value   || (r.awarded_date && r.awarded_date <= fTo.value))
))

/** คีย์ของกลุ่มตามตัวเลือก "จัดกลุ่มตาม" */
function groupKey(r) {
  switch (groupBy.value) {
    case 'school_group':  return r.school_group  || 'ไม่ระบุศูนย์เครือข่าย'
    case 'district':      return r.school_district ? `อำเภอ${r.school_district}` : 'ไม่ระบุอำเภอ'
    case 'school':        return r.school_name   || r.owner_label || 'ไม่ระบุโรงเรียน'
    case 'owner_kind':    return ownerKindMeta(r.owner_kind).label
    case 'level':         return levelMeta(r.level).label
    case 'academic_year': return r.academic_year ? `ปีการศึกษา ${r.academic_year}` : 'ไม่ระบุปีการศึกษา'
    default:              return '-'
  }
}

const grouped = computed(() => {
  const m = new Map()
  for (const r of filtered.value) {
    const k = groupKey(r)
    if (!m.has(k)) m.set(k, [])
    m.get(k).push(r)
  }
  return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0], 'th'))
})

/** แถวสรุป: นับแยกตามระดับรางวัล + รวม */
const summary = computed(() => grouped.value.map(([name, list]) => ({
  name,
  counts: AWARD_LEVELS.map(l => list.filter(x => x.level === l.value).length),
  total: list.length,
})))
const summaryTotal = computed(() => ({
  counts: AWARD_LEVELS.map((l, i) => summary.value.reduce((s, r) => s + r.counts[i], 0)),
  total: filtered.value.length,
}))

const trainingHours = computed(() => filtered.value.reduce((s, r) => s + Number(r.training_hours || 0), 0))
const trainingCount = computed(() => filtered.value.filter(r => r.is_training).length)

/** ข้อความบอกเงื่อนไขที่กรอง — พิมพ์หลายชุดจะได้ไม่สับสนว่าแผ่นไหนของอะไร */
const scopeText = computed(() => {
  const p = []
  if (fGroupCenter.value !== 'all') p.push(`ศูนย์เครือข่าย${fGroupCenter.value}`)
  if (fDistrict.value !== 'all')    p.push(`อำเภอ${fDistrict.value}`)
  if (fSchool.value !== 'all')      p.push(schools.value.find(s => s.id === fSchool.value)?.name || '')
  if (fKind.value !== 'all')        p.push(ownerKindMeta(fKind.value).label)
  if (fLevel.value !== 'all')       p.push(levelMeta(fLevel.value).label)
  if (fYear.value !== 'all')        p.push(`ปีการศึกษา ${fYear.value}`)
  if (fFrom.value || fTo.value)     p.push(`ช่วง ${fFrom.value || '…'} ถึง ${fTo.value || '…'}`)
  return p.length ? p.join(' · ') : 'ทั้งหมด (ไม่จำกัดเงื่อนไข)'
})

const reporterName = computed(() => {
  const p = me.value
  if (!p) return ''
  return `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim() || p.full_name || ''
})
const printedAt = new Date().toLocaleDateString('th-TH', { day: 'numeric', month: 'long', year: 'numeric' })

function doPrint() { window.print() }

function resetFilter() {
  fGroupCenter.value = fDistrict.value = fSchool.value = fKind.value = fLevel.value = fYear.value = 'all'
  fFrom.value = fTo.value = ''
}
const selCls = 'px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600'
</script>

<template>
  <div class="font-sarabun space-y-5">
    <!-- ── แถบตั้งค่า (ไม่ถูกพิมพ์ เพราะอยู่นอก #print-report-root) ── -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h1 class="text-2xl font-extrabold text-slate-800">📄 รายงานผลงานและรางวัล</h1>
      <div class="flex items-center gap-2">
        <label class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none">
          <input type="checkbox" v-model="landscape" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> แนวนอน
        </label>
        <button @click="doPrint"
          class="px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
          พิมพ์ / บันทึก PDF
        </button>
      </div>
    </div>

    <div class="glass-card p-4 space-y-3">
      <div class="flex flex-wrap gap-2">
        <select v-model="fGroupCenter" :class="selCls">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="c in centers" :key="c" :value="c">ศูนย์ {{ c }}</option>
        </select>
        <select v-model="fDistrict" :class="selCls">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="fSchool" :class="selCls">
          <option value="all">ทุกโรงเรียน</option>
          <option v-for="s in schoolsInScope" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
        <select v-model="fKind" :class="selCls">
          <option value="all">ทุกประเภทผู้รับ</option>
          <option v-for="k in OWNER_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
        </select>
        <select v-model="fLevel" :class="selCls">
          <option value="all">ทุกระดับ</option>
          <option v-for="l in AWARD_LEVELS" :key="l.value" :value="l.value">{{ l.label }}</option>
        </select>
        <select v-model="fYear" :class="selCls">
          <option value="all">ทุกปีการศึกษา</option>
          <option v-for="y in years" :key="y" :value="y">ปี {{ y }}</option>
        </select>
        <input v-model="fFrom" type="date" :class="selCls" title="ตั้งแต่วันที่"/>
        <input v-model="fTo" type="date" :class="selCls" title="ถึงวันที่"/>
        <button @click="resetFilter" class="text-sm text-slate-400 hover:text-red-500 px-2">ล้าง</button>
      </div>
      <div class="flex flex-wrap items-center gap-3 pt-2 border-t border-slate-900/[0.06]">
        <label class="text-xs font-bold text-slate-500">จัดกลุ่มตาม</label>
        <select v-model="groupBy" :class="selCls">
          <option v-for="g in REPORT_GROUP_BY" :key="g.value" :value="g.value">{{ g.label }}</option>
        </select>
        <div class="flex gap-1 bg-slate-100 p-1 rounded-xl">
          <button @click="mode = 'summary'" :class="['px-3 py-1.5 text-xs font-bold rounded-lg transition-colors', mode==='summary' ? 'bg-primary text-white' : 'text-slate-500']">แบบสรุป</button>
          <button @click="mode = 'detail'" :class="['px-3 py-1.5 text-xs font-bold rounded-lg transition-colors', mode==='detail' ? 'bg-primary text-white' : 'text-slate-500']">แบบรายชื่อ</button>
        </div>
        <span class="text-sm text-slate-500 ml-auto">พบ {{ filtered.length.toLocaleString() }} รายการ · {{ grouped.length }} กลุ่ม</span>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <!-- ── ตัวรายงาน (ส่วนเดียวที่ถูกพิมพ์) ──
         ต้อง Teleport ไป body เพราะ @media print ใน style.css ใช้ selector
         `body > *:not(#print-report-root)` — ถ้าปล่อยไว้ลึกใน #app ตัว #app จะถูกซ่อน
         พาเอารายงานหายไปด้วย และ navbar จะติดไปในกระดาษแทน (pattern เดียวกับ
         AdminNitetReportView / GroupNitetView ที่ทำไว้ก่อนหน้า) -->
    <Teleport v-else to="body">
    <div id="print-report-root" style="padding: 1.5cm; font-family: 'Sarabun', sans-serif; color: #0f172a; background:#fff;">
      <div style="text-align:center; margin-bottom:18px;">
        <img v-if="config?.logo_url" :src="config.logo_url" style="width:60px; height:60px; object-fit:contain; margin:0 auto 8px;"/>
        <div style="font-size:20px; font-weight:800;">รายงานผลงานและรางวัล</div>
        <div style="font-size:15px; font-weight:700;">{{ config?.area_name || '' }}</div>
        <div style="font-size:12px; color:#475569; margin-top:6px;">ขอบเขตข้อมูล: {{ scopeText }}</div>
        <div style="font-size:12px; color:#475569;">
          จัดกลุ่มตาม{{ REPORT_GROUP_BY.find(g => g.value === groupBy)?.label }} ·
          รวม {{ filtered.length.toLocaleString() }} รายการ · พิมพ์เมื่อ {{ printedAt }}
        </div>
      </div>

      <p v-if="!filtered.length" style="text-align:center; color:#64748b; padding:40px 0;">ไม่พบข้อมูลตามเงื่อนไขที่เลือก</p>

      <!-- แบบสรุป -->
      <table v-else-if="mode === 'summary'" style="width:100%; border-collapse:collapse; font-size:13px;">
        <thead>
          <tr style="background:#f1f5f9;">
            <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:left;">{{ REPORT_GROUP_BY.find(g => g.value === groupBy)?.label }}</th>
            <th v-for="l in AWARD_LEVELS" :key="l.value" style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ l.short }}</th>
            <th style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">รวม</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(r, i) in summary" :key="r.name">
            <td style="border:1px solid #cbd5e1; padding:6px 8px;">{{ i + 1 }}. {{ r.name }}</td>
            <td v-for="(c, ci) in r.counts" :key="ci" style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ c || '-' }}</td>
            <td style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center; font-weight:700;">{{ r.total }}</td>
          </tr>
          <tr style="background:#f8fafc; font-weight:800;">
            <td style="border:1px solid #cbd5e1; padding:6px 8px;">รวมทั้งสิ้น</td>
            <td v-for="(c, ci) in summaryTotal.counts" :key="ci" style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ c || '-' }}</td>
            <td style="border:1px solid #cbd5e1; padding:6px 8px; text-align:center;">{{ summaryTotal.total }}</td>
          </tr>
        </tbody>
      </table>

      <!-- แบบรายชื่อ -->
      <template v-else>
        <div v-for="([name, list], gi) in grouped" :key="name" style="margin-bottom:16px;">
          <div style="font-weight:800; font-size:14px; margin:10px 0 6px;">{{ gi + 1 }}. {{ name }} <span style="font-weight:400; color:#475569;">({{ list.length }} รายการ)</span></div>
          <table style="width:100%; border-collapse:collapse; font-size:12px;">
            <thead>
              <tr style="background:#f1f5f9;">
                <th style="border:1px solid #cbd5e1; padding:5px 6px; width:36px;">ที่</th>
                <th style="border:1px solid #cbd5e1; padding:5px 6px; text-align:left;">ชื่อผลงาน/รางวัล</th>
                <th style="border:1px solid #cbd5e1; padding:5px 6px; text-align:left;">ผู้รับรางวัล</th>
                <th style="border:1px solid #cbd5e1; padding:5px 6px; text-align:left;">รางวัลที่ได้รับ</th>
                <th style="border:1px solid #cbd5e1; padding:5px 6px;">ระดับ</th>
                <th style="border:1px solid #cbd5e1; padding:5px 6px;">ปี</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(a, i) in list" :key="a.id">
                <td style="border:1px solid #cbd5e1; padding:5px 6px; text-align:center;">{{ i + 1 }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 6px;">
                  {{ a.title }}
                  <span v-if="a.is_training" style="color:#0f766e;">(อบรม {{ a.training_hours }} ชม.)</span>
                </td>
                <td style="border:1px solid #cbd5e1; padding:5px 6px;">
                  {{ a.owner_label }}
                  <span v-if="a.is_group" style="color:#475569;">(กลุ่ม {{ (a.members||[]).length }} คน)</span>
                </td>
                <td style="border:1px solid #cbd5e1; padding:5px 6px;">{{ rankLabel(a) }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 6px; text-align:center;">{{ levelMeta(a.level).short }}</td>
                <td style="border:1px solid #cbd5e1; padding:5px 6px; text-align:center;">{{ a.academic_year || '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>

      <!-- สรุปชั่วโมงอบรม -->
      <div v-if="trainingCount" style="margin-top:14px; font-size:13px;">
        <b>สรุปการอบรม/พัฒนาตนเอง:</b> {{ trainingCount }} รายการ รวม {{ trainingHours.toLocaleString() }} ชั่วโมง
      </div>

      <!-- ลงชื่อ -->
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
  </div>
</template>
