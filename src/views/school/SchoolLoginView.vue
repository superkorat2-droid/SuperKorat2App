<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import SecretInput from '../../components/SecretInput.vue'
import { useAreaConfig } from '../../composables/useAreaConfig'

const router = useRouter()
const { config, fetchConfig } = useAreaConfig()
fetchConfig()

const email    = ref('')
const password = ref('')
const loading  = ref(false)
const error    = ref('')
async function login() {
  error.value = ''
  if (!email.value || !password.value) { error.value = 'กรุณากรอกอีเมลและรหัสผ่าน'; return }
  loading.value = true
  const { data, error: authErr } = await supabase.auth.signInWithPassword({
    email: email.value.trim(),
    password: password.value,
  })
  if (authErr) {
    error.value = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
    loading.value = false
    return
  }
  // ตรวจสอบว่าเป็น role school
  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_approved')
    .eq('id', data.user.id)
    .single()

  if (!profile || profile.role !== 'school') {
    await supabase.auth.signOut()
    error.value = 'บัญชีนี้ไม่ใช่บัญชีโรงเรียน'
    loading.value = false
    return
  }
  router.push('/school')
}
</script>

<template>
  <div class="font-sarabun min-h-screen bg-slate-50 flex items-center justify-center px-4">
    <div class="w-full max-w-md">

      <!-- Logo / Header -->
      <div class="text-center mb-8">
        <div class="w-16 h-16 rounded-2xl gradient-primary flex items-center justify-center mx-auto mb-4 shadow-xl">
          <img v-if="config?.logo_url" :src="config.logo_url" class="w-10 h-10 object-contain"/>
          <svg v-else class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75"/>
          </svg>
        </div>
        <h1 class="text-2xl font-extrabold text-slate-800">ระบบโรงเรียน</h1>
        <p class="text-slate-500 text-sm mt-1">{{ config?.area_name_short || 'สพป.นม.2' }}</p>
      </div>

      <!-- Card -->
      <div class="bg-white rounded-3xl shadow-xl border border-slate-100 p-8">
        <h2 class="text-lg font-extrabold text-slate-800 mb-6">เข้าสู่ระบบ</h2>

        <div class="space-y-4">
          <!-- Email -->
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1.5">อีเมลโรงเรียน</label>
            <input v-model="email" type="email" placeholder="30020001@korat2.go.th"
              @keydown.enter="login"
              class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm
                     focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
          </div>

          <!-- Password -->
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1.5">รหัสผ่าน</label>
            <SecretInput v-model="password" placeholder="รหัสผ่าน"
              autocomplete="current-password" @keydown.enter="login"
              input-class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm
                     focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
          </div>

          <!-- Error -->
          <div v-if="error" class="flex items-center gap-2 p-3 bg-red-50 border border-red-100 rounded-xl text-sm text-red-600">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
            </svg>
            {{ error }}
          </div>

          <!-- Submit -->
          <button @click="login" :disabled="loading"
            class="w-full py-3 gradient-primary text-white font-extrabold rounded-2xl shadow-lg
                   hover:shadow-xl hover:-translate-y-0.5 transition-all disabled:opacity-50 disabled:translate-y-0 text-sm">
            <span v-if="loading" class="flex items-center justify-center gap-2">
              <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
              </svg>
              กำลังเข้าสู่ระบบ...
            </span>
            <span v-else>เข้าสู่ระบบ</span>
          </button>
        </div>

        <p class="text-center text-xs text-slate-400 mt-6">
          ปัญหาการเข้าสู่ระบบ ติดต่อ สพป.นม.2
        </p>
      </div>

      <p class="text-center text-xs text-slate-400 mt-4">
        <a href="/" class="hover:text-primary transition-colors">← กลับหน้าหลัก</a>
      </p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
