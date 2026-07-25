<script setup>
/**
 * HolidayManagerModal — จัดการวันหยุดของเขต (admin เท่านั้น)
 * เพิ่ม/แก้/ลบทีละรายการ และนำเข้าจาก Excel ทีละหลายรายการ
 */
import { ref, computed, watch } from 'vue'
import * as XLSX from 'xlsx'
import Swal from 'sweetalert2'
import { supabase } from '../../supabase'
import { HOLIDAY_TYPES, holidayMeta, HOLIDAY_IMPORT_COLUMNS, parseHolidayRows } from '../../composables/useHolidays'

const props = defineProps({ show: { type: Boolean, default: false } })
const emit  = defineEmits(['close', 'changed'])

const rows      = ref([])
const loading   = ref(false)
const saving    = ref(false)
const importing = ref(false)
const yearFilter = ref('all')

const blank = () => ({ id: null, title: '', start_date: '', end_date: '', type: 'public', note: '' })
const form = ref(blank())
const editing = ref(false)

const years = computed(() =>
  [...new Set(rows.value.map(h => h.start_date.slice(0, 4)))].sort().reverse()
)
const filtered = computed(() =>
  yearFilter.value === 'all' ? rows.value : rows.value.filter(h => h.start_date.startsWith(yearFilter.value))
)

async function load() {
  loading.value = true
  const { data } = await supabase.from('nithet_holidays').select('*').order('start_date')
  rows.value = data || []
  loading.value = false
}
watch(() => props.show, v => { if (v) { load(); form.value = blank(); editing.value = false } })

function startEdit(h) {
  form.value = { ...h }
  editing.value = true
}
function cancelEdit() {
  form.value = blank()
  editing.value = false
}

async function saveOne() {
  const f = form.value
  if (!f.title.trim() || !f.start_date) {
    return Swal.fire({ icon: 'warning', title: 'กรอกไม่ครบ', text: 'ต้องมีชื่อวันหยุดและวันที่เริ่ม' })
  }
  const payload = {
    title: f.title.trim(),
    start_date: f.start_date,
    end_date: f.end_date || f.start_date,   // ไม่ระบุ = วันเดียว
    type: f.type,
    note: (f.note || '').trim(),
  }
  if (payload.end_date < payload.start_date) {
    return Swal.fire({ icon: 'warning', title: 'ช่วงวันที่ไม่ถูกต้อง', text: 'วันสิ้นสุดต้องไม่อยู่ก่อนวันเริ่ม' })
  }

  saving.value = true
  const { error } = f.id
    ? await supabase.from('nithet_holidays').update(payload).eq('id', f.id)
    : await supabase.from('nithet_holidays').insert(payload)
  saving.value = false

  if (error) {
    // unique index (start_date, end_date, title) กันเพิ่มซ้ำ
    const dup = error.code === '23505'
    return Swal.fire({ icon: 'error', title: dup ? 'มีวันหยุดนี้อยู่แล้ว' : 'บันทึกไม่สำเร็จ', text: dup ? '' : error.message })
  }
  cancelEdit()
  await load()
  emit('changed')
}

async function removeOne(h) {
  const res = await Swal.fire({
    title: 'ลบวันหยุดนี้?', text: h.title, icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('nithet_holidays').delete().eq('id', h.id)
  if (error) return Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message })
  await load()
  emit('changed')
}

// ── Excel ─────────────────────────────────────────────────────────
function downloadTemplate() {
  const sample = [
    { 'ชื่อวันหยุด': 'วันสงกรานต์',        'วันที่เริ่ม': '13/04/2569', 'วันที่สิ้นสุด': '15/04/2569', 'ประเภท': 'วันหยุดราชการ', 'หมายเหตุ': '' },
    { 'ชื่อวันหยุด': 'วันแรงงานแห่งชาติ',  'วันที่เริ่ม': '01/05/2569', 'วันที่สิ้นสุด': '',           'ประเภท': 'วันหยุดราชการ', 'หมายเหตุ': 'เว้นว่าง = วันเดียว' },
    { 'ชื่อวันหยุด': 'ปิดภาคเรียนที่ 1',   'วันที่เริ่ม': '11/10/2569', 'วันที่สิ้นสุด': '31/10/2569', 'ประเภท': 'ปิดภาคเรียน',   'หมายเหตุ': '' },
  ]
  const ws = XLSX.utils.json_to_sheet(sample, { header: HOLIDAY_IMPORT_COLUMNS })
  ws['!cols'] = [{ wch: 28 }, { wch: 14 }, { wch: 14 }, { wch: 16 }, { wch: 26 }]
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'วันหยุด')
  XLSX.writeFile(wb, 'เทมเพลตวันหยุด.xlsx')
}

async function onImportFile(ev) {
  const file = ev.target.files?.[0]
  ev.target.value = ''
  if (!file) return

  importing.value = true
  try {
    const buf = await file.arrayBuffer()
    const wb  = XLSX.read(buf, { type: 'array', cellDates: true })
    const ws  = wb.Sheets[wb.SheetNames[0]]
    const raw = XLSX.utils.sheet_to_json(ws, { defval: '' })

    const { rows: parsed, errors } = parseHolidayRows(raw)

    if (!parsed.length) {
      return Swal.fire({
        icon: 'warning', title: 'ไม่พบข้อมูลที่นำเข้าได้',
        html: errors.length ? `<div style="text-align:left;font-size:13px">${errors.slice(0, 10).join('<br>')}</div>`
                            : 'ตรวจสอบว่าหัวตารางตรงกับเทมเพลตหรือไม่',
      })
    }

    const res = await Swal.fire({
      icon: 'question',
      title: `นำเข้า ${parsed.length} รายการ?`,
      html: `<div style="text-align:left;font-size:13px">
        ${parsed.slice(0, 5).map(r => `• ${r.title} (${r.start_date}${r.end_date !== r.start_date ? ' – ' + r.end_date : ''})`).join('<br>')}
        ${parsed.length > 5 ? `<br>… และอีก ${parsed.length - 5} รายการ` : ''}
        ${errors.length ? `<br><br><b style="color:#b45309">ข้ามไป ${errors.length} แถว</b><br>${errors.slice(0, 5).join('<br>')}` : ''}
      </div>`,
      showCancelButton: true, confirmButtonText: 'นำเข้า', cancelButtonText: 'ยกเลิก',
    })
    if (!res.isConfirmed) return

    // upsert กับ unique index (start_date,end_date,title) → นำเข้าไฟล์เดิมซ้ำได้ ไม่เกิดข้อมูลซ้ำ
    const { error } = await supabase
      .from('nithet_holidays')
      .upsert(parsed, { onConflict: 'start_date,end_date,title', ignoreDuplicates: true })
    if (error) throw error

    await load()
    emit('changed')
    Swal.fire({ icon: 'success', title: `นำเข้าสำเร็จ ${parsed.length} รายการ`, timer: 1600, showConfirmButton: false })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'นำเข้าไม่สำเร็จ', text: e.message })
  } finally {
    importing.value = false
  }
}

function fmt(h) {
  const f = d => new Date(d + 'T00:00:00').toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: '2-digit' })
  return h.start_date === h.end_date ? f(h.start_date) : `${f(h.start_date)} – ${f(h.end_date)}`
}
</script>

<template>
  <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0">
      <div v-if="show" class="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
        @click.self="$emit('close')">
        <div class="glass-panel rounded-3xl w-full max-w-3xl max-h-[92dvh] flex flex-col overflow-hidden">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-900/[0.06]">
            <div>
              <h2 class="text-lg font-extrabold text-slate-800">จัดการวันหยุด</h2>
              <p class="text-xs text-slate-500 mt-0.5">วันหยุดจะแสดงบนปฏิทินนิเทศทั้งหลังบ้านและหน้าสาธารณะ</p>
            </div>
            <button @click="$emit('close')" aria-label="ปิด"
              class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-900/[0.05] text-slate-400 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-5">

            <!-- ฟอร์มเพิ่ม/แก้ -->
            <div class="glass-inset p-4 space-y-3">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">
                {{ editing ? 'แก้ไขวันหยุด' : 'เพิ่มวันหยุด' }}
              </p>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <input v-model="form.title" placeholder="ชื่อวันหยุด เช่น วันสงกรานต์"
                  class="sm:col-span-2 w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">วันที่เริ่ม</label>
                  <input v-model="form.start_date" type="date"
                    class="w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">วันที่สิ้นสุด <span class="font-normal text-slate-400">(เว้นว่าง = วันเดียว)</span></label>
                  <input v-model="form.end_date" type="date"
                    class="w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
                <select v-model="form.type"
                  class="w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary">
                  <option v-for="t in HOLIDAY_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
                </select>
                <input v-model="form.note" placeholder="หมายเหตุ (ถ้ามี)"
                  class="w-full px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div class="flex gap-2">
                <button @click="saveOne" :disabled="saving"
                  class="px-4 py-2 rounded-xl text-sm font-bold bg-primary text-white shadow-sm hover:-translate-y-0.5 transition-all disabled:opacity-50">
                  {{ saving ? 'กำลังบันทึก…' : (editing ? 'บันทึกการแก้ไข' : 'เพิ่มวันหยุด') }}
                </button>
                <button v-if="editing" @click="cancelEdit"
                  class="px-4 py-2 rounded-xl text-sm font-bold border border-white/80 bg-white/70 text-slate-600 hover:border-primary/40 transition-all">
                  ยกเลิก
                </button>
              </div>
            </div>

            <!-- นำเข้า Excel -->
            <div class="glass-inset p-4 space-y-2">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">นำเข้าจาก Excel</p>
              <div class="flex flex-wrap gap-2">
                <button @click="downloadTemplate"
                  class="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-primary hover:text-white transition-all">
                  ⬇ ดาวน์โหลดเทมเพลต
                </button>
                <label class="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-bold bg-emerald-600 text-white hover:-translate-y-0.5 shadow-sm transition-all cursor-pointer">
                  {{ importing ? 'กำลังนำเข้า…' : '⬆ เลือกไฟล์ Excel' }}
                  <input type="file" accept=".xlsx,.xls,.csv" class="hidden" @change="onImportFile" :disabled="importing"/>
                </label>
              </div>
              <p class="text-[11px] text-slate-500 leading-relaxed">
                คอลัมน์: <b>{{ HOLIDAY_IMPORT_COLUMNS.join(' · ') }}</b><br>
                วันที่รองรับทั้ง พ.ศ. และ ค.ศ. (เช่น 13/04/2569 หรือ 2026-04-13) ·
                นำเข้าไฟล์เดิมซ้ำได้ ระบบข้ามรายการที่มีอยู่แล้วให้อัตโนมัติ
              </p>
            </div>

            <!-- รายการ -->
            <div>
              <div class="flex items-center justify-between mb-2">
                <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">รายการวันหยุด ({{ filtered.length }})</p>
                <select v-model="yearFilter"
                  class="px-2.5 py-1 border border-white/80 bg-white/70 backdrop-blur rounded-lg text-xs focus:outline-none">
                  <option value="all">ทุกปี</option>
                  <option v-for="y in years" :key="y" :value="y">{{ +y + 543 }}</option>
                </select>
              </div>

              <div v-if="loading" class="text-center py-8 text-slate-400 text-sm">กำลังโหลด…</div>
              <div v-else-if="!filtered.length" class="text-center py-8 text-slate-400 text-sm">
                ยังไม่มีวันหยุด — เพิ่มทีละรายการหรือนำเข้าจาก Excel
              </div>
              <div v-else class="space-y-2">
                <div v-for="h in filtered" :key="h.id"
                  class="flex items-center gap-3 glass-tile px-3 py-2.5">
                  <span :class="['w-2.5 h-2.5 rounded-full flex-shrink-0', holidayMeta(h.type).dot]"></span>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-bold text-slate-800 truncate">{{ h.title }}</p>
                    <p class="text-xs text-slate-500">
                      {{ fmt(h) }} · {{ holidayMeta(h.type).label }}
                      <span v-if="h.note"> · {{ h.note }}</span>
                    </p>
                  </div>
                  <button @click="startEdit(h)" class="text-xs font-bold text-slate-500 hover:text-primary transition-colors">แก้ไข</button>
                  <button @click="removeOne(h)" class="text-xs font-bold text-slate-400 hover:text-red-500 transition-colors">ลบ</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
