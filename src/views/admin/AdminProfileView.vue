<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import ImageCropperModal from '../../components/ImageCropperModal.vue'
import Swal from 'sweetalert2'

const { config, fetchConfig } = useAreaConfig()
// เดียวกับตัวเลือก "กลุ่มงาน/สังกัด" ใน AdminPersonnelView.vue — ให้ผู้ใช้เลือกจากรายการที่ตั้งไว้จริง
// (แก้บั๊ก: เดิมเป็นช่องพิมพ์อิสระ ทำให้พิมพ์ชื่อกลุ่มเพี้ยนจากที่ตั้งค่าไว้ กลายเป็นกลุ่มลอยไม่ตรงกับใครในผังองค์กร)
const deptOptions = computed(() =>
  (config.value?.personnel_groups || [])
    .filter(g => g.visible !== false)
    .sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
    .map(g => g.label)
)

const profile   = ref(null)
const loading   = ref(true)
const saving    = ref(false)
const activeTab = ref('basic')

// ── Form ──────────────────────────────────────────────────────────
const form = ref({
  // พื้นฐาน
  title: '', first_name: '', last_name: '', full_name: '',
  avatar_url: '', position: '',
  // บุคลากร
  org_role: 'staff', department: '', position_level: '',
  subjects: [], expertise: [], bio: '',
  sort_order: 99,
  // ติดต่อ
  phone: '', line_id: '',
  // social
  personal_website: '', portfolio_url: '',
  facebook_url: '', youtube_url: '', tiktok_url: '',
  twitter_url: '', instagram_url: '', linkedin_url: '',
  // visibility
  contact_visibility: {
    phone: false, email: false, line_id: false,
    personal_website: true, portfolio_url: true,
    facebook_url: true, youtube_url: true,
    tiktok_url: true, twitter_url: true,
    instagram_url: true, linkedin_url: true,
  },
})

const tabs = [
  { key: 'basic',    label: 'รูปและข้อมูลพื้นฐาน' },
  { key: 'work',     label: 'ข้อมูลบุคลากร' },
  { key: 'contact',  label: 'ติดต่อ & Social' },
  { key: 'password', label: 'รหัสผ่าน' },
]

const ORG_ROLES = [
  { value: 'director',      label: 'ผู้อำนวยการเขตพื้นที่' },
  { value: 'deputy',        label: 'รองผู้อำนวยการเขตพื้นที่' },
  { value: 'group_director',label: 'ผู้อำนวยการกลุ่ม' },
  { value: 'supervisor',    label: 'ศึกษานิเทศก์' },
  { value: 'staff',         label: 'เจ้าหน้าที่/บุคลากร' },
  { value: 'other',         label: 'อื่นๆ' },
]
const TITLE_OPTIONS = ['นาย','นาง','นางสาว','ดร.','ผศ.ดร.','รศ.ดร.']
const SUBJECT_OPTIONS = [
  'ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ',
  'สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ',
  'กิจกรรมพัฒนาผู้เรียน','ปฐมวัย','การศึกษาพิเศษ',
]
const POSITION_LEVELS = [
  'ศึกษานิเทศก์','ศึกษานิเทศก์ชำนาญการ',
  'ศึกษานิเทศก์ชำนาญการพิเศษ','ศึกษานิเทศก์เชี่ยวชาญ',
]
// SVG paths สำหรับ social fields
const SOCIAL_FIELDS = [
  { key: 'personal_website', label: 'เว็บไซต์ส่วนตัว',  placeholder: 'https://...',              svgPath: 'M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418' },
  { key: 'portfolio_url',    label: 'Portfolio/ผลงาน',   placeholder: 'https://...',              svgPath: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  { key: 'facebook_url',     label: 'Facebook',           placeholder: 'https://facebook.com/...', svgPath: 'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244' },
  { key: 'youtube_url',      label: 'YouTube',            placeholder: 'https://youtube.com/...',  svgPath: 'M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z' },
  { key: 'tiktok_url',       label: 'TikTok',             placeholder: 'https://tiktok.com/...',   svgPath: 'M15.75 2.25a.75.75 0 01.75.75v.75a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75zm4.5 2.25a.75.75 0 00-1.5 0v.75a.75.75 0 001.5 0V4.5zM9 12a3 3 0 100 6 3 3 0 000-6zm-4.5 3a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zm12-7.5v9a6 6 0 01-12 0v-1.5' },
  { key: 'twitter_url',      label: 'X (Twitter)',        placeholder: 'https://x.com/...',        svgPath: 'M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.615 11.615 0 006.29 1.84' },
  { key: 'instagram_url',    label: 'Instagram',          placeholder: 'https://instagram.com/...', svgPath: 'M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.776 48.776 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316zM16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z' },
  { key: 'linkedin_url',     label: 'LinkedIn',           placeholder: 'https://linkedin.com/...',  svgPath: 'M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 2.25 0 00-2.25 2.25v.894m7.5 0a48.667 48.667 0 00-7.5 0M12 12.75h.008v.008H12V12.75z' },
]

const roleLabel = computed(() => ({
  super_admin:'ผู้ดูแลสูงสุด', admin:'ผู้ดูแลระบบ',
  supervisor:'ศึกษานิเทศก์',   staff:'เจ้าหน้าที่',
  school:'ผู้แทนโรงเรียน',     teacher:'ครู',
}[profile.value?.role] || '-'))

const roleColor = computed(() => ({
  super_admin:'bg-red-100 text-red-700',   admin:'bg-purple-100 text-purple-700',
  supervisor:'bg-blue-100 text-blue-700',  staff:'bg-indigo-100 text-indigo-700',
  school:'bg-emerald-100 text-emerald-700',teacher:'bg-amber-100 text-amber-700',
}[profile.value?.role] || 'bg-slate-100 text-slate-600'))

const isPersonnel = computed(() =>
  ['super_admin','admin','supervisor','staff'].includes(profile.value?.role))

const displayName = computed(() => {
  const f = form.value
  if (f.first_name || f.last_name) return `${f.title || ''}${f.first_name || ''}${f.last_name ? ' ' + f.last_name : ''}`.trim()
  return f.full_name || profile.value?.email || 'ผู้ใช้งาน'
})

// ── Avatar upload + crop + compress ─────────────────────────────
const showCropper     = ref(false)
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
    // compress → 400×400 webp
    const compressed = await compressToWebp(dataUrl, 400, 0.85)
    const res  = await fetch(compressed)
    const blob = await res.blob()
    const path = `avatars/${profile.value.id}.webp`

    const { error: upErr } = await supabase.storage.from('images')
      .upload(path, blob, { contentType: 'image/webp', upsert: true })
    if (upErr) throw upErr

    const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
    form.value.avatar_url = publicUrl + '?t=' + Date.now()
    await supabase.from('profiles').update({ avatar_url: form.value.avatar_url }).eq('id', profile.value.id)
    Swal.fire({ icon: 'success', title: 'อัปโหลดรูปสำเร็จ', showConfirmButton: false, timer: 1200 })
  } catch (e) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: e.message })
  } finally { uploadingAvatar.value = false }
}

// ── Subject / Expertise tags ─────────────────────────────────────
function toggleSubject(s) {
  const arr = [...(form.value.subjects || [])]
  const idx = arr.indexOf(s)
  idx >= 0 ? arr.splice(idx, 1) : arr.push(s)
  form.value.subjects = arr
}

const expertiseInput = ref('')
function addExpertise() {
  const v = expertiseInput.value.trim()
  if (!v) return
  if (!form.value.expertise.includes(v)) form.value.expertise = [...form.value.expertise, v]
  expertiseInput.value = ''
}
function removeExpertise(v) {
  form.value.expertise = form.value.expertise.filter(x => x !== v)
}

// ── Visibility toggle ────────────────────────────────────────────
function toggleVis(key) {
  form.value.contact_visibility = {
    ...form.value.contact_visibility,
    [key]: !form.value.contact_visibility[key],
  }
}

// ── Load ─────────────────────────────────────────────────────────
onMounted(async () => {
  fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return
  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  profile.value = data
  if (data) {
    const DEFAULT_VIS = {
      phone: false, email: false, line_id: false,
      personal_website: true, portfolio_url: true,
      facebook_url: true, youtube_url: true,
      tiktok_url: true, twitter_url: true,
      instagram_url: true, linkedin_url: true,
    }
    form.value = {
      title:             data.title            || '',
      first_name:        data.first_name       || '',
      last_name:         data.last_name        || '',
      full_name:         data.full_name        || '',
      avatar_url:        data.avatar_url       || '',
      position:          data.position         || '',
      org_role:          data.org_role         || 'staff',
      department:        data.department       || '',
      position_level:    data.position_level   || '',
      subjects:          data.subjects         || [],
      expertise:         data.expertise        || [],
      bio:               data.bio              || '',
      sort_order:        data.sort_order       ?? 99,
      phone:             data.phone            || '',
      line_id:           data.line_id          || '',
      personal_website:  data.personal_website || '',
      portfolio_url:     data.portfolio_url    || '',
      facebook_url:      data.facebook_url     || '',
      youtube_url:       data.youtube_url      || '',
      tiktok_url:        data.tiktok_url       || '',
      twitter_url:       data.twitter_url      || '',
      instagram_url:     data.instagram_url    || '',
      linkedin_url:      data.linkedin_url     || '',
      contact_visibility: { ...DEFAULT_VIS, ...(data.contact_visibility || {}) },
    }
  }
  loading.value = false
})

// ── Save ─────────────────────────────────────────────────────────
async function saveProfile() {
  saving.value = true
  const { id, ...rest } = { id: profile.value.id, ...form.value }
  const fullName = form.value.first_name
    ? `${form.value.title} ${form.value.first_name} ${form.value.last_name}`.trim()
    : form.value.full_name
  const { error } = await supabase.from('profiles')
    .update({ ...rest, full_name: fullName })
    .eq('id', profile.value.id)
  saving.value = false
  if (error) Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  else {
    profile.value = { ...profile.value, ...rest, full_name: fullName }
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1200 })
  }
}

// ── Password ─────────────────────────────────────────────────────
const pwForm   = ref({ newPw: '', confirm: '' })
const pwLoading = ref(false)
const pwStrength = computed(() => {
  const p = pwForm.value.newPw; if (!p) return 0
  let s = 0
  if (p.length >= 8) s++; if (/[A-Z]/.test(p)) s++
  if (/[0-9]/.test(p)) s++; if (/[^A-Za-z0-9]/.test(p)) s++
  return s
})
const pwStrengthLabel = ['','อ่อนมาก','อ่อน','ปานกลาง','แข็งแกร่ง']
const pwStrengthColor = ['','bg-red-400','bg-orange-400','bg-yellow-400','bg-emerald-400']
async function changePassword() {
  if (pwForm.value.newPw !== pwForm.value.confirm)
    return Swal.fire({ icon: 'warning', title: 'รหัสผ่านไม่ตรงกัน' })
  if (pwForm.value.newPw.length < 8)
    return Swal.fire({ icon: 'warning', title: 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร' })
  pwLoading.value = true
  const { error } = await supabase.auth.updateUser({ password: pwForm.value.newPw })
  pwLoading.value = false
  if (error) Swal.fire({ icon: 'error', title: 'ไม่สำเร็จ', text: error.message })
  else { pwForm.value = { newPw: '', confirm: '' }; Swal.fire({ icon: 'success', title: 'เปลี่ยนรหัสผ่านสำเร็จ', showConfirmButton: false, timer: 1500 }) }
}
</script>

<template>
  <div class="font-sarabun max-w-2xl mx-auto space-y-5">

    <!-- Header card -->
    <div class="bg-gradient-to-br from-slate-700 to-slate-900 rounded-3xl p-6 text-white">
      <div class="flex items-center gap-5">
        <!-- Avatar -->
        <div class="relative flex-shrink-0">
          <div class="w-20 h-20 rounded-2xl overflow-hidden bg-primary ring-2 ring-white/20 shadow-xl">
            <img v-if="form.avatar_url" :src="form.avatar_url" class="w-full h-full object-cover"/>
            <div v-else class="w-full h-full flex items-center justify-center text-3xl font-extrabold">
              {{ (form.first_name || form.full_name || 'U')[0].toUpperCase() }}
            </div>
          </div>
          <button @click="showCropper = true" :disabled="uploadingAvatar"
            class="absolute -bottom-1.5 -right-1.5 w-7 h-7 bg-white rounded-full flex items-center justify-center shadow-md hover:bg-slate-100 transition-colors">
            <svg v-if="!uploadingAvatar" class="w-3.5 h-3.5 text-slate-700" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.776 48.776 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"/>
            </svg>
            <svg v-else class="w-3.5 h-3.5 text-slate-700 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
            </svg>
          </button>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <h1 class="text-xl font-extrabold leading-tight truncate">{{ displayName }}</h1>
          <p class="text-slate-400 text-sm mt-0.5">{{ profile?.email }}</p>
          <p v-if="form.position || form.position_level" class="text-slate-300 text-xs mt-0.5">
            {{ form.position_level || form.position }}
          </p>
          <div class="flex items-center gap-2 mt-2">
            <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', roleColor]">{{ roleLabel }}</span>
            <span v-if="profile?.is_approved" class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">✅ อนุมัติ</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex flex-wrap gap-1 bg-white rounded-2xl border border-slate-200 p-1 shadow-sm">
      <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
        :class="['flex-1 py-2 text-xs font-bold rounded-xl transition-all min-w-[80px]',
          activeTab === tab.key ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:bg-slate-50']">
        {{ tab.label }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 4" :key="i" class="h-12 bg-slate-100 rounded-xl animate-pulse"></div>
    </div>

    <template v-else>

      <!-- ── TAB: พื้นฐาน ──────────────────────────────────────── -->
      <div v-if="activeTab === 'basic'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-4">
        <h2 class="font-extrabold text-slate-800">ข้อมูลพื้นฐาน</h2>

        <!-- คำนำหน้า + ชื่อ + นามสกุล -->
        <div class="grid grid-cols-4 gap-3">
          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">คำนำหน้า</label>
            <select v-model="form.title"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="">-</option>
              <option v-for="t in TITLE_OPTIONS" :key="t" :value="t">{{ t }}</option>
            </select>
          </div>
          <div class="col-span-3 grid grid-cols-2 gap-3">
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ชื่อ</label>
              <input v-model="form.first_name" type="text" placeholder="ชื่อ"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">นามสกุล</label>
              <input v-model="form.last_name" type="text" placeholder="นามสกุล"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
          </div>
        </div>

        <!-- ชื่อ-นามสกุล (กรณีไม่แยก) -->
        <div v-if="!form.first_name && !form.last_name">
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ชื่อ-นามสกุล (เดิม)</label>
          <input v-model="form.full_name" type="text"
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
        </div>

        <!-- ตำแหน่ง -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ตำแหน่งงาน</label>
          <input v-model="form.position" type="text" placeholder="เช่น ศึกษานิเทศก์"
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
        </div>

        <!-- ลำดับแสดงผล -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ลำดับในทำเนียบ (น้อย = ขึ้นก่อน)</label>
          <input v-model.number="form.sort_order" type="number" min="1"
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
        </div>
      </div>

      <!-- ── TAB: บุคลากร ──────────────────────────────────────── -->
      <div v-if="activeTab === 'work'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-5">
        <h2 class="font-extrabold text-slate-800">ข้อมูลบุคลากร</h2>

        <!-- ตำแหน่งในองค์กร -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ตำแหน่งในองค์กร</label>
            <select v-model="form.org_role"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option v-for="r in ORG_ROLES" :key="r.value" :value="r.value">{{ r.label }}</option>
            </select>
          </div>
          <div>
            <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ระดับ/วิทยฐานะ</label>
            <select v-model="form.position_level"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="">-</option>
              <option v-for="l in POSITION_LEVELS" :key="l" :value="l">{{ l }}</option>
              <option value="custom">อื่นๆ</option>
            </select>
          </div>
        </div>

        <!-- กลุ่มงาน -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">กลุ่มงาน/สังกัด</label>
          <select v-model="form.department"
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
            <option value="">-- ไม่ระบุ --</option>
            <option v-for="dep in deptOptions" :key="dep" :value="dep">{{ dep }}</option>
          </select>
        </div>

        <!-- กลุ่มสาระ -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2 block">กลุ่มสาระรับผิดชอบ</label>
          <div class="flex flex-wrap gap-2">
            <button v-for="s in SUBJECT_OPTIONS" :key="s" type="button"
              @click="toggleSubject(s)"
              :class="['px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-all',
                form.subjects.includes(s)
                  ? 'border-primary bg-primary text-white'
                  : 'border-slate-200 text-slate-600 hover:border-primary/50']">
              {{ s }}
            </button>
          </div>
        </div>

        <!-- ความเชี่ยวชาญ -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2 block">ความเชี่ยวชาญพิเศษ (tag)</label>
          <div class="flex gap-2 mb-2">
            <input v-model="expertiseInput" @keydown.enter.prevent="addExpertise"
              type="text" placeholder="พิมพ์แล้วกด Enter"
              class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            <button @click="addExpertise" type="button"
              class="px-4 py-2 bg-primary text-white text-sm font-bold rounded-xl hover:bg-primary-dark transition-colors">
              เพิ่ม
            </button>
          </div>
          <div class="flex flex-wrap gap-2">
            <span v-for="tag in form.expertise" :key="tag"
              class="flex items-center gap-1.5 px-3 py-1 bg-primary/10 text-primary text-xs font-bold rounded-full">
              {{ tag }}
              <button @click="removeExpertise(tag)" class="hover:text-red-500 transition-colors">×</button>
            </span>
          </div>
        </div>

        <!-- ประวัติย่อ -->
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ประวัติย่อ / Bio</label>
          <textarea v-model="form.bio" rows="4"
            placeholder="แนะนำตัวเอง ประสบการณ์ ความเชี่ยวชาญ..."
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-y"/>
        </div>
      </div>

      <!-- ── TAB: ติดต่อ & Social ──────────────────────────────── -->
      <div v-if="activeTab === 'contact'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-5">
        <h2 class="font-extrabold text-slate-800">ติดต่อ & Social Media</h2>
        <!-- legend -->
        <div class="flex items-center gap-4 text-xs text-slate-400">
          <span class="flex items-center gap-1">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/></svg>
            ซ่อน
          </span>
          <span class="flex items-center gap-1">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
            แสดงสาธารณะ
          </span>
        </div>

        <!-- SVG helper สำหรับ contact icons -->
        <div class="space-y-3">
          <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">ข้อมูลติดต่อ</p>

          <!-- email -->
          <div class="flex items-center gap-3">
            <div class="w-7 h-7 flex items-center justify-center rounded-lg bg-slate-100 flex-shrink-0">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/></svg>
            </div>
            <div class="flex-1">
              <p class="text-xs font-bold text-slate-500">อีเมล (จากระบบ auth)</p>
              <p class="text-sm text-slate-700">{{ profile?.email }}</p>
            </div>
            <button @click="toggleVis('email')" type="button"
              :class="['w-9 h-9 rounded-xl flex items-center justify-center transition-colors',
                form.contact_visibility.email ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400']">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path v-if="form.contact_visibility.email" stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
              </svg>
            </button>
          </div>

          <!-- phone -->
          <div class="flex items-center gap-3">
            <div class="w-7 h-7 flex items-center justify-center rounded-lg bg-slate-100 flex-shrink-0">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 6.75z"/></svg>
            </div>
            <input v-model="form.phone" type="tel" placeholder="เบอร์โทรศัพท์"
              class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            <button @click="toggleVis('phone')" type="button"
              :class="['w-9 h-9 rounded-xl flex items-center justify-center transition-colors',
                form.contact_visibility.phone ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400']">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path v-if="form.contact_visibility.phone" stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
              </svg>
            </button>
          </div>

          <!-- LINE -->
          <div class="flex items-center gap-3">
            <div class="w-7 h-7 flex items-center justify-center rounded-lg bg-slate-100 flex-shrink-0">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 01-.923 1.785A5.969 5.969 0 006 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337z"/></svg>
            </div>
            <input v-model="form.line_id" type="text" placeholder="LINE ID"
              class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            <button @click="toggleVis('line_id')" type="button"
              :class="['w-9 h-9 rounded-xl flex items-center justify-center transition-colors',
                form.contact_visibility.line_id ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400']">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path v-if="form.contact_visibility.line_id" stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Social Media -->
        <div class="space-y-3">
          <p class="text-xs font-bold text-slate-500 uppercase tracking-widest">Social Media & เว็บไซต์</p>
          <div v-for="sf in SOCIAL_FIELDS" :key="sf.key" class="flex items-center gap-3">
            <!-- icon -->
            <div class="w-7 h-7 flex items-center justify-center rounded-lg bg-slate-100 flex-shrink-0">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" :d="sf.svgPath"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-0.5">{{ sf.label }}</p>
              <input v-model="form[sf.key]" type="url" :placeholder="sf.placeholder"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <!-- visibility toggle -->
            <button @click="toggleVis(sf.key)" type="button"
              :class="['w-9 h-9 rounded-xl flex items-center justify-center transition-colors flex-shrink-0',
                form.contact_visibility[sf.key] ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-400']">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path v-if="form.contact_visibility[sf.key]" stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path v-else stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- ── TAB: รหัสผ่าน ─────────────────────────────────────── -->
      <div v-if="activeTab === 'password'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-4">
        <h2 class="font-extrabold text-slate-800">เปลี่ยนรหัสผ่าน</h2>
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">รหัสผ่านใหม่</label>
          <input v-model="pwForm.newPw" type="password" minlength="8"
            class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          <div v-if="pwForm.newPw" class="mt-2 flex items-center gap-2">
            <div class="flex gap-1 flex-1">
              <div v-for="i in 4" :key="i"
                :class="['h-1.5 flex-1 rounded-full transition-colors',
                  i <= pwStrength ? pwStrengthColor[pwStrength] : 'bg-slate-200']"/>
            </div>
            <span class="text-xs font-bold text-slate-500">{{ pwStrengthLabel[pwStrength] }}</span>
          </div>
        </div>
        <div>
          <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ยืนยันรหัสผ่าน</label>
          <input v-model="pwForm.confirm" type="password"
            :class="['mt-1 w-full px-3 py-2 border rounded-xl text-sm focus:outline-none',
              pwForm.confirm && pwForm.confirm !== pwForm.newPw
                ? 'border-red-300 focus:border-red-400' : 'border-slate-200 focus:border-primary']"/>
          <p v-if="pwForm.confirm && pwForm.confirm !== pwForm.newPw" class="text-xs text-red-500 mt-1">รหัสผ่านไม่ตรงกัน</p>
        </div>
        <button @click="changePassword" :disabled="pwLoading || !pwForm.newPw || pwForm.newPw !== pwForm.confirm"
          class="w-full py-3 bg-slate-800 text-white font-bold text-sm rounded-2xl hover:bg-slate-900 transition-colors disabled:opacity-50">
          {{ pwLoading ? 'กำลังเปลี่ยน...' : 'เปลี่ยนรหัสผ่าน' }}
        </button>
      </div>

      <!-- Save button (ยกเว้น tab password) -->
      <button v-if="activeTab !== 'password'"
        @click="saveProfile" :disabled="saving"
        class="w-full py-3.5 bg-primary text-white font-bold text-sm rounded-2xl shadow-md hover:bg-primary-dark hover:-translate-y-0.5 transition-all disabled:opacity-50">
        {{ saving ? 'กำลังบันทึก...' : '💾 บันทึกข้อมูล' }}
      </button>

    </template>

    <!-- Image Cropper Modal -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="1"
      title="ครอบรูปโปรไฟล์"
      @cropped="onCropped"
      @close="showCropper = false"/>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
