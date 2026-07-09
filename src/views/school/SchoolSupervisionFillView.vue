<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { Cropper } from 'vue-advanced-cropper'
import 'vue-advanced-cropper/dist/style.css'
import Swal from 'sweetalert2'
import { useFormDraft } from '../../composables/useFormDraft'

const route  = useRoute()
const router = useRouter()

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const formId = computed(() => route.params.formId)

// ─── State ────────────────────────────────────────────────────────────────────
const loading     = ref(true)
const submitting  = ref(false)
const submitted   = ref(false)
const error       = ref(null)
const alreadyDone = ref(false)
const notAssigned = ref(false)
const started     = ref(false)

const form      = ref(null)
const questions = ref([])
const schools   = ref([])  // for individual mode school selector

const answers           = ref({})
const otherText         = ref({})
const evidenceFileUrls  = ref({})
const evidencePreviews  = ref({})
const evidenceLinks     = ref({})
const uploadingEvidence = ref({})

// Individual mode respondent state
const respondentName     = ref('')
const respondentPosition = ref('')
const respondentSchoolId = ref(null)
const respondentGender   = ref('')
const respondentAgeRange = ref('')
const respondentPhone    = ref('')
const respondentEmail    = ref('')
const AGE_RANGES = ['ต่ำกว่า 30 ปี', '30–39 ปี', '40–49 ปี', '50 ปี ขึ้นไป']

const isAnonymous = computed(() => isIndividual.value && !form.value?.respondent_fields?.some(f => f.show))

function showField(key) {
  if (!isIndividual.value) return false
  return form.value?.respondent_fields?.find(f => f.key === key)?.show === true
}
function fieldRequired(key) {
  const f = form.value?.respondent_fields?.find(x => x.key === key)
  return f?.show && f?.required
}
function buildRespondentInfo() {
  if (!isIndividual.value || isAnonymous.value) return null
  const info = {}
  if (showField('name')      && respondentName.value.trim())     info.name      = respondentName.value.trim()
  if (showField('position')  && respondentPosition.value.trim()) info.position  = respondentPosition.value.trim()
  if (showField('school')    && respondentSchoolId.value)        info.school    = schools.value.find(s => s.id === respondentSchoolId.value)?.name
  if (showField('gender')    && respondentGender.value)          info.gender    = respondentGender.value
  if (showField('age_range') && respondentAgeRange.value)        info.age_range = respondentAgeRange.value
  if (showField('phone')     && respondentPhone.value.trim())    info.phone     = respondentPhone.value.trim()
  if (showField('email')     && respondentEmail.value.trim())    info.email     = respondentEmail.value.trim()
  return Object.keys(info).length > 0 ? info : null
}

// ─── Cropper ──────────────────────────────────────────────────────────────────
const cropModal  = ref({ open: false, questionId: null, imageSrc: '' })
const cropperRef = ref(null)
const cropAspect = ref(null)
const cropping   = ref(false)

const RATIO_PRESETS = [
  { label: 'อิสระ', value: null },
  { label: '4:3',   value: 4/3 },
  { label: '3:4 (A4)', value: 3/4 },
  { label: '1:1',   value: 1 },
]
const stencilProps = computed(() =>
  cropAspect.value ? { aspectRatio: cropAspect.value } : {}
)
onUnmounted(() => { cropModal.value.open = false })

// ─── Load form ────────────────────────────────────────────────────────────────
async function loadForm() {
  loading.value = true
  const [{ data: formData, error: fErr }, { data: qs }] = await Promise.all([
    supabase.from('supervision_forms').select('*').eq('id', formId.value).eq('status', 'published').single(),
    supabase.from('supervision_questions').select('*').eq('form_id', formId.value).order('sort_order'),
  ])

  if (fErr || !formData) {
    error.value = 'ไม่พบแบบนิเทศ หรือยังไม่ได้เผยแพร่'
    loading.value = false
    return
  }

  // ตรวจ assignment
  if (formData.target === 'selected' && !formData.target_schools?.includes(props.school?.id)) {
    notAssigned.value = true
    loading.value = false
    return
  }

  form.value      = formData
  questions.value = qs || []
  questions.value.filter(q => q.type !== 'section').forEach(q => {
    answers.value[q.id] = q.type === 'multi_choice' ? [] : q.type === 'rating' ? null : ''
  })

  // ตรวจส่งซ้ำ (school mode)
  if (formData.respondent_type === 'school' && props.school?.id) {
    const { data: existing } = await supabase
      .from('supervision_responses').select('id')
      .eq('form_id', formId.value).eq('school_id', props.school.id).eq('is_complete', true)
      .maybeSingle()
    if (existing) { alreadyDone.value = true; loading.value = false; return }
  }

  // individual mode: โหลด school list สำหรับ dropdown
  if (formData.respondent_type === 'individual') {
    const { data: sc } = await supabase.from('schools').select('id, name, district').order('district').order('name')
    schools.value = sc || []
  }

  loading.value = false

  // กู้คืนคำตอบที่กรอกค้างไว้ (ถ้ามี) แล้วเริ่ม autosave
  const restored = restoreDraft()
  if (restored) {
    started.value = true
    Swal.fire({ icon: 'info', title: 'กู้คืนคำตอบที่กรอกค้างไว้แล้ว', showConfirmButton: false, timer: 1800 })
  }
  watchAndSave()
}

// ─── Draft (กันข้อมูลหายเมื่อเน็ตหลุด) ───────────────────────────────────────
const { restoreDraft, clearDraft, watchAndSave } = useFormDraft(
  `supervision_school_draft_${route.params.formId}_${props.profile?.id || ''}`,
  () => ({
    started: started.value,
    answers: answers.value, otherText: otherText.value,
    evidenceFileUrls: evidenceFileUrls.value, evidenceLinks: evidenceLinks.value,
    respondentName: respondentName.value, respondentPosition: respondentPosition.value,
    respondentSchoolId: respondentSchoolId.value, respondentGender: respondentGender.value,
    respondentAgeRange: respondentAgeRange.value, respondentPhone: respondentPhone.value,
    respondentEmail: respondentEmail.value,
  }),
  (saved) => {
    started.value = saved.started ?? false
    if (saved.answers) Object.assign(answers.value, saved.answers)
    if (saved.otherText) Object.assign(otherText.value, saved.otherText)
    if (saved.evidenceFileUrls) {
      Object.assign(evidenceFileUrls.value, saved.evidenceFileUrls)
      Object.assign(evidencePreviews.value, saved.evidenceFileUrls)
    }
    if (saved.evidenceLinks) Object.assign(evidenceLinks.value, saved.evidenceLinks)
    respondentName.value     = saved.respondentName || ''
    respondentPosition.value = saved.respondentPosition || ''
    respondentSchoolId.value = saved.respondentSchoolId || null
    respondentGender.value   = saved.respondentGender || ''
    respondentAgeRange.value = saved.respondentAgeRange || ''
    respondentPhone.value    = saved.respondentPhone || ''
    respondentEmail.value    = saved.respondentEmail || ''
  }
)

// ─── "อื่นๆ" free-text: แปลงคำตอบก่อนส่ง ─────────────────────────────────────
function resolveAnswerForSubmit(q) {
  const a = answers.value[q.id]
  if (q.type === 'choice') {
    const opt = q.options?.find(o => o.value === a)
    if (opt?.is_other) return `อื่นๆ: ${(otherText.value[q.id] || '').trim()}`.trim()
    return a
  }
  if (q.type === 'multi_choice' && Array.isArray(a)) {
    return a.map(v => {
      const opt = q.options?.find(o => o.value === v)
      return opt?.is_other ? `อื่นๆ: ${(otherText.value[q.id] || '').trim()}`.trim() : v
    })
  }
  return a
}

// ─── Progress ─────────────────────────────────────────────────────────────────
const nonSectionQs = computed(() => questions.value.filter(q => q.type !== 'section'))
const answered = computed(() =>
  nonSectionQs.value.filter(q => {
    const a = answers.value[q.id]
    if (q.type === 'multi_choice') return a?.length > 0
    if (q.type === 'rating') return a !== null && a !== undefined
    return a !== '' && a !== null && a !== undefined
  }).length
)
const progress = computed(() =>
  nonSectionQs.value.length > 0 ? Math.round((answered.value / nonSectionQs.value.length) * 100) : 0
)

// ─── Helpers ──────────────────────────────────────────────────────────────────
const isIndividual = computed(() => form.value?.respondent_type === 'individual')

function formatDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

// ─── Evidence upload (same as public fill) ────────────────────────────────────
function isImageMime(type) { return type?.startsWith('image/') }

function resizeCanvas(src, maxPx = 1200) {
  const scale = Math.min(1, maxPx / Math.max(src.width, src.height))
  const w = Math.round(src.width * scale), h = Math.round(src.height * scale)
  const c = document.createElement('canvas')
  c.width = w; c.height = h
  c.getContext('2d').drawImage(src, 0, 0, w, h)
  return c
}

async function uploadBlob(questionId, blob, ext = 'jpg') {
  uploadingEvidence.value[questionId] = true
  const path = `${formId.value}/${questionId}_${Date.now()}.${ext}`
  const { error: upErr } = await supabase.storage
    .from('supervision-evidence').upload(path, blob, { upsert: true, contentType: blob.type })
  if (upErr) {
    uploadingEvidence.value[questionId] = false
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: upErr.message })
    return
  }
  const { data: { publicUrl } } = supabase.storage.from('supervision-evidence').getPublicUrl(path)
  evidenceFileUrls.value[questionId]  = publicUrl
  uploadingEvidence.value[questionId] = false
}

function onFileChange(questionId, event) {
  const file = event.target.files?.[0]
  if (!file) return
  event.target.value = ''
  if (file.type === 'application/pdf') { uploadBlob(questionId, file, 'pdf'); return }
  if (!isImageMime(file.type)) return
  const reader = new FileReader()
  reader.onload = e => {
    cropModal.value = { open: true, questionId, imageSrc: e.target.result }
    cropAspect.value = null
  }
  reader.readAsDataURL(file)
}

async function confirmCrop() {
  const result = cropperRef.value?.getResult()
  if (!result?.canvas) return
  cropping.value = true
  const resized = resizeCanvas(result.canvas, 1200)
  evidencePreviews.value[cropModal.value.questionId] = resized.toDataURL('image/jpeg', 0.75)
  resized.toBlob(async blob => {
    await uploadBlob(cropModal.value.questionId, blob, 'jpg')
    cropModal.value.open = false
    cropping.value = false
  }, 'image/jpeg', 0.75)
}

function cancelCrop() { cropModal.value = { open: false, questionId: null, imageSrc: '' } }
function rePickImage(qId) {
  evidenceFileUrls.value[qId] = null; evidencePreviews.value[qId] = null
  document.getElementById(`sfile_${qId}`)?.click()
}

// ─── Validation ───────────────────────────────────────────────────────────────
function validate() {
  if (isIndividual.value && !isAnonymous.value) {
    if (fieldRequired('name')      && !respondentName.value.trim())     return 'กรุณาใส่ชื่อ-นามสกุล'
    if (fieldRequired('position')  && !respondentPosition.value.trim()) return 'กรุณาใส่ตำแหน่ง'
    if (fieldRequired('school')    && !respondentSchoolId.value)        return 'กรุณาเลือกโรงเรียน'
    if (fieldRequired('gender')    && !respondentGender.value)          return 'กรุณาเลือกเพศ'
    if (fieldRequired('age_range') && !respondentAgeRange.value)        return 'กรุณาเลือกช่วงอายุ'
    if (fieldRequired('phone')     && !respondentPhone.value.trim())    return 'กรุณาใส่เบอร์โทรศัพท์'
    if (fieldRequired('email')     && !respondentEmail.value.trim())    return 'กรุณาใส่อีเมล'
  }
  for (const q of nonSectionQs.value) {
    const idx = nonSectionQs.value.indexOf(q) + 1
    if (q.required) {
      const a = answers.value[q.id]
      if (q.type === 'multi_choice' && (!a || a.length === 0)) return `กรุณาตอบคำถามข้อที่ ${idx}`
      if (q.type === 'rating' && (a === null || a === undefined)) return `กรุณาตอบคำถามข้อที่ ${idx}`
      if (!['multi_choice','rating'].includes(q.type) && (a === '' || a === null)) return `กรุณาตอบคำถามข้อที่ ${idx}`
    }
    if (['choice','multi_choice'].includes(q.type)) {
      const a = answers.value[q.id]
      const selectedValues = q.type === 'multi_choice' ? (a || []) : (a ? [a] : [])
      const hasOtherSelected = selectedValues.some(v => q.options?.find(o => o.value === v)?.is_other)
      if (hasOtherSelected && !(otherText.value[q.id] || '').trim()) return `กรุณาพิมพ์ข้อความ "อื่นๆ" ในข้อที่ ${idx}`
    }
    if (q.evidence_required && q.evidence_type !== 'none') {
      if (['upload','both'].includes(q.evidence_type) && !evidenceFileUrls.value[q.id]) return `กรุณาอัปโหลดหลักฐานข้อที่ ${idx}`
      if (['url','both'].includes(q.evidence_type) && !evidenceLinks.value[q.id]?.trim()) return `กรุณาใส่ลิงค์หลักฐานข้อที่ ${idx}`
    }
  }
  return null
}

// ─── Submit ───────────────────────────────────────────────────────────────────
async function submit() {
  const errMsg = validate()
  if (errMsg) {
    Swal.fire({ icon: 'warning', title: 'กรุณาตรวจสอบ', text: errMsg, confirmButtonColor: 'var(--color-primary, #2563eb)' })
    return
  }
  submitting.value = true

  const answerPayload = nonSectionQs.value.map(q => ({
    question_id:       q.id,
    answer:            resolveAnswerForSubmit(q),
    evidence_file_url: evidenceFileUrls.value[q.id] || null,
    evidence_link_url: evidenceLinks.value[q.id]?.trim() || null,
  }))

  if (isIndividual.value) {
    const school = schools.value.find(s => s.id === respondentSchoolId.value)
    const { data, error: rpcErr } = await supabase.rpc('submit_supervision_authenticated', {
      p_form_id:         formId.value,
      p_answers:         answerPayload,
      p_respondent_info: buildRespondentInfo(),
    })
    submitting.value = false
    if (rpcErr) { Swal.fire({ icon: 'error', title: 'เกิดข้อผิดพลาด', text: rpcErr.message }); return }
    if (data?.error) { Swal.fire({ icon: 'error', title: 'เกิดข้อผิดพลาด', text: data.error }); return }
  } else {
    // school mode: ใช้ authenticated RPC
    const { data, error: rpcErr } = await supabase.rpc('submit_supervision_authenticated', {
      p_form_id: formId.value,
      p_answers: answerPayload,
    })
    submitting.value = false
    if (rpcErr) { Swal.fire({ icon: 'error', title: 'เกิดข้อผิดพลาด', text: rpcErr.message }); return }
    if (data?.error === 'already_submitted') { alreadyDone.value = true; return }
    if (data?.error === 'not_assigned') { notAssigned.value = true; return }
    if (data?.error) { Swal.fire({ icon: 'error', title: 'เกิดข้อผิดพลาด', text: data.error }); return }
  }

  clearDraft()
  submitted.value = true
}

onMounted(loadForm)
</script>

<template>
  <div class="max-w-2xl mx-auto space-y-4 pb-10">

    <!-- Loading -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-24 gap-4">
      <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
      <p class="text-slate-500 text-sm">กำลังโหลดแบบนิเทศ...</p>
    </div>

    <!-- Not assigned -->
    <div v-else-if="notAssigned" class="text-center py-20 bg-white rounded-2xl border border-slate-100 shadow-sm">
      <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>
        </svg>
      </div>
      <h2 class="text-lg font-bold text-slate-700 mb-1">ไม่ได้รับมอบหมาย</h2>
      <p class="text-sm text-slate-400">แบบนิเทศนี้ไม่ได้กำหนดสำหรับโรงเรียนของคุณ</p>
      <button @click="router.push('/school')" class="mt-4 text-sm text-primary font-bold hover:underline">
        กลับหน้าหลัก
      </button>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="text-center py-20 bg-white rounded-2xl border border-slate-100 shadow-sm">
      <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
        </svg>
      </div>
      <h2 class="text-lg font-bold text-slate-700 mb-1">ไม่พบแบบนิเทศ</h2>
      <p class="text-sm text-slate-400">{{ error }}</p>
    </div>

    <!-- Already submitted -->
    <div v-else-if="alreadyDone" class="text-center py-20 bg-white rounded-2xl border border-slate-100 shadow-sm">
      <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </div>
      <h2 class="text-lg font-bold text-emerald-700 mb-1">ส่งแบบนิเทศไปแล้ว</h2>
      <p class="text-sm text-slate-400">โรงเรียนของคุณได้ส่งแบบนิเทศนี้เรียบร้อยแล้ว</p>
      <button @click="router.push('/school')" class="mt-4 text-sm text-primary font-bold hover:underline">
        กลับหน้าหลัก
      </button>
    </div>

    <!-- Submitted success -->
    <div v-else-if="submitted" class="text-center py-24 bg-white rounded-2xl border border-slate-100 shadow-sm">
      <div class="w-20 h-20 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-6">
        <svg class="w-10 h-10 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </div>
      <h2 class="text-2xl font-extrabold text-emerald-700 mb-2">ส่งแบบนิเทศเรียบร้อย!</h2>
      <p class="text-slate-500 text-sm mb-4">ข้อมูลของคุณได้รับการบันทึกแล้ว</p>
      <button @click="router.push('/school')"
        class="px-6 py-2.5 bg-primary text-white font-bold rounded-xl text-sm hover:-translate-y-0.5 transition-all shadow-md">
        กลับหน้าหลัก
      </button>
    </div>

    <!-- Cover page (ก่อนเริ่มทำแบบสอบถาม) -->
    <div v-else-if="form && !started" class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
      <img v-if="form.cover_image_url" :src="form.cover_image_url" class="w-full h-auto block"/>
      <div class="p-8 text-center">
        <span class="text-xs bg-primary/10 text-primary font-bold px-3 py-1 rounded-full">แบบนิเทศ</span>
        <h1 class="text-2xl font-extrabold text-slate-800 mt-3">{{ form.title }}</h1>
        <p v-if="form.description" class="text-slate-500 text-sm mt-2 whitespace-pre-line">{{ form.description }}</p>
        <p v-if="form.deadline" class="text-xs text-slate-400 mt-3">กำหนดส่ง: {{ formatDate(form.deadline) }}</p>
        <button @click="started = true"
          class="mt-6 w-full sm:w-auto sm:px-12 py-3.5 bg-primary text-white font-extrabold rounded-2xl shadow-lg hover:-translate-y-0.5 transition-all">
          เริ่มทำแบบสอบถาม
        </button>
      </div>
    </div>

    <!-- Form -->
    <template v-else-if="form">

      <!-- Form header -->
      <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-6">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-xs bg-primary/10 text-primary font-bold px-3 py-1 rounded-full">แบบนิเทศ</span>
          <span v-if="!form.allow_public" class="text-xs bg-slate-100 text-slate-600 font-bold px-2 py-0.5 rounded-full flex items-center gap-1">
            🔒 ต้อง Login
          </span>
          <span v-if="form.deadline" class="text-xs text-slate-400">
            กำหนดส่ง: {{ formatDate(form.deadline) }}
          </span>
        </div>
        <h1 class="text-xl font-extrabold text-slate-800 mt-2">{{ form.title }}</h1>
        <p v-if="form.description" class="text-slate-500 text-sm mt-1">{{ form.description }}</p>
        <!-- Progress -->
        <div class="mt-4">
          <div class="flex justify-between text-xs text-slate-400 mb-1">
            <span>ตอบแล้ว {{ answered }} / {{ nonSectionQs.length }} ข้อ</span>
            <span>{{ progress }}%</span>
          </div>
          <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
            <div class="h-full bg-primary rounded-full transition-all duration-500" :style="`width:${progress}%`"/>
          </div>
        </div>
      </div>

      <!-- School info (school mode) -->
      <div v-if="!isIndividual" class="bg-white rounded-2xl shadow-sm border border-slate-100 p-5">
        <p class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">โรงเรียนของคุณ</p>
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 bg-primary/10 rounded-xl flex items-center justify-center flex-shrink-0">
            <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
            </svg>
          </div>
          <div>
            <p class="font-bold text-slate-800 text-sm">{{ school?.name }}</p>
            <p class="text-xs text-slate-400">{{ school?.district }} · {{ school?.school_group }}</p>
          </div>
          <span class="ml-auto text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">Verified ✓</span>
        </div>
      </div>

      <!-- Respondent info (individual mode, not anonymous) -->
      <div v-if="isIndividual && !isAnonymous" class="bg-white rounded-2xl shadow-sm border border-slate-100 p-5 space-y-3">
        <p class="text-sm font-extrabold text-slate-700 flex items-center gap-2">
          <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
          </svg>
          ข้อมูลผู้ตอบแบบสอบถาม
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div v-if="showField('name')">
            <label class="block text-xs font-bold text-slate-500 mb-1">ชื่อ-นามสกุล<span v-if="fieldRequired('name')" class="text-red-500 ml-0.5">*</span></label>
            <input v-model="respondentName" type="text" placeholder="ชื่อ นามสกุล"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
          <div v-if="showField('position')">
            <label class="block text-xs font-bold text-slate-500 mb-1">ตำแหน่ง/วิทยฐานะ<span v-if="fieldRequired('position')" class="text-red-500 ml-0.5">*</span></label>
            <input v-model="respondentPosition" type="text" placeholder="เช่น ครูชำนาญการ"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
          <div v-if="showField('gender')" class="sm:col-span-2">
            <label class="block text-xs font-bold text-slate-500 mb-2">เพศ<span v-if="fieldRequired('gender')" class="text-red-500 ml-0.5">*</span></label>
            <div class="flex gap-3">
              <label v-for="g in ['ชาย','หญิง','ไม่ระบุ']" :key="g"
                :class="['flex items-center gap-2 px-4 py-2.5 rounded-xl border-2 cursor-pointer transition-all text-sm font-medium',
                  respondentGender === g ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600 hover:border-slate-300']">
                <input type="radio" v-model="respondentGender" :value="g" class="sr-only"/>{{ g }}
              </label>
            </div>
          </div>
          <div v-if="showField('age_range')">
            <label class="block text-xs font-bold text-slate-500 mb-1">ช่วงอายุ<span v-if="fieldRequired('age_range')" class="text-red-500 ml-0.5">*</span></label>
            <select v-model="respondentAgeRange"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="">-- เลือกช่วงอายุ --</option>
              <option v-for="r in AGE_RANGES" :key="r" :value="r">{{ r }}</option>
            </select>
          </div>
          <div v-if="showField('school')" class="sm:col-span-2">
            <label class="block text-xs font-bold text-slate-500 mb-1">โรงเรียน<span v-if="fieldRequired('school')" class="text-red-500 ml-0.5">*</span><span v-else class="text-slate-400 font-normal ml-1">(ไม่บังคับ)</span></label>
            <select v-model="respondentSchoolId"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option :value="null">— ไม่ระบุ —</option>
              <optgroup v-for="dist in [...new Set(schools.map(s=>s.district))].sort()" :key="dist" :label="`อ.${dist}`">
                <option v-for="s in schools.filter(x=>x.district===dist)" :key="s.id" :value="s.id">{{ s.name }}</option>
              </optgroup>
            </select>
          </div>
          <div v-if="showField('phone')">
            <label class="block text-xs font-bold text-slate-500 mb-1">เบอร์โทรศัพท์<span v-if="fieldRequired('phone')" class="text-red-500 ml-0.5">*</span></label>
            <input v-model="respondentPhone" type="tel" placeholder="08x-xxx-xxxx"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
          <div v-if="showField('email')">
            <label class="block text-xs font-bold text-slate-500 mb-1">อีเมล<span v-if="fieldRequired('email')" class="text-red-500 ml-0.5">*</span></label>
            <input v-model="respondentEmail" type="email" placeholder="example@email.com"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
        </div>
      </div>

      <!-- Questions -->
      <div class="space-y-4">
        <template v-for="(q, i) in questions" :key="q.id">

          <!-- Section header -->
          <div v-if="q.type === 'section'"
            class="bg-indigo-600 rounded-2xl px-5 py-4 text-white shadow-sm">
            <div class="flex items-center gap-2">
              <svg class="w-5 h-5 text-indigo-200" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z"/>
              </svg>
              <h3 class="font-extrabold text-base">{{ q.question_text }}</h3>
            </div>
            <p v-if="q.description" class="text-indigo-200 text-sm mt-1 ml-7">{{ q.description }}</p>
          </div>

          <!-- Question card -->
          <div v-else class="bg-white rounded-2xl shadow-sm border border-slate-100 p-5">
            <div class="mb-3">
              <div class="flex items-start gap-2">
                <span class="w-6 h-6 rounded-full bg-primary/10 text-primary text-xs font-bold flex items-center justify-center flex-shrink-0 mt-0.5">
                  {{ questions.slice(0, i+1).filter(x => x.type !== 'section').length }}
                </span>
                <div>
                  <p class="font-semibold text-slate-800 text-sm leading-snug">
                    {{ q.question_text }}<span v-if="q.required" class="text-red-500 ml-0.5">*</span>
                  </p>
                  <p v-if="q.description" class="text-xs text-slate-400 mt-0.5">{{ q.description }}</p>
                </div>
              </div>
              <img v-if="q.image_url" :src="q.image_url" class="w-full h-auto rounded-xl mt-3 block"/>
            </div>

            <input v-if="q.type === 'text'" v-model="answers[q.id]" type="text" placeholder="พิมพ์คำตอบ..."
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            <textarea v-else-if="q.type === 'textarea'" v-model="answers[q.id]" rows="3" placeholder="พิมพ์คำตอบ..."
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm resize-none focus:outline-none focus:border-primary"/>
            <input v-else-if="q.type === 'number'" v-model.number="answers[q.id]" type="number" placeholder="0"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>

            <div v-else-if="q.type === 'choice'" class="space-y-2">
              <template v-for="opt in q.options" :key="opt.value">
                <label class="flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-all"
                  :class="answers[q.id] === opt.value ? 'border-primary bg-primary/5' : 'border-slate-200 hover:border-slate-300'">
                  <div :class="['w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0',
                    answers[q.id] === opt.value ? 'border-primary' : 'border-slate-300']">
                    <div v-if="answers[q.id] === opt.value" class="w-2 h-2 rounded-full bg-primary"/>
                  </div>
                  <input type="radio" v-model="answers[q.id]" :value="opt.value" class="sr-only"/>
                  <span class="text-sm text-slate-700">{{ opt.label }}</span>
                </label>
                <input v-if="opt.is_other && answers[q.id] === opt.value" v-model="otherText[q.id]" type="text"
                  placeholder="พิมพ์คำตอบของคุณ..."
                  class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"
                  style="width: calc(100% - 1.75rem); margin-left: 1.75rem;"/>
              </template>
            </div>

            <div v-else-if="q.type === 'multi_choice'" class="space-y-2">
              <template v-for="opt in q.options" :key="opt.value">
                <label class="flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-all"
                  :class="answers[q.id]?.includes(opt.value) ? 'border-primary bg-primary/5' : 'border-slate-200 hover:border-slate-300'">
                  <div :class="['w-4 h-4 rounded border-2 flex items-center justify-center flex-shrink-0',
                    answers[q.id]?.includes(opt.value) ? 'border-primary bg-primary' : 'border-slate-300']">
                    <svg v-if="answers[q.id]?.includes(opt.value)" class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="3">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
                    </svg>
                  </div>
                  <input type="checkbox" :value="opt.value" v-model="answers[q.id]" class="sr-only"/>
                  <span class="text-sm text-slate-700">{{ opt.label }}</span>
                </label>
                <input v-if="opt.is_other && answers[q.id]?.includes(opt.value)" v-model="otherText[q.id]" type="text"
                  placeholder="พิมพ์คำตอบของคุณ..."
                  class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"
                  style="width: calc(100% - 1.75rem); margin-left: 1.75rem;"/>
              </template>
            </div>

            <div v-else-if="q.type === 'rating'" class="flex flex-wrap gap-2">
              <button v-for="n in (q.settings?.max || 5)" :key="n" type="button" @click="answers[q.id] = n"
                :class="['w-10 h-10 rounded-xl border-2 font-bold text-sm transition-all',
                  answers[q.id] === n ? 'border-primary bg-primary text-white scale-110' : 'border-slate-200 text-slate-500 hover:border-primary hover:text-primary']">
                {{ n }}
              </button>
              <span v-if="answers[q.id]" class="ml-2 self-center text-xs text-slate-400">
                เลือก {{ answers[q.id] }} / {{ q.settings?.max || 5 }}
              </span>
            </div>

            <div v-else-if="q.type === 'yes_no'" class="flex gap-3">
              <button type="button" @click="answers[q.id] = 'yes'"
                :class="['flex-1 py-3 rounded-xl border-2 font-bold text-sm transition-all',
                  answers[q.id] === 'yes' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-emerald-300']">
                ✓ ใช่
              </button>
              <button type="button" @click="answers[q.id] = 'no'"
                :class="['flex-1 py-3 rounded-xl border-2 font-bold text-sm transition-all',
                  answers[q.id] === 'no' ? 'border-red-500 bg-red-50 text-red-700' : 'border-slate-200 text-slate-500 hover:border-red-300']">
                ✗ ไม่ใช่
              </button>
            </div>

            <!-- Evidence -->
            <div v-if="q.evidence_type && q.evidence_type !== 'none'" class="mt-4 pt-3 border-t border-slate-100 space-y-3">
              <p class="text-xs font-bold text-slate-500 flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5 text-primary/60" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32"/>
                </svg>
                หลักฐานอ้างอิง
                <span v-if="q.evidence_required" class="text-red-500">*</span>
                <span v-else class="text-slate-400 font-normal">(ไม่บังคับ)</span>
              </p>
              <div v-if="['upload','both'].includes(q.evidence_type)">
                <input type="file" :id="`sfile_${q.id}`"
                  accept="image/jpeg,image/png,image/webp,image/heic,image/gif,application/pdf"
                  @change="onFileChange(q.id, $event)" class="sr-only"/>
                <label v-if="!evidencePreviews[q.id] && !uploadingEvidence[q.id]" :for="`sfile_${q.id}`"
                  class="flex items-center justify-center gap-2 px-4 py-4 rounded-2xl border-2 border-dashed border-slate-300 cursor-pointer hover:border-primary hover:bg-primary/5 transition-all text-sm text-slate-500 hover:text-primary">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0z"/>
                  </svg>
                  เลือกภาพ / ถ่ายภาพ / ไฟล์ PDF
                </label>
                <div v-else-if="uploadingEvidence[q.id]" class="flex items-center gap-2 px-4 py-3 bg-blue-50 rounded-xl text-sm text-blue-700">
                  <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  กำลังอัปโหลด...
                </div>
                <div v-else-if="evidencePreviews[q.id]" class="flex items-start gap-3">
                  <img :src="evidencePreviews[q.id]" alt="หลักฐาน" class="w-24 h-24 object-cover rounded-xl border border-slate-200 shadow-sm flex-shrink-0"/>
                  <div class="flex flex-col gap-1.5 pt-1">
                    <span class="text-xs text-emerald-700 font-bold">✓ อัปโหลดแล้ว</span>
                    <p class="text-xs text-slate-400">≤ 1200px · JPEG 75%</p>
                    <button type="button" @click="rePickImage(q.id)" class="text-xs text-primary font-bold hover:underline text-left">เปลี่ยนภาพ</button>
                  </div>
                </div>
              </div>
              <div v-if="['url','both'].includes(q.evidence_type)">
                <div class="relative">
                  <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"/>
                  </svg>
                  <input v-model="evidenceLinks[q.id]" type="url" placeholder="https://drive.google.com/..."
                    class="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- Submit -->
      <button @click="submit" :disabled="submitting"
        class="w-full py-4 bg-primary text-white font-extrabold text-lg rounded-2xl shadow-lg hover:-translate-y-0.5 transition-all disabled:opacity-50">
        {{ submitting ? 'กำลังส่ง...' : 'ส่งแบบนิเทศ' }}
      </button>

    </template>
  </div>

  <!-- Cropper Modal -->
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="cropModal.open"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-4 font-sarabun"
        @click.self="cancelCrop">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg flex flex-col overflow-hidden" style="max-height:92dvh">
          <div class="px-5 py-3 border-b border-slate-100 flex-shrink-0">
            <p class="text-sm font-extrabold text-slate-700 mb-2">ครอบภาพหลักฐาน</p>
            <div class="flex flex-wrap gap-1.5">
              <button v-for="p in RATIO_PRESETS" :key="p.label" type="button" @click="cropAspect = p.value"
                :class="['px-3 py-1 text-xs font-bold rounded-lg transition-colors',
                  cropAspect === p.value ? 'bg-primary text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200']">
                {{ p.label }}
              </button>
            </div>
          </div>
          <div class="flex-1 overflow-hidden bg-slate-900" style="min-height:280px;max-height:55dvh">
            <Cropper ref="cropperRef" :src="cropModal.imageSrc" :stencil-props="stencilProps" class="w-full h-full" style="height:100%"/>
          </div>
          <div class="px-5 py-4 border-t border-slate-100 flex items-center justify-between gap-3 flex-shrink-0">
            <p class="text-xs text-slate-400">JPEG 75% · ≤ 1,200 px</p>
            <div class="flex gap-2">
              <button type="button" @click="cancelCrop" :disabled="cropping"
                class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200 disabled:opacity-50 transition-colors">
                ยกเลิก
              </button>
              <button type="button" @click="confirmCrop" :disabled="cropping"
                class="flex items-center gap-1.5 px-5 py-2 text-sm font-bold text-white bg-primary rounded-xl disabled:opacity-50 transition-all shadow-md">
                <svg v-if="cropping" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
                {{ cropping ? 'กำลังอัปโหลด...' : 'ยืนยัน & อัปโหลด' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
