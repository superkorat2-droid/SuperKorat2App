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
} from '../../composables/useNithetVisits'

const route  = useRoute()
const router = useRouter()
const isNew  = computed(() => !route.params.id)
const gc     = useUploadGc()

const { config, fetchConfig } = useAreaConfig()
const { keyFromLabel } = useGroupOptions(config)

const loading = ref(true)
const saving  = ref(false)
const canWrite = ref(true)
const myId    = ref('')
const people  = ref([])
const eventTopics = ref([])
let saved = false

const emptyForm = () => ({
  id: null,
  status: 'draft',
  event_id: null,
  school_id: '',
  place_name: '',
  visit_date: new Date().toISOString().slice(0, 10),
  visit_type: 'school_visit',
  title: '',
  topics: [],
  work_group: '',
  academic_year: currentAcademicYear(),
  term: currentTerm(),
  summary: '', strengths: '', issues: '', suggestions: '',
  co_supervisor_ids: [],
  receiver_name: '', receiver_position: '', receiver_count: null,
  photos: [], links: [],
  followup_required: false, followup_due: null, followup_note: '',
  is_public: false,
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
    // มาจากปฏิทิน — เติมข้อมูลจากแผนให้เลย
    const eventId = route.query.event
    if (eventId) {
      const { data: ev } = await supabase.from('nithet_events')
        .select('id, title, description, type, start_date, responsible_ids, responsible_group')
        .eq('id', eventId).single()
      if (ev) {
        form.value.event_id = ev.id
        form.value.title = ev.title || ''
        form.value.visit_date = ev.start_date || form.value.visit_date
        form.value.visit_type = ev.type === 'school_visit' ? 'school_visit'
          : ev.type === 'training' ? 'speaker' : (ev.type || 'other')
        form.value.co_supervisor_ids = (ev.responsible_ids || []).filter(id => id !== myId.value)
        if (ev.responsible_group) form.value.work_group = ev.responsible_group
        // ชื่อกิจกรรมเสนอเป็นชิปประเด็นให้กดเพิ่มได้ทันที
        eventTopics.value = [ev.title].filter(Boolean)
      }
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
      co_supervisor_ids: data.co_supervisor_ids || [] }
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

async function save(finalize) {
  if (!form.value.school_id && !form.value.place_name.trim()) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้ระบุว่าไปที่ไหน' }); return
  }
  if (!form.value.visit_date) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้ใส่วันที่' }); return
  }
  if (finalize && !form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'บันทึกสมบูรณ์ต้องใส่เรื่องที่นิเทศ' }); return
  }

  saving.value = true
  const payload = {
    status: finalize ? 'final' : 'draft',
    event_id: form.value.event_id || null,
    school_id: form.value.school_id || null,
    place_name: form.value.place_name.trim(),
    visit_date: form.value.visit_date,
    visit_type: form.value.visit_type,
    title: form.value.title.trim(),
    topics: form.value.topics,
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
  await gc.commit(form.value.photos.map(p => p.url))

  // มาจากปฏิทินและกรอกครบแล้ว — เสนอปิดงานในแผนให้ด้วย
  if (finalize && form.value.event_id) {
    const ask = await Swal.fire({
      icon: 'question', title: 'บันทึกแล้ว',
      text: 'ตั้งกิจกรรมในปฏิทินเป็น "เสร็จสิ้น" ด้วยไหม',
      showCancelButton: true, confirmButtonText: 'ตั้งให้เลย', cancelButtonText: 'ไม่ต้อง',
    })
    if (ask.isConfirmed) {
      await supabase.from('nithet_events').update({ status: 'done' }).eq('id', form.value.event_id)
    }
  } else {
    Swal.fire({
      icon: 'success',
      title: finalize ? 'บันทึกสมบูรณ์แล้ว' : 'บันทึกร่างแล้ว',
      text: finalize ? '' : 'กลับมาเติมเนื้อหาให้ครบภายหลังได้',
      timer: 1400, showConfirmButton: false,
    })
  }
  router.push('/dashboard/nithet-visits')
}
</script>

<template>
  <div class="space-y-5 pb-24">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">{{ isNew ? 'บันทึกการนิเทศ' : 'แก้ไขบันทึกการนิเทศ' }}</h1>
        <span class="block text-xs text-slate-400 mt-0.5">
          กรอกแค่ ไปที่ไหน + วันที่ + รูป ก็กด "บันทึกด่วน" ได้เลย แล้วค่อยกลับมาเติมทีหลัง
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

        <!-- 1. ไปไหน เมื่อไหร่ -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">1. ไปไหน เมื่อไหร่</p>

          <PlacePicker
            :school-id="form.school_id" :place-name="form.place_name"
            @update:schoolId="form.school_id = $event" @update:placeName="form.place_name = $event"/>

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
            <label class="text-[11px] font-bold text-slate-500">ผู้ร่วมนิเทศ (ไม่รวมตัวคุณเอง)</label>
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
          <p class="font-bold text-sm text-slate-700">2. เรื่องที่นิเทศ</p>
          <div>
            <label class="text-[11px] font-bold text-slate-500">เรื่อง/หัวข้อ</label>
            <input v-model="form.title" type="text" placeholder="เช่น นิเทศการจัดการเรียนรู้เชิงรุก" :class="inputCls"/>
          </div>
          <TopicChips v-model="form.topics" :suggested="eventTopics"/>
        </div>

        <!-- 3. ผลการนิเทศ -->
        <div class="glass-card p-5 space-y-4">
          <p class="font-bold text-sm text-slate-700">3. ผลการนิเทศ</p>
          <VoiceTextarea v-model="form.summary" label="สภาพที่พบ" placeholder="บรรยายสิ่งที่พบจากการนิเทศ"/>
          <VoiceTextarea v-model="form.strengths" label="จุดเด่น" placeholder="สิ่งที่โรงเรียนทำได้ดี"/>
          <VoiceTextarea v-model="form.issues" label="จุดที่ควรพัฒนา"
            placeholder="ประเด็นที่ควรปรับปรุง" hint="ไม่แสดงบนหน้าเว็บสาธารณะ"/>
          <VoiceTextarea v-model="form.suggestions" label="ข้อเสนอแนะ"
            placeholder="แนวทางที่แนะนำให้ดำเนินการ" hint="ไม่แสดงบนหน้าเว็บสาธารณะ"/>
        </div>

        <!-- 5. หลักฐาน -->
        <div class="glass-card p-5 space-y-4">
          <p class="font-bold text-sm text-slate-700">4. ภาพและลิงก์ประกอบ</p>
          <VisitPhotoUploader :model-value="form.photos" :category="photoCategory" :gc="gc"/>
          <LinkListEditor :model-value="form.links"/>
        </div>
      </div>

      <!-- คอลัมน์ขวา -->
      <div class="space-y-5">
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-sm text-slate-700">ผู้รับการนิเทศ</p>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ชื่อ</label>
            <input v-model="form.receiver_name" type="text" placeholder="เช่น นายสมชาย ใจดี" :class="inputCls"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ตำแหน่ง</label>
            <input v-model="form.receiver_position" type="text" placeholder="เช่น ผู้อำนวยการโรงเรียน" :class="inputCls"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">จำนวนผู้รับการนิเทศ (คน)</label>
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
                แสดงเฉพาะ สภาพที่พบ · จุดเด่น · รูป — จุดที่ควรพัฒนาและข้อเสนอแนะไม่ถูกเผยแพร่
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
