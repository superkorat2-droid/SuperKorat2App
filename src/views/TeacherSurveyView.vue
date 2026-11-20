<script setup>
/**
 * แบบสำรวจเครือข่ายวิชาชีพครู (สาธารณะ ไม่ต้องล็อกอิน)
 *   /teacher-survey              → ส่งครั้งแรก
 *   /teacher-survey/edit/:token  → แก้ไขข้อมูลตัวเองด้วยลิงก์ส่วนตัว (+ เพิ่ม/เปลี่ยนรูปโปรไฟล์)
 *
 * ทุกอย่างตรวจซ้ำที่ server (_teacher_clean ใน migration 0104) — ฝั่งนี้ตรวจเพื่อ UX เท่านั้น
 */
import { ref, computed, onMounted, watch, defineAsyncComponent } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { uploadTeacherPhoto } from '../composables/useExternalUpload'
import {
  useTeacherSurveyConfig, isSurveyOpen, leafOptions, PREFIXES, fullName, initialsOf,
  rememberToken, recallToken, forgetToken, editLinkOf,
} from '../composables/useTeacherSurvey'
import SchoolPicker from '../components/supervision/SchoolPicker.vue'
import TsIcon from '../components/teachers/TsIcon.vue'

const ImageCropperModal = defineAsyncComponent(() => import('../components/ImageCropperModal.vue'))

const route  = useRoute()
const router = useRouter()
const { config: area, fetchConfig: fetchArea } = useAreaConfig()
const { config: cfg, fetchConfig } = useTeacherSurveyConfig()

const token    = computed(() => String(route.params.token || ''))
const isEdit   = computed(() => !!token.value)
const loading  = ref(true)
const loadErr  = ref('')
const schools  = ref([])
const saving   = ref(false)
const errMsg   = ref('')
const done     = ref(null)        // { token } หลังส่งครั้งแรกสำเร็จ
const savedOk  = ref(false)       // แก้ไขสำเร็จ (โหมดแก้ไข)
const copied   = ref(false)
const savedToken = ref(recallToken())

function emptyForm() {
  return {
    prefix: '', first_name: '', last_name: '', school_id: null,
    phone: '', line_id: '', email: '',
    grades: [], degree_ba: '', degree_ma: '', degree_phd: '',
    academic_rank: '', major_match: '',
    networks: [], networks_other: '',
    constraints: [], constraints_other: '',
    topics: [], topics_other: '',
    suggestion: '', extra: {},
  }
}
const form = ref(emptyForm())
const photoUrl = ref('')
const customPrefix = ref(false)

const opts   = computed(() => cfg.value?.options || {})
const limits = computed(() => cfg.value?.limits || {})
const extras = computed(() => Array.isArray(cfg.value?.extra_questions) ? cfg.value.extra_questions : [])
const open   = computed(() => isSurveyOpen(cfg.value))

const selectedSchool = computed(() => schools.value.find(s => s.id === form.value.school_id))

// ชื่อสำนักงานเต็ม — สูตรเดียวกับหน้ากรอกแบบนิเทศ (area_name คือชื่อกลุ่มนิเทศ ไม่ใช่ชื่อเขต)
const officeName = computed(() => {
  const a = area.value || {}
  if (a.tagline?.trim()) return a.tagline.trim()
  if (a.province) return `${a.area_type || 'สพป.'}${a.province}${a.area_number ? ` เขต ${a.area_number}` : ''}`
  return a.area_name || ''
})

onMounted(async () => {
  try {
    const [, , sch] = await Promise.all([
      fetchArea(),
      fetchConfig(true),
      supabase.rpc('get_schools_public'),
    ])
    schools.value = sch.data || []

    if (isEdit.value) await loadMine()
  } catch (e) {
    loadErr.value = e.message || 'โหลดข้อมูลไม่สำเร็จ'
  } finally {
    loading.value = false
  }
})

// เปลี่ยนจากหน้าส่งใหม่ → หน้าแก้ไข (router.replace หลังส่งสำเร็จ) ให้โหลดข้อมูลใหม่
watch(token, async (t) => { if (t) { loading.value = true; await loadMine(); loading.value = false } })

async function loadMine() {
  loadErr.value = ''
  const { data, error } = await supabase.rpc('teacher_survey_load', { p_token: token.value })
  if (error) { loadErr.value = error.message; return }
  if (!data) {
    loadErr.value = 'ลิงก์แก้ไขไม่ถูกต้อง หรือถูกออกลิงก์ใหม่แทนแล้ว กรุณาติดต่อศึกษานิเทศก์เพื่อขอลิงก์ใหม่'
    if (recallToken() === token.value) forgetToken()
    return
  }
  // ⚠️ ไม่ใช้ {...emptyForm(), ...data} — ค่า null จาก DB จะทับค่าว่างเริ่มต้น (บทเรียนข่าว 0065)
  const f = emptyForm()
  for (const k of Object.keys(f)) {
    if (data[k] !== null && data[k] !== undefined) f[k] = data[k]
  }
  form.value = f
  customPrefix.value = !!f.prefix && !PREFIXES.includes(f.prefix)
  photoUrl.value = data.photo_url || ''
  rememberToken(token.value)
  savedToken.value = token.value
}

// ── ตัวเลือกหลายข้อ + จำกัดจำนวน ─────────────────────────────────────────
function isChecked(field, key) { return form.value[field].includes(key) }
function atLimit(field) {
  const max = Number(limits.value[field] || 0)
  return max > 0 && form.value[field].length >= max
}
function toggle(field, key) {
  const arr = form.value[field]
  const i = arr.indexOf(key)
  if (i >= 0) { arr.splice(i, 1); return }
  if (atLimit(field)) return
  arr.push(key)
}
function hasOther(field) {
  const otherKeys = leafOptions(opts.value[field]).filter(o => o.is_other).map(o => o.key)
  return form.value[field].some(k => otherKeys.includes(k))
}

// คำถามเสริม (แอดมินเพิ่มเอง)
function extraToggle(q, value) {
  const cur = Array.isArray(form.value.extra[q.key]) ? [...form.value.extra[q.key]] : []
  const i = cur.indexOf(value)
  if (i >= 0) cur.splice(i, 1)
  else if (!(q.max > 0 && cur.length >= q.max)) cur.push(value)
  form.value.extra = { ...form.value.extra, [q.key]: cur }
}
function extraChecked(q, value) {
  return Array.isArray(form.value.extra[q.key]) && form.value.extra[q.key].includes(value)
}
function setExtra(key, value) {
  form.value.extra = { ...form.value.extra, [key]: value }
}

function onPrefixSelect(e) {
  const v = e.target.value
  customPrefix.value = v === '__other'
  form.value.prefix = customPrefix.value ? '' : v
}

// ── ตรวจก่อนส่ง (ข้อความเดียวกับ server) ─────────────────────────────────
function validate() {
  const f = form.value
  if (!f.prefix.trim() || !f.first_name.trim() || !f.last_name.trim()) return 'กรุณากรอกคำนำหน้า ชื่อ และนามสกุลให้ครบ'
  if (!f.school_id) return 'กรุณาเลือกโรงเรียน'
  if (!/^0\d{8,9}$/.test(f.phone.replace(/\D/g, ''))) return 'เบอร์โทรศัพท์ไม่ถูกต้อง (ตัวเลข 9-10 หลัก ขึ้นต้นด้วย 0)'
  if (f.email.trim() && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email.trim())) return 'รูปแบบอีเมลไม่ถูกต้อง'
  if (!f.grades.length) return 'กรุณาเลือกระดับชั้นที่รับผิดชอบการสอนอย่างน้อย 1 ข้อ'
  if (!f.academic_rank) return 'กรุณาเลือกวิทยฐานะปัจจุบัน'
  if (!f.networks.length) return 'กรุณาเลือกเครือข่ายที่สนใจอย่างน้อย 1 เครือข่าย'
  for (const [field, label] of [['networks', 'เครือข่ายที่สนใจ'], ['constraints', 'สภาพความพร้อมและข้อจำกัด'], ['topics', 'ประเด็นที่ต้องการพัฒนา']]) {
    if (hasOther(field) && !f[`${field}_other`].trim()) return `กรุณาระบุรายละเอียด "อื่น ๆ" ในข้อ "${label}"`
  }
  for (const q of extras.value) {
    const v = f.extra[q.key]
    if (q.required && (v === undefined || v === '' || (Array.isArray(v) && !v.length))) return `กรุณาตอบข้อ "${q.label}"`
  }
  return ''
}

const ERR_TEXT = {
  phone_exists: 'เบอร์โทรศัพท์นี้ลงทะเบียนไว้แล้ว — ถ้าเป็นของท่าน กรุณาใช้ลิงก์แก้ไขที่ได้รับตอนส่งครั้งแรก หรือติดต่อศึกษานิเทศก์เพื่อขอลิงก์ใหม่',
  closed:       'ขณะนี้ปิดรับแบบสำรวจแล้ว',
  rate_limited: 'ส่งข้อมูลจากเครื่องนี้บ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่',
  invalid_token:'ลิงก์แก้ไขไม่ถูกต้อง กรุณาติดต่อศึกษานิเทศก์เพื่อขอลิงก์ใหม่',
}

async function submit() {
  errMsg.value = ''
  savedOk.value = false
  const v = validate()
  if (v) { errMsg.value = v; scrollToError(); return }

  saving.value = true
  try {
    const payload = { ...form.value, phone: form.value.phone.replace(/\D/g, '') }
    const { data, error } = isEdit.value
      ? await supabase.rpc('teacher_survey_update', { p_token: token.value, p_data: payload })
      : await supabase.rpc('teacher_survey_submit', { p_data: payload })
    if (error) throw error
    if (!data?.ok) { errMsg.value = ERR_TEXT[data?.error] || 'บันทึกไม่สำเร็จ'; scrollToError(); return }

    if (isEdit.value) {
      savedOk.value = true
      window.scrollTo({ top: 0, behavior: 'smooth' })
    } else {
      rememberToken(data.token)
      savedToken.value = data.token
      // ข้อมูลบันทึกแล้ว — รูปอัปไม่ผ่านก็ไม่ล้มทั้งหมด แจ้งให้เพิ่มทีหลังในหน้าแก้ไข
      let photoFailed = ''
      if (pendingPhoto.value) {
        try { await savePhoto(pendingPhoto.value.blob, data.token); pendingPhoto.value = null }
        catch (e) { photoFailed = e.message || 'อัปโหลดรูปไม่สำเร็จ' }
      }
      done.value = { token: data.token, photoFailed }
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  } catch (e) {
    errMsg.value = e.message || 'บันทึกไม่สำเร็จ'
    scrollToError()
  } finally {
    saving.value = false
  }
}

function scrollToError() {
  requestAnimationFrame(() => document.getElementById('survey-error')?.scrollIntoView({ behavior: 'smooth', block: 'center' }))
}

const doneLink = computed(() => done.value ? editLinkOf(done.value.token) : '')
async function copyLink(link) {
  try {
    await navigator.clipboard.writeText(link)
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch {
    window.prompt('คัดลอกลิงก์นี้เก็บไว้', link)
  }
}
function goEdit() {
  // ซ่อนฟอร์มทันที — ไม่งั้นช่วงรอ loadMine() ผู้ใช้พิมพ์ได้ แล้วโดนข้อมูลจาก DB ทับ
  loading.value = true
  router.replace(`/teacher-survey/edit/${done.value.token}`)
  done.value = null
}
function goSavedEdit() { router.push(`/teacher-survey/edit/${savedToken.value}`) }

// ── รูปโปรไฟล์ (ครอปสี่เหลี่ยม 256px ~20 KB → โฮสต์ PHP) ───────────────────
const showCropper = ref(false)
const photoBusy   = ref(false)
const photoErr    = ref('')
// ส่งครั้งแรกยังไม่มี token → เก็บรูปที่ครอปไว้ก่อน แล้วอัปทันทีหลังส่งสำเร็จ
const pendingPhoto = ref(null)    // { blob, dataUrl }
const photoPreview = computed(() => pendingPhoto.value?.dataUrl || photoUrl.value)

async function savePhoto(blob, tok) {
  const url = await uploadTeacherPhoto(blob, tok)
  const { data, error } = await supabase.rpc('teacher_survey_set_photo', { p_token: tok, p_url: url })
  if (error) throw error
  if (!data?.ok) throw new Error(ERR_TEXT[data?.error] || 'บันทึกรูปไม่สำเร็จ')
  return url
}

async function onCropped({ blob, dataUrl }) {
  showCropper.value = false
  photoErr.value = ''
  if (!isEdit.value) { pendingPhoto.value = { blob, dataUrl }; return }
  photoBusy.value = true
  try {
    photoUrl.value = await savePhoto(blob, token.value)
  } catch (e) {
    photoErr.value = e.message || 'อัปโหลดรูปไม่สำเร็จ'
  } finally {
    photoBusy.value = false
  }
}
async function removePhoto() {
  if (!isEdit.value) { pendingPhoto.value = null; return }
  if (!window.confirm('ลบรูปโปรไฟล์?')) return
  const { data } = await supabase.rpc('teacher_survey_set_photo', { p_token: token.value, p_url: null })
  if (data?.ok) photoUrl.value = ''
}

const inputCls = 'w-full px-4 py-3 border-2 border-slate-200 bg-white rounded-xl text-sm focus:outline-none focus:border-indigo-400 focus:ring-4 focus:ring-indigo-100 transition'

// ── สีประจำแต่ละข้อ (เขียนคลาสเต็มทุกตัว — Tailwind ตัดคลาสที่ประกอบสตริงทิ้งตอน build) ──
const CHIP = {
  indigo:  { on: 'bg-indigo-100 border-indigo-400 text-indigo-900',   hover: 'hover:border-indigo-300 hover:bg-indigo-50',   acc: 'accent-indigo-600',  badge: 'bg-indigo-500'  },
  sky:     { on: 'bg-sky-100 border-sky-400 text-sky-900',            hover: 'hover:border-sky-300 hover:bg-sky-50',         acc: 'accent-sky-600',     badge: 'bg-sky-500'     },
  violet:  { on: 'bg-violet-100 border-violet-400 text-violet-900',   hover: 'hover:border-violet-300 hover:bg-violet-50',   acc: 'accent-violet-600',  badge: 'bg-violet-500'  },
  teal:    { on: 'bg-teal-100 border-teal-400 text-teal-900',         hover: 'hover:border-teal-300 hover:bg-teal-50',       acc: 'accent-teal-600',    badge: 'bg-teal-500'    },
  emerald: { on: 'bg-emerald-100 border-emerald-400 text-emerald-900', hover: 'hover:border-emerald-300 hover:bg-emerald-50', acc: 'accent-emerald-600', badge: 'bg-emerald-500' },
  amber:   { on: 'bg-amber-100 border-amber-400 text-amber-900',      hover: 'hover:border-amber-300 hover:bg-amber-50',     acc: 'accent-amber-600',   badge: 'bg-amber-500'   },
  pink:    { on: 'bg-pink-100 border-pink-400 text-pink-900',         hover: 'hover:border-pink-300 hover:bg-pink-50',       acc: 'accent-pink-600',    badge: 'bg-pink-500'    },
  rose:    { on: 'bg-rose-100 border-rose-400 text-rose-900',         hover: 'hover:border-rose-300 hover:bg-rose-50',       acc: 'accent-rose-600',    badge: 'bg-rose-500'    },
}
function chip(color, on, disabled = false) {
  const c = CHIP[color]
  return ['flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl border-2 text-sm transition select-none',
    on ? `${c.on} font-semibold shadow-sm` : 'bg-white border-slate-200 text-slate-700',
    disabled ? 'opacity-40 cursor-not-allowed' : `cursor-pointer ${c.hover}`]
}
const PART2 = [
  { field: 'constraints', no: 9,  color: 'amber', title: 'สภาพความพร้อมและข้อจำกัดของสถานศึกษาในการจัดกิจกรรมการเรียนรู้' },
  { field: 'topics',      no: 10, color: 'pink',  title: 'ประเด็นที่ท่านต้องการพัฒนาหรือแลกเปลี่ยนเรียนรู้ในเครือข่ายมากที่สุด' },
]
</script>

<template>
  <div class="font-sarabun min-h-screen bg-gradient-to-br from-indigo-50 via-sky-50 to-emerald-50">
    <div class="max-w-3xl mx-auto px-4 py-6 space-y-5">

      <!-- ── หัวแบบสำรวจ ─────────────────────────────────────────────── -->
      <div class="relative overflow-hidden rounded-3xl p-6 sm:p-8 text-center text-white shadow-xl bg-gradient-to-br from-indigo-600 via-sky-500 to-emerald-400">
        <div class="absolute -top-10 -right-10 w-40 h-40 rounded-full bg-white/15"></div>
        <div class="absolute -bottom-12 -left-8 w-36 h-36 rounded-full bg-white/10"></div>
        <div class="relative mx-auto mb-3 w-14 h-14 rounded-2xl bg-white/20 ring-1 ring-white/40 flex items-center justify-center"><TsIcon name="users" class="w-8 h-8 text-white"/></div>
        <div role="heading" aria-level="1" class="relative text-xl sm:text-2xl font-extrabold leading-snug drop-shadow">
          {{ cfg?.title || 'การขับเคลื่อนระบบฐานข้อมูลพัฒนาเครือข่ายวิชาชีพครู' }}
        </div>
        <div class="relative text-sm font-bold text-white/90 mt-1">{{ officeName }}</div>
        <div v-if="isEdit && !loadErr" class="relative inline-block mt-3 text-xs font-bold bg-white text-indigo-700 px-3 py-1 rounded-full shadow">
          โหมดแก้ไขข้อมูลของ {{ fullName(form) || 'ท่าน' }}
        </div>
      </div>

      <div v-if="loading" class="glass-card p-10 text-center text-slate-400 animate-pulse">กำลังโหลด...</div>

      <div v-else-if="loadErr" class="glass-card p-6 text-center space-y-3">
        <div class="text-red-600 font-bold">{{ loadErr }}</div>
        <router-link to="/teacher-survey" class="text-sm text-primary hover:underline">ไปหน้าแบบสำรวจ</router-link>
      </div>

      <!-- ── ส่งสำเร็จ: ลิงก์แก้ไขส่วนตัว ─────────────────────────────── -->
      <div v-else-if="done" class="rounded-3xl bg-white shadow-xl p-6 space-y-4 text-center border-t-8 border-emerald-400">
        <div class="mx-auto w-16 h-16 rounded-full bg-emerald-100 flex items-center justify-center"><TsIcon name="check" class="w-10 h-10 text-emerald-600"/></div>
        <div role="heading" aria-level="2" class="text-lg font-extrabold text-emerald-700">ส่งแบบสำรวจเรียบร้อยแล้ว ขอบคุณครับ/ค่ะ</div>
        <div class="text-left bg-amber-50 border border-amber-200 rounded-xl p-4 space-y-2">
          <div class="text-sm font-bold text-amber-800 flex items-center gap-1.5"><TsIcon name="key" class="w-4 h-4 shrink-0"/>ลิงก์แก้ไขข้อมูลส่วนตัวของท่าน — กรุณาเก็บไว้</div>
          <div class="text-xs text-amber-700">ใช้ลิงก์นี้กลับมาแก้ไขข้อมูลหรือเพิ่มรูปโปรไฟล์ได้ตลอด (เครื่องนี้จำไว้ให้แล้ว แต่ถ้าเปลี่ยนเครื่องต้องใช้ลิงก์นี้)</div>
          <div class="flex flex-col sm:flex-row gap-2">
            <input :value="doneLink" readonly class="flex-1 min-w-0 px-3 py-2 text-xs border border-amber-200 rounded-lg bg-white" @focus="$event.target.select()"/>
            <button @click="copyLink(doneLink)" class="px-4 py-2 text-sm font-bold rounded-lg bg-amber-500 text-white hover:bg-amber-600">
              {{ copied ? '✓ คัดลอกแล้ว' : 'คัดลอกลิงก์' }}
            </button>
          </div>
        </div>
        <div v-if="done.photoFailed" class="text-sm text-red-600 bg-red-50 rounded-xl p-3">
          ข้อมูลบันทึกแล้ว แต่อัปโหลดรูปไม่สำเร็จ ({{ done.photoFailed }}) — กดปุ่มด้านล่างเพื่อเพิ่มรูปอีกครั้ง
        </div>
        <button @click="goEdit" class="w-full sm:w-auto px-6 py-3 rounded-xl bg-gradient-to-r from-indigo-500 to-sky-500 text-white font-bold shadow hover:opacity-90">
          <span class="inline-flex items-center gap-2"><TsIcon name="pencil" class="w-5 h-5"/>ตรวจทาน / แก้ไขข้อมูลและรูป</span>
        </button>
        <div><router-link to="/teachers" class="text-sm text-primary hover:underline">ดูทำเนียบครู</router-link></div>
      </div>

      <template v-else>
        <!-- เคยส่งจากเครื่องนี้แล้ว -->
        <div v-if="!isEdit && savedToken" class="glass-card p-4 flex flex-col sm:flex-row items-center gap-3 border-l-4 border-l-amber-400">
          <div class="flex-1 text-sm text-slate-700">เครื่องนี้เคยส่งแบบสำรวจไว้แล้ว ต้องการแก้ไขข้อมูลเดิมแทนการส่งใหม่หรือไม่?</div>
          <button @click="goSavedEdit" class="px-4 py-2 rounded-lg bg-amber-500 text-white text-sm font-bold whitespace-nowrap">แก้ไขข้อมูลเดิม</button>
        </div>

        <div v-if="!isEdit && !open" class="glass-card p-6 text-center">
          <div class="font-bold text-slate-600">ขณะนี้ปิดรับแบบสำรวจ</div>
          <div v-if="cfg?.open_at && new Date(cfg.open_at) > new Date()" class="text-sm text-slate-500 mt-1">
            เปิดรับวันที่ {{ new Date(cfg.open_at).toLocaleString('th-TH', { dateStyle: 'long', timeStyle: 'short' }) }}
          </div>
        </div>

        <template v-else>
          <div v-if="savedOk" class="glass-card p-4 text-center text-emerald-700 font-bold border-l-4 border-l-emerald-500">
            ✓ บันทึกการแก้ไขเรียบร้อยแล้ว
          </div>

          <div v-if="!isEdit && cfg?.intro" class="rounded-2xl p-5 bg-white shadow-sm border-2 border-sky-100 flex gap-3">
            <div class="w-9 h-9 rounded-full bg-sky-100 flex items-center justify-center shrink-0"><TsIcon name="info" class="w-5 h-5 text-sky-600"/></div>
            <div class="text-sm text-slate-700 leading-relaxed"><b class="text-sky-700">คำชี้แจง :</b> {{ cfg.intro }}</div>
          </div>

          <!-- ═══ ส่วนที่ 1 ═══ -->
          <section class="rounded-3xl overflow-hidden bg-white shadow-lg">
            <div role="heading" aria-level="2" class="bg-gradient-to-r from-indigo-600 to-violet-500 text-white font-bold px-5 py-4 flex items-center gap-3">
              <span class="w-9 h-9 rounded-full bg-white/20 ring-1 ring-white/40 flex items-center justify-center shrink-0"><TsIcon name="user" class="w-5 h-5"/></span>
              ส่วนที่ 1: ข้อมูลพื้นฐาน บริบทการปฏิบัติงาน และช่องทางการติดต่อ
            </div>
            <div class="px-5 sm:px-7 py-2 q-list">

              <!-- รูปโปรไฟล์: ส่งใหม่ = เก็บไว้ก่อนแล้วอัปหลังส่งสำเร็จ · แก้ไข = อัปทันที -->
              <div class="flex flex-col sm:flex-row items-center gap-4 p-4 rounded-2xl bg-gradient-to-r from-violet-50 to-sky-50 border-2 border-dashed border-violet-300">
                <button type="button" @click="showCropper = true" :disabled="photoBusy"
                  class="w-24 h-24 rounded-full overflow-hidden bg-white flex items-center justify-center shrink-0 shadow-md ring-4 ring-violet-200 hover:ring-violet-400 transition">
                  <img v-if="photoPreview" :src="photoPreview" alt="รูปโปรไฟล์" class="w-full h-full object-cover"/>
                  <TsIcon v-else name="camera" class="w-10 h-10 text-violet-400"/>
                </button>
                <div class="flex-1 text-center sm:text-left space-y-1.5">
                  <div class="font-bold text-slate-700">รูปโปรไฟล์ในทำเนียบครู <span class="text-xs font-normal text-slate-400">(ไม่บังคับ)</span></div>
                  <div class="text-xs text-slate-500">เลือกรูปหน้าตรงจากเครื่องหรือถ่ายจากมือถือ แล้วลากกรอบครอบให้พอดีหน้า ระบบย่อให้อัตโนมัติ</div>
                  <div class="flex flex-wrap gap-2 justify-center sm:justify-start pt-1">
                    <button type="button" @click="showCropper = true" :disabled="photoBusy"
                      class="px-4 py-2 rounded-lg bg-gradient-to-r from-violet-500 to-indigo-500 text-white text-sm font-bold shadow disabled:opacity-50">
                      <span class="inline-flex items-center gap-1.5"><TsIcon name="camera" class="w-4 h-4"/>{{ photoBusy ? 'กำลังอัปโหลด...' : (photoPreview ? 'เปลี่ยนรูป' : 'เลือกรูป / ถ่ายรูป') }}</span>
                    </button>
                    <button v-if="photoPreview" type="button" @click="removePhoto" class="px-4 py-2 rounded-lg text-sm text-red-500 hover:bg-red-50">ลบรูป</button>
                  </div>
                  <div v-if="pendingPhoto" class="text-[11px] text-amber-600">รูปจะถูกอัปโหลดเมื่อกด "ส่งแบบสำรวจ"</div>
                  <div v-if="photoErr" class="text-xs text-red-600">{{ photoErr }}</div>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.indigo.badge">1</span>คำนำหน้า ชื่อ - นามสกุล <span class="text-red-500">*</span></label>
                <div class="grid grid-cols-1 sm:grid-cols-[10rem_1fr_1fr] gap-2">
                  <div class="space-y-2">
                    <select :value="customPrefix ? '__other' : form.prefix" @change="onPrefixSelect" :class="inputCls">
                      <option value="" disabled>คำนำหน้า</option>
                      <option v-for="p in PREFIXES" :key="p" :value="p">{{ p }}</option>
                      <option value="__other">อื่น ๆ</option>
                    </select>
                    <input v-if="customPrefix" v-model="form.prefix" maxlength="50" placeholder="ระบุคำนำหน้า" :class="inputCls"/>
                  </div>
                  <input v-model="form.first_name" maxlength="100" placeholder="ชื่อ" :class="inputCls"/>
                  <input v-model="form.last_name" maxlength="100" placeholder="นามสกุล" :class="inputCls"/>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.sky.badge">2</span>โรงเรียน <span class="text-red-500">*</span></label>
                <SchoolPicker v-model="form.school_id" :schools="schools"/>
                <div v-if="selectedSchool" class="text-xs text-slate-500">
                  อ.{{ selectedSchool.district }} · ศูนย์เครือข่ายพัฒนาคุณภาพการศึกษา {{ selectedSchool.school_group }}
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.teal.badge">3</span>ช่องทางการติดต่อ <span class="text-xs font-normal text-slate-500">(เพื่อใช้ประสานงานและเชิญเข้ากลุ่มเครือข่ายรายวิชา)</span></label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <input v-model="form.phone" type="tel" inputmode="numeric" maxlength="12" placeholder="เบอร์โทรศัพท์ *" :class="inputCls"/>
                  <input v-model="form.line_id" maxlength="100" placeholder="ID Line" :class="inputCls"/>
                  <input v-model="form.email" type="email" maxlength="200" placeholder="E-mail address" :class="[inputCls, 'sm:col-span-2']"/>
                </div>
                <div class="text-xs text-slate-500 flex items-start gap-1.5"><TsIcon name="lock" class="w-4 h-4 shrink-0 text-teal-600"/><span>เบอร์โทร Line และอีเมล ไม่แสดงในทำเนียบสาธารณะ — เห็นเฉพาะศึกษานิเทศก์และเจ้าหน้าที่เขต · เบอร์โทรใช้ยืนยันตัวตน 1 เบอร์ต่อ 1 คน</span></div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.sky.badge">4</span>ระดับชั้นที่รับผิดชอบการสอน <span class="text-red-500">*</span> <span class="text-xs font-normal text-slate-500">(เลือกได้มากกว่า 1 ข้อ)</span></label>
                <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  <label v-for="o in opts.grades" :key="o.key" :class="chip('sky', isChecked('grades', o.key))">
                    <input type="checkbox" :checked="isChecked('grades', o.key)" @change="toggle('grades', o.key)" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.sky.acc]"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.indigo.badge">5</span>วุฒิการศึกษาและสาขาวิชาเอกที่สำเร็จการศึกษา <span class="text-xs font-normal text-slate-500">(เช่น ค.บ. คณิตศาสตร์ / วท.บ. วิทยาการคอมพิวเตอร์)</span></label>
                <div class="space-y-2">
                  <input v-model="form.degree_ba"  maxlength="200" placeholder="ปริญญาตรี" :class="inputCls"/>
                  <input v-model="form.degree_ma"  maxlength="200" placeholder="ปริญญาโท (ถ้ามี)" :class="inputCls"/>
                  <input v-model="form.degree_phd" maxlength="200" placeholder="ปริญญาเอก (ถ้ามี)" :class="inputCls"/>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.violet.badge">6</span>วิทยฐานะปัจจุบัน <span class="text-red-500">*</span></label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <label v-for="o in opts.ranks" :key="o.key" :class="chip('violet', form.academic_rank === o.key)">
                    <input type="radio" v-model="form.academic_rank" :value="o.key" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.violet.acc]"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.teal.badge">7</span>ลักษณะการจัดการเรียนการสอนในปัจจุบัน</label>
                <div class="space-y-2">
                  <label v-for="o in opts.major_match" :key="o.key" :class="chip('teal', form.major_match === o.key)">
                    <input type="radio" v-model="form.major_match" :value="o.key" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.teal.acc]"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800">
                  <span class="qno" :class="CHIP.emerald.badge">8</span>เครือข่ายวิชาชีพครูที่ท่านสนใจเข้าร่วม <span class="text-red-500">*</span>
                  <span class="text-xs font-normal text-slate-500">(เลือกได้ไม่เกิน {{ limits.networks || '–' }} เครือข่าย ตามรายวิชาที่สอนหรือสนใจ)</span>
                </label>
                <div class="text-xs" :class="['inline-block px-2.5 py-0.5 rounded-full font-bold', atLimit('networks') ? 'bg-amber-100 text-amber-700' : 'bg-emerald-50 text-emerald-700']">
                  เลือกแล้ว {{ form.networks.length }}{{ limits.networks ? ` / ${limits.networks}` : '' }}
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <template v-for="o in opts.networks" :key="o.key">
                    <div v-if="o.children?.length" class="sm:col-span-2 px-1 pt-2 text-sm font-bold text-emerald-700 flex items-center gap-1.5"><TsIcon name="language" class="w-4 h-4"/>{{ o.label }}</div>
                    <label v-for="c in (o.children?.length ? o.children : [o])" :key="c.key"
                      :class="[chip('emerald', isChecked('networks', c.key), !isChecked('networks', c.key) && atLimit('networks')), o.children?.length ? 'sm:ml-4' : '']">
                      <input type="checkbox" :checked="isChecked('networks', c.key)"
                        :disabled="!isChecked('networks', c.key) && atLimit('networks')"
                        @change="toggle('networks', c.key)" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.emerald.acc]"/>
                      {{ c.label }}
                    </label>
                  </template>
                </div>
                <input v-if="hasOther('networks')" v-model="form.networks_other" maxlength="200" placeholder="โปรดระบุ" :class="inputCls"/>
              </div>
            </div>
          </section>

          <!-- ═══ ส่วนที่ 2 ═══ -->
          <section class="rounded-3xl overflow-hidden bg-white shadow-lg">
            <div role="heading" aria-level="2" class="bg-gradient-to-r from-orange-500 to-pink-500 text-white font-bold px-5 py-4 flex items-center gap-3">
              <span class="w-9 h-9 rounded-full bg-white/20 ring-1 ring-white/40 flex items-center justify-center shrink-0"><TsIcon name="clipboard" class="w-5 h-5"/></span>
              ส่วนที่ 2: สภาพปัญหา บริบทโรงเรียน และความต้องการจำเป็นในการพัฒนา
            </div>
            <div class="px-5 sm:px-7 py-2 q-list">
              <div v-for="q in PART2" :key="q.field" class="space-y-2">
                <label class="block font-bold text-slate-800">
                  <span class="qno" :class="CHIP[q.color].badge">{{ q.no }}</span>{{ q.title }}
                  <span class="text-xs font-normal text-slate-500">
                    ({{ limits[q.field] ? `เลือกได้สูงสุด ${limits[q.field]} ข้อ` : 'เลือกได้มากกว่า 1 ข้อ' }})
                  </span>
                </label>
                <div v-if="limits[q.field]" class="text-xs" :class="['inline-block px-2.5 py-0.5 rounded-full font-bold', atLimit(q.field) ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-600']">
                  เลือกแล้ว {{ form[q.field].length }} / {{ limits[q.field] }}
                </div>
                <div class="space-y-2">
                  <label v-for="o in leafOptions(opts[q.field])" :key="o.key"
                    :class="chip(q.color, isChecked(q.field, o.key), !isChecked(q.field, o.key) && atLimit(q.field))">
                    <input type="checkbox" :checked="isChecked(q.field, o.key)"
                      :disabled="!isChecked(q.field, o.key) && atLimit(q.field)"
                      @change="toggle(q.field, o.key)" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP[q.color].acc]"/>
                    {{ o.label }}
                  </label>
                </div>
                <input v-if="hasOther(q.field)" v-model="form[`${q.field}_other`]" maxlength="200" placeholder="โปรดระบุ" :class="inputCls"/>
              </div>

              <!-- คำถามเสริมที่แอดมินเพิ่ม -->
              <div v-for="(q, i) in extras" :key="q.key" class="space-y-2">
                <label class="block font-bold text-slate-800">
                  <span class="qno" :class="CHIP.indigo.badge">{{ 11 + i }}</span>{{ q.label }} <span v-if="q.required" class="text-red-500">*</span>
                  <span v-if="q.type === 'multi' && q.max" class="text-xs font-normal text-slate-500">(เลือกได้สูงสุด {{ q.max }} ข้อ)</span>
                </label>
                <input v-if="q.type === 'text'" :value="form.extra[q.key] || ''" @input="setExtra(q.key, $event.target.value)" maxlength="1000" :class="inputCls"/>
                <textarea v-else-if="q.type === 'textarea'" :value="form.extra[q.key] || ''" @input="setExtra(q.key, $event.target.value)" rows="3" maxlength="1000" :class="inputCls"/>
                <div v-else-if="q.type === 'choice'" class="space-y-1">
                  <label v-for="op in q.options || []" :key="op" :class="chip('indigo', form.extra[q.key] === op)">
                    <input type="radio" :name="`x-${q.key}`" :checked="form.extra[q.key] === op" @change="setExtra(q.key, op)" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.indigo.acc]"/>
                    {{ op }}
                  </label>
                </div>
                <div v-else-if="q.type === 'multi'" class="space-y-1">
                  <label v-for="op in q.options || []" :key="op" :class="chip('indigo', extraChecked(q, op))">
                    <input type="checkbox" :checked="extraChecked(q, op)" @change="extraToggle(q, op)" :class="['w-4 h-4 mt-0.5 shrink-0', CHIP.indigo.acc]"/>
                    {{ op }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-800"><span class="qno" :class="CHIP.rose.badge">{{ 11 + extras.length }}</span>ข้อเสนอแนะอื่น ๆ</label>
                <textarea v-model="form.suggestion" rows="3" maxlength="2000" :class="inputCls"/>
              </div>
            </div>
          </section>

          <div v-if="errMsg" id="survey-error" class="glass-card p-4 text-sm text-red-600 font-bold border-l-4 border-l-red-500">
            {{ errMsg }}
          </div>

          <button @click="submit" :disabled="saving"
            class="w-full py-4 rounded-2xl bg-gradient-to-r from-indigo-600 via-sky-500 to-emerald-500 text-white font-extrabold text-lg shadow-xl hover:shadow-2xl hover:-translate-y-0.5 transition disabled:opacity-50">
            <span class="inline-flex items-center justify-center gap-2"><TsIcon :name="isEdit ? 'save' : 'send'" class="w-6 h-6"/>{{ saving ? 'กำลังบันทึก...' : (isEdit ? 'บันทึกการแก้ไข' : 'ส่งแบบสำรวจ') }}</span>
          </button>

          <div class="text-center text-xs text-slate-400 italic pb-6">
            ขอขอบพระคุณคณะครูทุกท่านที่ร่วมให้ข้อมูลเพื่อการพัฒนาเครือข่ายวิชาชีพครู {{ officeName }}
          </div>
        </template>
      </template>
    </div>

    <ImageCropperModal v-if="showCropper" :show="showCropper" :aspect-ratio="1" title="ครอปรูปโปรไฟล์"
      :output-max-width="256" :output-max-height="256" output-type="image/jpeg" :output-quality="0.8"
      @close="showCropper = false" @cropped="onCropped"/>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
/* แต่ละข้อแยกด้วยเส้นชัดเจน + เว้นระยะเท่ากัน */
.q-list > * { padding-top: 1.5rem; padding-bottom: 1.5rem; }
.q-list > * + * { border-top: 1.5px solid #cbd5e1; }
.q-list > * > label:first-child { display: block; margin-bottom: .75rem; }
/* วงกลมเลขข้อ (สีพื้นมาจาก CHIP[...].badge) */
.qno {
  display: inline-flex; align-items: center; justify-content: center;
  width: 1.75rem; height: 1.75rem; margin-right: .5rem; border-radius: 9999px;
  color: #fff; font-size: .8rem; font-weight: 800; vertical-align: middle;
  box-shadow: 0 2px 6px rgba(15,23,42,.15);
}
</style>
