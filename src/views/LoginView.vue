<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import Swal from 'sweetalert2'

const router = useRouter()
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
      router.push({ name: 'schoolHome' })
    } else {
      Swal.fire({ icon:'success', title:'เข้าสู่ระบบสำเร็จ', text:'ยินดีต้อนรับกลับเข้าสู่ระบบ', showConfirmButton:false, timer:1500 })
      router.push({ name: 'dashboard' })
    }
  } catch (e) {
    Swal.fire({ icon:'error', title:'เข้าสู่ระบบไม่สำเร็จ',
      text: e.message === 'Invalid login credentials' ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' : e.message,
      confirmButtonColor:'#3b82f6' })
  } finally { loading.value = false }
}

// ── Register ───────────────────────────────────────────────────
const rFullName = ref('')
const rEmail    = ref('')
const rPassword = ref('')
const rConfirm  = ref('')
const rPhone    = ref('')
const rSchool   = ref('')
const rRole     = ref('teacher') // teacher | school
const rLoading  = ref(false)

const handleRegister = async () => {
  if (rPassword.value !== rConfirm.value) {
    return Swal.fire({ icon:'warning', title:'รหัสผ่านไม่ตรงกัน', confirmButtonColor:'#3b82f6' })
  }
  if (rPassword.value.length < 8) {
    return Swal.fire({ icon:'warning', title:'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร', confirmButtonColor:'#3b82f6' })
  }
  try {
    rLoading.value = true
    const { data, error } = await supabase.auth.signUp({
      email: rEmail.value,
      password: rPassword.value,
      options: {
        data: { full_name: rFullName.value }
      }
    })
    if (error) throw error

    // อัปเดต profile ที่ trigger สร้างไว้
    if (data.user) {
      await supabase.from('profiles').upsert({
        id:          data.user.id,
        email:       rEmail.value,
        full_name:   rFullName.value,
        phone:       rPhone.value,
        school_name: rSchool.value,
        role:        rRole.value,
        is_approved: false,
        is_active:   true,
      }, { onConflict: 'id' })
    }

    Swal.fire({
      icon: 'success',
      title: 'สมัครสมาชิกสำเร็จ!',
      html: `<p class="text-slate-600 text-sm">กรุณาตรวจสอบอีเมล <b>${rEmail.value}</b><br>เพื่อยืนยันตัวตนก่อนเข้าสู่ระบบ</p>
             <p class="text-amber-600 text-xs mt-2">⏳ บัญชีของคุณต้องรอผู้ดูแลระบบอนุมัติ</p>`,
      confirmButtonColor: '#3b82f6',
      confirmButtonText: 'รับทราบ'
    })
    tab.value = 'login'
    email.value = rEmail.value
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
            :class="['flex-1 py-2.5 text-sm font-bold rounded-xl transition-all',
              tab==='login' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
            🔐 เข้าสู่ระบบ
          </button>
          <button @click="tab='register'"
            :class="['flex-1 py-2.5 text-sm font-bold rounded-xl transition-all',
              tab==='register' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
            📝 สมัครสมาชิก
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
            class="w-full flex justify-center py-3.5 rounded-2xl shadow-lg shadow-blue-100 text-sm font-extrabold text-white bg-blue-600 hover:bg-blue-700 transition-all disabled:opacity-50">
            {{ loading ? 'กำลังดำเนินการ...' : '🔐 เข้าสู่ระบบ' }}
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
            <div class="flex gap-3">
              <label :class="['flex-1 flex items-center gap-2 px-4 py-3 rounded-2xl border-2 cursor-pointer transition-all',
                rRole==='teacher' ? 'border-blue-500 bg-blue-50' : 'border-slate-200 hover:border-slate-300']">
                <input type="radio" v-model="rRole" value="teacher" class="accent-blue-600"/>
                <span class="text-sm font-bold">🧑‍🏫 ครู</span>
              </label>
              <label :class="['flex-1 flex items-center gap-2 px-4 py-3 rounded-2xl border-2 cursor-pointer transition-all',
                rRole==='school' ? 'border-blue-500 bg-blue-50' : 'border-slate-200 hover:border-slate-300']">
                <input type="radio" v-model="rRole" value="school" class="accent-blue-600"/>
                <span class="text-sm font-bold">🏫 โรงเรียน</span>
              </label>
            </div>
          </div>

          <!-- ชื่อ-นามสกุล -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">ชื่อ-นามสกุล <span class="text-red-500">*</span></label>
            <input v-model="rFullName" type="text" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="นาย/นาง/นางสาว ชื่อ นามสกุล"/>
          </div>

          <!-- โรงเรียน -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">
              {{ rRole==='school' ? 'ชื่อโรงเรียน' : 'โรงเรียนที่สังกัด' }}
              <span class="text-red-500">*</span>
            </label>
            <input v-model="rSchool" type="text" required
              class="block w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              placeholder="โรงเรียน..."/>
          </div>

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
