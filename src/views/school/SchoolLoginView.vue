<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'

const router = useRouter()
const { config, fetchConfig } = useAreaConfig()
fetchConfig()

const email    = ref('')
const password = ref('')
const loading  = ref(false)
const error    = ref('')
const showPass = ref(false)

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
            <div class="relative">
              <input v-model="password" :type="showPass ? 'text' : 'password'"
                placeholder="รหัสผ่าน"
                @keydown.enter="login"
                class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm
                       focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all pr-10"/>
              <button @click="showPass = !showPass" type="button"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round"
                    :d="showPass
                      ? 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'
                      : 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'"/>
                </svg>
              </button>
            </div>
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
