<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../supabase'
import { ICON_MAP } from '../composables/useIcons.js'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()
const tab = ref('login') // 'login' | 'register'

// ── Login ──────────────────────────────────────────────────────
const email    = ref('')
const password = ref('')
const loading  = ref(false)

const handleLogin = async () => {
  try {
    loading.value = true
    const { data: authData, error } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value,
    })
    if (error) throw error

    // ดึง profile เพื่อเช็ค role
    const { data: profile } = await supabase
      .from('profiles')
      .select('role, is_approved')
      .eq('id', authData.user.id)
      .single()

    if (profile?.role === 'school') {
      if (!profile.is_approved) {
        await supabase.auth.signOut()
        throw new Error('บัญชีนี้ยังไม่ได้รับการอนุมัติ')
      }
      Swal.fire({ icon:'success', title:'เข้าสู่ระบบสำเร็จ', showConfirmButton:false, timer:1200 })
      const next = route.query.next
      router.push(next ? String(next) : { name: 'schoolHome' })
    } else {
      Swal.fire({ icon:'success', title:'เข้าสู่ระบบสำเร็จ', text:'ยินดีต้อนรับกลับเข้าสู่ระบบ', showConfirmButton:false, timer:1500 })
      const next = route.query.next
      router.push(next ? String(next) : { name: 'dashboard' })
    }
  } catch (e) {
    Swal.fire({ icon:'error', title:'เข้าสู่ระบบไม่สำเร็จ',
      text: e.message === 'Invalid login credentials' ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' : e.message,
      confirmButtonColor:'#3b82f6' })
  } finally { loading.value = false }
}

// ── Register ───────────────────────────────────────────────────
const rFullName  = ref('')
const rEmail     = ref('')
const rPassword  = ref('')
const rConfirm   = ref('')
const rPhone     = ref('')
const rRole      = ref('teacher') // teacher | school | personnel
const rPosition  = ref('')
const rRegCode   = ref('')  // รหัสลับสมัครสมาชิก
const rLoading   = ref(false)

// โหลด area config เพื่อตรวจสอบรหัส
const areaConfig = ref(null)
const isPersonnel = computed(() => ['supervisor','staff'].includes(rRole.value))

// ── School cascade dropdown (teacher) ────────────────────────
const schools       = ref([])
const rDistrict     = ref('')
const rSchoolGroup  = ref('')
const rSchoolId     = ref('')

const districts = computed(() =>
  [...new Set(schools.value.map(s => s.district).filter(Boolean))].sort()
)
const schoolGroups = computed(() => {
  if (!rDistrict.value) return []
  return [...new Set(
    schools.value.filter(s => s.district === rDistrict.value).map(s => s.school_group).filter(Boolean)
  )].sort()
})
const filteredSchools = computed(() => {
  if (!rDistrict.value) return []
  return schools.value.filter(s =>
    s.district === rDistrict.value &&
    (!rSchoolGroup.value || s.school_group === rSchoolGroup.value)
  ).sort((a,b) => a.name.localeCompare(b.name, 'th'))
})

// reset cascade เมื่อเปลี่ยน
function onDistrictChange()    { rSchoolGroup.value = ''; rSchoolId.value = '' }
function onSchoolGroupChange() { rSchoolId.value = '' }

onMounted(async () => {
  const [schoolsRes, configRes] = await Promise.all([
    supabase.from('schools').select('id, name, district, school_group').eq('is_active', true).order('district'),
    supabase.rpc('get_area_config'),
  ])
  schools.value    = schoolsRes.data || []
  areaConfig.value = configRes.data  || {}
})

const handleRegister = async () => {
  if (rPassword.value !== rConfirm.value)
    return Swal.fire({ icon:'warning', title:'รหัสผ่านไม่ตรงกัน', confirmButtonColor:'#3b82f6' })
  if (rPassword.value.length < 8)
    return Swal.fire({ icon:'warning', title:'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร', confirmButtonColor:'#3b82f6' })
  if (rRole.value === 'teacher' && !rSchoolId.value)
    return Swal.fire({ icon:'warning', title:'กรุณาเลือกโรงเรียน', confirmButtonColor:'#3b82f6' })

  // ── ตรวจสอบรหัสลับ ────────────────────────────────────────
  const cfg = areaConfig.value
  if (cfg?.register_code_enabled) {
    const isPersonnelRole = ['supervisor','staff'].includes(rRole.value)
    const expectedCode = isPersonnelRole
      ? cfg.register_code_personnel
      : cfg.register_code_teacher
    if (expectedCode && rRegCode.value.trim().toUpperCase() !== expectedCode.trim().toUpperCase()) {
      return Swal.fire({ icon:'error', title:'รหัสสมัครสมาชิกไม่ถูกต้อง', text:'กรุณาติดต่อผู้ดูแลระบบเพื่อขอรหัส', confirmButtonColor:'#3b82f6' })
    }
  }

  try {
    rLoading.value = true
    const { data, error } = await supabase.auth.signUp({
      email: rEmail.value, password: rPassword.value,
      options: { data: { full_name: rFullName.value } }
    })
    if (error) throw error

    if (data.user) {
      const selectedSchool = schools.value.find(s => s.id === rSchoolId.value)
      const isPersonnelRole = ['supervisor','staff'].includes(rRole.value)
      await supabase.from('profiles').upsert({
        id:          data.user.id,
        email:       rEmail.value,
        full_name:   rFullName.value,
        phone:       rPhone.value,
        role:        rRole.value,
        org_role:    isPersonnelRole ? rRole.value : null,
        position:    rPosition.value,
        school_id:   rSchoolId.value   || null,
        school_name: selectedSchool?.name || '',
        is_approved: false,
        is_active:   true,
      }, { onConflict: 'id' })
    }

    Swal.fire({
      icon: 'success', title: 'สมัครสมาชิกสำเร็จ!',
      html: `<p class="text-slate-600 text-sm">กรุณาตรวจสอบอีเมล <b>${rEmail.value}</b><br>เพื่อยืนยันตัวตนก่อนเข้าสู่ระบบ</p>
             <p class="text-amber-600 text-xs mt-2">⏳ บัญชีของคุณต้องรอผู้ดูแลระบบอนุมัติ</p>`,
      confirmButtonColor: '#3b82f6', confirmButtonText: 'รับทราบ',
    })
    tab.value = 'login'; email.value = rEmail.value
  } catch (e) {
    Swal.fire({ icon:'error', title:'สมัครสมาชิกไม่สำเร็จ', text: e.message, confirmButtonColor:'#3b82f6' })
  } finally { rLoading.value = false }
}
</script>

<template>
  <div class="font-sarabun flex flex-col justify-center py-12 sm:px-6 lg:px-8">

    <!-- Logo -->
    <div class="sm:mx-auto sm:w-full sm:max-w-md text-center">
      <div class="mx-auto h-16 w-16 bg-blue-600 rounded-2xl flex items-center justify-center shadow-xl shadow-blue-200">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
        </svg>
      </div>
      <h2 class="mt-5 text-3xl font-extrabold text-slate-900">
        {{ tab === 'login' ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก' }}
      </h2>
      <p class="mt-1 text-sm text-slate-500">ระบบหลังบ้านกลุ่มนิเทศ ติดตามและประเมินผลฯ</p>
    </div>

    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
      <div class="bg-white py-8 px-6 shadow-2xl shadow-slate-200/50 sm:rounded-[2.5rem] border border-slate-100 sm:px-10">

        <!-- Tab switcher -->
        <div class="flex bg-slate-100 rounded-2xl p-1 mb-7">
          <button @click="tab='login'"
            :class="['flex-1 flex items-center justify-center gap-2 py-2.5 text-sm font-bold rounded-xl transition-all',
              tab==='login' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
            </svg>
            เข้าสู่ระบบ
          </button>
          <button @click="tab='register'"
            :class="['flex-1 flex items-center justify-center gap-2 py-2.5 text-sm font-bold rounded-xl transition-all',
              tab==='register' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z"/>
            </svg>
            สมัครสมาชิก
          </button>
        </div>

        <!-- ── LOGIN FORM ─────────────────────────────────────── -->
        <form v-if="tab==='login'" @submit.prevent="handleLogin" class="space-y-5">
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">อีเมล</label>
            <input v-model="email" type="email" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="name@example.com"/>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">รหัสผ่าน</label>
            <input v-model="password" type="password" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="••••••••"/>
          </div>
          <button :disabled="loading" type="submit"
            class="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl shadow-lg shadow-blue-100 text-sm font-extrabold text-white bg-blue-600 hover:bg-blue-700 transition-all disabled:opacity-50">
            <svg v-if="!loading" class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
            </svg>
            {{ loading ? 'กำลังดำเนินการ...' : 'เข้าสู่ระบบ' }}
          </button>
          <p class="text-center text-xs text-slate-400">
            หากลืมรหัสผ่าน กรุณาติดต่อผู้ดูแลระบบ
          </p>
        </form>

        <!-- ── REGISTER FORM ──────────────────────────────────── -->
        <form v-else @submit.prevent="handleRegister" class="space-y-4">

          <!-- ประเภทผู้ใช้ -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">สมัครในฐานะ</label>
            <div class="grid grid-cols-2 gap-2">
              <label v-for="opt in [
                { value:'teacher',    iconKey:'school',       label:'ครู' },
                { value:'school',     iconKey:'building',     label:'โรงเรียน' },
                { value:'supervisor', iconKey:'magnify',      label:'ศึกษานิเทศก์' },
                { value:'staff',      iconKey:'user',         label:'บุคลากร/เจ้าหน้าที่' },
              ]" :key="opt.value"
                :class="['flex items-center gap-2 px-3 py-2.5 rounded-2xl border-2 cursor-pointer transition-all',
                  rRole===opt.value ? 'border-blue-500 bg-blue-50' : 'border-slate-200 hover:border-slate-300']">
                <input type="radio" v-model="rRole" :value="opt.value" class="accent-blue-600 flex-shrink-0"/>
                <svg class="w-4 h-4 flex-shrink-0 text-slate-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="ICON_MAP[opt.iconKey]"/>
                </svg>
                <span class="text-sm font-bold">{{ opt.label }}</span>
              </label>
            </div>
          </div>

          <!-- รหัสลับ (แสดงเมื่อ config เปิดและมีรหัส) -->
          <div v-if="areaConfig?.register_code_enabled && (isPersonnel ? areaConfig?.register_code_personnel : areaConfig?.register_code_teacher)">
            <label class="flex items-center gap-1.5 text-sm font-bold text-slate-700 mb-1.5">
              <svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z"/>
              </svg>
              รหัสสมัครสมาชิก <span class="text-red-500">*</span>
              <span class="text-xs font-normal text-slate-400 ml-1">(ขอรหัสจากผู้ดูแลระบบ)</span>
            </label>
            <input v-model="rRegCode" type="text" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all font-mono uppercase tracking-widest"
              placeholder="กรอกรหัสลับ"/>
          </div>

          <!-- ชื่อ-นามสกุล -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">ชื่อ-นามสกุล <span class="text-red-500">*</span></label>
            <input v-model="rFullName" type="text" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="นาย/นาง/นางสาว ชื่อ นามสกุล"/>
          </div>

          <!-- ตำแหน่ง -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">ตำแหน่ง</label>
            <input v-model="rPosition" type="text"
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              :placeholder="rRole==='teacher' ? 'เช่น ครูผู้สอน, หัวหน้าวิชาการ' : 'เช่น ผู้อำนวยการโรงเรียน'"/>
          </div>

          <!-- ── Teacher: cascade school dropdown ── -->
          <template v-if="rRole === 'teacher'">

            <!-- อำเภอ -->
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">อำเภอ <span class="text-red-500">*</span></label>
              <select v-model="rDistrict" @change="onDistrictChange" required
                class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none bg-white transition-all">
                <option value="">-- เลือกอำเภอ --</option>
                <option v-for="d in districts" :key="d" :value="d">{{ d }}</option>
              </select>
            </div>

            <!-- ศูนย์เครือข่าย -->
            <div v-if="rDistrict">
              <label class="block text-sm font-bold text-slate-700 mb-1.5">ศูนย์เครือข่าย <span class="text-red-500">*</span></label>
              <select v-model="rSchoolGroup" @change="onSchoolGroupChange"
                class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none bg-white transition-all">
                <option value="">-- ทุกศูนย์เครือข่าย --</option>
                <option v-for="g in schoolGroups" :key="g" :value="g">{{ g }}</option>
              </select>
            </div>

            <!-- โรงเรียน -->
            <div v-if="rDistrict">
              <label class="block text-sm font-bold text-slate-700 mb-1.5">
                โรงเรียนที่สังกัด <span class="text-red-500">*</span>
                <span class="text-slate-400 font-normal text-xs ml-1">({{ filteredSchools.length }} โรงเรียน)</span>
              </label>
              <select v-model="rSchoolId" required
                class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none bg-white transition-all">
                <option value="">-- เลือกโรงเรียน --</option>
                <option v-for="s in filteredSchools" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>

          </template>

          <!-- เบอร์โทร -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">เบอร์โทรศัพท์</label>
            <input v-model="rPhone" type="tel"
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="08x-xxx-xxxx"/>
          </div>

          <!-- อีเมล -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">อีเมล <span class="text-red-500">*</span></label>
            <input v-model="rEmail" type="email" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="name@example.com"/>
          </div>

          <!-- รหัสผ่าน -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">รหัสผ่าน <span class="text-red-500">*</span></label>
              <input v-model="rPassword" type="password" required minlength="8"
                class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
                placeholder="อย่างน้อย 8 ตัว"/>
            </div>
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">ยืนยันรหัสผ่าน <span class="text-red-500">*</span></label>
              <input v-model="rConfirm" type="password" required
                :class="['block w-full px-4 py-3 border rounded-2xl focus:ring-4 outline-none transition-all',
                  rConfirm && rConfirm !== rPassword
                    ? 'border-red-300 focus:ring-red-50 focus:border-red-400'
                    : 'border-slate-200 focus:ring-blue-50 focus:border-blue-500']"
                placeholder="••••••••"/>
            </div>
          </div>
          <p v-if="rConfirm && rConfirm !== rPassword" class="text-xs text-red-500 -mt-2">รหัสผ่านไม่ตรงกัน</p>

          <!-- หมายเหตุ -->
          <div class="bg-amber-50 border border-amber-200 rounded-2xl p-3 text-xs text-amber-700">
            ⏳ บัญชีของคุณต้องรอ<strong>ผู้ดูแลระบบอนุมัติ</strong>ก่อนจึงจะเข้าใช้งานได้
          </div>

          <button :disabled="rLoading || (rConfirm && rConfirm !== rPassword)" type="submit"
            class="w-full flex justify-center py-3.5 rounded-2xl shadow-lg shadow-blue-100 text-sm font-extrabold text-white bg-blue-600 hover:bg-blue-700 transition-all disabled:opacity-50">
            {{ rLoading ? 'กำลังดำเนินการ...' : '📝 สมัครสมาชิก' }}
          </button>
        </form>

      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
