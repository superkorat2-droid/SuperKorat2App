<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { ICON_MAP } from '../../composables/useIcons.js'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()
const isNew  = computed(() => route.name === 'adminSupervisionNew' || !route.params.id)

function publicUrl(token) {
  return `${window.location.origin}${window.location.pathname}#/supervision/${token}`
}

function copyPublicUrl(token) {
  navigator.clipboard.writeText(publicUrl(token))
  Swal.fire({ icon: 'success', title: 'คัดลอกแล้ว', showConfirmButton: false, timer: 1200 })
}

// ─── Respondent field definitions (must be before meta) ───────────────────────
const ALL_RESPONDENT_FIELD_DEFS = [
  { key: 'name',      label: 'ชื่อ-นามสกุล',     type: 'text' },
  { key: 'position',  label: 'ตำแหน่ง/วิทยฐานะ',  type: 'text' },
  { key: 'school',    label: 'โรงเรียน',           type: 'school_select' },
  { key: 'gender',    label: 'เพศ',                type: 'gender' },
  { key: 'age_range', label: 'ช่วงอายุ',           type: 'age_range' },
  { key: 'phone',     label: 'เบอร์โทรศัพท์',      type: 'tel' },
  { key: 'email',     label: 'อีเมล',              type: 'email' },
]

function normalizeRespondentFields(saved) {
  return ALL_RESPONDENT_FIELD_DEFS.map(def => {
    const found = Array.isArray(saved)
      ? saved.find(f => (typeof f === 'object' ? f.key : f) === def.key)
      : null
    if (!found) return { ...def, show: false, required: false }
    if (typeof found === 'string') return { ...def, show: true, required: ['name','position'].includes(def.key) }
    return { ...def, ...found }
  })
}

// ─── Form meta ───────────────────────────────────────────────────────────────
const meta = ref({
  title:             '',
  description:       '',
  status:            'draft',
  target:            'all',
  target_schools:    [],
  deadline:          '',
  allow_public:      false,
  respondent_type:   'school',
  respondent_fields: normalizeRespondentFields([]),
  show_on_home:      false,
  status_visibility: 'hidden',
  cover_image_url:   '',
})

// ── current user permission ─────────────────────────────────────
const currentProfile = ref(null)
const currentUserId  = ref(null)
const isAdminUser = computed(() =>
  ['super_admin','admin'].includes(currentProfile.value?.role)
)
const canPublish = computed(() =>
  isAdminUser.value
  || currentProfile.value?.role === 'supervisor'
  || currentProfile.value?.can_publish_supervision === true
)

// ─── Questions ───────────────────────────────────────────────────────────────
const questions = ref([])
const saving    = ref(false)
const loading   = ref(false)
const formId    = ref(null)
const publicToken = ref(null)

// ─── Schools (สำหรับเลือกเป้าหมาย "เฉพาะโรงเรียน") ──────────────────────────
const schools = ref([])
const schoolFilterDistrict = ref('all')
const schoolFilterGroup    = ref('all')
const schoolFilterSearch   = ref('')
const districts = computed(() => [...new Set(schools.value.map(s => s.district))].filter(Boolean).sort())
const schoolGroups = computed(() => [...new Set(schools.value.map(s => s.school_group))].filter(Boolean).sort())
const filteredSchools = computed(() => {
  const q = schoolFilterSearch.value.trim().toLowerCase()
  return schools.value.filter(s =>
    (schoolFilterDistrict.value === 'all' || s.district === schoolFilterDistrict.value) &&
    (schoolFilterGroup.value    === 'all' || s.school_group === schoolFilterGroup.value) &&
    (!q || s.name.toLowerCase().includes(q))
  )
})
const filteredDistricts = computed(() => [...new Set(filteredSchools.value.map(s => s.district))].filter(Boolean).sort())
function resetSchoolFilters() { schoolFilterDistrict.value = 'all'; schoolFilterGroup.value = 'all'; schoolFilterSearch.value = '' }
function selectAllSchools() { meta.value.target_schools = [...new Set([...meta.value.target_schools, ...filteredSchools.value.map(s => s.id)])] }
function clearTargetSchools() { meta.value.target_schools = [] }

const QUESTION_TYPES = [
  { value: 'text',         label: 'ข้อความสั้น',    icon: 'document' },
  { value: 'textarea',     label: 'ข้อความยาว',     icon: 'document' },
  { value: 'choice',       label: 'เลือกคำตอบเดียว', icon: 'clipboard' },
  { value: 'multi_choice', label: 'เลือกได้หลายข้อ', icon: 'clipboard' },
  { value: 'rating',       label: 'ระดับคะแนน 1-5',  icon: 'star' },
  { value: 'yes_no',       label: 'ใช่ / ไม่ใช่',    icon: 'beaker' },
  { value: 'number',       label: 'ตัวเลข',           icon: 'chart-bar' },
]

function newQuestion() {
  return {
    _key:              Date.now(),
    question_text:     '',
    description:       '',
    type:              'choice',
    options:           [{ value: 'a', label: 'ตัวเลือกที่ 1', score: '' }, { value: 'b', label: 'ตัวเลือกที่ 2', score: '' }],
    required:          true,
    settings:          {},
    sort_order:        questions.value.length,
    evidence_type:     'none',
    evidence_required: false,
    image_url:         '',
  }
}

function newSection() {
  return {
    _key:              Date.now(),
    question_text:     `หัวข้อส่วนที่ ${questions.value.filter(q => q.type === 'section').length + 1}`,
    description:       '',
    type:              'section',
    options:           [],
    required:          false,
    settings:          {},
    sort_order:        questions.value.length,
    evidence_type:     'none',
    evidence_required: false,
  }
}

function addSection() {
  questions.value.push(newSection())
}

function addQuestion() {
  questions.value.push(newQuestion())
}

function removeQuestion(i) {
  questions.value.splice(i, 1)
  reorder()
}

function moveUp(i) {
  if (i > 0) {
    [questions.value[i - 1], questions.value[i]] = [questions.value[i], questions.value[i - 1]]
    reorder()
  }
}

function moveDown(i) {
  if (i < questions.value.length - 1) {
    [questions.value[i], questions.value[i + 1]] = [questions.value[i + 1], questions.value[i]]
    reorder()
  }
}

function reorder() {
  questions.value.forEach((q, idx) => q.sort_order = idx)
}

function addOption(q) {
  const n = q.options.length + 1
  q.options.push({ value: `opt_${Date.now()}`, label: `ตัวเลือกที่ ${n}`, score: '', is_other: false })
}

function removeOption(q, i) {
  if (q.options.length > 2) q.options.splice(i, 1)
}

function onTypeChange(q) {
  if (['choice', 'multi_choice'].includes(q.type) && q.options.length === 0) {
    q.options = [{ value: 'a', label: 'ตัวเลือกที่ 1', score: '' }, { value: 'b', label: 'ตัวเลือกที่ 2', score: '' }]
  }
  if (q.type === 'rating') {
    q.settings = { max: 5 }
    q.options = []
  }
  if (['text', 'textarea', 'number', 'yes_no'].includes(q.type)) {
    q.options = []
  }
}

// ─── Cover image (form) + question image upload ──────────────────────────────
const { uploadFile: uploadImgExternal } = useExternalUpload()
const coverFileInput      = ref(null)
const questionFileInput   = ref(null)
const activeQuestionIndex = ref(-1)
const uploadingCover      = ref(false)
const uploadingQuestionImage = ref(false)

async function uploadPlainImage(file, category) {
  if (externalUploadEnabled) return uploadImgExternal(file, category)
  const ext = file.name.split('.').pop() || 'jpg'
  const fileName = `${category}-${Date.now()}.${ext}`
  const { data, error } = await supabase.storage.from('supervision-evidence').upload(fileName, file, { contentType: file.type })
  if (error) throw error
  return supabase.storage.from('supervision-evidence').getPublicUrl(fileName).data.publicUrl
}

function triggerCoverUpload() { coverFileInput.value?.click() }
async function onCoverFileSelected(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  uploadingCover.value = true
  try {
    meta.value.cover_image_url = await uploadPlainImage(file, 'supervision-cover')
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: err.message })
  } finally {
    uploadingCover.value = false
  }
}
async function clearCoverImage() {
  if (meta.value.cover_image_url) await deleteUploadedFile(meta.value.cover_image_url)
  meta.value.cover_image_url = ''
}

function triggerQuestionUpload(i) { activeQuestionIndex.value = i; questionFileInput.value?.click() }
async function onQuestionFileSelected(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file || activeQuestionIndex.value < 0) return
  const q = questions.value[activeQuestionIndex.value]
  uploadingQuestionImage.value = true
  try {
    q.image_url = await uploadPlainImage(file, 'supervision-question')
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: err.message })
  } finally {
    uploadingQuestionImage.value = false
  }
}
async function clearQuestionImage(q) {
  if (q.image_url) await deleteUploadedFile(q.image_url)
  q.image_url = ''
}

// ─── Load existing form ──────────────────────────────────────────────────────
async function load() {
  if (isNew.value) return
  loading.value = true
  const { data: form, error } = await supabase
    .from('supervision_forms')
    .select('*')
    .eq('id', route.params.id)
    .single()

  if (error || !form) {
    Swal.fire({ icon: 'error', title: 'ไม่พบแบบนิเทศ' })
    router.push('/dashboard/supervision')
    return
  }

  formId.value     = form.id
  publicToken.value = form.public_token
  meta.value = {
    title:             form.title,
    description:       form.description || '',
    status:            form.status,
    target:            form.target,
    target_schools:    form.target_schools || [],
    deadline:          form.deadline ? form.deadline.slice(0, 16) : '',
    allow_public:      form.allow_public,
    respondent_type:   form.respondent_type || 'school',
    respondent_fields: normalizeRespondentFields(form.respondent_fields || []),
    show_on_home:      form.show_on_home      || false,
    status_visibility: form.status_visibility || 'hidden',
    cover_image_url:   form.cover_image_url    || '',
  }

  const { data: qs } = await supabase
    .from('supervision_questions')
    .select('*')
    .eq('form_id', form.id)
    .order('sort_order')

  questions.value = (qs || []).map(q => ({
    ...q,
    _key:              q.id,
    evidence_type:     q.evidence_type || 'none',
    evidence_required: q.evidence_required || false,
    image_url:         q.image_url || '',
    options:           (q.options || []).map(o => ({ score: '', is_other: false, ...o })),
  }))
  loading.value = false
}

// ─── Save ────────────────────────────────────────────────────────────────────
async function save() {
  if (!meta.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณาใส่ชื่อแบบนิเทศ' })
    return
  }

  saving.value = true

  const payload = {
    title:             meta.value.title.trim(),
    description:       meta.value.description.trim() || null,
    status:            meta.value.status,
    target:            meta.value.target,
    target_schools:    meta.value.target_schools,
    deadline:          meta.value.deadline || null,
    allow_public:      meta.value.allow_public,
    respondent_type:   meta.value.respondent_type,
    respondent_fields: meta.value.respondent_fields,
    show_on_home:      meta.value.show_on_home,
    status_visibility: meta.value.status_visibility,
    cover_image_url:   meta.value.cover_image_url,
    updated_at:        new Date().toISOString(),
  }

  let id = formId.value

  if (isNew.value) {
    const { data, error } = await supabase
      .from('supervision_forms')
      .insert({ ...payload, created_by: currentUserId.value })
      .select()
      .single()
    if (error) {
      Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
      saving.value = false
      return
    }
    id = data.id
    publicToken.value = data.public_token
    formId.value = id
  } else {
    const { error } = await supabase
      .from('supervision_forms')
      .update(payload)
      .eq('id', id)
    if (error) {
      Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
      saving.value = false
      return
    }
  }

  // Save questions: delete all then re-insert
  await supabase.from('supervision_questions').delete().eq('form_id', id)

  if (questions.value.length > 0) {
    const qRows = questions.value.map((q, idx) => ({
      form_id:           id,
      sort_order:        idx,
      question_text:     q.question_text.trim() || '(ไม่มีชื่อคำถาม)',
      description:       q.description?.trim() || null,
      type:              q.type,
      options:           q.options || [],
      required:          q.required,
      settings:          q.settings || {},
      evidence_type:     q.evidence_type || 'none',
      evidence_required: q.evidence_required || false,
      image_url:         q.image_url || '',
    }))
    const { error } = await supabase.from('supervision_questions').insert(qRows)
    if (error) {
      Swal.fire({ icon: 'error', title: 'บันทึกคำถามไม่สำเร็จ', text: error.message })
      saving.value = false
      return
    }
  }

  saving.value = false
  await Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1000 })

  if (isNew.value) {
    router.replace(`/dashboard/supervision/${id}/edit`)
  } else {
    load()
  }
}

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  currentUserId.value = user?.id
  if (user?.id) {
    const { data: p } = await supabase
      .from('profiles').select('role, can_publish_supervision').eq('id', user.id).single()
    currentProfile.value = p
  }
  const { data: sc } = await supabase.from('schools').select('id, name, district, school_group').order('district').order('name')
  schools.value = sc || []
  load()
})
</script>

<template>
  <div class="font-sarabun space-y-6 max-w-4xl">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <button @click="router.push('/dashboard/supervision')"
          class="flex items-center gap-1 text-sm text-slate-400 hover:text-slate-600 mb-1 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
          </svg>
          กลับรายการ
        </button>
        <h1 class="text-2xl font-extrabold text-slate-800">
          {{ isNew ? 'สร้างแบบนิเทศใหม่' : 'แก้ไขแบบนิเทศ' }}
        </h1>
      </div>
      <div class="flex gap-2">
        <button v-if="!isNew" @click="router.push(`/dashboard/supervision/${formId}/results`)"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
          <SvgIcon name="chart-bar" class="w-4 h-4"/>
          ดูผลลัพธ์
        </button>
        <button @click="save" :disabled="saving"
          class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
          <SvgIcon name="document" class="w-4 h-4"/>
          {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else>
      <!-- Meta section -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
        <h2 class="font-bold text-slate-700 flex items-center gap-2">
          <SvgIcon name="document" class="w-5 h-5 text-primary"/>
          ข้อมูลทั่วไป
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <!-- Title -->
          <div class="sm:col-span-2">
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">ชื่อแบบนิเทศ <span class="text-red-500">*</span></label>
            <input v-model="meta.title" type="text" placeholder="เช่น แบบนิเทศการเรียนการสอน ภาคเรียนที่ 1/2567"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>

          <!-- Description -->
          <div class="sm:col-span-2">
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">คำอธิบาย</label>
            <textarea v-model="meta.description" rows="2" placeholder="อธิบายวัตถุประสงค์ของแบบนิเทศนี้ (ไม่บังคับ)"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm resize-none focus:outline-none focus:border-primary"/>
          </div>

          <!-- Cover image -->
          <div class="sm:col-span-2">
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">รูปหน้าปก (ไม่บังคับ)</label>
            <p class="text-xs text-slate-400 mb-2">แสดงในหน้าปกก่อนเริ่มทำแบบสอบถาม (เหมือน Google Form)</p>
            <div v-if="meta.cover_image_url" class="relative rounded-xl overflow-hidden mb-2 bg-slate-100 max-w-sm">
              <img :src="meta.cover_image_url" class="w-full h-auto block"/>
              <button @click="clearCoverImage" type="button"
                class="absolute top-2 right-2 w-7 h-7 bg-white/90 hover:bg-white rounded-full flex items-center justify-center shadow">
                <svg class="w-3.5 h-3.5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <button @click="triggerCoverUpload" :disabled="uploadingCover" type="button"
              class="px-3 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 text-slate-600 rounded-xl transition-colors disabled:opacity-50">
              {{ uploadingCover ? 'กำลังอัปโหลด...' : (meta.cover_image_url ? '🖼️ เปลี่ยนรูป' : '🖼️ อัปโหลดรูปหน้าปก') }}
            </button>
          </div>

          <!-- Status -->
          <div>
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">สถานะ</label>
            <select v-model="meta.status"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="draft">ร่าง (ยังไม่เผยแพร่)</option>
              <option v-if="canPublish" value="published">เผยแพร่แล้ว</option>
              <option v-if="canPublish" value="closed">ปิดรับแล้ว</option>
            </select>
          </div>

          <!-- Target -->
          <div>
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">เป้าหมาย</label>
            <select v-model="meta.target"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="all">ทุกโรงเรียน</option>
              <option value="selected">เลือกเฉพาะโรงเรียน</option>
            </select>
          </div>

          <!-- Target schools picker (แสดงเฉพาะเมื่อเลือก "เฉพาะโรงเรียน") -->
          <div v-if="meta.target === 'selected'" class="sm:col-span-2 bg-slate-50 rounded-xl p-4 space-y-2">
            <div class="flex items-center justify-between mb-1">
              <p class="text-xs font-bold text-slate-600">
                เลือกโรงเรียนเป้าหมาย ({{ meta.target_schools.length }} โรงเรียน)
              </p>
              <div class="flex gap-3">
                <button type="button" @click="selectAllSchools" class="text-xs text-primary font-bold hover:underline">เลือกทั้งหมด</button>
                <button type="button" @click="clearTargetSchools" class="text-xs text-slate-400 font-bold hover:underline">ล้าง</button>
              </div>
            </div>

            <!-- ตัวกรอง: ชื่อโรงเรียน / อำเภอ / ศูนย์เครือข่าย -->
            <div class="flex flex-wrap items-center gap-2">
              <div class="relative flex-1 min-w-[160px]">
                <SvgIcon name="magnify" class="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400"/>
                <input v-model="schoolFilterSearch" type="text" placeholder="ค้นหาชื่อโรงเรียน..."
                  class="w-full pl-8 pr-2.5 py-1.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-primary"/>
              </div>
              <select v-model="schoolFilterDistrict" class="px-2.5 py-1.5 border border-slate-200 rounded-lg text-xs bg-white focus:outline-none focus:border-primary">
                <option value="all">ทุกอำเภอ</option>
                <option v-for="dist in districts" :key="dist" :value="dist">อ.{{ dist }}</option>
              </select>
              <select v-model="schoolFilterGroup" class="px-2.5 py-1.5 border border-slate-200 rounded-lg text-xs bg-white focus:outline-none focus:border-primary">
                <option value="all">ทุกศูนย์เครือข่าย</option>
                <option v-for="g in schoolGroups" :key="g" :value="g">{{ g }}</option>
              </select>
              <button v-if="schoolFilterDistrict !== 'all' || schoolFilterGroup !== 'all' || schoolFilterSearch"
                type="button" @click="resetSchoolFilters"
                class="text-xs text-slate-400 hover:text-slate-600 font-bold">✕ ทั้งหมด</button>
              <span class="text-xs text-slate-400 w-full text-right">พบ {{ filteredSchools.length }} โรงเรียน</span>
            </div>

            <div class="max-h-64 overflow-y-auto border border-slate-200 bg-white rounded-xl divide-y divide-slate-100">
              <template v-for="dist in filteredDistricts" :key="dist">
                <p class="px-3 py-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider bg-slate-50 sticky top-0">อ.{{ dist }}</p>
                <label v-for="s in filteredSchools.filter(x => x.district === dist)" :key="s.id"
                  class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-slate-50">
                  <input type="checkbox" :value="s.id" v-model="meta.target_schools"
                    class="rounded border-slate-300 text-primary focus:ring-primary/30"/>
                  <span class="flex-1">{{ s.name }}</span>
                  <span v-if="s.school_group" class="text-[10px] text-slate-400">{{ s.school_group }}</span>
                </label>
              </template>
              <p v-if="!schools.length" class="px-3 py-3 text-xs text-slate-400 text-center">กำลังโหลดรายชื่อโรงเรียน...</p>
              <p v-else-if="!filteredSchools.length" class="px-3 py-3 text-xs text-slate-400 text-center">ไม่พบโรงเรียนตามตัวกรอง</p>
            </div>
            <p v-if="meta.target_schools.length === 0" class="text-xs text-amber-600">
              ⚠️ ยังไม่ได้เลือกโรงเรียน — ถ้าไม่เลือกจะไม่มีโรงเรียนใดเห็นแบบนิเทศนี้
            </p>
          </div>

          <!-- Deadline -->
          <div>
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">กำหนดส่ง</label>
            <input v-model="meta.deadline" type="datetime-local"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>

          <!-- Respondent type -->
          <div>
            <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">ประเภทผู้ตอบ</label>
            <div class="flex gap-3">
              <label :class="['flex items-center gap-2 px-4 py-2.5 rounded-xl border-2 cursor-pointer transition-all text-sm font-bold',
                meta.respondent_type === 'school'
                  ? 'border-primary bg-primary/5 text-primary'
                  : 'border-slate-200 text-slate-500 hover:border-slate-300']">
                <input type="radio" v-model="meta.respondent_type" value="school" class="sr-only"/>
                <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0012 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75z"/>
                </svg>
                โรงเรียน (1 ต่อโรง)
              </label>
              <label :class="['flex items-center gap-2 px-4 py-2.5 rounded-xl border-2 cursor-pointer transition-all text-sm font-bold',
                meta.respondent_type === 'individual'
                  ? 'border-indigo-500 bg-indigo-50 text-indigo-700'
                  : 'border-slate-200 text-slate-500 hover:border-slate-300']">
                <input type="radio" v-model="meta.respondent_type" value="individual" class="sr-only"/>
                <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                </svg>
                บุคคล (อบรม/สำรวจ)
              </label>
            </div>
          </div>

          <!-- Respondent fields (individual only) -->
          <div v-if="meta.respondent_type === 'individual'"
            class="bg-indigo-50 rounded-xl p-4 space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-xs font-bold text-indigo-700">ฟิลด์ข้อมูลผู้ตอบ</p>
              <span :class="['text-xs font-bold px-2.5 py-1 rounded-full',
                meta.respondent_fields.some(f => f.show)
                  ? 'bg-indigo-200 text-indigo-800'
                  : 'bg-slate-200 text-slate-600']">
                {{ meta.respondent_fields.some(f => f.show)
                  ? `แสดง ${meta.respondent_fields.filter(f=>f.show).length} ฟิลด์`
                  : 'ไม่เก็บข้อมูลส่วนตัว (Anonymous)' }}
              </span>
            </div>
            <div class="space-y-1.5">
              <div v-for="f in meta.respondent_fields" :key="f.key"
                class="flex items-center gap-3 bg-white rounded-xl px-3 py-2.5">
                <!-- Show toggle -->
                <label class="relative inline-flex items-center cursor-pointer flex-shrink-0">
                  <input type="checkbox" v-model="f.show"
                    @change="() => { if (!f.show) f.required = false }"
                    class="sr-only peer"/>
                  <div class="w-8 h-4 bg-slate-200 rounded-full peer peer-checked:bg-indigo-500 transition-colors
                              after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                              after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:after:translate-x-4"/>
                </label>
                <span :class="['text-sm font-medium flex-1', f.show ? 'text-slate-700' : 'text-slate-400']">
                  {{ f.label }}
                </span>
                <!-- Required toggle (show only when field is shown) -->
                <Transition
                  enter-active-class="transition duration-150"
                  enter-from-class="opacity-0 scale-95"
                  enter-to-class="opacity-100 scale-100"
                  leave-active-class="transition duration-100"
                  leave-from-class="opacity-100"
                  leave-to-class="opacity-0 scale-95">
                  <div v-if="f.show" class="flex items-center gap-1.5 flex-shrink-0">
                    <button type="button" @click="f.required = !f.required"
                      :class="['text-xs font-bold px-2.5 py-1 rounded-lg transition-colors',
                        f.required
                          ? 'bg-red-100 text-red-600'
                          : 'bg-slate-100 text-slate-400 hover:bg-slate-200']">
                      {{ f.required ? 'บังคับ' : 'ไม่บังคับ' }}
                    </button>
                  </div>
                </Transition>
              </div>
            </div>
            <p class="text-xs text-indigo-500">
              ปิดทุกฟิลด์ = Anonymous (ไม่เก็บข้อมูลส่วนตัวใดๆ)
            </p>
          </div>

          <!-- Allow public -->
          <div class="flex items-start gap-3 pt-5">
            <label class="relative inline-flex items-center cursor-pointer mt-0.5">
              <input type="checkbox" v-model="meta.allow_public" class="sr-only peer"/>
              <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-primary transition-colors
                          after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                          after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5"/>
            </label>
            <div>
              <p class="text-sm font-bold text-slate-700">เปิดลิงค์สาธารณะ</p>
              <p class="text-xs text-slate-400">ใครก็ตามที่มีลิงค์สามารถกรอกโดยไม่ต้อง login</p>
            </div>
          </div>

          <!-- Show on home -->
          <div class="flex items-start gap-3">
            <label class="relative inline-flex items-center cursor-pointer mt-0.5">
              <input type="checkbox" v-model="meta.show_on_home" class="sr-only peer"/>
              <div class="w-10 h-5 bg-slate-200 rounded-full peer peer-checked:bg-indigo-500 transition-colors
                          after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                          after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5"/>
            </label>
            <div>
              <p class="text-sm font-bold text-slate-700">แสดงในหน้าแรก</p>
              <p class="text-xs text-slate-400">ปรากฏใน Section "แบบนิเทศและแบบสอบถาม" ของเว็บไซต์</p>
            </div>
          </div>

          <!-- Status option: hide if staff without publish permission -->
          <div v-if="!canPublish">
            <p class="text-xs text-amber-600 bg-amber-50 rounded-xl px-3 py-2">
              ⚠️ คุณไม่มีสิทธิ์เผยแพร่แบบนิเทศ — ติดต่อ admin เพื่อขอสิทธิ์
            </p>
          </div>
        </div>

        <!-- Status access visibility: only show when show_on_home -->
        <div v-if="meta.show_on_home" class="bg-indigo-50 rounded-xl p-4 space-y-2">
          <p class="text-xs font-bold text-indigo-700">สถานะโรงเรียนในหน้าแรก</p>
          <div class="flex flex-wrap gap-2">
            <label v-for="opt in [
              { value:'hidden',        label:'ซ่อน',          desc:'ไม่แสดงปุ่มดูสถานะ' },
              { value:'authenticated', label:'Login เท่านั้น', desc:'เฉพาะผู้ใช้ที่ login' },
              { value:'public',        label:'สาธารณะ',       desc:'ทุกคนเห็นได้' },
            ]" :key="opt.value"
              :class="['flex-1 min-w-[130px] flex items-center gap-2.5 px-3 py-2.5 rounded-xl border-2 cursor-pointer transition-all',
                meta.status_visibility === opt.value
                  ? 'border-indigo-500 bg-indigo-100 text-indigo-700'
                  : 'border-slate-200 bg-white text-slate-600 hover:border-indigo-300']">
              <input type="radio" v-model="meta.status_visibility" :value="opt.value" class="sr-only"/>
              <!-- icon per option -->
              <svg v-if="opt.value === 'hidden'" class="w-4 h-4 flex-shrink-0 opacity-60" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
              </svg>
              <svg v-else-if="opt.value === 'authenticated'" class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
              </svg>
              <svg v-else class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253"/>
              </svg>
              <div>
                <p class="text-xs font-bold">{{ opt.label }}</p>
                <p class="text-[10px] opacity-70">{{ opt.desc }}</p>
              </div>
            </label>
          </div>
        </div>

        <!-- Public link preview -->
        <div v-if="!isNew && meta.allow_public && publicToken"
          class="flex items-center gap-3 p-3 bg-blue-50 rounded-xl border border-blue-100">
          <SvgIcon name="link" class="w-4 h-4 text-blue-600 flex-shrink-0"/>
          <span class="text-xs text-blue-700 font-mono truncate flex-1">
            {{ publicUrl(publicToken) }}
          </span>
          <button @click="copyPublicUrl(publicToken)"
            class="text-xs font-bold text-blue-600 hover:text-blue-800 flex-shrink-0">
            คัดลอก
          </button>
        </div>
      </div>

      <!-- Questions section -->
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="font-bold text-slate-700 flex items-center gap-2">
            <SvgIcon name="clipboard" class="w-5 h-5 text-primary"/>
            คำถาม ({{ questions.filter(q=>q.type!=='section').length }} ข้อ
            <span v-if="questions.filter(q=>q.type==='section').length">
              · {{ questions.filter(q=>q.type==='section').length }} หมวด
            </span>)
          </h2>
          <div class="flex gap-2">
            <button @click="addSection"
              class="flex items-center gap-1.5 px-3 py-2 text-sm font-bold bg-indigo-50 text-indigo-600 rounded-xl hover:bg-indigo-100 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z"/>
              </svg>
              หัวข้อส่วน
            </button>
            <button @click="addQuestion"
              class="flex items-center gap-1.5 px-4 py-2 text-sm font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors">
              <SvgIcon name="plus" class="w-4 h-4"/>
              เพิ่มคำถาม
            </button>
          </div>
        </div>

        <div v-if="questions.length === 0"
          class="text-center py-10 border-2 border-dashed border-slate-200 rounded-xl text-slate-400">
          <SvgIcon name="clipboard" class="w-10 h-10 mx-auto mb-2 opacity-30"/>
          <p class="text-sm">ยังไม่มีคำถาม — กด "เพิ่มคำถาม" เพื่อเริ่ม</p>
        </div>

        <div class="space-y-3">
          <div v-for="(q, i) in questions" :key="q._key">

            <!-- ─── Section card ──────────────────────────────────────────── -->
            <div v-if="q.type === 'section'"
              class="border-2 border-indigo-200 bg-indigo-50 rounded-2xl p-4">
              <div class="flex items-start gap-3">
                <!-- up/down -->
                <div class="flex flex-col gap-0.5 flex-shrink-0 mt-1">
                  <button @click="moveUp(i)" :disabled="i===0" type="button"
                    class="w-6 h-6 flex items-center justify-center rounded-lg text-indigo-400 hover:bg-indigo-100 disabled:opacity-20 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
                    </svg>
                  </button>
                  <button @click="moveDown(i)" :disabled="i===questions.length-1" type="button"
                    class="w-6 h-6 flex items-center justify-center rounded-lg text-indigo-400 hover:bg-indigo-100 disabled:opacity-20 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                    </svg>
                  </button>
                </div>
                <svg class="w-5 h-5 text-indigo-500 flex-shrink-0 mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z"/>
                </svg>
                <div class="flex-1 min-w-0 space-y-2">
                  <input v-model="q.question_text" type="text" placeholder="ชื่อหัวข้อส่วน เช่น หมวด 1: การจัดการเรียนการสอน"
                    class="w-full px-3 py-2 border border-indigo-200 bg-white rounded-xl text-sm font-bold text-indigo-700 focus:outline-none focus:border-indigo-400"/>
                  <input v-model="q.description" type="text" placeholder="คำอธิบายหัวข้อ (ไม่บังคับ)"
                    class="w-full px-3 py-2 border border-indigo-100 bg-white/70 rounded-xl text-xs focus:outline-none focus:border-indigo-300"/>
                </div>
                <button @click="removeQuestion(i)" type="button"
                  class="w-7 h-7 flex items-center justify-center text-indigo-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors flex-shrink-0">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- ─── Question card ─────────────────────────────────────────── -->
            <div v-else
              class="border border-slate-200 rounded-2xl p-4 space-y-3 hover:border-primary/40 transition-colors">

              <!-- Question header -->
              <div class="flex items-start gap-3">
                <div class="flex flex-col gap-0.5 flex-shrink-0 mt-1">
                  <button @click="moveUp(i)" :disabled="i===0" type="button"
                    class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
                    </svg>
                  </button>
                  <button @click="moveDown(i)" :disabled="i===questions.length-1" type="button"
                    class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                    </svg>
                  </button>
                </div>

                <div class="w-7 h-7 rounded-full bg-primary/10 text-primary text-xs font-bold flex items-center justify-center flex-shrink-0 mt-0.5">
                  {{ questions.slice(0, i+1).filter(x => x.type !== 'section').length }}
                </div>

                <div class="flex-1 min-w-0 space-y-2">
                  <input v-model="q.question_text" type="text" :placeholder="`คำถามข้อที่ ${i+1}`"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:border-primary"/>
                  <input v-model="q.description" type="text" placeholder="คำอธิบายเพิ่มเติม (ไม่บังคับ)"
                    class="w-full px-3 py-2 border border-slate-100 bg-slate-50 rounded-xl text-xs focus:outline-none focus:border-primary"/>
                  <div v-if="q.image_url" class="relative rounded-lg overflow-hidden bg-slate-100 max-w-[200px]">
                    <img :src="q.image_url" class="w-full h-auto block"/>
                    <button @click="clearQuestionImage(q)" type="button"
                      class="absolute top-1 right-1 w-6 h-6 bg-white/90 hover:bg-white rounded-full flex items-center justify-center shadow">
                      <svg class="w-3 h-3 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </div>
                  <button v-else @click="triggerQuestionUpload(i)" :disabled="uploadingQuestionImage" type="button"
                    class="flex items-center gap-1 text-xs text-slate-400 hover:text-primary transition-colors disabled:opacity-50">
                    🖼️ แทรกภาพประกอบคำถาม
                  </button>
                </div>

                <div class="flex items-center gap-2 flex-shrink-0">
                  <select v-model="q.type" @change="onTypeChange(q)"
                    class="px-2 py-1.5 border border-slate-200 rounded-xl text-xs bg-white focus:outline-none focus:border-primary">
                    <option v-for="t in QUESTION_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
                  </select>
                  <button @click="q.required = !q.required" type="button"
                    :class="['text-xs font-bold px-2.5 py-1.5 rounded-xl transition-colors',
                      q.required ? 'bg-red-100 text-red-600' : 'bg-slate-100 text-slate-400']">
                    {{ q.required ? 'จำเป็น' : 'ไม่บังคับ' }}
                  </button>
                  <button @click="removeQuestion(i)" type="button"
                    class="w-7 h-7 flex items-center justify-center text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              </div>

              <!-- Rating settings -->
              <div v-if="q.type === 'rating'" class="ml-16 flex items-center gap-3">
                <span class="text-xs text-slate-500">ระดับสูงสุด:</span>
                <select v-model.number="q.settings.max"
                  class="px-3 py-1.5 border border-slate-200 rounded-xl text-xs bg-white focus:outline-none focus:border-primary">
                  <option :value="3">3 ระดับ</option>
                  <option :value="4">4 ระดับ</option>
                  <option :value="5">5 ระดับ</option>
                  <option :value="10">10 ระดับ</option>
                </select>
                <span class="text-xs text-slate-400">ผู้กรอกเลือก 1–{{ q.settings.max || 5 }}</span>
                <span class="text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">📊 นับคะแนน</span>
              </div>

              <!-- yes_no score info -->
              <div v-if="q.type === 'yes_no'" class="ml-16 flex items-center gap-3">
                <div class="px-4 py-1.5 rounded-xl border-2 border-emerald-200 bg-emerald-50 text-emerald-700 text-xs font-bold">ใช่ = 100%</div>
                <div class="px-4 py-1.5 rounded-xl border-2 border-red-200 bg-red-50 text-red-700 text-xs font-bold">ไม่ใช่ = 0%</div>
                <span class="text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">📊 นับคะแนน</span>
              </div>

              <!-- Choice options + optional score -->
              <div v-if="['choice','multi_choice'].includes(q.type)" class="ml-16 space-y-2">
                <div class="flex items-center gap-1 mb-1">
                  <span class="text-xs text-slate-400">ใส่คะแนนต่อตัวเลือกเพื่อให้ระบบคำนวณ (ไม่บังคับ)</span>
                </div>
                <div v-for="(opt, oi) in q.options" :key="oi" class="flex items-center gap-2">
                  <div :class="['w-4 h-4 flex-shrink-0 border-2 border-slate-300',
                    q.type === 'choice' ? 'rounded-full' : 'rounded']"/>
                  <input v-model="opt.label" type="text" :placeholder="`ตัวเลือกที่ ${oi+1}`"
                    class="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-primary"/>
                  <input v-model.number="opt.score" type="number" min="0" placeholder="คะแนน"
                    class="w-20 px-2 py-1.5 border border-slate-200 rounded-lg text-xs text-center focus:outline-none focus:border-emerald-400"/>
                  <label class="flex items-center gap-1 flex-shrink-0 cursor-pointer" title="เป็นตัวเลือก 'อื่นๆ' — ผู้ตอบจะเห็นช่องให้พิมพ์ข้อความเอง">
                    <input type="checkbox" v-model="opt.is_other" class="w-3.5 h-3.5 rounded accent-primary cursor-pointer"/>
                    <span class="text-[10px] text-slate-500">อื่นๆ</span>
                  </label>
                  <button @click="removeOption(q, oi)" :disabled="q.options.length <= 2" type="button"
                    class="w-5 h-5 flex items-center justify-center text-slate-300 hover:text-red-500 disabled:opacity-20 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
                <div class="flex items-center justify-between mt-1">
                  <button @click="addOption(q)" type="button"
                    class="flex items-center gap-1 text-xs text-primary/70 hover:text-primary transition-colors">
                    <SvgIcon name="plus" class="w-3.5 h-3.5"/>
                    เพิ่มตัวเลือก
                  </button>
                  <span v-if="q.options.some(o => o.score !== '' && o.score !== null && o.score !== undefined)"
                    class="text-xs bg-emerald-100 text-emerald-700 font-bold px-2 py-0.5 rounded-full">📊 นับคะแนน</span>
                </div>
              </div>

              <!-- Evidence settings -->
              <div class="ml-16 flex flex-wrap items-center gap-3 pt-2 border-t border-slate-100">
                <svg class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13"/>
                </svg>
                <span class="text-xs text-slate-500 flex-shrink-0">หลักฐาน:</span>
                <select v-model="q.evidence_type"
                  class="px-2 py-1.5 border border-slate-200 rounded-xl text-xs bg-white focus:outline-none focus:border-primary">
                  <option value="none">ไม่ต้องการ</option>
                  <option value="upload">อัปโหลดภาพ/ไฟล์</option>
                  <option value="url">ลิงค์ URL</option>
                  <option value="both">ทั้งสองอย่าง</option>
                </select>
                <label v-if="q.evidence_type !== 'none'" class="flex items-center gap-1.5 cursor-pointer">
                  <input type="checkbox" v-model="q.evidence_required"
                    class="w-3.5 h-3.5 rounded accent-primary cursor-pointer"/>
                  <span class="text-xs text-slate-600">บังคับ</span>
                </label>
              </div>
            </div>

          </div>
        </div>

        <!-- Add buttons bottom -->
        <div v-if="questions.length > 0" class="flex items-center justify-center gap-4 pt-2">
          <button @click="addSection"
            class="text-sm text-indigo-500 hover:text-indigo-700 font-medium transition-colors">
            + เพิ่มหัวข้อส่วน
          </button>
          <span class="text-slate-200">|</span>
          <button @click="addQuestion"
            class="text-sm text-primary/70 hover:text-primary font-medium transition-colors">
            + เพิ่มคำถามอีกข้อ
          </button>
        </div>
      </div>
    </template>

    <input ref="coverFileInput" type="file" accept="image/*" class="hidden" @change="onCoverFileSelected"/>
    <input ref="questionFileInput" type="file" accept="image/*" class="hidden" @change="onQuestionFileSelected"/>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
