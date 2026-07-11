<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()

const personnel      = ref([])
const loading        = ref(true)
const saving         = ref(false)
const creating       = ref(false)
const editTarget     = ref(null)
const showCreate     = ref(false)
const savingGroups   = ref(false)
const personnelGroups = ref([])

const DEFAULT_GROUPS = [
  { key: 'nitet',     label: 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา', visible: true, order: 1 },
  { key: 'promote',   label: 'กลุ่มส่งเสริมการจัดการศึกษา',                 visible: true, order: 2 },
  { key: 'personnel', label: 'กลุ่มบริหารงานบุคคล',                         visible: true, order: 3 },
  { key: 'budget',    label: 'กลุ่มบริหารงบประมาณ',                         visible: true, order: 4 },
  { key: 'general',   label: 'กลุ่มอำนวยการ',                               visible: true, order: 5 },
]

// department options สำหรับ dropdown
const deptOptions = computed(() =>
  personnelGroups.value.map(g => g.label)
)

function moveGroupUp(i) {
  if (i === 0) return
  ;[personnelGroups.value[i-1], personnelGroups.value[i]] = [personnelGroups.value[i], personnelGroups.value[i-1]]
  personnelGroups.value.forEach((g, idx) => g.order = idx + 1)
}
function moveGroupDown(i) {
  if (i === personnelGroups.value.length - 1) return
  ;[personnelGroups.value[i], personnelGroups.value[i+1]] = [personnelGroups.value[i+1], personnelGroups.value[i]]
  personnelGroups.value.forEach((g, idx) => g.order = idx + 1)
}
function addGroup() {
  personnelGroups.value.push({ key: 'group_' + Date.now(), label: '(กลุ่มใหม่)', visible: true, order: personnelGroups.value.length + 1 })
}
function removeGroup(i) {
  personnelGroups.value.splice(i, 1)
  personnelGroups.value.forEach((g, idx) => g.order = idx + 1)
}
async function saveGroups() {
  savingGroups.value = true
  await updateConfig({ personnel_groups: personnelGroups.value })
  savingGroups.value = false
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 800 })
}

const createForm = ref({ email: '', password: '', full_name: '', role: 'supervisor', org_role: 'supervisor' })

async function createUser() {
  if (!createForm.value.email || !createForm.value.password || !createForm.value.full_name)
    return Swal.fire({ icon: 'warning', title: 'กรอกข้อมูลให้ครบ' })
  if (createForm.value.password.length < 8)
    return Swal.fire({ icon: 'warning', title: 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร' })

  creating.value = true
  try {
    const { data, error } = await supabase.functions.invoke('admin-users', {
      body: {
        action: 'create_personnel',
        email: createForm.value.email,
        password: createForm.value.password,
        full_name: createForm.value.full_name,
        role: createForm.value.role,
        org_role: createForm.value.org_role,
      },
    })
    if (error || data?.error) throw new Error(data?.error || error.message)

    Swal.fire({ icon: 'success', title: 'สร้างบัญชีสำเร็จ', text: `${createForm.value.email} พร้อมใช้งานแล้ว`, confirmButtonColor: '#3b82f6' })
    showCreate.value = false
    createForm.value = { email: '', password: '', full_name: '', role: 'supervisor', org_role: 'supervisor' }
    load()
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'สร้างบัญชีไม่สำเร็จ', text: e.message })
  } finally { creating.value = false }
}

const ORG_ROLES = [
  { value: 'director',      label: 'ผู้อำนวยการเขต' },
  { value: 'deputy',        label: 'รองผู้อำนวยการเขต' },
  { value: 'group_director',label: 'ผู้อำนวยการกลุ่ม' },
  { value: 'supervisor',    label: 'ศึกษานิเทศก์' },
  { value: 'staff',         label: 'เจ้าหน้าที่' },
  { value: 'other',         label: 'อื่นๆ' },
]
const ORG_ROLE_ORDER = ['director','deputy','group_director','supervisor','staff','other']
const TITLE_OPTIONS = ['นาย','นาง','นางสาว','ดร.','ผศ.ดร.','รศ.ดร.']
const SUBJECT_OPTIONS = [
  'ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ',
  'สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ',
  'กิจกรรมพัฒนาผู้เรียน','ปฐมวัย','การศึกษาพิเศษ',
]

const form = ref({})
const expertiseInput = ref('')

const searchQ = ref('')
const filterRole = ref('')

const filtered = computed(() => {
  let list = [...personnel.value]
  if (filterRole.value) list = list.filter(p => p.org_role === filterRole.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.toLowerCase()
    list = list.filter(p =>
      (p.full_name||'').toLowerCase().includes(q) ||
      (p.first_name||'').toLowerCase().includes(q) ||
      (p.last_name||'').toLowerCase().includes(q) ||
      (p.position||'').toLowerCase().includes(q) ||
      (p.department||'').toLowerCase().includes(q)
    )
  }
  return list
})

function displayName(p) {
  if (p.first_name || p.last_name) return `${p.title||''}${p.first_name||''}${p.last_name ? ' ' + p.last_name : ''}`.trim()
  return p.full_name || p.email || '-'
}

const orgRoleLabel = v => ORG_ROLES.find(r => r.value === v)?.label || v

async function load() {
  loading.value = true
  const [{ data }, _] = await Promise.all([
    supabase.from('profiles').select('*').in('role', ['super_admin','admin','supervisor','staff']).order('sort_order', { ascending: true }),
    fetchConfig(),
  ])
  personnelGroups.value = (config.value?.personnel_groups || DEFAULT_GROUPS).map(g => ({ ...g }))
  personnel.value = (data || []).sort((a,b) => {
    const ra = ORG_ROLE_ORDER.indexOf(a.org_role)
    const rb = ORG_ROLE_ORDER.indexOf(b.org_role)
    return ra !== rb ? ra - rb : (a.sort_order||99) - (b.sort_order||99)
  })
  loading.value = false
}
onMounted(load)

function openEdit(p) {
  form.value = {
    id: p.id,
    avatar_url: p.avatar_url||'',
    title: p.title||'', first_name: p.first_name||'', last_name: p.last_name||'',
    full_name: p.full_name||'', position: p.position||'',
    org_role: p.org_role||'staff', department: p.department||'',
    position_level: p.position_level||'', subjects: [...(p.subjects||[])],
    expertise: [...(p.expertise||[])], bio: p.bio||'', sort_order: p.sort_order??99,
    phone: p.phone||'', line_id: p.line_id||'',
    personal_website: p.personal_website||'', portfolio_url: p.portfolio_url||'',
    facebook_url: p.facebook_url||'', youtube_url: p.youtube_url||'',
    tiktok_url: p.tiktok_url||'', twitter_url: p.twitter_url||'',
    instagram_url: p.instagram_url||'', linkedin_url: p.linkedin_url||'',
  }
  expertiseInput.value = ''
  editTarget.value = p
}

function toggleSubject(s) {
  const arr = [...form.value.subjects]
  const idx = arr.indexOf(s)
  idx >= 0 ? arr.splice(idx, 1) : arr.push(s)
  form.value.subjects = arr
}
function addExpertise() {
  const v = expertiseInput.value.trim()
  if (v && !form.value.expertise.includes(v)) form.value.expertise = [...form.value.expertise, v]
  expertiseInput.value = ''
}
function removeExpertise(v) { form.value.expertise = form.value.expertise.filter(x => x !== v) }

// ── Avatar upload ────────────────────────────────────────────────
const showCropper    = ref(false)
const uploadingAvatar = ref(false)

async function compressToWebp(dataUrl, maxSize = 400, quality = 0.85) {
  return new Promise(resolve => {
    const img = new Image()
    img.onload = () => {
      const ratio = Math.min(maxSize / img.width, maxSize / img.height, 1)
      const canvas = document.createElement('canvas')
      canvas.width  = Math.round(img.width  * ratio)
      canvas.height = Math.round(img.height * ratio)
      canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height)
      resolve(canvas.toDataURL('image/webp', quality))
    }
    img.src = dataUrl
  })
}

async function onCropped({ dataUrl }) {
  showCropper.value = false
  uploadingAvatar.value = true
  try {
    const compressed = await compressToWebp(dataUrl, 400, 0.85)
    const res  = await fetch(compressed)
    const blob = await res.blob()
    const path = `avatars/${editTarget.value.id}.webp`
    const { error: upErr } = await supabase.storage.from('images')
      .upload(path, blob, { contentType: 'image/webp', upsert: true })
    if (upErr) throw upErr
    const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
    const url = publicUrl + '?t=' + Date.now()
    form.value.avatar_url = url
    // บันทึกทันที
    await supabase.from('profiles').update({ avatar_url: url }).eq('id', editTarget.value.id)
    editTarget.value.avatar_url = url
    Swal.fire({ icon: 'success', title: 'อัปโหลดรูปสำเร็จ', showConfirmButton: false, timer: 1200 })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: e.message })
  } finally { uploadingAvatar.value = false }
}

async function save() {
  saving.value = true
  const { id, ...patch } = form.value
  const fullName = patch.first_name
    ? `${patch.title} ${patch.first_name} ${patch.last_name}`.trim()
    : patch.full_name
  const { error } = await supabase.from('profiles')
    .update({ ...patch, full_name: fullName })
    .eq('id', id)
  saving.value = false
  if (error) return Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 900 })
  editTarget.value = null
  load()
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2"><SvgIcon name="users" class="w-6 h-6 text-primary"/> จัดการบุคลากร</h1>
        <p class="text-sm text-slate-500 mt-0.5">แก้ไขข้อมูลบุคลากร ตำแหน่ง กลุ่มสาระ และ social media</p>
      </div>
      <button @click="showCreate = true"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary text-white font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        สร้างบัญชีบุคลากร
      </button>
    </div>

    <!-- Create user modal -->
    <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" leave-to-class="opacity-0">
      <div v-if="showCreate" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 space-y-4">
          <h2 class="text-lg font-extrabold text-slate-800">สร้างบัญชีบุคลากร</h2>
          <p class="text-xs text-slate-400">บัญชีจะถูกสร้างและอนุมัติทันที บุคลากรสามารถ login ได้เลย</p>

          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ชื่อ-นามสกุล *</label>
            <input v-model="createForm.full_name" type="text" placeholder="เช่น นาย วินัย หนุนกระโทก"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>
          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">อีเมล *</label>
            <input v-model="createForm.email" type="email" placeholder="email@korat2.go.th"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
          </div>
          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">รหัสผ่านเริ่มต้น *</label>
            <input v-model="createForm.password" type="text" placeholder="อย่างน้อย 8 ตัวอักษร"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
            <p class="text-[10px] text-slate-400 mt-0.5">แจ้งให้บุคลากรเปลี่ยนรหัสผ่านหลัง login ครั้งแรก</p>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">System role</label>
              <select v-model="createForm.role"
                class="mt-1 w-full px-2 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                <option value="admin">Admin</option>
                <option value="supervisor">ศึกษานิเทศก์</option>
                <option value="staff">เจ้าหน้าที่</option>
              </select>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ตำแหน่งองค์กร</label>
              <select v-model="createForm.org_role"
                class="mt-1 w-full px-2 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                <option v-for="r in ORG_ROLES" :key="r.value" :value="r.value">{{ r.label }}</option>
              </select>
            </div>
          </div>

          <div class="flex gap-3 pt-2">
            <button @click="showCreate = false"
              class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
              ยกเลิก
            </button>
            <button @click="createUser" :disabled="creating"
              class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
              {{ creating ? 'กำลังสร้าง...' : 'สร้างบัญชี' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- จัดการกลุ่มงาน -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-extrabold text-slate-700 flex items-center gap-2">
          <SvgIcon name="building" class="w-4 h-4 text-primary"/> กลุ่มงาน/สังกัด
        </p>
        <div class="flex items-center gap-2">
          <button @click="addGroup" type="button"
            class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
            <SvgIcon name="plus" class="w-3.5 h-3.5"/> เพิ่มกลุ่ม
          </button>
          <button @click="saveGroups" :disabled="savingGroups" type="button"
            class="px-3 py-1.5 text-xs font-bold bg-primary text-white rounded-xl disabled:opacity-50 transition-colors">
            {{ savingGroups ? '...' : 'บันทึก' }}
          </button>
        </div>
      </div>
      <div class="space-y-2">
        <div v-for="(g, i) in personnelGroups" :key="g.key"
          class="flex items-center gap-2 px-3 py-2 bg-slate-50 rounded-xl border border-slate-100">
          <!-- up/down -->
          <div class="flex flex-col gap-0.5">
            <button @click="moveGroupUp(i)" :disabled="i===0" type="button"
              class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
            </button>
            <button @click="moveGroupDown(i)" :disabled="i===personnelGroups.length-1" type="button"
              class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
            </button>
          </div>
          <!-- label input -->
          <input v-model="g.label" type="text"
            class="flex-1 px-2 py-1 text-sm font-bold border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
          <!-- visible toggle -->
          <button @click="g.visible = !g.visible" type="button"
            :class="['px-2.5 py-1 text-xs font-bold rounded-lg transition-colors',
              g.visible ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-200 text-slate-400']">
            {{ g.visible ? '👁 แสดง' : '🚫 ซ่อน' }}
          </button>
          <!-- delete -->
          <button @click="removeGroup(i)" type="button"
            class="w-6 h-6 flex items-center justify-center rounded text-slate-300 hover:text-red-400 hover:bg-red-50 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อ ตำแหน่ง กลุ่มงาน..."
        class="flex-1 min-w-[200px] px-4 py-2.5 border border-slate-200 rounded-2xl text-sm focus:outline-none focus:border-primary"/>
      <select v-model="filterRole"
        class="px-4 py-2.5 border border-slate-200 rounded-2xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="">ทุกตำแหน่ง</option>
        <option v-for="r in ORG_ROLES" :key="r.value" :value="r.value">{{ r.label }}</option>
      </select>
    </div>

    <!-- List -->
    <div v-if="loading" class="space-y-2">
      <div v-for="i in 5" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <div v-else class="space-y-2">
      <div v-for="p in filtered" :key="p.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm px-4 py-3 flex flex-wrap items-center gap-3">
        <!-- Avatar -->
        <div class="w-10 h-10 rounded-xl overflow-hidden bg-slate-100 flex-shrink-0">
          <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover"/>
          <div v-else class="w-full h-full flex items-center justify-center text-sm font-extrabold text-primary">
            {{ displayName(p)[0]||'?' }}
          </div>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <p class="font-bold text-slate-800 truncate text-sm">{{ displayName(p) }}</p>
          <p class="text-xs text-slate-400">{{ p.position_level || p.position || '-' }}</p>
        </div>
        <!-- Badges -->
        <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 hidden sm:block">
          {{ orgRoleLabel(p.org_role) }}
        </span>
        <span v-if="p.department" class="text-[10px] text-slate-400 hidden md:block max-w-[120px] truncate">
          {{ p.department }}
        </span>
        <!-- Subjects mini -->
        <div class="hidden lg:flex gap-1">
          <span v-for="s in (p.subjects||[]).slice(0,2)" :key="s"
            class="text-[9px] font-bold px-1.5 py-0.5 bg-secondary/10 text-secondary rounded-full">{{ s }}</span>
        </div>
        <span class="text-xs text-slate-400 font-mono hidden sm:block">#{{ p.sort_order||99 }}</span>
        <!-- Edit btn -->
        <button @click="openEdit(p)"
          class="px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary hover:text-white transition-colors flex-shrink-0">
          แก้ไข
        </button>
      </div>
      <p v-if="!filtered.length" class="text-center text-slate-400 text-sm py-8">ไม่พบบุคลากร</p>
    </div>

    <!-- Edit Modal -->
    <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" leave-to-class="opacity-0">
      <div v-if="editTarget" class="fixed inset-0 z-50 flex items-start justify-center p-4 bg-black/50 backdrop-blur-sm overflow-y-auto">
        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl my-4 p-6 space-y-5">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-extrabold text-slate-800">แก้ไข: {{ displayName(editTarget) }}</h2>
            <button @click="editTarget=null"
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Avatar upload -->
          <div class="flex items-center gap-5 p-4 bg-slate-50 rounded-2xl">
            <div class="relative flex-shrink-0">
              <div class="w-20 h-20 rounded-full overflow-hidden bg-slate-200 ring-2 ring-white shadow-md">
                <img v-if="form.avatar_url || editTarget?.avatar_url"
                  :src="form.avatar_url || editTarget?.avatar_url"
                  class="w-full h-full object-cover"/>
                <div v-else class="w-full h-full flex items-center justify-center text-2xl font-extrabold text-slate-400">
                  {{ displayName(editTarget)[0] || '?' }}
                </div>
              </div>
              <!-- upload spinner overlay -->
              <div v-if="uploadingAvatar" class="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center">
                <svg class="w-5 h-5 text-white animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
              </div>
            </div>
            <div>
              <p class="text-sm font-bold text-slate-700 mb-1">รูปโปรไฟล์</p>
              <p class="text-xs text-slate-400 mb-3">ภาพจะถูกครอบและย่อเป็น 400×400 px อัตโนมัติ</p>
              <button @click="showCropper = true" :disabled="uploadingAvatar" type="button"
                class="flex items-center gap-2 px-4 py-2 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-50">
                <SvgIcon name="folder" class="w-3.5 h-3.5"/>
                {{ uploadingAvatar ? 'กำลังอัปโหลด...' : 'เลือกรูปภาพ' }}
              </button>
            </div>
          </div>

          <!-- ชื่อ -->
          <div class="grid grid-cols-4 gap-3">
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">คำนำหน้า</label>
              <select v-model="form.title"
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                <option value="">-</option>
                <option v-for="t in TITLE_OPTIONS" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ชื่อ</label>
              <input v-model="form.first_name" type="text"
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">นามสกุล</label>
              <input v-model="form.last_name" type="text"
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ลำดับ</label>
              <input v-model.number="form.sort_order" type="number" min="1"
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
          </div>

          <!-- ตำแหน่ง -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ตำแหน่งในองค์กร</label>
              <select v-model="form.org_role"
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                <option v-for="r in ORG_ROLES" :key="r.value" :value="r.value">{{ r.label }}</option>
              </select>
            </div>
            <div>
              <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">วิทยฐานะ</label>
              <input v-model="form.position_level" type="text" placeholder="ชำนาญการ, ชำนาญการพิเศษ..."
                class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
          </div>

          <!-- ตำแหน่งแสดงบนทำเนียบ (เฉพาะผู้บริหาร) -->
          <div v-if="['director','deputy','group_director'].includes(form.org_role)">
            <label class="text-[10px] font-bold text-amber-600 uppercase tracking-wider">
              ตำแหน่งที่แสดงบนทำเนียบ <span class="text-amber-400 font-normal normal-case">(พิมพ์ได้อิสระ)</span>
            </label>
            <input v-model="form.position" type="text"
              placeholder="เช่น ผอ.สพป.นม.2, รอง ผอ.สพป.นม.2, ผอ.กลุ่มนิเทศฯ"
              class="mt-1 w-full px-2 py-1.5 border border-amber-300 bg-amber-50 rounded-xl text-sm focus:outline-none focus:border-amber-500"/>
            <p class="text-[10px] text-amber-500 mt-0.5">ข้อความนี้จะแสดงใต้ชื่อบนการ์ดทำเนียบ</p>
          </div>

          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">กลุ่มงาน/สังกัด</label>
            <select v-model="form.department"
              class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="">-- ไม่ระบุ --</option>
              <option v-for="dep in deptOptions" :key="dep" :value="dep">{{ dep }}</option>
            </select>
          </div>

          <!-- กลุ่มสาระ -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-2 block">กลุ่มสาระ</label>
            <div class="flex flex-wrap gap-1.5">
              <button v-for="s in SUBJECT_OPTIONS" :key="s" type="button" @click="toggleSubject(s)"
                :class="['px-2.5 py-1 rounded-lg text-xs font-bold border transition-all',
                  form.subjects.includes(s) ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                {{ s }}
              </button>
            </div>
          </div>

          <!-- Expertise -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5 block">ความเชี่ยวชาญ</label>
            <div class="flex gap-2 mb-2">
              <input v-model="expertiseInput" @keydown.enter.prevent="addExpertise" type="text" placeholder="Enter เพื่อเพิ่ม"
                class="flex-1 px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              <button @click="addExpertise" type="button"
                class="px-3 py-1.5 bg-primary text-white text-xs font-bold rounded-xl">เพิ่ม</button>
            </div>
            <div class="flex flex-wrap gap-1.5">
              <span v-for="tag in form.expertise" :key="tag"
                class="flex items-center gap-1 px-2.5 py-0.5 bg-primary/10 text-primary text-xs font-bold rounded-full">
                {{ tag }}<button @click="removeExpertise(tag)" class="hover:text-red-500">×</button>
              </span>
            </div>
          </div>

          <!-- Bio -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Bio</label>
            <textarea v-model="form.bio" rows="2"
              class="mt-1 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-none"/>
          </div>

          <!-- Social (collapsed) -->
          <details class="border border-slate-200 rounded-xl">
            <summary class="px-4 py-2.5 text-sm font-bold text-slate-700 cursor-pointer hover:bg-slate-50 rounded-xl">
              Social Media & ติดต่อ
            </summary>
            <div class="px-4 pb-4 pt-2 grid grid-cols-2 gap-3">
              <div v-for="key in ['phone','line_id','personal_website','portfolio_url','facebook_url','youtube_url','tiktok_url','twitter_url','instagram_url','linkedin_url']" :key="key">
                <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">{{ key.replace(/_url$/,'').replace(/_/g,' ') }}</label>
                <input v-model="form[key]" type="text"
                  class="mt-0.5 w-full px-2 py-1.5 border border-slate-200 rounded-xl text-xs focus:outline-none focus:border-primary font-mono"/>
              </div>
            </div>
          </details>

          <div class="flex gap-3 pt-2">
            <button @click="editTarget=null"
              class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
              ยกเลิก
            </button>
            <button @click="save" :disabled="saving"
              class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
              {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Image Cropper Modal -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="1"
      title="ครอบรูปโปรไฟล์บุคลากร"
      @cropped="onCropped"
      @close="showCropper = false"/>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
