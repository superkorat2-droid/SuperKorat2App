<script setup>
/**
 * ทำเนียบครู (หลังบ้าน) — ศน./เจ้าหน้าที่/แอดมิน เห็นข้อมูลครบทุกช่อง (RLS ของ teachers คุมอีกชั้น)
 *   แท็บ "รายชื่อ"  : กรอง/ค้น · รายละเอียดรายคน · ออกลิงก์แก้ไขใหม่ · (แอดมิน) ซ่อน/ลบ · Excel
 *   แท็บ "ภาพรวม"  : สรุปเพื่อวางแผนนิเทศ + โรงเรียนที่ยังไม่มีครูตอบ
 *
 * ⚠️ PostgREST ส่งได้ครั้งละ 1,000 แถว (max_rows) — ครูทั้งเขต ~2,000 คน ต้องดึงเป็นหน้า ๆ
 */
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import { telHref } from '../../composables/useMapLink'
import {
  useTeacherSurveyConfig, leafOptions, labelOf, labelsOf, fullName, initialsOf, editLinkOf,
} from '../../composables/useTeacherSurvey'

const { config: cfg, fetchConfig } = useTeacherSurveyConfig()

const rows    = ref([])
const schools = ref([])
const loading = ref(true)
const loadErr = ref('')
const isAdmin = ref(false)
const tab     = ref('list')

const q        = ref('')
const district = ref('')
const group    = ref('')
const network  = ref('')
const grade    = ref('')
const rank     = ref('')
const major    = ref('')
const topic    = ref('')
const showHidden = ref(false)

const SELECT = '*, schools(id, name, district, school_group)'

async function fetchAll() {
  const out = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await supabase.from('teachers').select(SELECT)
      .order('submitted_at', { ascending: true }).range(from, from + 999)
    if (error) throw error
    out.push(...data)
    if (data.length < 1000) break
  }
  return out.map(t => ({ ...t, school: t.schools || {} }))
}

onMounted(async () => {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      const { data: me } = await supabase.from('profiles').select('role').eq('id', user.id).single()
      isAdmin.value = ['super_admin', 'admin'].includes(me?.role)
    }
    const [, list, sch] = await Promise.all([
      fetchConfig(true),
      fetchAll(),
      supabase.from('schools').select('id, name, district, school_group').eq('is_active', true),
    ])
    rows.value = list
    schools.value = sch.data || []
  } catch (e) {
    loadErr.value = e.message || 'โหลดข้อมูลไม่สำเร็จ'
  } finally {
    loading.value = false
  }
})

const opts = computed(() => cfg.value?.options || {})
const districts = computed(() => [...new Set(schools.value.map(s => s.district).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
const groups = computed(() => [...new Set(schools.value
  .filter(s => !district.value || s.district === district.value)
  .map(s => s.school_group).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))

const norm = s => (s || '').replace(/\s+/g, '')
const filtered = computed(() => {
  const qq = norm(q.value)
  const digits = q.value.replace(/\D/g, '')
  return rows.value.filter(t =>
    (showHidden.value || !t.is_hidden) &&
    (!district.value || t.school.district === district.value) &&
    (!group.value    || t.school.school_group === group.value) &&
    (!network.value  || t.networks.includes(network.value)) &&
    (!grade.value    || t.grades.includes(grade.value)) &&
    (!rank.value     || t.academic_rank === rank.value) &&
    (!major.value    || t.major_match === major.value) &&
    (!topic.value    || t.topics.includes(topic.value)) &&
    (!qq || norm(fullName(t) + t.school.name).includes(qq) || (digits.length >= 3 && t.phone.includes(digits)))
  ).sort((a, b) =>
    (a.school.district || '').localeCompare(b.school.district || '', 'th') ||
    (a.school.school_group || '').localeCompare(b.school.school_group || '', 'th') ||
    (a.school.name || '').localeCompare(b.school.name || '', 'th') ||
    a.first_name.localeCompare(b.first_name, 'th'))
})
const isFiltered = computed(() => !!(q.value || district.value || group.value || network.value || grade.value || rank.value || major.value || topic.value))
function reset() { q.value = district.value = group.value = network.value = grade.value = rank.value = major.value = topic.value = '' }
function onDistrictChange() { group.value = '' }

// ── รายละเอียด / การจัดการ ─────────────────────────────────────────────
const detail   = ref(null)
const newLink  = ref('')
const busy     = ref(false)
const copiedLink = ref(false)

function openDetail(t) { detail.value = t; newLink.value = ''; copiedLink.value = false }
function onKey(e) { if (e.key === 'Escape') detail.value = null }
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))

async function reissue() {
  if (!window.confirm(`ออกลิงก์แก้ไขใหม่ให้ ${fullName(detail.value)}?\nลิงก์เดิมที่ครูมีอยู่จะใช้ไม่ได้ทันที`)) return
  busy.value = true
  const { data, error } = await supabase.rpc('teacher_reissue_edit_token', { p_teacher: detail.value.id })
  busy.value = false
  if (error) { window.alert(error.message); return }
  newLink.value = editLinkOf(data)
}
async function copyNewLink() {
  try { await navigator.clipboard.writeText(newLink.value); copiedLink.value = true } catch { window.prompt('คัดลอกลิงก์', newLink.value) }
}

async function toggleHidden() {
  const t = detail.value
  busy.value = true
  const { error } = await supabase.from('teachers').update({ is_hidden: !t.is_hidden }).eq('id', t.id)
  busy.value = false
  if (error) { window.alert(error.message); return }
  t.is_hidden = !t.is_hidden
}

async function remove() {
  const t = detail.value
  if (!window.confirm(`ลบข้อมูล ${fullName(t)} ออกจากทำเนียบถาวร?\n(ถ้าแค่ไม่อยากให้แสดงสาธารณะ ใช้ "ซ่อน" แทน)`)) return
  busy.value = true
  const { error } = await supabase.from('teachers').delete().eq('id', t.id)
  busy.value = false
  if (error) { window.alert(error.message); return }
  rows.value = rows.value.filter(r => r.id !== t.id)
  detail.value = null
}

function otherText(t, field) { return t[`${field}_other`] ? ` (${t[`${field}_other`]})` : '' }
function listText(t, field) {
  return labelsOf(cfg.value, field, t[field]).join(', ') + otherText(t, field)
}
function extraText(v) { return Array.isArray(v) ? v.join(', ') : (v ?? '') }
const extras = computed(() => Array.isArray(cfg.value?.extra_questions) ? cfg.value.extra_questions : [])

// ── Excel ───────────────────────────────────────────────────────────────
const exporting = ref(false)
async function exportExcel() {
  exporting.value = true
  try {
    const { utils, writeFile } = await import('xlsx')
    const data = filtered.value.map((t, i) => {
      const row = {
        'ลำดับ': i + 1,
        'คำนำหน้า': t.prefix, 'ชื่อ': t.first_name, 'นามสกุล': t.last_name,
        'โรงเรียน': t.school.name, 'อำเภอ': t.school.district, 'ศูนย์เครือข่าย': t.school.school_group,
        'เบอร์โทร': t.phone, 'Line': t.line_id || '', 'อีเมล': t.email || '',
        'ระดับชั้นที่สอน': labelsOf(cfg.value, 'grades', t.grades).join(', '),
        'ปริญญาตรี': t.degree_ba || '', 'ปริญญาโท': t.degree_ma || '', 'ปริญญาเอก': t.degree_phd || '',
        'วิทยฐานะ': labelOf(cfg.value, 'ranks', t.academic_rank),
        'ลักษณะการสอน': t.major_match ? labelOf(cfg.value, 'major_match', t.major_match) : '',
        'เครือข่ายที่สนใจ': listText(t, 'networks'),
        'ข้อจำกัดของสถานศึกษา': listText(t, 'constraints'),
        'ประเด็นที่ต้องการพัฒนา': listText(t, 'topics'),
      }
      for (const x of extras.value) row[x.label] = extraText(t.extra?.[x.key])
      row['ข้อเสนอแนะ'] = t.suggestion || ''
      row['มีรูป'] = t.photo_url ? 'มี' : ''
      row['ซ่อนจากสาธารณะ'] = t.is_hidden ? 'ซ่อน' : ''
      row['ส่งเมื่อ'] = new Date(t.submitted_at).toLocaleString('th-TH')
      return row
    })
    const wb = utils.book_new()
    utils.book_append_sheet(wb, utils.json_to_sheet(data), 'ทำเนียบครู')
    utils.book_append_sheet(wb, utils.json_to_sheet(summaryRows('networks', 'เครือข่าย')), 'สรุปเครือข่าย')
    utils.book_append_sheet(wb, utils.json_to_sheet(summaryRows('topics', 'ประเด็นพัฒนา')), 'สรุปประเด็นพัฒนา')
    utils.book_append_sheet(wb, utils.json_to_sheet(coverageRows.value), 'รายโรงเรียน')
    writeFile(wb, `ทำเนียบครู_${new Date().toISOString().slice(0, 10)}.xlsx`)
  } finally {
    exporting.value = false
  }
}

// ── ภาพรวม (คำนวณจาก filtered → กรองอำเภอ/ศูนย์แล้วสรุปเฉพาะพื้นที่นั้นได้) ──
function countBy(field, isArray = true) {
  const opts = leafOptions(cfg.value?.options?.[field === 'academic_rank' ? 'ranks' : field])
  const n = filtered.value.length || 1
  return opts.map(o => {
    const c = filtered.value.filter(t => isArray ? t[field].includes(o.key) : t[field] === o.key).length
    return { key: o.key, label: o.label, count: c, pct: Math.round((c / n) * 100) }
  }).sort((a, b) => b.count - a.count)
}
const stats = computed(() => ({
  networks:    countBy('networks'),
  topics:      countBy('topics'),
  constraints: countBy('constraints'),
  ranks:       countBy('academic_rank', false),
  major:       leafOptions(cfg.value?.options?.major_match).map(o => {
    const c = filtered.value.filter(t => t.major_match === o.key).length
    return { key: o.key, label: o.label, count: c, pct: Math.round((c / (filtered.value.length || 1)) * 100) }
  }),
  grades:      countBy('grades'),
}))
function summaryRows(field, title) {
  return stats.value[field].map(s => ({ [title]: s.label, 'จำนวนครู': s.count, 'ร้อยละ': s.pct }))
}

// ความครอบคลุมรายโรงเรียน (ตามตัวกรองอำเภอ/ศูนย์เท่านั้น)
const coverage = computed(() => {
  const byS = new Map()
  for (const t of rows.value) if (t.school_id) byS.set(t.school_id, (byS.get(t.school_id) || 0) + 1)
  return schools.value
    .filter(s => (!district.value || s.district === district.value) && (!group.value || s.school_group === group.value))
    .map(s => ({ ...s, count: byS.get(s.id) || 0 }))
    .sort((a, b) => a.count - b.count || (a.district || '').localeCompare(b.district || '', 'th') || a.name.localeCompare(b.name, 'th'))
})
const coverageRows = computed(() => coverage.value.map(s => ({
  'โรงเรียน': s.name, 'อำเภอ': s.district, 'ศูนย์เครือข่าย': s.school_group, 'จำนวนครูที่ตอบ': s.count,
})))
const schoolsZero = computed(() => coverage.value.filter(s => s.count === 0))

const selCls = 'px-3 py-2 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-0'
</script>

<template>
  <div class="space-y-4 font-sarabun">
    <div class="flex flex-wrap items-center gap-3">
      <div class="flex-1 min-w-0">
        <div role="heading" aria-level="1" class="text-xl font-extrabold text-slate-800">ทำเนียบครู · เครือข่ายวิชาชีพ</div>
        <div class="text-xs text-slate-500">ข้อมูลจากแบบสำรวจ · ทั้งหมด {{ rows.length.toLocaleString() }} คน</div>
      </div>
      <a href="#/teacher-survey" target="_blank" class="px-3 py-2 rounded-xl bg-white/70 border border-slate-200 text-sm text-primary font-bold">🔗 ลิงก์แบบสำรวจ</a>
      <router-link v-if="isAdmin" to="/dashboard/teachers/settings" class="px-3 py-2 rounded-xl bg-white/70 border border-slate-200 text-sm font-bold text-slate-600">⚙️ ตั้งค่าแบบสำรวจ</router-link>
      <button @click="exportExcel" :disabled="exporting || !filtered.length"
        class="px-3 py-2 rounded-xl bg-emerald-600 text-white text-sm font-bold disabled:opacity-50">
        {{ exporting ? 'กำลังสร้าง...' : `⬇ Excel (${filtered.length})` }}
      </button>
    </div>

    <div class="flex gap-1 bg-white/50 p-1 rounded-xl w-fit">
      <button v-for="t in [{ k: 'list', l: 'รายชื่อ' }, { k: 'summary', l: 'ภาพรวม / วางแผนนิเทศ' }]" :key="t.k"
        @click="tab = t.k"
        :class="['px-4 py-1.5 rounded-lg text-sm font-bold', tab === t.k ? 'bg-primary text-white shadow' : 'text-slate-600']">
        {{ t.l }}
      </button>
    </div>

    <!-- ตัวกรอง (ใช้ร่วมกันทั้งสองแท็บ) -->
    <div class="glass-card p-3 space-y-2">
      <input :value="q" @input="q = $event.target.value" type="search" placeholder="ค้นชื่อ โรงเรียน หรือเบอร์โทร..." :class="[selCls, 'w-full']"/>
      <div class="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-8 gap-2">
        <select v-model="district" @change="onDistrictChange" :class="selCls">
          <option value="">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="group" :class="selCls">
          <option value="">ทุกศูนย์</option>
          <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="network" :class="selCls">
          <option value="">ทุกเครือข่าย</option>
          <option v-for="o in leafOptions(opts.networks)" :key="o.key" :value="o.key">{{ o.label.replace('เครือข่ายครู', '') }}</option>
        </select>
        <select v-model="grade" :class="selCls">
          <option value="">ทุกชั้น</option>
          <option v-for="o in opts.grades" :key="o.key" :value="o.key">{{ o.label }}</option>
        </select>
        <select v-model="rank" :class="selCls">
          <option value="">ทุกวิทยฐานะ</option>
          <option v-for="o in opts.ranks" :key="o.key" :value="o.key">{{ o.label }}</option>
        </select>
        <select v-model="major" :class="selCls">
          <option value="">ตรง/ไม่ตรงเอก ทั้งหมด</option>
          <option v-for="o in opts.major_match" :key="o.key" :value="o.key">{{ o.label }}</option>
        </select>
        <select v-model="topic" :class="[selCls, 'col-span-2']">
          <option value="">ทุกประเด็นพัฒนา</option>
          <option v-for="o in leafOptions(opts.topics)" :key="o.key" :value="o.key">{{ o.label }}</option>
        </select>
      </div>
      <div class="flex flex-wrap items-center gap-3 text-xs">
        <span class="font-bold text-primary">พบ {{ filtered.length.toLocaleString() }} คน</span>
        <label class="flex items-center gap-1 text-slate-500"><input type="checkbox" v-model="showHidden"/> รวมที่ซ่อนไว้</label>
        <button v-if="isFiltered" @click="reset" class="text-slate-400 hover:text-red-500">✕ ล้างตัวกรอง</button>
      </div>
    </div>

    <div v-if="loading" class="glass-card p-10 text-center text-slate-400 animate-pulse">กำลังโหลด...</div>
    <div v-else-if="loadErr" class="glass-card p-6 text-center text-red-600">{{ loadErr }}</div>

    <!-- ═══ รายชื่อ ═══ -->
    <template v-else-if="tab === 'list'">
      <div v-if="!filtered.length" class="glass-card p-10 text-center text-slate-400">ไม่พบข้อมูล</div>
      <div v-else class="grid grid-cols-[minmax(0,1fr)] sm:grid-cols-2 xl:grid-cols-3 gap-3">
        <button v-for="t in filtered" :key="t.id" @click="openDetail(t)"
          :class="['glass-tile p-3 flex gap-3 items-start text-left hover:shadow-md transition', t.is_hidden ? 'opacity-50' : '']">
          <div class="w-12 h-12 rounded-full overflow-hidden bg-slate-100 flex items-center justify-center shrink-0">
            <img v-if="t.photo_url" :src="t.photo_url" loading="lazy" class="w-full h-full object-cover" alt=""/>
            <span v-else class="text-sm font-bold text-primary">{{ initialsOf(t) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="font-bold text-sm text-slate-800 truncate">{{ fullName(t) }} <span v-if="t.is_hidden" class="text-[10px] text-red-500">(ซ่อน)</span></div>
            <div class="text-[11px] text-slate-500 truncate">{{ t.school.name }} · {{ t.school.school_group }}</div>
            <div class="text-[11px] text-slate-500">{{ labelOf(cfg, 'ranks', t.academic_rank) }}</div>
            <div class="flex flex-wrap gap-1 mt-1">
              <span v-for="n in t.networks" :key="n" class="text-[10px] bg-indigo-50 text-indigo-700 font-bold px-2 py-0.5 rounded-full">
                {{ labelOf(cfg, 'networks', n).replace('เครือข่ายครู', '') }}
              </span>
            </div>
          </div>
          <a :href="`tel:${telHref(t.phone)}`" @click.stop class="text-xs text-primary font-bold whitespace-nowrap">📞 {{ t.phone }}</a>
        </button>
      </div>
    </template>

    <!-- ═══ ภาพรวม ═══ -->
    <template v-else>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="glass-tile p-4 text-center"><div class="text-2xl font-extrabold text-primary">{{ filtered.length.toLocaleString() }}</div><div class="text-xs text-slate-500">ครูที่ตอบ</div></div>
        <div class="glass-tile p-4 text-center"><div class="text-2xl font-extrabold text-emerald-600">{{ coverage.length - schoolsZero.length }}</div><div class="text-xs text-slate-500">โรงเรียนที่มีครูตอบ</div></div>
        <div class="glass-tile p-4 text-center"><div class="text-2xl font-extrabold text-red-500">{{ schoolsZero.length }}</div><div class="text-xs text-slate-500">โรงเรียนยังไม่มีครูตอบ</div></div>
        <div class="glass-tile p-4 text-center"><div class="text-2xl font-extrabold text-amber-600">{{ stats.major.find(m => m.key === 'mismatch')?.pct ?? 0 }}%</div><div class="text-xs text-slate-500">สอนไม่ตรงเอก</div></div>
      </div>

      <div class="grid grid-cols-[minmax(0,1fr)] lg:grid-cols-2 gap-4">
        <div v-for="blk in [
               { k: 'networks',    t: 'เครือข่ายที่ครูสนใจ',             c: 'bg-indigo-500' },
               { k: 'topics',      t: 'ประเด็นที่ต้องการพัฒนา',          c: 'bg-emerald-500' },
               { k: 'constraints', t: 'ข้อจำกัดของสถานศึกษา',            c: 'bg-amber-500' },
               { k: 'ranks',       t: 'วิทยฐานะ',                        c: 'bg-sky-500' },
               { k: 'major',       t: 'ลักษณะการสอนเทียบกับวิชาเอก',     c: 'bg-rose-500' },
               { k: 'grades',      t: 'ระดับชั้นที่สอน',                  c: 'bg-violet-500' },
             ]" :key="blk.k" class="glass-card p-4">
          <div role="heading" aria-level="3" class="font-bold text-slate-700 mb-3">{{ blk.t }}</div>
          <div class="space-y-2">
            <div v-for="s in stats[blk.k]" :key="s.key" class="text-xs">
              <div class="flex justify-between gap-2 mb-0.5">
                <span class="text-slate-600 line-clamp-1">{{ s.label }}</span>
                <span class="font-bold text-slate-700 whitespace-nowrap">{{ s.count }} ({{ s.pct }}%)</span>
              </div>
              <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                <div :class="['h-full rounded-full', blk.c]" :style="{ width: `${s.pct}%` }"/>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="glass-card p-4">
        <div role="heading" aria-level="3" class="font-bold text-slate-700 mb-1">โรงเรียนที่ยังไม่มีครูตอบ ({{ schoolsZero.length }})</div>
        <div class="text-xs text-slate-500 mb-3">ใช้ติดตามให้ครบทุกโรงเรียน · กรองตามอำเภอ/ศูนย์ด้านบนได้</div>
        <div v-if="!schoolsZero.length" class="text-sm text-emerald-600 font-bold">✓ ครบทุกโรงเรียนแล้ว</div>
        <div v-else class="grid grid-cols-[minmax(0,1fr)] sm:grid-cols-2 xl:grid-cols-3 gap-x-4 gap-y-1 text-sm">
          <div v-for="s in schoolsZero" :key="s.id" class="truncate text-slate-600">• {{ s.name }} <span class="text-[11px] text-slate-400">({{ s.school_group }})</span></div>
        </div>
      </div>
    </template>

    <!-- ═══ รายละเอียดรายคน ═══ -->
    <div v-if="detail" class="fixed inset-0 z-50 bg-black/40 flex items-end sm:items-center justify-center p-0 sm:p-4" @click.self="detail = null">
      <div class="bg-white w-full sm:max-w-2xl max-h-[92vh] overflow-y-auto rounded-t-2xl sm:rounded-2xl p-5 space-y-4">
        <div class="flex gap-4 items-center">
          <div class="w-20 h-20 rounded-full overflow-hidden bg-slate-100 flex items-center justify-center shrink-0">
            <img v-if="detail.photo_url" :src="detail.photo_url" class="w-full h-full object-cover" alt=""/>
            <span v-else class="text-xl font-bold text-primary">{{ initialsOf(detail) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div role="heading" aria-level="2" class="text-lg font-extrabold text-slate-800">{{ fullName(detail) }}</div>
            <div class="text-sm text-slate-500">{{ detail.school.name }}</div>
            <div class="text-xs text-slate-400">อ.{{ detail.school.district }} · {{ detail.school.school_group }}</div>
          </div>
          <button @click="detail = null" class="text-2xl text-slate-400 self-start">×</button>
        </div>

        <div class="flex flex-wrap gap-2 text-sm">
          <a :href="`tel:${telHref(detail.phone)}`" class="px-3 py-1.5 rounded-lg bg-primary text-white font-bold">📞 {{ detail.phone }}</a>
          <span v-if="detail.line_id" class="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 font-bold">LINE: {{ detail.line_id }}</span>
          <a v-if="detail.email" :href="`mailto:${detail.email}`" class="px-3 py-1.5 rounded-lg bg-slate-100 text-slate-700">✉️ {{ detail.email }}</a>
        </div>

        <dl class="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-2 text-sm">
          <dt class="text-slate-500">ระดับชั้นที่สอน</dt><dd>{{ labelsOf(cfg, 'grades', detail.grades).join(', ') }}</dd>
          <dt class="text-slate-500">วุฒิการศึกษา</dt>
          <dd>
            <div v-if="detail.degree_ba">ตรี: {{ detail.degree_ba }}</div>
            <div v-if="detail.degree_ma">โท: {{ detail.degree_ma }}</div>
            <div v-if="detail.degree_phd">เอก: {{ detail.degree_phd }}</div>
            <span v-if="!detail.degree_ba && !detail.degree_ma && !detail.degree_phd" class="text-slate-400">–</span>
          </dd>
          <dt class="text-slate-500">วิทยฐานะ</dt><dd>{{ labelOf(cfg, 'ranks', detail.academic_rank) }}</dd>
          <dt class="text-slate-500">ลักษณะการสอน</dt><dd>{{ detail.major_match ? labelOf(cfg, 'major_match', detail.major_match) : '–' }}</dd>
          <dt class="text-slate-500">เครือข่ายที่สนใจ</dt><dd>{{ listText(detail, 'networks') }}</dd>
          <dt class="text-slate-500">ข้อจำกัด</dt><dd>{{ listText(detail, 'constraints') || '–' }}</dd>
          <dt class="text-slate-500">ประเด็นพัฒนา</dt><dd>{{ listText(detail, 'topics') || '–' }}</dd>
          <template v-for="x in extras" :key="x.key">
            <dt class="text-slate-500">{{ x.label }}</dt><dd>{{ extraText(detail.extra?.[x.key]) || '–' }}</dd>
          </template>
          <dt class="text-slate-500">ข้อเสนอแนะ</dt><dd class="whitespace-pre-line">{{ detail.suggestion || '–' }}</dd>
          <dt class="text-slate-500">ส่งเมื่อ</dt><dd class="text-xs">{{ new Date(detail.submitted_at).toLocaleString('th-TH') }} · แก้ล่าสุด {{ new Date(detail.updated_at).toLocaleString('th-TH') }}</dd>
        </dl>

        <div class="border-t pt-4 space-y-3">
          <div v-if="newLink" class="bg-amber-50 border border-amber-200 rounded-xl p-3 space-y-2">
            <div class="text-xs font-bold text-amber-800">ลิงก์แก้ไขใหม่ — ส่งให้ครูทาง LINE (ลิงก์เดิมใช้ไม่ได้แล้ว)</div>
            <div class="flex gap-2">
              <input :value="newLink" readonly class="flex-1 min-w-0 px-2 py-1.5 text-xs border rounded-lg" @focus="$event.target.select()"/>
              <button @click="copyNewLink" class="px-3 py-1.5 text-xs font-bold rounded-lg bg-amber-500 text-white">{{ copiedLink ? '✓' : 'คัดลอก' }}</button>
            </div>
          </div>
          <div class="flex flex-wrap gap-2">
            <button @click="reissue" :disabled="busy" class="px-3 py-2 rounded-lg bg-amber-100 text-amber-800 text-sm font-bold disabled:opacity-50">🔑 ออกลิงก์แก้ไขใหม่</button>
            <template v-if="isAdmin">
              <button @click="toggleHidden" :disabled="busy" class="px-3 py-2 rounded-lg bg-slate-100 text-slate-700 text-sm font-bold disabled:opacity-50">
                {{ detail.is_hidden ? '👁 แสดงในทำเนียบสาธารณะ' : '🙈 ซ่อนจากทำเนียบสาธารณะ' }}
              </button>
              <button @click="remove" :disabled="busy" class="px-3 py-2 rounded-lg text-red-600 hover:bg-red-50 text-sm font-bold disabled:opacity-50">ลบ</button>
            </template>
          </div>
          <div class="text-[11px] text-slate-400">ต้องการแก้คำตอบแทนครู: ออกลิงก์ใหม่แล้วเปิดลิงก์นั้นเอง (จากนั้นส่งลิงก์ให้ครูเก็บไว้)</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
