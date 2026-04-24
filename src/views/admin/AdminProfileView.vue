<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const profile  = ref(null)
const loading  = ref(true)
const saving   = ref(false)
const activeTab = ref('info')

const form = ref({
  full_name:     '',
  phone:         '',
  line_id:       '',
  subject_group: '',
  work_group:    '',
  school_name:   '',
  teacher_code:  '',
})

const tabs = [
  { key: 'info',     icon: '👤', label: 'ข้อมูลส่วนตัว' },
  { key: 'password', icon: '🔐', label: 'เปลี่ยนรหัสผ่าน' },
]

const roleLabel = computed(() => ({
  super_admin: 'ผู้ดูแลสูงสุด',
  admin:       'ผู้ดูแลระบบ',
  supervisor:  'ศึกษานิเทศก์',
  staff:       'เจ้าหน้าที่',
  school:      'ผู้แทนโรงเรียน',
  teacher:     'ครู',
}[profile.value?.role] || '-'))

const roleColor = computed(() => ({
  super_admin: 'bg-red-100 text-red-700',
  admin:       'bg-purple-100 text-purple-700',
  supervisor:  'bg-blue-100 text-blue-700',
  staff:       'bg-indigo-100 text-indigo-700',
  school:      'bg-emerald-100 text-emerald-700',
  teacher:     'bg-amber-100 text-amber-700',
}[profile.value?.role] || 'bg-slate-100 text-slate-600'))

const isSupervisor = computed(() =>
  ['super_admin','admin','supervisor'].includes(profile.value?.role))
const isTeacher = computed(() =>
  ['teacher','school'].includes(profile.value?.role))

const avatarLetter = computed(() =>
  (form.value.full_name || profile.value?.email || 'U')[0].toUpperCase())

// ── Password form ───────────────────────────────────────────────
const pwForm = ref({ current: '', newPw: '', confirm: '' })
const pwLoading = ref(false)
const showPw = ref({ current: false, new: false, confirm: false })

const pwStrength = computed(() => {
  const p = pwForm.value.newPw
  if (!p) return 0
  let s = 0
  if (p.length >= 8)  s++
  if (/[A-Z]/.test(p)) s++
  if (/[0-9]/.test(p)) s++
  if (/[^A-Za-z0-9]/.test(p)) s++
  return s
})
const pwStrengthLabel = ['', 'อ่อนมาก', 'อ่อน', 'ปานกลาง', 'แข็งแกร่ง']
const pwStrengthColor = ['', 'bg-red-400', 'bg-orange-400', 'bg-yellow-400', 'bg-emerald-400']

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return
  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  profile.value = data
  if (data) {
    form.value = {
      full_name:     data.full_name     || '',
      phone:         data.phone         || '',
      line_id:       data.line_id       || '',
      subject_group: data.subject_group || '',
      work_group:    data.work_group    || '',
      school_name:   data.school_name   || '',
      teacher_code:  data.teacher_code  || '',
    }
  }
  loading.value = false
})

async function saveProfile() {
  saving.value = true
  const { error } = await supabase
    .from('profiles')
    .update({ ...form.value })
    .eq('id', profile.value.id)
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    profile.value = { ...profile.value, ...form.value }
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1500 })
  }
}

async function changePassword() {
  if (pwForm.value.newPw !== pwForm.value.confirm) {
    return Swal.fire({ icon: 'warning', title: 'รหัสผ่านไม่ตรงกัน', confirmButtonColor: '#3b82f6' })
  }
  if (pwForm.value.newPw.length < 8) {
    return Swal.fire({ icon: 'warning', title: 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร', confirmButtonColor: '#3b82f6' })
  }
  pwLoading.value = true
  const { error } = await supabase.auth.updateUser({ password: pwForm.value.newPw })
  pwLoading.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'เปลี่ยนรหัสผ่านไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    pwForm.value = { current: '', newPw: '', confirm: '' }
    Swal.fire({ icon: 'success', title: 'เปลี่ยนรหัสผ่านสำเร็จ', showConfirmButton: false, timer: 1500 })
  }
}

const subjectGroups = [
  'ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ',
  'สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ','กิจกรรมพัฒนาผู้เรียน',
]
const workGroups = [
  'พัฒนาหลักสูตร','นิเทศการศึกษา','วัดและประเมินผล',
  'ประกันคุณภาพ','วิจัยและสื่อ','บริหารจัดการ',
]
</script>

<template>
  <div class="font-sarabun max-w-2xl mx-auto space-y-6">

    <!-- Header card -->
    <div class="bg-gradient-to-br from-slate-700 to-slate-900 rounded-3xl p-6 text-white">
      <div class="flex items-center gap-4">
        <!-- Avatar -->
        <div class="w-16 h-16 bg-primary rounded-2xl flex items-center justify-center text-2xl font-extrabold shadow-lg flex-shrink-0">
          {{ avatarLetter }}
        </div>
        <div class="flex-1 min-w-0">
          <h1 class="text-xl font-extrabold truncate">{{ form.full_name || 'ผู้ใช้งาน' }}</h1>
          <p class="text-slate-400 text-sm truncate">{{ profile?.email }}</p>
          <div class="flex items-center gap-2 mt-1.5">
            <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', roleColor]">{{ roleLabel }}</span>
            <span v-if="profile?.is_approved" class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-700">✅ อนุมัติแล้ว</span>
            <span v-else class="text-xs font-bold px-2.5 py-0.5 rounded-full bg-amber-100 text-amber-700">⏳ รออนุมัติ</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex bg-white rounded-2xl border border-slate-200 p-1 shadow-sm">
      <button v-for="tab in tabs" :key="tab.key"
        @click="activeTab = tab.key"
        :class="['flex-1 flex items-center justify-center gap-2 py-2.5 text-sm font-bold rounded-xl transition-all',
          activeTab === tab.key
            ? 'bg-primary text-white shadow-sm'
            : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50']">
        {{ tab.icon }} {{ tab.label }}
      </button>
    </div>

    <!-- ── ข้อมูลส่วนตัว ─────────────────────────────────────── -->
    <div v-if="activeTab === 'info'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-5">
      <h2 class="font-extrabold text-slate-800 text-lg">👤 ข้อมูลส่วนตัว</h2>

      <div v-if="loading" class="space-y-3">
        <div v-for="i in 4" :key="i" class="h-12 bg-slate-100 rounded-xl animate-pulse"></div>
      </div>

      <template v-else>
        <!-- ชื่อ-นามสกุล -->
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">ชื่อ-นามสกุล <span class="text-red-500">*</span></label>
          <input v-model="form.full_name" type="text" placeholder="ชื่อ-นามสกุล"
            class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
        </div>

        <!-- เบอร์โทร + LINE -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">📞 เบอร์โทรศัพท์</label>
            <input v-model="form.phone" type="tel" placeholder="08x-xxx-xxxx"
              class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">💬 LINE ID</label>
            <input v-model="form.line_id" type="text" placeholder="@lineid"
              class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
          </div>
        </div>

        <!-- ข้อมูลสำหรับ Supervisor -->
        <template v-if="isSupervisor">
          <div class="pt-2 border-t border-slate-100">
            <p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">ข้อมูลศึกษานิเทศก์</p>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-bold text-slate-700 mb-1.5">📚 กลุ่มสาระรับผิดชอบ</label>
                <select v-model="form.subject_group"
                  class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm bg-white">
                  <option value="">-- เลือกกลุ่มสาระ --</option>
                  <option v-for="g in subjectGroups" :key="g" :value="g">{{ g }}</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-bold text-slate-700 mb-1.5">🏢 กลุ่มงาน</label>
                <select v-model="form.work_group"
                  class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm bg-white">
                  <option value="">-- เลือกกลุ่มงาน --</option>
                  <option v-for="g in workGroups" :key="g" :value="g">{{ g }}</option>
                </select>
              </div>
            </div>
          </div>
        </template>

        <!-- ข้อมูลสำหรับ Teacher/School -->
        <template v-if="isTeacher">
          <div class="pt-2 border-t border-slate-100">
            <p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">ข้อมูลโรงเรียน</p>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-bold text-slate-700 mb-1.5">🏫 โรงเรียน</label>
                <input v-model="form.school_name" type="text" placeholder="ชื่อโรงเรียน"
                  class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
              </div>
              <div>
                <label class="block text-sm font-bold text-slate-700 mb-1.5">🪪 รหัสครู</label>
                <input v-model="form.teacher_code" type="text" placeholder="รหัสครู"
                  class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
              </div>
            </div>
          </div>
        </template>

        <!-- อีเมล (readonly) -->
        <div class="pt-2 border-t border-slate-100">
          <label class="block text-sm font-bold text-slate-700 mb-1.5">📧 อีเมล (ไม่สามารถแก้ไขได้)</label>
          <input :value="profile?.email" type="email" readonly
            class="w-full px-4 py-3 border border-slate-100 rounded-2xl bg-slate-50 text-slate-400 text-sm cursor-not-allowed"/>
        </div>

        <!-- Save button -->
        <div class="flex justify-end pt-2">
          <button @click="saveProfile" :disabled="saving"
            class="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white font-bold px-6 py-3 rounded-2xl shadow-md transition-all disabled:opacity-50">
            <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
            </svg>
            {{ saving ? 'กำลังบันทึก...' : '💾 บันทึกข้อมูล' }}
          </button>
        </div>
      </template>
    </div>

    <!-- ── เปลี่ยนรหัสผ่าน ───────────────────────────────────── -->
    <div v-if="activeTab === 'password'" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-5">
      <h2 class="font-extrabold text-slate-800 text-lg">🔐 เปลี่ยนรหัสผ่าน</h2>

      <!-- New password -->
      <div>
        <label class="block text-sm font-bold text-slate-700 mb-1.5">รหัสผ่านใหม่ <span class="text-red-500">*</span></label>
        <div class="relative">
          <input v-model="pwForm.newPw"
            :type="showPw.new ? 'text' : 'password'"
            placeholder="อย่างน้อย 8 ตัวอักษร"
            class="w-full px-4 py-3 pr-12 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all text-sm"/>
          <button @click="showPw.new = !showPw.new" type="button"
            class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
            {{ showPw.new ? '🙈' : '👁️' }}
          </button>
        </div>
        <!-- Strength bar -->
        <div v-if="pwForm.newPw" class="mt-2 space-y-1">
          <div class="flex gap-1">
            <div v-for="i in 4" :key="i"
              :class="['h-1.5 flex-1 rounded-full transition-all', i <= pwStrength ? pwStrengthColor[pwStrength] : 'bg-slate-200']"></div>
          </div>
          <p class="text-xs" :class="pwStrength <= 1 ? 'text-red-500' : pwStrength <= 2 ? 'text-orange-500' : 'text-emerald-600'">
            ความแข็งแกร่ง: {{ pwStrengthLabel[pwStrength] }}
          </p>
        </div>
      </div>

      <!-- Confirm password -->
      <div>
        <label class="block text-sm font-bold text-slate-700 mb-1.5">ยืนยันรหัสผ่านใหม่ <span class="text-red-500">*</span></label>
        <div class="relative">
          <input v-model="pwForm.confirm"
            :type="showPw.confirm ? 'text' : 'password'"
            placeholder="พิมพ์รหัสผ่านอีกครั้ง"
            :class="['w-full px-4 py-3 pr-12 border rounded-2xl focus:ring-4 outline-none transition-all text-sm',
              pwForm.confirm && pwForm.confirm !== pwForm.newPw
                ? 'border-red-300 focus:ring-red-50 focus:border-red-400'
                : 'border-slate-200 focus:ring-blue-50 focus:border-blue-500']"/>
          <button @click="showPw.confirm = !showPw.confirm" type="button"
            class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
            {{ showPw.confirm ? '🙈' : '👁️' }}
          </button>
        </div>
        <p v-if="pwForm.confirm && pwForm.confirm !== pwForm.newPw"
          class="text-xs text-red-500 mt-1">รหัสผ่านไม่ตรงกัน</p>
      </div>

      <!-- Tips -->
      <div class="bg-blue-50 border border-blue-100 rounded-2xl p-4 text-sm text-blue-700 space-y-1">
        <p class="font-bold mb-2">💡 คำแนะนำ</p>
        <p :class="pwForm.newPw.length >= 8 ? 'text-emerald-600' : ''">
          {{ pwForm.newPw.length >= 8 ? '✅' : '○' }} ความยาวอย่างน้อย 8 ตัวอักษร
        </p>
        <p :class="/[A-Z]/.test(pwForm.newPw) ? 'text-emerald-600' : ''">
          {{ /[A-Z]/.test(pwForm.newPw) ? '✅' : '○' }} มีตัวพิมพ์ใหญ่
        </p>
        <p :class="/[0-9]/.test(pwForm.newPw) ? 'text-emerald-600' : ''">
          {{ /[0-9]/.test(pwForm.newPw) ? '✅' : '○' }} มีตัวเลข
        </p>
        <p :class="/[^A-Za-z0-9]/.test(pwForm.newPw) ? 'text-emerald-600' : ''">
          {{ /[^A-Za-z0-9]/.test(pwForm.newPw) ? '✅' : '○' }} มีอักขระพิเศษ (!@#$%)
        </p>
      </div>

      <div class="flex justify-end">
        <button @click="changePassword"
          :disabled="pwLoading || !pwForm.newPw || pwForm.newPw !== pwForm.confirm"
          class="flex items-center gap-2 bg-primary hover:bg-primary-dark text-white font-bold px-6 py-3 rounded-2xl shadow-md transition-all disabled:opacity-50">
          <svg v-if="pwLoading" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
          {{ pwLoading ? 'กำลังเปลี่ยน...' : '🔐 เปลี่ยนรหัสผ่าน' }}
        </button>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
