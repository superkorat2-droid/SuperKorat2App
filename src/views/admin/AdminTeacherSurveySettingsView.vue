<script setup>
/**
 * ตั้งค่าแบบสำรวจเครือข่ายวิชาชีพครู (แอดมิน)
 *   - เปิด/ปิดรับ + วันเริ่ม/หมดเขต
 *   - แก้ชื่อ/เพิ่ม/ลบ/เรียงตัวเลือกแต่ละข้อ + จำนวนที่เลือกได้สูงสุด
 *   - คำถามเสริม (ข้อความ / เลือกข้อเดียว / เลือกหลายข้อ)
 *
 * key ของตัวเลือกเดิม "ห้ามเปลี่ยน" — ข้อมูลครูเก็บ key (migration 0104)
 * แก้ label ได้อิสระ · ตัวเลือกใหม่ได้ key สุ่มให้อัตโนมัติ
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useTeacherSurveyConfig, OPTION_FIELDS } from '../../composables/useTeacherSurvey'

const { fetchConfig } = useTeacherSurveyConfig()

const loading = ref(true)
const saving  = ref(false)
const msg     = ref('')
const err     = ref('')
const c       = ref(null)
const usage   = ref({})        // { field: { key: count } } — กันลบตัวเลือกที่มีคนเลือกแล้ว

// datetime-local ↔ ISO ต้องแปลงโซนเวลาเอง (บทเรียนแบบนิเทศคลาด 7 ชม.)
function toLocalInput(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}
function fromLocalInput(v) { return v ? new Date(v).toISOString() : null }

const openAt   = ref('')
const deadline = ref('')

onMounted(async () => {
  const { data, error } = await supabase.from('teacher_survey_config').select('*').eq('id', 1).single()
  if (error) { err.value = error.message; loading.value = false; return }
  c.value = JSON.parse(JSON.stringify(data))
  c.value.extra_questions = Array.isArray(c.value.extra_questions) ? c.value.extra_questions : []
  openAt.value = toLocalInput(data.open_at)
  deadline.value = toLocalInput(data.deadline)
  await loadUsage()
  loading.value = false
})

async function loadUsage() {
  const out = {}
  for (let from = 0; ; from += 1000) {
    const { data } = await supabase.from('teachers')
      .select('grades, networks, constraints, topics, academic_rank, major_match').range(from, from + 999)
    for (const t of data || []) {
      const add = (f, k) => { if (!k) return; out[f] ??= {}; out[f][k] = (out[f][k] || 0) + 1 }
      t.grades.forEach(k => add('grades', k)); t.networks.forEach(k => add('networks', k))
      t.constraints.forEach(k => add('constraints', k)); t.topics.forEach(k => add('topics', k))
      add('ranks', t.academic_rank); add('major_match', t.major_match)
    }
    if (!data || data.length < 1000) break
  }
  usage.value = out
}
const used = (field, key) => usage.value[field]?.[key] || 0

const newKey = () => 'x' + Date.now().toString(36) + Math.random().toString(36).slice(2, 5)

function list(field, parent = null) { return parent ? parent.children : c.value.options[field] }
function addOpt(field, parent = null) {
  const arr = list(field, parent) || (c.value.options[field] = [])
  arr.push({ key: newKey(), label: '' })
}
function removeOpt(field, idx, parent = null) {
  const arr = list(field, parent)
  const o = arr[idx]
  const n = used(field, o.key) + (o.children || []).reduce((s, ch) => s + used(field, ch.key), 0)
  if (n > 0 && !window.confirm(`มีครูเลือก "${o.label}" ไว้แล้ว ${n} คน\nถ้าลบ ข้อมูลเดิมจะแสดงเป็นรหัส "${o.key}" แทนชื่อ\n(แนะนำให้แก้ชื่อแทนการลบ) ยืนยันลบ?`)) return
  arr.splice(idx, 1)
}
function move(field, idx, dir, parent = null) {
  const arr = list(field, parent)
  const j = idx + dir
  if (j < 0 || j >= arr.length) return
  ;[arr[idx], arr[j]] = [arr[j], arr[idx]]
}

const hasLimit = f => ['networks', 'topics', 'constraints', 'grades'].includes(f)
function setLimit(field, v) {
  const n = parseInt(v, 10)
  const next = { ...c.value.limits }
  if (n > 0) next[field] = n
  else delete next[field]
  c.value.limits = next
}

// ── คำถามเสริม ──
function addExtra() {
  c.value.extra_questions.push({ key: newKey(), label: '', type: 'text', options: [], required: false, max: 0 })
}
function removeExtra(i) {
  if (!window.confirm('ลบคำถามนี้? (คำตอบเดิมยังเก็บอยู่ในฐานข้อมูล แต่จะไม่แสดง)')) return
  c.value.extra_questions.splice(i, 1)
}
function setExtraOptions(q, text) { q.options = text.split('\n').map(s => s.trim()).filter(Boolean) }

function validate() {
  for (const f of OPTION_FIELDS) {
    const arr = c.value.options[f.key] || []
    if (!arr.length) return `ข้อ "${f.label}" ต้องมีตัวเลือกอย่างน้อย 1 ตัว`
    for (const o of arr) {
      if (!o.label?.trim()) return `มีตัวเลือกที่ยังไม่ได้ตั้งชื่อในข้อ "${f.label}"`
      for (const ch of o.children || []) if (!ch.label?.trim()) return `มีตัวเลือกย่อยที่ยังไม่ได้ตั้งชื่อในข้อ "${f.label}"`
    }
  }
  for (const q of c.value.extra_questions) {
    if (!q.label?.trim()) return 'มีคำถามเสริมที่ยังไม่ได้ตั้งชื่อ'
    if (['choice', 'multi'].includes(q.type) && !q.options?.length) return `คำถาม "${q.label}" ต้องมีตัวเลือก`
  }
  if (openAt.value && deadline.value && new Date(openAt.value) >= new Date(deadline.value)) return 'วันหมดเขตต้องหลังวันเริ่ม'
  return ''
}

async function save() {
  msg.value = ''; err.value = ''
  const v = validate()
  if (v) { err.value = v; return }
  saving.value = true
  const { data: { user } } = await supabase.auth.getUser()
  const { error } = await supabase.from('teacher_survey_config').update({
    title: c.value.title, intro: c.value.intro, is_open: c.value.is_open,
    open_at: fromLocalInput(openAt.value), deadline: fromLocalInput(deadline.value),
    options: c.value.options, limits: c.value.limits, extra_questions: c.value.extra_questions,
    updated_by: user?.id || null,
  }).eq('id', 1)
  saving.value = false
  if (error) { err.value = error.message; return }
  await fetchConfig(true)
  msg.value = 'บันทึกแล้ว'
  setTimeout(() => { msg.value = '' }, 2500)
}

const inputCls = 'w-full px-3 py-2 border border-slate-200 bg-white rounded-lg text-sm focus:outline-none focus:border-primary'
const surveyLink = computed(() => `${window.location.origin}${window.location.pathname}#/teacher-survey`)
</script>

<template>
  <div class="space-y-4 font-sarabun max-w-4xl">
    <div class="flex flex-wrap items-center gap-3">
      <router-link to="/dashboard/teachers" class="text-sm text-slate-500">← ทำเนียบครู</router-link>
      <h1 class="flex-1 text-xl font-extrabold text-slate-800">ตั้งค่าแบบสำรวจเครือข่ายวิชาชีพครู</h1>
    </div>

    <div v-if="loading" class="glass-card p-10 text-center text-slate-400 animate-pulse">กำลังโหลด...</div>

    <template v-else-if="c">
      <section class="glass-card p-4 space-y-3">
        <h2 class="font-bold text-slate-700">การเปิดรับ</h2>
        <label class="flex items-center gap-2 text-sm font-bold">
          <input type="checkbox" v-model="c.is_open" class="w-4 h-4"/> เปิดรับแบบสำรวจ
        </label>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label class="text-sm">วันเริ่ม (ว่าง = ทันที)<input type="datetime-local" v-model="openAt" :class="inputCls"/></label>
          <label class="text-sm">วันหมดเขต (ว่าง = ไม่มีกำหนด)<input type="datetime-local" v-model="deadline" :class="inputCls"/></label>
        </div>
        <p class="text-xs text-slate-500">ปิดรับแล้วครูยังแก้ข้อมูลเดิมผ่านลิงก์ส่วนตัวได้ตลอด (ทำเนียบเป็นข้อมูลถาวร) · ลิงก์แบบสำรวจ:
          <a :href="surveyLink" target="_blank" class="text-primary break-all">{{ surveyLink }}</a></p>
      </section>

      <section class="glass-card p-4 space-y-3">
        <h2 class="font-bold text-slate-700">หัวเรื่องและคำชี้แจง</h2>
        <input v-model="c.title" :class="inputCls" placeholder="ชื่อแบบสำรวจ"/>
        <textarea v-model="c.intro" rows="5" :class="inputCls" placeholder="คำชี้แจง"/>
      </section>

      <section v-for="f in OPTION_FIELDS" :key="f.key" class="glass-card p-4 space-y-2">
        <div class="flex flex-wrap items-center gap-3">
          <h2 class="flex-1 font-bold text-slate-700">{{ f.label }} <span class="text-xs font-normal text-slate-400">({{ f.multi ? 'เลือกหลายข้อ' : 'เลือกข้อเดียว' }})</span></h2>
          <label v-if="hasLimit(f.key)" class="text-xs text-slate-600 flex items-center gap-1">
            เลือกได้สูงสุด
            <input type="number" min="0" :value="c.limits[f.key] || ''" @input="setLimit(f.key, $event.target.value)" class="w-16 px-2 py-1 border rounded"/>
            ข้อ (ว่าง = ไม่จำกัด)
          </label>
        </div>

        <div v-for="(o, i) in c.options[f.key]" :key="o.key" class="space-y-1">
          <div class="flex items-center gap-1">
            <button @click="move(f.key, i, -1)" class="px-1 text-slate-400 hover:text-slate-700" title="ขึ้น">▲</button>
            <button @click="move(f.key, i, 1)" class="px-1 text-slate-400 hover:text-slate-700" title="ลง">▼</button>
            <input v-model="o.label" :class="inputCls" :placeholder="o.children ? 'ชื่อหัวกลุ่ม' : 'ชื่อตัวเลือก'"/>
            <label v-if="!o.children" class="text-[11px] text-slate-500 flex items-center gap-1 whitespace-nowrap" title="แสดงช่อง 'โปรดระบุ' เมื่อเลือก">
              <input type="checkbox" v-model="o.is_other"/> มีช่องระบุ
            </label>
            <span class="text-[11px] text-slate-400 whitespace-nowrap w-14 text-right">{{ used(f.key, o.key) || '' }}{{ used(f.key, o.key) ? ' คน' : '' }}</span>
            <button @click="removeOpt(f.key, i)" class="px-2 text-red-400 hover:text-red-600" title="ลบ">✕</button>
          </div>
          <!-- ตัวเลือกย่อย (เช่น ภาษาต่างประเทศ → อังกฤษ/จีน/อื่น ๆ) -->
          <div v-if="o.children" class="ml-10 space-y-1 border-l-2 border-slate-200 pl-3">
            <div v-for="(ch, j) in o.children" :key="ch.key" class="flex items-center gap-1">
              <button @click="move(f.key, j, -1, o)" class="px-1 text-slate-400">▲</button>
              <button @click="move(f.key, j, 1, o)" class="px-1 text-slate-400">▼</button>
              <input v-model="ch.label" :class="inputCls" placeholder="ชื่อตัวเลือกย่อย"/>
              <label class="text-[11px] text-slate-500 flex items-center gap-1 whitespace-nowrap"><input type="checkbox" v-model="ch.is_other"/> มีช่องระบุ</label>
              <span class="text-[11px] text-slate-400 whitespace-nowrap w-14 text-right">{{ used(f.key, ch.key) ? used(f.key, ch.key) + ' คน' : '' }}</span>
              <button @click="removeOpt(f.key, j, o)" class="px-2 text-red-400">✕</button>
            </div>
            <button @click="addOpt(f.key, o)" class="text-xs text-primary font-bold">+ ตัวเลือกย่อย</button>
          </div>
        </div>
        <button @click="addOpt(f.key)" class="text-sm text-primary font-bold">+ เพิ่มตัวเลือก</button>
      </section>

      <section class="glass-card p-4 space-y-3">
        <div class="flex items-center">
          <h2 class="flex-1 font-bold text-slate-700">คำถามเสริม <span class="text-xs font-normal text-slate-400">(แสดงต่อท้ายส่วนที่ 2 ก่อนข้อเสนอแนะ)</span></h2>
          <button @click="addExtra" class="text-sm text-primary font-bold">+ เพิ่มคำถาม</button>
        </div>
        <p v-if="!c.extra_questions.length" class="text-sm text-slate-400">ยังไม่มีคำถามเสริม</p>
        <div v-for="(q, i) in c.extra_questions" :key="q.key" class="border border-slate-200 rounded-xl p-3 space-y-2">
          <div class="flex flex-wrap gap-2 items-center">
            <input v-model="q.label" :class="[inputCls, 'flex-1 !w-auto min-w-[12rem]']" placeholder="คำถาม"/>
            <select v-model="q.type" class="px-2 py-2 border rounded-lg text-sm">
              <option value="text">ข้อความสั้น</option>
              <option value="textarea">ข้อความยาว</option>
              <option value="choice">เลือกข้อเดียว</option>
              <option value="multi">เลือกหลายข้อ</option>
            </select>
            <label class="text-xs flex items-center gap-1"><input type="checkbox" v-model="q.required"/> บังคับตอบ</label>
            <button @click="removeExtra(i)" class="px-2 text-red-400">✕</button>
          </div>
          <template v-if="['choice', 'multi'].includes(q.type)">
            <textarea :value="(q.options || []).join('\n')" @change="setExtraOptions(q, $event.target.value)" rows="3" :class="inputCls" placeholder="ตัวเลือก บรรทัดละ 1 ตัว"/>
            <label v-if="q.type === 'multi'" class="text-xs flex items-center gap-1">เลือกได้สูงสุด
              <input type="number" min="0" v-model.number="q.max" class="w-16 px-2 py-1 border rounded"/> ข้อ (0 = ไม่จำกัด)
            </label>
          </template>
        </div>
      </section>

      <div class="sticky bottom-3 flex items-center gap-3 glass-card p-3">
        <button @click="save" :disabled="saving" class="px-6 py-2.5 rounded-xl bg-primary text-white font-bold disabled:opacity-50">
          {{ saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า' }}
        </button>
        <span v-if="msg" class="text-sm text-emerald-600 font-bold">✓ {{ msg }}</span>
        <span v-if="err" class="text-sm text-red-600 font-bold">{{ err }}</span>
      </div>
    </template>
    <p v-else class="text-red-600">{{ err }}</p>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
