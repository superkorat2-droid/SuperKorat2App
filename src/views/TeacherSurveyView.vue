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

const inputCls = 'w-full px-4 py-3 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary'
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <div class="max-w-3xl mx-auto px-4 py-6 space-y-5">

      <!-- ── หัวแบบสำรวจ ─────────────────────────────────────────────── -->
      <div class="glass-card p-5 sm:p-6 text-center space-y-1">
        <div role="heading" aria-level="1" class="text-xl sm:text-2xl font-extrabold text-primary leading-snug">
          {{ cfg?.title || 'การขับเคลื่อนระบบฐานข้อมูลพัฒนาเครือข่ายวิชาชีพครู' }}
        </div>
        <div class="text-sm font-bold text-slate-600">{{ officeName }}</div>
        <div v-if="isEdit && !loadErr" class="inline-block mt-2 text-xs font-bold bg-amber-100 text-amber-700 px-3 py-1 rounded-full">
          โหมดแก้ไขข้อมูลของ {{ fullName(form) || 'ท่าน' }}
        </div>
      </div>

      <div v-if="loading" class="glass-card p-10 text-center text-slate-400 animate-pulse">กำลังโหลด...</div>

      <div v-else-if="loadErr" class="glass-card p-6 text-center space-y-3">
        <div class="text-red-600 font-bold">{{ loadErr }}</div>
        <router-link to="/teacher-survey" class="text-sm text-primary hover:underline">ไปหน้าแบบสำรวจ</router-link>
      </div>

      <!-- ── ส่งสำเร็จ: ลิงก์แก้ไขส่วนตัว ─────────────────────────────── -->
      <div v-else-if="done" class="glass-card p-6 space-y-4 text-center">
        <div class="text-5xl">🎉</div>
        <div role="heading" aria-level="2" class="text-lg font-extrabold text-emerald-700">ส่งแบบสำรวจเรียบร้อยแล้ว ขอบคุณครับ/ค่ะ</div>
        <div class="text-left bg-amber-50 border border-amber-200 rounded-xl p-4 space-y-2">
          <div class="text-sm font-bold text-amber-800">🔑 ลิงก์แก้ไขข้อมูลส่วนตัวของท่าน — กรุณาเก็บไว้</div>
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
        <button @click="goEdit" class="w-full sm:w-auto px-6 py-3 rounded-xl bg-primary text-white font-bold hover:opacity-90">
          ✏️ ตรวจทาน / แก้ไขข้อมูลและรูป
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

          <div v-if="!isEdit && cfg?.intro" class="glass-card p-5 border-l-4 border-l-primary">
            <div class="text-sm text-slate-700 leading-relaxed"><b>คำชี้แจง :</b> {{ cfg.intro }}</div>
          </div>

          <!-- ═══ ส่วนที่ 1 ═══ -->
          <section class="glass-card overflow-hidden">
            <div role="heading" aria-level="2" class="bg-primary text-white font-bold px-5 py-3">ส่วนที่ 1: ข้อมูลพื้นฐาน บริบทการปฏิบัติงาน และช่องทางการติดต่อ</div>
            <div class="p-5 space-y-6">

              <!-- รูปโปรไฟล์: ส่งใหม่ = เก็บไว้ก่อนแล้วอัปหลังส่งสำเร็จ · แก้ไข = อัปทันที -->
              <div class="flex flex-col sm:flex-row items-center gap-4 p-4 rounded-2xl bg-slate-50 border border-dashed border-slate-300">
                <button type="button" @click="showCropper = true" :disabled="photoBusy"
                  class="w-24 h-24 rounded-full overflow-hidden bg-white flex items-center justify-center shrink-0 shadow ring-2 ring-white hover:ring-primary transition">
                  <img v-if="photoPreview" :src="photoPreview" alt="รูปโปรไฟล์" class="w-full h-full object-cover"/>
                  <span v-else class="text-3xl">📷</span>
                </button>
                <div class="flex-1 text-center sm:text-left space-y-1.5">
                  <div class="font-bold text-slate-700">รูปโปรไฟล์ในทำเนียบครู <span class="text-xs font-normal text-slate-400">(ไม่บังคับ)</span></div>
                  <div class="text-xs text-slate-500">เลือกรูปหน้าตรงจากเครื่องหรือถ่ายจากมือถือ แล้วลากกรอบครอบให้พอดีหน้า ระบบย่อให้อัตโนมัติ</div>
                  <div class="flex flex-wrap gap-2 justify-center sm:justify-start pt-1">
                    <button type="button" @click="showCropper = true" :disabled="photoBusy"
                      class="px-4 py-2 rounded-lg bg-primary text-white text-sm font-bold disabled:opacity-50">
                      {{ photoBusy ? 'กำลังอัปโหลด...' : (photoPreview ? 'เปลี่ยนรูป' : '📷 เลือกรูป / ถ่ายรูป') }}
                    </button>
                    <button v-if="photoPreview" type="button" @click="removePhoto" class="px-4 py-2 rounded-lg text-sm text-red-500 hover:bg-red-50">ลบรูป</button>
                  </div>
                  <div v-if="pendingPhoto" class="text-[11px] text-amber-600">รูปจะถูกอัปโหลดเมื่อกด "ส่งแบบสำรวจ"</div>
                  <div v-if="photoErr" class="text-xs text-red-600">{{ photoErr }}</div>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">1. คำนำหน้า ชื่อ - นามสกุล <span class="text-red-500">*</span></label>
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
                <label class="block font-bold text-slate-700">2. โรงเรียน <span class="text-red-500">*</span></label>
                <SchoolPicker v-model="form.school_id" :schools="schools"/>
                <div v-if="selectedSchool" class="text-xs text-slate-500">
                  อ.{{ selectedSchool.district }} · ศูนย์เครือข่ายพัฒนาคุณภาพการศึกษา {{ selectedSchool.school_group }}
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">3. ช่องทางการติดต่อ <span class="text-xs font-normal text-slate-500">(เพื่อใช้ประสานงานและเชิญเข้ากลุ่มเครือข่ายรายวิชา)</span></label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <input v-model="form.phone" type="tel" inputmode="numeric" maxlength="12" placeholder="เบอร์โทรศัพท์ *" :class="inputCls"/>
                  <input v-model="form.line_id" maxlength="100" placeholder="ID Line" :class="inputCls"/>
                  <input v-model="form.email" type="email" maxlength="200" placeholder="E-mail address" :class="[inputCls, 'sm:col-span-2']"/>
                </div>
                <div class="text-xs text-slate-500">🔒 เบอร์โทร Line และอีเมล ไม่แสดงในทำเนียบสาธารณะ — เห็นเฉพาะศึกษานิเทศก์และเจ้าหน้าที่เขต · เบอร์โทรใช้ยืนยันตัวตน 1 เบอร์ต่อ 1 คน</div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">4. ระดับชั้นที่รับผิดชอบการสอน <span class="text-red-500">*</span> <span class="text-xs font-normal text-slate-500">(เลือกได้มากกว่า 1 ข้อ)</span></label>
                <div class="grid grid-cols-2 sm:grid-cols-3 gap-1.5">
                  <label v-for="o in opts.grades" :key="o.key" class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/60 cursor-pointer text-sm">
                    <input type="checkbox" :checked="isChecked('grades', o.key)" @change="toggle('grades', o.key)" class="w-4 h-4 accent-primary"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">5. วุฒิการศึกษาและสาขาวิชาเอกที่สำเร็จการศึกษา <span class="text-xs font-normal text-slate-500">(เช่น ค.บ. คณิตศาสตร์ / วท.บ. วิทยาการคอมพิวเตอร์)</span></label>
                <div class="space-y-2">
                  <input v-model="form.degree_ba"  maxlength="200" placeholder="ปริญญาตรี" :class="inputCls"/>
                  <input v-model="form.degree_ma"  maxlength="200" placeholder="ปริญญาโท (ถ้ามี)" :class="inputCls"/>
                  <input v-model="form.degree_phd" maxlength="200" placeholder="ปริญญาเอก (ถ้ามี)" :class="inputCls"/>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">6. วิทยฐานะปัจจุบัน <span class="text-red-500">*</span></label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                  <label v-for="o in opts.ranks" :key="o.key" class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/60 cursor-pointer text-sm">
                    <input type="radio" v-model="form.academic_rank" :value="o.key" class="w-4 h-4 accent-primary"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">7. ลักษณะการจัดการเรียนการสอนในปัจจุบัน</label>
                <div class="space-y-1.5">
                  <label v-for="o in opts.major_match" :key="o.key" class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/60 cursor-pointer text-sm">
                    <input type="radio" v-model="form.major_match" :value="o.key" class="w-4 h-4 accent-primary"/>
                    {{ o.label }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">
                  8. เครือข่ายวิชาชีพครูที่ท่านสนใจเข้าร่วม <span class="text-red-500">*</span>
                  <span class="text-xs font-normal text-slate-500">(เลือกได้ไม่เกิน {{ limits.networks || '–' }} เครือข่าย ตามรายวิชาที่สอนหรือสนใจ)</span>
                </label>
                <div class="text-xs" :class="atLimit('networks') ? 'text-amber-600 font-bold' : 'text-slate-400'">
                  เลือกแล้ว {{ form.networks.length }}{{ limits.networks ? ` / ${limits.networks}` : '' }}
                </div>
                <div class="space-y-1">
                  <template v-for="o in opts.networks" :key="o.key">
                    <div v-if="o.children?.length" class="px-3 pt-2 text-sm font-bold text-slate-600">{{ o.label }}</div>
                    <label v-for="c in (o.children?.length ? o.children : [o])" :key="c.key"
                      :class="['flex items-center gap-2 px-3 py-2 rounded-lg text-sm',
                               o.children?.length ? 'ml-6' : '',
                               !isChecked('networks', c.key) && atLimit('networks') ? 'opacity-40 cursor-not-allowed' : 'hover:bg-white/60 cursor-pointer']">
                      <input type="checkbox" :checked="isChecked('networks', c.key)"
                        :disabled="!isChecked('networks', c.key) && atLimit('networks')"
                        @change="toggle('networks', c.key)" class="w-4 h-4 accent-primary"/>
                      {{ c.label }}
                    </label>
                  </template>
                </div>
                <input v-if="hasOther('networks')" v-model="form.networks_other" maxlength="200" placeholder="โปรดระบุ" :class="[inputCls, 'ml-6 !w-[calc(100%-1.5rem)]']"/>
              </div>
            </div>
          </section>

          <!-- ═══ ส่วนที่ 2 ═══ -->
          <section class="glass-card overflow-hidden">
            <div role="heading" aria-level="2" class="bg-primary text-white font-bold px-5 py-3">ส่วนที่ 2: สภาพปัญหา บริบทโรงเรียน และความต้องการจำเป็นในการพัฒนา</div>
            <div class="p-5 space-y-6">
              <div v-for="(q, qi) in [
                     { field: 'constraints', no: 9,  title: 'สภาพความพร้อมและข้อจำกัดของสถานศึกษาในการจัดกิจกรรมการเรียนรู้' },
                     { field: 'topics',      no: 10, title: 'ประเด็นที่ท่านต้องการพัฒนาหรือแลกเปลี่ยนเรียนรู้ในเครือข่ายมากที่สุด' },
                   ]" :key="qi" class="space-y-2">
                <label class="block font-bold text-slate-700">
                  {{ q.no }}. {{ q.title }}
                  <span class="text-xs font-normal text-slate-500">
                    ({{ limits[q.field] ? `เลือกได้สูงสุด ${limits[q.field]} ข้อ` : 'เลือกได้มากกว่า 1 ข้อ' }})
                  </span>
                </label>
                <div v-if="limits[q.field]" class="text-xs" :class="atLimit(q.field) ? 'text-amber-600 font-bold' : 'text-slate-400'">
                  เลือกแล้ว {{ form[q.field].length }} / {{ limits[q.field] }}
                </div>
                <div class="space-y-1">
                  <label v-for="o in leafOptions(opts[q.field])" :key="o.key"
                    :class="['flex items-start gap-2 px-3 py-2 rounded-lg text-sm',
                             !isChecked(q.field, o.key) && atLimit(q.field) ? 'opacity-40 cursor-not-allowed' : 'hover:bg-white/60 cursor-pointer']">
                    <input type="checkbox" :checked="isChecked(q.field, o.key)"
                      :disabled="!isChecked(q.field, o.key) && atLimit(q.field)"
                      @change="toggle(q.field, o.key)" class="w-4 h-4 mt-0.5 accent-primary shrink-0"/>
                    {{ o.label }}
                  </label>
                </div>
                <input v-if="hasOther(q.field)" v-model="form[`${q.field}_other`]" maxlength="200" placeholder="โปรดระบุ" :class="inputCls"/>
              </div>

              <!-- คำถามเสริมที่แอดมินเพิ่ม -->
              <div v-for="(q, i) in extras" :key="q.key" class="space-y-2">
                <label class="block font-bold text-slate-700">
                  {{ 11 + i }}. {{ q.label }} <span v-if="q.required" class="text-red-500">*</span>
                  <span v-if="q.type === 'multi' && q.max" class="text-xs font-normal text-slate-500">(เลือกได้สูงสุด {{ q.max }} ข้อ)</span>
                </label>
                <input v-if="q.type === 'text'" :value="form.extra[q.key] || ''" @input="setExtra(q.key, $event.target.value)" maxlength="1000" :class="inputCls"/>
                <textarea v-else-if="q.type === 'textarea'" :value="form.extra[q.key] || ''" @input="setExtra(q.key, $event.target.value)" rows="3" maxlength="1000" :class="inputCls"/>
                <div v-else-if="q.type === 'choice'" class="space-y-1">
                  <label v-for="op in q.options || []" :key="op" class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/60 cursor-pointer text-sm">
                    <input type="radio" :name="`x-${q.key}`" :checked="form.extra[q.key] === op" @change="setExtra(q.key, op)" class="w-4 h-4 accent-primary"/>
                    {{ op }}
                  </label>
                </div>
                <div v-else-if="q.type === 'multi'" class="space-y-1">
                  <label v-for="op in q.options || []" :key="op" class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-white/60 cursor-pointer text-sm">
                    <input type="checkbox" :checked="extraChecked(q, op)" @change="extraToggle(q, op)" class="w-4 h-4 accent-primary"/>
                    {{ op }}
                  </label>
                </div>
              </div>

              <div class="space-y-2">
                <label class="block font-bold text-slate-700">{{ 11 + extras.length }}. ข้อเสนอแนะอื่น ๆ</label>
                <textarea v-model="form.suggestion" rows="3" maxlength="2000" :class="inputCls"/>
              </div>
            </div>
          </section>

          <div v-if="errMsg" id="survey-error" class="glass-card p-4 text-sm text-red-600 font-bold border-l-4 border-l-red-500">
            {{ errMsg }}
          </div>

          <button @click="submit" :disabled="saving"
            class="w-full py-4 rounded-2xl bg-primary text-white font-extrabold text-lg shadow-lg hover:opacity-90 disabled:opacity-50">
            {{ saving ? 'กำลังบันทึก...' : (isEdit ? 'บันทึกการแก้ไข' : 'ส่งแบบสำรวจ') }}
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
</style>
