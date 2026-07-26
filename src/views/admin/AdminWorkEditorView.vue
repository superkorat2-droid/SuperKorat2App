<script setup>
/**
 * AdminWorkEditorView — ฟอร์มเพิ่ม/แก้ไขผลงาน
 * ใช้ ContentBlockEditor ตัวเดียวกับคลังสื่อ
 *
 * status / owner_id ไม่ส่งจาก client — trigger ใน DB กำหนดเองตามบทบาท
 * (ถ้าส่งมาก็ถูกเขียนทับ) การอนุมัติทำผ่าน RPC review_work เท่านั้น
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import ContentBlockEditor from '../../components/content/ContentBlockEditor.vue'
import { withKeys, stripKeys } from '../../composables/useContentBlocks'
import { WORK_TYPES, OWNER_TYPES, ownerTypeFromRole, AUTO_APPROVE_ROLES, workStatusMeta } from '../../composables/useWorks'

const route  = useRoute()
const router = useRouter()
const isNew  = computed(() => !route.params.id)

const loading = ref(true)
const saving  = ref(false)
const blocks  = ref([])
const myRole  = ref('')
const schools = ref([])
const existing = ref(null)

const GRADES = ['ป.1','ป.2','ป.3','ป.4','ป.5','ป.6','ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']
const SUBJECT_GROUPS = ['ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ','สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ','ปฐมวัย','อื่นๆ']

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

          <ContentBlockEditor :blocks="blocks" title="รายละเอียดผลงาน"/>
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

            <div>
              <label class="text-[11px] font-bold text-slate-500">ลิงก์ไฟล์ผลงาน (Drive/PDF)</label>
              <input v-model="form.file_url" placeholder="https://drive.google.com/…"
                class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">URL รูปปก</label>
              <input v-model="form.cover_url" placeholder="https://…"
                class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>
            </div>
          </div>

          <button @click="save" :disabled="saving"
            class="w-full py-3 rounded-2xl bg-primary text-white font-bold shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
            {{ saving ? 'กำลังบันทึก…' : (isNew ? 'บันทึกผลงาน' : 'บันทึกการแก้ไข') }}
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
