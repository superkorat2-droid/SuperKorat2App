<script setup>
/**
 * SupervisionAnswerEditModal — ผู้จัดการแบบนิเทศ (แอดมิน/ผู้สร้าง/ผู้รับผิดชอบรายบุคคล) แก้คำตอบที่ส่งมาแล้ว
 *
 * - รูปแบบคำตอบต้องตรงกับที่ SupervisionFillView ส่ง: choice = value ของตัวเลือก, multi_choice = array,
 *   yes_no = 'yes'/'no', rating/number = ตัวเลข, ตัวเลือก "อื่นๆ" เก็บเป็นข้อความ "อื่นๆ: ..."
 * - บันทึกเฉพาะข้อที่เปลี่ยน: มีแถวเดิม → update, ไม่มี (ผู้ตอบข้าม) → insert
 * - สิทธิ์จริงอยู่ที่ RLS (migration 99: can_manage_supervision_form) หน้านี้แค่ซ่อนปุ่ม
 * - ลบหลักฐาน = ตัดลิงก์ออกจากคำตอบ ไม่ลบไฟล์ใน Storage
 */
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const props = defineProps({
  response:  { type: Object, default: null },   // null = ปิด
  questions: { type: Array,  default: () => [] },
  title:     { type: String, default: '' },     // ชื่อผู้ตอบ/โรงเรียน สำหรับหัวโมดัล
})
const emit = defineEmits(['close', 'saved'])

const OTHER_PREFIX = 'อื่นๆ:'
const draft  = ref({})
const saving = ref(false)

const answerable = computed(() => props.questions.filter(q => q.type !== 'section'))
function existingRow(q) { return (props.response?.supervision_answers || []).find(a => a.question_id === q.id) }
function otherOption(q) { return q.options?.find(o => o.is_other) }
function isOtherString(v) { return typeof v === 'string' && v.startsWith('อื่นๆ') }
function stripOther(v) { return v.replace(/^อื่นๆ:?\s*/, '') }

// คำตอบที่เก็บไว้ → ค่าที่ผูกกับช่องกรอก (แยกข้อความ "อื่นๆ" ออกมา)
function toDraft(q, row) {
  const a = row?.answer
  const d = { answer: a ?? null, other: '', file: row?.evidence_file_url || null, link: row?.evidence_link_url || '' }
  const oth = otherOption(q)
  if (q.type === 'choice' && oth && isOtherString(a)) { d.answer = oth.value; d.other = stripOther(a) }
  if (q.type === 'multi_choice') {
    const arr = Array.isArray(a) ? a : []
    d.answer = arr.map(v => (oth && isOtherString(v)) ? (d.other = stripOther(v), oth.value) : v)
  }
  if (['text','textarea'].includes(q.type)) d.answer = a ?? ''
  return d
}

// ค่าในช่องกรอก → คำตอบที่จะเก็บ (เหมือน resolveAnswerForSubmit ของหน้ากรอก)
function fromDraft(q, d) {
  const oth = otherOption(q)
  if (q.type === 'choice' && oth && d.answer === oth.value) return `${OTHER_PREFIX} ${d.other.trim()}`.trim()
  if (q.type === 'multi_choice') return (d.answer || []).map(v => (oth && v === oth.value) ? `${OTHER_PREFIX} ${d.other.trim()}`.trim() : v)
  if (q.type === 'number') return d.answer === '' || d.answer === null ? null : Number(d.answer)
  return d.answer
}

function isEmpty(v) { return v === null || v === undefined || v === '' || (Array.isArray(v) && !v.length) }

function toggleMulti(q, v) {
  const arr = draft.value[q.id].answer || []
  draft.value[q.id].answer = arr.includes(v) ? arr.filter(x => x !== v) : [...arr, v]
}

async function save() {
  const { data: { user } } = await supabase.auth.getUser()
  const updates = [], inserts = []
  for (const q of answerable.value) {
    const row = existingRow(q)
    const d   = draft.value[q.id]
    const next = {
      answer:            fromDraft(q, d),
      evidence_file_url: d.file || null,
      evidence_link_url: d.link?.trim() || null,
    }
    const prev = {
      answer:            row?.answer ?? null,
      evidence_file_url: row?.evidence_file_url || null,
      evidence_link_url: row?.evidence_link_url || null,
    }
    // '' / null / [] = ไม่ได้ตอบ เหมือนกัน — ไม่งั้นข้อที่ผู้ตอบข้ามจะถูกนับว่า "แก้" ทุกครั้ง
    const norm = o => JSON.stringify({ ...o, answer: isEmpty(o.answer) ? null : o.answer })
    if (norm(next) === norm(prev)) continue
    if (!row && isEmpty(next.answer) && !next.evidence_file_url && !next.evidence_link_url) continue
    if (row) updates.push({ id: row.id, ...next })
    else inserts.push({ response_id: props.response.id, question_id: q.id, ...next })
  }
  if (!updates.length && !inserts.length) {
    Swal.fire({ icon: 'info', title: 'ไม่มีการเปลี่ยนแปลง', showConfirmButton: false, timer: 1200 })
    return
  }

  saving.value = true
  try {
    for (const u of updates) {
      const { id, ...vals } = u
      const { error } = await supabase.from('supervision_answers').update(vals).eq('id', id)
      if (error) throw error
    }
    if (inserts.length) {
      const { error } = await supabase.from('supervision_answers').insert(inserts)
      if (error) throw error
    }
    const { error } = await supabase.from('supervision_responses')
      .update({ edited_by: user?.id, edited_at: new Date().toISOString() })
      .eq('id', props.response.id)
    if (error) throw error
    await Swal.fire({ icon: 'success', title: `บันทึกแล้ว (${updates.length + inserts.length} ข้อ)`, showConfirmButton: false, timer: 1200 })
    emit('saved')
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: err.message })
  } finally {
    saving.value = false
  }
}

function onKey(e) { if (e.key === 'Escape' && !saving.value) emit('close') }

watch(() => props.response, (r) => {
  if (r) {
    draft.value = Object.fromEntries(answerable.value.map(q => [q.id, toDraft(q, existingRow(q))]))
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKey)
  } else {
    document.body.style.overflow = ''
    window.removeEventListener('keydown', onKey)
  }
}, { immediate: true })

// ต้องคืนค่าเสมอ ไม่งั้นกด back ขณะโมดัลเปิด หน้าเว็บจะเลื่อนไม่ได้ค้างถาวร
onBeforeUnmount(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onKey)
})

function qNumber(q) { return answerable.value.indexOf(q) + 1 }
</script>

<template>
  <Teleport to="body">
    <div v-if="response"
      class="fixed inset-0 z-[110] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm font-sarabun"
      @click.self="!saving && $emit('close')">
      <div class="bg-white rounded-t-3xl sm:rounded-3xl w-full sm:max-w-3xl max-h-[95dvh] flex flex-col overflow-hidden shadow-2xl">

        <!-- Header -->
        <div class="flex items-center gap-3 px-5 py-3 border-b border-slate-100 flex-shrink-0">
          <div class="flex-1 min-w-0">
            <p class="text-xs text-slate-400">แก้ไขคำตอบ</p>
            <p class="text-sm font-bold text-slate-800 truncate">{{ title || '—' }}</p>
          </div>
          <button @click="$emit('close')" :disabled="saving" aria-label="ปิด"
            class="w-9 h-9 flex-shrink-0 flex items-center justify-center rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto px-5 py-4 space-y-3">
          <p class="text-xs text-amber-700 bg-amber-50 rounded-xl px-3 py-2">
            การแก้ไขจะถูกบันทึกว่า "แก้ไขโดยผู้ดูแล" พร้อมชื่อและเวลา · คะแนนและกราฟคำนวณใหม่ทันที
          </p>

          <template v-for="q in questions" :key="q.id">
            <div v-if="q.type === 'section'" class="pt-2">
              <p class="text-sm font-bold text-indigo-700">{{ q.question_text }}</p>
            </div>

            <div v-else-if="draft[q.id]" class="border border-slate-200 rounded-2xl p-4 space-y-2">
              <p class="text-sm font-medium text-slate-700">
                <span class="text-primary font-bold mr-1">{{ qNumber(q) }}.</span>{{ q.question_text }}
                <span v-if="!existingRow(q)" class="ml-1 text-[10px] bg-slate-100 text-slate-500 px-1.5 py-0.5 rounded">ผู้ตอบไม่ได้ตอบ</span>
              </p>

              <input v-if="q.type === 'text'" v-model="draft[q.id].answer" type="text"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              <textarea v-else-if="q.type === 'textarea'" v-model="draft[q.id].answer" rows="3"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              <input v-else-if="q.type === 'number'" v-model.number="draft[q.id].answer" type="number"
                class="w-40 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>

              <div v-else-if="q.type === 'choice' || q.type === 'multi_choice'" class="space-y-1.5">
                <label v-for="o in q.options" :key="o.value" class="flex items-center gap-2 text-sm cursor-pointer">
                  <input v-if="q.type === 'choice'" type="radio" :value="o.value" v-model="draft[q.id].answer" class="accent-primary"/>
                  <input v-else type="checkbox" :checked="(draft[q.id].answer || []).includes(o.value)" @change="toggleMulti(q, o.value)" class="accent-primary rounded"/>
                  <span>{{ o.label }}</span>
                  <span v-if="o.score !== '' && o.score !== null && o.score !== undefined" class="text-[10px] text-emerald-600">({{ o.score }} คะแนน)</span>
                </label>
                <input v-if="otherOption(q) && (q.type === 'choice' ? draft[q.id].answer === otherOption(q).value : (draft[q.id].answer || []).includes(otherOption(q).value))"
                  v-model="draft[q.id].other" type="text" placeholder="ข้อความ อื่นๆ"
                  class="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-primary"/>
                <button v-if="q.type === 'choice' && draft[q.id].answer" type="button" @click="draft[q.id].answer = null"
                  class="text-[11px] text-slate-400 hover:text-red-500">ล้างคำตอบ</button>
              </div>

              <div v-else-if="q.type === 'yes_no'" class="flex gap-2">
                <button v-for="o in [{ v: 'yes', l: 'ใช่', on: 'border-emerald-500 bg-emerald-50 text-emerald-700' }, { v: 'no', l: 'ไม่ใช่', on: 'border-red-500 bg-red-50 text-red-700' }]"
                  :key="o.v" type="button" @click="draft[q.id].answer = draft[q.id].answer === o.v ? null : o.v"
                  :class="['px-5 py-1.5 rounded-xl border-2 text-sm font-bold', draft[q.id].answer === o.v ? o.on : 'border-slate-200 text-slate-500']">
                  {{ o.l }}
                </button>
              </div>

              <div v-else-if="q.type === 'rating'" class="flex flex-wrap gap-1.5">
                <button v-for="n in (q.settings?.max || 5)" :key="n" type="button"
                  @click="draft[q.id].answer = draft[q.id].answer === n ? null : n"
                  :class="['w-9 h-9 rounded-xl border-2 text-sm font-bold', draft[q.id].answer === n ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500']">
                  {{ n }}
                </button>
              </div>

              <!-- หลักฐาน -->
              <div v-if="q.evidence_type !== 'none' || draft[q.id].file || draft[q.id].link"
                class="pt-2 border-t border-slate-100 space-y-1.5">
                <div v-if="draft[q.id].file" class="flex items-center gap-2 text-xs">
                  <span class="text-slate-500">ไฟล์หลักฐาน:</span>
                  <a :href="draft[q.id].file" target="_blank" rel="noopener" class="text-primary font-bold hover:underline">เปิดดู</a>
                  <button type="button" @click="draft[q.id].file = null" class="text-slate-400 hover:text-red-500">ลบออก</button>
                </div>
                <div v-if="['url','both'].includes(q.evidence_type) || draft[q.id].link" class="flex items-center gap-2 text-xs">
                  <span class="text-slate-500 flex-shrink-0">ลิงก์หลักฐาน:</span>
                  <input v-model="draft[q.id].link" type="url" placeholder="https://"
                    class="flex-1 px-2 py-1 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-primary"/>
                </div>
              </div>
            </div>
          </template>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-2 px-5 py-3 border-t border-slate-100 flex-shrink-0">
          <button @click="$emit('close')" :disabled="saving"
            class="px-4 py-2 text-sm font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200">ยกเลิก</button>
          <button @click="save" :disabled="saving"
            class="px-5 py-2 text-sm font-bold bg-primary text-white rounded-xl shadow disabled:opacity-50">
            {{ saving ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
