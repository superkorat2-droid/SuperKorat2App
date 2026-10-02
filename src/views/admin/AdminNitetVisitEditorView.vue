<script setup>
/**
 * AdminNitetVisitEditorView — กรอกบันทึกการนิเทศ
 *
 * ออกแบบให้กรอกบนมือถือหน้างานเป็นหลัก:
 *   • "บันทึกด่วน" (status=draft) กรอกแค่ ไปที่ไหน + วันที่ + รูป ก็บันทึกได้
 *   • useFormDraft กันข้อมูลหายตอนสลับไปเปิดกล้องแล้วเบราว์เซอร์รีโหลดแท็บ
 *   • ทุกช่องบรรยายมีปุ่มไมค์
 *   • ปุ่มบันทึกลอยติดขอบล่าง
 *
 * เปิดจากปฏิทินได้ด้วย ?event=<id>&school=<id> แล้วเติมข้อมูลจากแผนให้อัตโนมัติ
 * หรือเลือกนัดจากในฟอร์มเอง: "ปฏิทินของฉัน" (นัดที่สร้างเอง/ถูกใส่ชื่อร่วม) + "แผนทางการ" (มีเลขที่คำสั่ง)
 * ทุกทางเข้าเรียก applyPlan() ตัวเดียวกัน — ข้อมูลที่เติมเป็นสำเนา แก้ปฏิทินทีหลังบันทึกไม่เปลี่ยนตาม
 */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Swal from 'sweetalert2'
import { supabase } from '../../supabase'
import { useUploadGc } from '../../composables/useUploadGc'
import { useFormDraft } from '../../composables/useFormDraft'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { useGroupOptions } from '../../composables/useLibraryOptions'
import PlacePicker from '../../components/nithet/PlacePicker.vue'
import TopicChips from '../../components/nithet/TopicChips.vue'
import VoiceTextarea from '../../components/nithet/VoiceTextarea.vue'
import VisitPhotoUploader from '../../components/nithet/VisitPhotoUploader.vue'
import LinkListEditor from '../../components/nithet/LinkListEditor.vue'
import {
  VISIT_TYPES, VISIT_WRITER_ROLES, currentAcademicYear, currentTerm,
  resultLabels, visitTypeFromEvent, typeMeta, refKindMeta,
} from '../../composables/useNithetVisits'

const route  = useRoute()
const router = useRouter()
const isNew  = computed(() => !route.params.id)
const gc     = useUploadGc()

const { config, fetchConfig } = useAreaConfig()
const { groupOptions, groupLabel, keyFromLabel } = useGroupOptions(config)

const loading = ref(true)
const saving  = ref(false)
const canWrite = ref(true)
const myId    = ref('')
const people  = ref([])
const eventTopics  = ref([])
const officialPlans = ref([])   // nithet_events ที่มีเลขที่คำสั่ง — ให้เลือกใช้ตอนบันทึกผล
const myEvents = ref([])        // นัดในปฏิทินของฉัน (สร้างเอง/ถูกใส่ชื่อร่วม) ช่วงใกล้ ๆ นี้
const eventVisitCount = ref({}) // event_id → จำนวนบันทึกที่ผูกไว้แล้ว (เท่าที่ RLS ให้เห็น)
const planGroupFilter = ref('')
const linkedEvent = ref(null)   // นัดที่เลือกอยู่ — ใช้แสดงกล่อง "เชื่อมกับนัด"
let saved = false

const emptyForm = () => ({
  id: null,
  status: 'draft',
  event_id: null,
  school_id: '',
  place_name: '',
  visit_date: new Date().toISOString().slice(0, 10),
  visit_type: 'school_visit',
  visit_type_other: '',
  title: '',
  topics: [],
  work_group: '',
  academic_year: currentAcademicYear(),
  term: currentTerm(),
  summary: '', strengths: '', issues: '', suggestions: '',
  co_supervisor_ids: [],
  receiver_name: '', receiver_position: '', receiver_count: null,
  photos: [], links: [], logbook_photos: [],
  followup_required: false, followup_due: null, followup_note: '',
  is_public: false,
  // สำเนาจากแผนการนิเทศ (nithet_events) ที่เลือก — อ่านอย่างเดียวในฟอร์มนี้ (migration 0077)
  order_number: '', order_date: null, order_link: '', doc_links: [], ref_kind: 'order',
})
const form = ref(emptyForm())

// เก็บร่างแยกตามบันทึก — ของใหม่กับของที่กำลังแก้ต้องไม่ทับกัน
const draftKey = computed(() => `nithet_visit_draft_${route.params.id || 'new'}`)
const { restoreDraft, clearDraft, watchAndSave } = useFormDraft(
  draftKey.value,
  () => form.value,
  (s) => { form.value = { ...emptyForm(), ...s } },
)

const inputCls = 'w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary'

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || ''

  if (user) {
    const { data: p } = await supabase.from('profiles')
      .select('role, department').eq('id', user.id).single()
    canWrite.value = VISIT_WRITER_ROLES.includes(p?.role)
    // profiles.department เก็บเป็น label ต้องแปลงเป็น key ให้ตรงกับ nithet_events
    if (isNew.value) form.value.work_group = keyFromLabel(p?.department) || ''
  }

  const { data: pp } = await supabase.from('profiles')
    .select('id, title, first_name, last_name, full_name, role')
    .in('role', VISIT_WRITER_ROLES).order('first_name')
  people.value = pp || []

  if (isNew.value) {
    // แผนการนิเทศที่มีเลขที่คำสั่งอยู่แล้ว (หัวหน้างานกำหนดไว้) — ให้เลือกจากในฟอร์มได้เลย
    // ไม่ต้องเริ่มจากปฏิทินเสมอไป (RLS: show_public=true อ่านได้ทุกคนอยู่แล้ว ไม่ใช่แค่เจ้าของ)
    const { data: plans } = await supabase.from('nithet_events')
      .select(EVENT_COLS)
      .neq('order_number', '').neq('status', 'cancelled').order('start_date', { ascending: false })
    officialPlans.value = plans || []

    // ปฏิทินของฉัน — ย้อนหลัง 60 วัน ถึงล่วงหน้า 7 วัน (บันทึกผลมักทำหลังวันงานไม่นาน)
    if (myId.value) {
      const { data: mine } = await supabase.from('nithet_events')
        .select(EVENT_COLS)
        .or(`created_by.eq.${myId.value},responsible_ids.cs.{${myId.value}}`)
        .neq('status', 'cancelled')
        .gte('end_date', shiftDate(-60)).lte('start_date', shiftDate(7))
        .order('start_date', { ascending: false })
      myEvents.value = mine || []
    }
    await loadVisitCounts([...myEvents.value, ...officialPlans.value].map(e => e.id))

    // มาจากปฏิทิน — เติมข้อมูลจากแผนให้เลย (ระบุโรงมาแล้วใน ?school= ไม่ต้องถามซ้ำ)
    const eventId = route.query.event
    if (eventId) {
      const { data: ev } = await supabase.from('nithet_events')
        .select(EVENT_COLS).eq('id', eventId).single()
      if (ev) await applyPlan(ev, { schoolId: route.query.school || '' })
    }
    if (route.query.school) form.value.school_id = route.query.school
    restoreDraft()
  } else {
    const { data, error } = await supabase.from('nithet_visits')
      .select('*').eq('id', route.params.id).single()
    if (error || !data) {
      Swal.fire({ icon: 'error', title: 'ไม่พบบันทึกนี้' })
      router.push('/dashboard/nithet-visits')
      return
    }
    form.value = { ...emptyForm(), ...data,
      school_id: data.school_id || '',
      photos: data.photos || [], links: data.links || [], topics: data.topics || [],
      logbook_photos: data.logbook_photos || [],
      co_supervisor_ids: data.co_supervisor_ids || [] }
  }

  // ร่างที่กู้คืน / บันทึกเดิมที่เปิดแก้ อาจผูกนัดไว้แล้ว — โหลดนัดนั้นมาด้วย
  // (ใช้แสดงกล่อง "เชื่อมกับนัด")
  if (form.value.event_id && linkedEvent.value?.id !== form.value.event_id) {
    const { data: ev } = await supabase.from('nithet_events')
      .select(EVENT_COLS).eq('id', form.value.event_id).maybeSingle()
    linkedEvent.value = ev || null
  }

  loading.value = false
  watchAndSave()
})

// ออกจากหน้าโดยไม่บันทึก = ลบรูปที่เพิ่งอัปทิ้ง ไม่ให้ค้างกินพื้นที่โฮสต์ตลอดไป
onBeforeUnmount(() => { if (!saved) gc.discard() })

const photoCategory = computed(() => `nithet-${form.value.academic_year || currentAcademicYear()}`)

function toggleCo(id) {
  const list = form.value.co_supervisor_ids
  const i = list.indexOf(id)
  if (i >= 0) list.splice(i, 1)
  else list.push(id)
}

function personName(p) {
  if (p.first_name || p.last_name) return `${p.title || ''}${p.first_name || ''} ${p.last_name || ''}`.trim()
  return p.full_name || '-'
}

const EVENT_COLS = 'id, title, description, type, status, start_date, end_date, location, school_ids, created_by, responsible_ids, responsible_group, order_number, order_date, order_link, doc_links, topics, ref_kind'

function shiftDate(days) {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return d.toISOString().slice(0, 10)
}

async function loadVisitCounts(ids) {
  const unique = [...new Set(ids)].filter(Boolean)
  if (!unique.length) return
  const { data } = await supabase.from('nithet_visits').select('event_id').in('event_id', unique)
  const m = {}
  for (const r of data || []) m[r.event_id] = (m[r.event_id] || 0) + 1
  eventVisitCount.value = m
}

// สถานที่จากนัด: โรงเดียว → เลือกให้เลย · หลายโรง → ถาม · ไม่มีโรงแต่มี location → "สถานที่อื่น"
async function applyPlace(ev, presetSchoolId) {
  const ids = ev.school_ids || []
  if (presetSchoolId) { form.value.school_id = presetSchoolId; form.value.place_name = ''; return }
  if (ids.length === 1) { form.value.school_id = ids[0]; form.value.place_name = ''; return }
  if (ids.length > 1) {
    const { data: ss } = await supabase.from('schools').select('id, name').in('id', ids).order('name')
    const inputOptions = Object.fromEntries((ss || []).map(s => [s.id, s.name]))
    const { isConfirmed, value } = await Swal.fire({
      title: 'บันทึกผลของโรงเรียนไหน',
      text: 'นัดนี้มีหลายโรง กรอกทีละโรงเรียน กลับมาเลือกนัดเดิมเพื่อบันทึกโรงถัดไปได้',
      input: 'radio', inputOptions, inputValue: (ss || [])[0]?.id,
      showCancelButton: true, confirmButtonText: 'เลือก', cancelButtonText: 'ไว้เลือกเอง',
    })
    if (isConfirmed && value) { form.value.school_id = value; form.value.place_name = '' }
    return
  }
  if (ev.location?.trim()) { form.value.school_id = ''; form.value.place_name = ev.location.trim() }
}

// เติมข้อมูลจากแผนการนิเทศ (nithet_events) ที่เลือก — ใช้ทั้งตอนมาจาก ?event= ของปฏิทิน
// ตอนเลือกจาก dropdown และตอนกดชิปนัดใน PlacePicker เพื่อไม่ให้ logic หลายทางเพี้ยนจากกัน
async function applyPlan(ev, { schoolId = '' } = {}) {
  linkedEvent.value = ev
  form.value.event_id = ev.id
  form.value.title = ev.title || ''
  form.value.visit_date = ev.start_date || form.value.visit_date
  form.value.visit_type = visitTypeFromEvent(ev.type)
  form.value.co_supervisor_ids = (ev.responsible_ids || []).filter(id => id !== myId.value)
  if (ev.responsible_group) form.value.work_group = ev.responsible_group
  // ชื่อกิจกรรม + ประเด็นย่อยที่หัวหน้ากำหนดไว้ เสนอเป็นชิปประเด็นให้กดเพิ่มได้ทันที (ไม่บังคับใส่)
  eventTopics.value = [ev.title, ...(ev.topics || [])].filter(Boolean)
  // สำเนาข้อมูลคำสั่ง — อ่านอย่างเดียวในฟอร์มนี้ แก้ได้แค่จากปฏิทินโดยหัวหน้างานเท่านั้น
  form.value.order_number = ev.order_number || ''
  form.value.ref_kind = ev.ref_kind || 'order'
  form.value.order_date = ev.order_date || null
  form.value.order_link = ev.order_link || ''
  form.value.doc_links = [...(ev.doc_links || [])]
  await applyPlace(ev, schoolId)
}

// แผนทางการที่อยู่ในปฏิทินของฉันอยู่แล้วไม่ต้องโชว์ซ้ำอีกกลุ่ม
const filteredPlans = computed(() => {
  const mine = new Set(myEvents.value.map(e => e.id))
  return officialPlans.value
    .filter(p => !mine.has(p.id))
    .filter(p => !planGroupFilter.value || p.responsible_group === planGroupFilter.value)
})

// ชิปลัดใน PlacePicker โหมด "สถานที่อื่น": นัดประชุม/อบรม/อื่นๆ ของฉัน ใกล้วันที่ในฟอร์มก่อน
const placeShortcutEvents = computed(() => {
  const base = new Date(form.value.visit_date || Date.now()).getTime()
  return myEvents.value
    .filter(e => e.type !== 'school_visit')
    .map(e => ({ ...e, _dist: Math.abs(new Date(e.start_date).getTime() - base) }))
    .sort((a, b) => a._dist - b._dist)
    .slice(0, 6)
})

function eventOptionLabel(e) {
  const d = new Date(e.start_date).toLocaleDateString('th-TH', { day: 'numeric', month: 'short' })
  const n = eventVisitCount.value[e.id]
  return `${d} · ${typeMeta(visitTypeFromEvent(e.type)).icon} ${e.title}${n ? ` · บันทึกแล้ว ${n}` : ''}`
}

async function pickPlan(id) {
  if (!id) { clearPlan(); return }
  const ev = myEvents.value.find(p => p.id === id) || officialPlans.value.find(p => p.id === id)
  if (ev) await applyPlan(ev)
}

const rl = computed(() => resultLabels(form.value.visit_type))

function clearPlan() {
  linkedEvent.value = null
  form.value.event_id = null
  form.value.ref_kind = 'order'
  form.value.order_number = ''
  form.value.order_date = null
  form.value.order_link = ''
  form.value.doc_links = []
}

async function save(finalize) {
  if (!form.value.school_id && !form.value.place_name.trim()) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้ระบุสถานที่' }); return
  }
  if (!form.value.visit_date) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้ใส่วันที่' }); return
  }
  if (finalize && !form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: `บันทึกสมบูรณ์ต้องใส่${rl.value.topic}` }); return
  }

  saving.value = true
  const payload = {
    status: finalize ? 'final' : 'draft',
    event_id: form.value.event_id || null,
    school_id: form.value.school_id || null,
    place_name: form.value.place_name.trim(),
    visit_date: form.value.visit_date,
    visit_type: form.value.visit_type,
    visit_type_other: form.value.visit_type === 'other' ? form.value.visit_type_other.trim() : '',
    title: form.value.title.trim(),
    topics: form.value.topics,
    // สำเนาจากแผนที่เลือก (ถ้ามี) — ฟอร์มนี้ไม่มีช่องแก้ไขฟิลด์เหล่านี้เอง
    order_number: form.value.order_number,
    ref_kind: form.value.ref_kind || 'order',
    order_date: form.value.order_date || null,
    order_link: form.value.order_link,
    doc_links: form.value.doc_links,
    work_group: form.value.work_group || '',
    academic_year: form.value.academic_year ? Number(form.value.academic_year) : null,
    term: form.value.term ? Number(form.value.term) : null,
    summary: form.value.summary.trim(),
    strengths: form.value.strengths.trim(),
    issues: form.value.issues.trim(),
    suggestions: form.value.suggestions.trim(),
    co_supervisor_ids: form.value.co_supervisor_ids,
    receiver_name: form.value.receiver_name.trim(),
    receiver_position: form.value.receiver_position.trim(),
    receiver_count: form.value.receiver_count ? Number(form.value.receiver_count) : null,
    photos: form.value.photos,
    links: form.value.links.filter(l => l.url?.trim()),
    logbook_photos: form.value.logbook_photos,
    followup_required: form.value.followup_required,
    followup_due: form.value.followup_due || null,
    followup_note: form.value.followup_note.trim(),
    is_public: form.value.is_public,
  }

  let error, savedId = form.value.id
  if (isNew.value) {
    // ต้องส่ง created_by ให้ผ่าน WITH CHECK ของ RLS แม้ trigger จะเขียนทับอีกที
    const res = await supabase.from('nithet_visits')
      .insert({ ...payload, created_by: myId.value }).select('id').single()
    error = res.error
    savedId = res.data?.id
  } else {
    const res = await supabase.from('nithet_visits').update(payload).eq('id', form.value.id)
    error = res.error
  }
  saving.value = false

  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }

  saved = true
  clearDraft()
  await gc.commit([...form.value.photos, ...form.value.logbook_photos].map(p => p.url))

  // นัดในปฏิทินเปลี่ยนเป็น "เสร็จสิ้น" เองที่ฐานข้อมูลเมื่อบันทึกครบ (trigger migration 91) ไม่ต้องถาม
  Swal.fire({
    icon: 'success',
    title: finalize ? 'บันทึกสมบูรณ์แล้ว' : 'บันทึกร่างแล้ว',
    text: finalize
      ? (form.value.event_id ? 'นัดในปฏิทินจะเปลี่ยนเป็น "เสร็จสิ้น" ให้เองเมื่อบันทึกครบทุกโรงในนัด' : '')
      : 'กลับมาเติมเนื้อหาให้ครบภายหลังได้',
    timer: form.value.event_id && finalize ? 2200 : 1400, showConfirmButton: false,
  })
  router.push('/dashboard/nithet-visits')
}
</script>

<template>
  <div class="space-y-5 pb-24">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">{{ isNew ? 'บันทึกการนิเทศ' : 'แก้ไขบันทึกการนิเทศ' }}</h1>
        <span class="block text-xs text-slate-400 mt-0.5">
          กรอกแค่ สถานที่ + วันที่ + รูป ก็กด "บันทึกด่วน" ได้เลย แล้วค่อยกลับมาเติมทีหลัง
        </span>
      </div>
      <RouterLink to="/dashboard/nithet-visits" class="text-sm font-bold text-slate-500 hover:text-primary">← กลับ</RouterLink>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>

    <div v-else-if="!canWrite" class="glass-card text-center py-16">
      <p class="text-4xl mb-3">🔒</p>
      <p class="text-sm font-bold text-slate-600">คุณไม่มีสิทธิ์บันทึกการนิเทศ</p>
      <p class="text-xs text-slate-400 mt-1">เฉพาะศึกษานิเทศก์ เจ้าหน้าที่ และผู้ดูแลระบบ</p>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-5">
      <div class="lg:col-span-2 space-y-5">

        <!-- 1. สถานที่ -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">1. สถานที่</p>

          <PlacePicker
            :school-id="form.school_id" :place-name="form.place_name"
            :events="isNew ? placeShortcutEvents : []" :picked-event-id="form.event_id || ''"
            @update:schoolId="form.school_id = $event" @update:placeName="form.place_name = $event"
            @pick-event="pickPlan"/>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">วันที่ <span class="text-red-500">*</span></label>
              <input v-model="form.visit_date" type="date" :class="inputCls"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ประเภท</label>
              <select v-model="form.visit_type" :class="inputCls">
                <option v-for="t in VISIT_TYPES" :key="t.value" :value="t.value">{{ t.icon }} {{ t.label }}</option>
              </select>
            </div>
          </div>

          <div v-if="form.visit_type === 'other'">
            <label class="text-[11px] font-bold text-slate-500">ระบุประเภท</label>
            <input v-model="form.visit_type_other" type="text" placeholder="เช่น ร่วมกิจกรรมของโรงเรียน" :class="inputCls"/>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">ปีการศึกษา (พ.ศ.)</label>
              <input v-model="form.academic_year" inputmode="numeric" :class="inputCls"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ภาคเรียน</label>
              <select v-model="form.term" :class="inputCls">
                <option :value="1">1</option>
                <option :value="2">2</option>
              </select>
            </div>
          </div>

          <div>
            <label class="text-[11px] font-bold text-slate-500">{{ rl.co }} (ไม่รวมตัวคุณเอง)</label>
            <div class="border border-slate-200 rounded-xl max-h-40 overflow-y-auto divide-y divide-slate-100 bg-white">
              <label v-for="p in people.filter(x => x.id !== myId)" :key="p.id"
                class="flex items-center gap-2 px-3 py-2 text-sm cursor-pointer hover:bg-slate-50">
                <input type="checkbox" :checked="form.co_supervisor_ids.includes(p.id)" @change="toggleCo(p.id)"
                  class="rounded border-slate-300"/>
                {{ personName(p) }}
              </label>
            </div>
          </div>
        </div>

        <!-- 2. เรื่องที่นิเทศ -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">2. {{ rl.topic }}</p>

          <!-- เลือกจากปฏิทิน — ไม่บังคับ · ปฏิทินของฉัน (ทุกประเภท) + แผนทางการที่มีเลขที่คำสั่ง
               มาจากปฏิทินอยู่แล้วก็เลือกซ้ำ/เปลี่ยนจากตรงนี้ได้เหมือนกัน -->
          <div v-if="isNew && (myEvents.length || officialPlans.length)" class="p-3 rounded-xl bg-indigo-50/60 border border-indigo-100 space-y-2">
            <label class="text-[11px] font-bold text-indigo-700">เลือกจากปฏิทิน / แผนการนิเทศ (ถ้ามี) — เติมวันที่ หัวข้อ ประเภท สถานที่ให้</label>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <select v-model="planGroupFilter" :class="inputCls" title="กรองเฉพาะแผนทางการตามกลุ่มงาน">
                <option value="">แผนทางการ: ทุกกลุ่มงาน</option>
                <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
              </select>
              <select :value="form.event_id || ''" @change="pickPlan($event.target.value)" :class="[inputCls, 'sm:col-span-2']">
                <option value="">-- ไม่ใช้นัด/แผน --</option>
                <optgroup v-if="myEvents.length" label="ปฏิทินของฉัน">
                  <option v-for="e in myEvents" :key="e.id" :value="e.id">{{ eventOptionLabel(e) }}</option>
                </optgroup>
                <optgroup v-if="filteredPlans.length" label="แผนทางการ (มีคำสั่ง/หนังสืออ้างอิง)">
                  <option v-for="p in filteredPlans" :key="p.id" :value="p.id">
                    {{ p.order_number }} · {{ p.title }}{{ eventVisitCount[p.id] ? ` · บันทึกแล้ว ${eventVisitCount[p.id]}` : '' }}
                  </option>
                </optgroup>
              </select>
            </div>
          </div>

          <!-- เชื่อมกับนัดที่ไม่มีเลขคำสั่ง — บอกให้รู้ว่าผูกอยู่ และเลิกผูกได้ -->
          <div v-if="form.event_id && !form.order_number && linkedEvent"
            class="p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs flex items-center justify-between gap-2">
            <span class="font-bold text-slate-600">🗓 เชื่อมกับนัดในปฏิทิน: {{ linkedEvent.title }}</span>
            <button type="button" @click="clearPlan" class="text-slate-400 hover:text-red-500 font-bold shrink-0">เลิกเชื่อม</button>
          </div>

          <!-- อ้างอิงจากแผนที่เลือก — อ่านอย่างเดียว แก้ได้แค่จากปฏิทินโดยหัวหน้างานเท่านั้น -->
          <div v-if="form.order_number" class="p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs space-y-1">
            <div class="flex items-center justify-between gap-2">
              <span class="font-bold text-slate-600">📋 อ้างอิง{{ refKindMeta(form.ref_kind).label }}เลขที่ {{ form.order_number }}</span>
              <button type="button" @click="clearPlan" class="text-slate-400 hover:text-red-500 font-bold">เลิกใช้แผนนี้</button>
            </div>
            <p v-if="form.order_date" class="text-slate-500">ลงวันที่ {{ form.order_date }}</p>
            <a v-if="form.order_link" :href="form.order_link" target="_blank" class="text-primary font-bold hover:underline block">ดู{{ refKindMeta(form.ref_kind).label }} ↗</a>
            <a v-for="(d, i) in form.doc_links" :key="i" :href="d.url" target="_blank" class="text-primary font-bold hover:underline block">
              {{ d.label || 'เอกสารประกอบ' }} ↗
            </a>
          </div>

          <div>
            <label class="text-[11px] font-bold text-slate-500">เรื่อง/หัวข้อ</label>
            <input v-model="form.title" type="text" :placeholder="rl.topicPlaceholder" :class="inputCls"/>
          </div>
          <TopicChips v-model="form.topics" :suggested="eventTopics"/>
        </div>

        <!-- 3. ผลการนิเทศ -->
        <div class="glass-card p-5 space-y-4">
          <!-- หัวข้อเปลี่ยนตามประเภท (resultLabels) — ข้อมูลยังลง 4 คอลัมน์เดิม -->
          <p class="font-bold text-sm text-slate-700">3. {{ rl.section }}</p>
          <VoiceTextarea v-model="form.summary" :label="rl.summary.label" :placeholder="rl.summary.placeholder"/>
          <VoiceTextarea v-model="form.strengths" :label="rl.strengths.label" :placeholder="rl.strengths.placeholder"/>
          <VoiceTextarea v-model="form.issues" :label="rl.issues.label"
            :placeholder="rl.issues.placeholder" hint="ไม่แสดงบนหน้าเว็บสาธารณะ"/>
          <VoiceTextarea v-model="form.suggestions" :label="rl.suggestions.label"
            :placeholder="rl.suggestions.placeholder" hint="ไม่แสดงบนหน้าเว็บสาธารณะ"/>
        </div>

        <!-- 4. หลักฐาน -->
        <div class="glass-card p-5 space-y-4">
          <p class="font-bold text-sm text-slate-700">4. ภาพและลิงก์ประกอบ</p>
          <VisitPhotoUploader :model-value="form.photos" :category="photoCategory" :gc="gc"/>
          <LinkListEditor :model-value="form.links"/>
        </div>

        <!-- 5. สมุดบันทึกการนิเทศ -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">5. สมุดบันทึกการนิเทศ</p>
          <p class="text-xs text-slate-400">
            แนบภาพหน้าสมุดบันทึกเป็นหลักฐานประกอบ (ไม่บังคับ) — แนบได้ภาพเดียว แนบใหม่จะแทนที่ภาพเดิม
          </p>
          <VisitPhotoUploader :model-value="form.logbook_photos" :category="`${photoCategory}-logbook`"
            :aspect-ratio="21/29.7" :max="1" :gc="gc"/>
        </div>
      </div>

      <!-- คอลัมน์ขวา -->
      <div class="space-y-5">
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">{{ rl.receiver }}</p>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ชื่อ</label>
            <input v-model="form.receiver_name" type="text" placeholder="เช่น นายสมชาย ใจดี" :class="inputCls"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ตำแหน่ง</label>
            <input v-model="form.receiver_position" type="text" placeholder="เช่น ผู้อำนวยการโรงเรียน" :class="inputCls"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">จำนวน{{ rl.receiver }} (คน)</label>
            <input v-model="form.receiver_count" inputmode="numeric" placeholder="เช่น 25" :class="inputCls"/>
          </div>
        </div>

        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">การติดตามผล</p>
          <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
            <input type="checkbox" v-model="form.followup_required" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
            ต้องติดตามผลรอบถัดไป
          </label>
          <template v-if="form.followup_required">
            <div>
              <label class="text-[11px] font-bold text-slate-500">กำหนดติดตามภายใน</label>
              <input v-model="form.followup_due" type="date" :class="inputCls"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">สิ่งที่ต้องติดตาม</label>
              <textarea v-model="form.followup_note" rows="2" :class="inputCls"></textarea>
            </div>
          </template>
        </div>

        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">การเผยแพร่</p>
          <label class="flex items-start gap-2 text-sm text-slate-600 cursor-pointer select-none">
            <input type="checkbox" v-model="form.is_public" class="w-4 h-4 rounded mt-0.5 accent-[var(--color-primary)]"/>
            <span>
              เผยแพร่บนหน้าเว็บสาธารณะ
              <span class="block text-[11px] text-slate-400">
                แสดงเฉพาะ {{ rl.summary.label }} · {{ rl.strengths.label }} · รูป — {{ rl.issues.label }}และ{{ rl.suggestions.label }}ไม่ถูกเผยแพร่
              </span>
            </span>
          </label>
        </div>
      </div>
    </div>

    <!-- ปุ่มลอยติดขอบล่าง — กรอกบนมือถือแล้วกดบันทึกได้โดยไม่ต้องเลื่อนหาสุดหน้า -->
    <div v-if="!loading && canWrite"
      class="sticky bottom-0 -mx-4 px-4 py-3 bg-white/85 backdrop-blur border-t border-slate-200 flex gap-3">
      <button @click="save(false)" :disabled="saving" type="button"
        class="flex-1 py-2.5 rounded-2xl border-2 border-primary text-primary text-sm font-bold disabled:opacity-50">
        {{ saving ? 'กำลังบันทึก...' : 'บันทึกด่วน (ร่าง)' }}
      </button>
      <button @click="save(true)" :disabled="saving" type="button"
        class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold shadow-md disabled:opacity-50">
        บันทึกสมบูรณ์
      </button>
    </div>
  </div>
</template>
