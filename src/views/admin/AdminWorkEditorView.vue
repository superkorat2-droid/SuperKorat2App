<script setup>
/**
 * AdminWorkEditorView — ฟอร์มเพิ่ม/แก้ไขผลงาน
 * ใช้ ContentBlockEditor ตัวเดียวกับคลังสื่อ
 *
 * status / owner_id ไม่ส่งจาก client — trigger ใน DB กำหนดเองตามบทบาท
 * (ถ้าส่งมาก็ถูกเขียนทับ) การอนุมัติทำผ่าน RPC review_work เท่านั้น
 */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import ContentBlockEditor from '../../components/content/ContentBlockEditor.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import { withKeys, stripKeys } from '../../composables/useContentBlocks'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { useUploadGc } from '../../composables/useUploadGc'
import { WORK_TYPES, OWNER_TYPES, SUBJECT_GROUPS, GRADES, ownerTypeFromRole, AUTO_APPROVE_ROLES, workStatusMeta } from '../../composables/useWorks'

const route  = useRoute()
const router = useRouter()
const isNew  = computed(() => !route.params.id)

const loading = ref(true)
const saving  = ref(false)
const blocks  = ref([])
const myRole  = ref('')
const schools = ref([])
const existing = ref(null)

// ── รูปปก: อัปโหลดขึ้น PHP server เหมือนข่าว/แบนเนอร์ ────────────────
// gc ผูกการลบรูปเก่าไว้กับผลการบันทึก — เปลี่ยนรูปแล้วกดยกเลิก รูปเดิมต้องไม่หาย
const { uploadImage } = useExternalUpload()
const gc = useUploadGc()
const showCropper    = ref(false)
const coverUploading = ref(false)
const coverErr       = ref('')

async function onCoverCropped({ blob }) {
  coverUploading.value = true
  coverErr.value = ''
  try {
    let url
    if (externalUploadEnabled) {
      url = await uploadImage(blob, 'works')
    } else {
      // สำรองเมื่อยังไม่ได้ตั้งค่า PHP host — เก็บลง Supabase storage
      const name = `works/cover_${Date.now()}.png`
      const { error } = await supabase.storage.from('images')
        .upload(name, blob, { contentType: 'image/png', upsert: false })
      if (error) throw error
      url = supabase.storage.from('images').getPublicUrl(name).data.publicUrl
    }
    if (form.value.cover_url) gc.trackReplaced(form.value.cover_url)
    gc.trackUploaded(url)
    form.value.cover_url = url
    showCropper.value = false
  } catch (e) {
    coverErr.value = e.message || 'อัปโหลดรูปปกไม่สำเร็จ'
  }
  coverUploading.value = false
}

function clearCover() {
  if (form.value.cover_url) gc.trackReplaced(form.value.cover_url)
  form.value.cover_url = ''
}

const form = ref({
  title: '', description: '', work_type: 'research', owner_type: 'supervisor',
  subject_group: '', grade_levels: [], academic_year: '', tags: '',
  file_url: '', cover_url: '', school_id: '', school_name: '',
})

const autoApprove = computed(() => AUTO_APPROVE_ROLES.includes(myRole.value))

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles').select('role, school_id').eq('id', user.id).single()
    myRole.value = p?.role || ''
    form.value.owner_type = ownerTypeFromRole(p?.role)
    if (p?.school_id) form.value.school_id = p.school_id
  }
  const { data: sc } = await supabase.from('schools').select('id, name, district').order('district').order('name')
  schools.value = sc || []

  if (!isNew.value) {
    const { data } = await supabase.from('works').select('*').eq('id', route.params.id).single()
    if (!data) { router.push('/dashboard/works'); return }
    existing.value = data
    form.value = {
      title: data.title, description: data.description || '', work_type: data.work_type,
      owner_type: data.owner_type, subject_group: data.subject_group || '',
      grade_levels: [...(data.grade_levels || [])], academic_year: data.academic_year || '',
      tags: (data.tags || []).join(', '), file_url: data.file_url || '', cover_url: data.cover_url || '',
      school_id: data.school_id || '', school_name: data.school_name || '',
    }
    blocks.value = withKeys(data.content_blocks)
  }
  loading.value = false
})

function toggleGrade(g) {
  const i = form.value.grade_levels.indexOf(g)
  if (i >= 0) form.value.grade_levels.splice(i, 1)
  else form.value.grade_levels.push(g)
}

// ออกจากหน้าโดยไม่บันทึก → ลบรูปที่เพิ่งอัปแต่ไม่ได้ใช้ ไม่ให้ค้างกินพื้นที่
let saved = false
onBeforeUnmount(() => { if (!saved) gc.discard() })

async function save() {
  if (!form.value.title.trim()) {
    return Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อผลงาน' })
  }
  saving.value = true
  const payload = {
    title: form.value.title.trim(),
    description: form.value.description.trim(),
    work_type: form.value.work_type,
    owner_type: form.value.owner_type,
    subject_group: form.value.subject_group,
    grade_levels: form.value.grade_levels,
    academic_year: form.value.academic_year.trim(),
    tags: form.value.tags.split(',').map(t => t.trim()).filter(Boolean),
    file_url: form.value.file_url.trim(),
    cover_url: form.value.cover_url.trim(),
    school_id: form.value.school_id || null,
    school_name: form.value.school_name.trim(),
    content_blocks: stripKeys(blocks.value),
  }

  const { data: { user } } = await supabase.auth.getUser()
  let error
  if (isNew.value) {
    // owner_id ต้องส่งให้ผ่าน RLS WITH CHECK — trigger จะเขียนทับด้วย auth.uid() อีกที
    ;({ error } = await supabase.from('works').insert({ ...payload, owner_id: user?.id }))
  } else {
    ;({ error } = await supabase.from('works').update(payload).eq('id', route.params.id))
  }
  saving.value = false
  if (error) return Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })

  // บันทึกผ่านแล้วจึงลบรูปเก่าบน server ได้ — ส่งรูปที่ยังใช้อยู่ไปกันลบผิดตัว
  saved = true
  const stillUsed = [payload.cover_url, ...blocks.value.map(b => b.url).filter(Boolean)].filter(Boolean)
  await gc.commit(stillUsed)

  await Swal.fire({
    icon: 'success',
    title: 'บันทึกแล้ว',
    text: isNew.value && !autoApprove.value ? 'ผลงานถูกส่งเข้าคิวรออนุมัติแล้ว' : '',
    timer: isNew.value && !autoApprove.value ? 2200 : 900,
    showConfirmButton: false,
  })
  router.push('/dashboard/works')
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-2xl font-extrabold text-slate-800">{{ isNew ? 'เพิ่มผลงาน' : 'แก้ไขผลงาน' }}</h1>
      <button @click="router.push('/dashboard/works')"
        class="px-4 py-2 rounded-2xl text-sm font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors">← กลับ</button>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <template v-else>
      <!-- สถานะ (เฉพาะตอนแก้ไข) -->
      <div v-if="existing" class="glass-tile px-4 py-3 flex flex-wrap items-center gap-2 text-sm">
        <span class="text-slate-500">สถานะ:</span>
        <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workStatusMeta(existing.status).bg, workStatusMeta(existing.status).text]">
          {{ workStatusMeta(existing.status).label }}
        </span>
        <span v-if="existing.status === 'rejected' && existing.reject_reason" class="text-xs text-red-600">
          — {{ existing.reject_reason }}
        </span>
        <span class="text-xs text-slate-400 ml-auto">สถานะเปลี่ยนได้โดยผู้อนุมัติเท่านั้น</span>
      </div>
      <div v-else-if="!autoApprove" class="glass-tile px-4 py-3 text-sm text-amber-700 bg-amber-50/60">
        ผลงานของคุณจะเข้าคิว <b>รออนุมัติ</b> จากศึกษานิเทศก์ก่อนขึ้นหน้าสาธารณะ
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <!-- ซ้าย: เนื้อหา -->
        <div class="lg:col-span-2 space-y-5">
          <div class="glass-card p-5 space-y-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">ชื่อผลงาน *</label>
              <input v-model="form.title" placeholder="เช่น การพัฒนาทักษะการอ่านด้วยชุดกิจกรรม…"
                class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">คำอธิบายย่อ</label>
              <textarea v-model="form.description" rows="3" placeholder="สรุปสั้นๆ ว่าผลงานนี้เกี่ยวกับอะไร"
                class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm resize-none focus:outline-none focus:border-primary"/>
            </div>
          </div>

          <div class="space-y-1.5">
            <ContentBlockEditor :blocks="blocks" title="รายละเอียดผลงาน (ไม่ใส่ก็ได้)"/>
            <p class="text-[11px] text-slate-400 px-1">
              ส่วนนี้คือ<b>เนื้อหาที่จะแสดงบนหน้าเว็บ</b> — ใช้เมื่ออยากเล่าเรื่องผลงาน
              ใส่รูป วิดีโอ ข้อความได้ · ถ้ามีแค่ไฟล์ Drive ให้ไปใส่ที่ช่อง
              <b>“ลิงก์ไฟล์ผลงานฉบับเต็ม”</b> ด้านขวา แล้วข้ามส่วนนี้ไปเลย
            </p>
          </div>
        </div>

        <!-- ขวา: ข้อมูลประกอบ -->
        <div class="space-y-5">
          <div class="glass-card p-5 space-y-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">ประเภทผลงาน</label>
              <div class="grid grid-cols-2 gap-1.5 mt-1">
                <button v-for="t in WORK_TYPES" :key="t.value" type="button" @click="form.work_type = t.value"
                  :class="['px-2 py-2 rounded-xl text-xs font-bold border-2 transition-all',
                    form.work_type === t.value ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                  {{ t.icon }} {{ t.label }}
                </button>
              </div>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-500">ผู้จัดทำเป็น</label>
              <select v-model="form.owner_type" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                <option v-for="o in OWNER_TYPES" :key="o.value" :value="o.value">{{ o.label }}</option>
              </select>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-500">กลุ่มสาระ</label>
              <select v-model="form.subject_group" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                <option value="">— ไม่ระบุ —</option>
                <option v-for="s in SUBJECT_GROUPS" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-500">ระดับชั้น</label>
              <div class="flex flex-wrap gap-1 mt-1">
                <button v-for="g in GRADES" :key="g" type="button" @click="toggleGrade(g)"
                  :class="['px-2 py-1 rounded-lg text-[11px] font-bold border transition-all',
                    form.grade_levels.includes(g) ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500']">
                  {{ g }}
                </button>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="text-[11px] font-bold text-slate-500">ปีการศึกษา</label>
                <input v-model="form.academic_year" placeholder="2569"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="text-[11px] font-bold text-slate-500">แท็ก</label>
                <input v-model="form.tags" placeholder="คั่นด้วย ,"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-500">โรงเรียน (ถ้ามี)</label>
              <select v-model="form.school_id" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                <option value="">— ระดับเขต —</option>
                <optgroup v-for="d in [...new Set(schools.map(s => s.district))].sort()" :key="d" :label="`อ.${d}`">
                  <option v-for="s in schools.filter(x => x.district === d)" :key="s.id" :value="s.id">{{ s.name }}</option>
                </optgroup>
              </select>
            </div>

          </div>

          <!-- ไฟล์และรูปปก แยกเป็นการ์ดของตัวเอง ให้เห็นชัดว่าเป็นของแนบ ไม่ใช่เนื้อหา -->
          <div class="glass-card p-5 space-y-4">
            <p class="font-bold text-slate-700 text-sm">ไฟล์แนบและรูปปก</p>

            <div>
              <label class="text-[11px] font-bold text-slate-500">ลิงก์ไฟล์ผลงานฉบับเต็ม (Drive/PDF)</label>
              <input v-model="form.file_url" placeholder="https://drive.google.com/…"
                class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono focus:outline-none focus:border-primary"/>
              <p class="text-[10px] text-slate-400 mt-1">
                จะขึ้นเป็นปุ่ม <b>“เปิดไฟล์ผลงาน”</b> บนหน้าสาธารณะ · ไม่ใส่ก็ได้
              </p>
            </div>

            <!-- รูปปก: อัปโหลดขึ้น server เหมือนข่าว/แบนเนอร์ ไม่ต้องหา URL มาแปะเอง -->
            <div>
              <label class="text-[11px] font-bold text-slate-500">รูปปก</label>
              <div v-if="form.cover_url" class="mt-1 relative rounded-xl overflow-hidden border border-slate-200">
                <img :src="form.cover_url" alt="รูปปก" class="w-full aspect-[4/3] object-cover"/>
                <div class="absolute top-1.5 right-1.5 flex gap-1.5">
                  <button type="button" @click="showCropper = true"
                    class="px-2 py-1 text-[10px] font-bold bg-white/90 text-primary rounded-lg shadow-sm hover:bg-white">เปลี่ยน</button>
                  <button type="button" @click="clearCover"
                    class="px-2 py-1 text-[10px] font-bold bg-white/90 text-red-500 rounded-lg shadow-sm hover:bg-white">ลบ</button>
                </div>
              </div>
              <button v-else type="button" @click="showCropper = true" :disabled="coverUploading"
                class="mt-1 w-full py-6 rounded-xl border-2 border-dashed border-slate-300 text-slate-500 hover:border-primary hover:text-primary transition-colors disabled:opacity-50">
                <svg class="w-6 h-6 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                </svg>
                <span class="text-xs font-bold">{{ coverUploading ? 'กำลังอัปโหลด…' : 'อัปโหลดรูปปก' }}</span>
                <span class="block text-[10px] text-slate-400 mt-0.5">ครอบสัดส่วน 4:3 ให้อัตโนมัติ</span>
              </button>
              <p v-if="coverErr" class="text-[10px] text-red-500 mt-1">{{ coverErr }}</p>
            </div>
          </div>

          <button @click="save" :disabled="saving"
            class="w-full py-3 rounded-2xl bg-primary text-white font-bold shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
            {{ saving ? 'กำลังบันทึก…' : (isNew ? 'บันทึกผลงาน' : 'บันทึกการแก้ไข') }}
          </button>
        </div>
      </div>
    </template>

    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="4/3"
      title="ครอบรูปปกผลงาน (4:3)"
      @close="showCropper = false"
      @cropped="onCoverCropped"/>
  </div>
</template>
