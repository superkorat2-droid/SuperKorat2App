<script setup>
import { ref, watch } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})
const emit = defineEmits(['refresh'])

const website_url   = ref('')
const saving        = ref(false)
const changingPass  = ref(false)
const oldPass       = ref('')
const newPass       = ref('')
const confirmPass   = ref('')
const passError     = ref('')
const showOld       = ref(false)
const showNew       = ref(false)

watch(() => props.school, (s) => {
  if (s) website_url.value = s.website_url || ''
}, { immediate: true })

async function saveProfile() {
  saving.value = true
  const url = website_url.value.trim()
  // basic validation
  if (url && !url.startsWith('http')) {
    Swal.fire({ icon: 'warning', title: 'URL ไม่ถูกต้อง', text: 'กรุณาใส่ URL ที่ขึ้นต้นด้วย https://' })
    saving.value = false
    return
  }
  const { error } = await supabase
    .from('schools')
    .update({ website_url: url, updated_at: new Date().toISOString() })
    .eq('id', props.school.id)
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1200 })
    emit('refresh')
  }
}

async function changePassword() {
  passError.value = ''
  if (!newPass.value || newPass.value.length < 8) {
    passError.value = 'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร'; return
  }
  if (newPass.value !== confirmPass.value) {
    passError.value = 'รหัสผ่านใหม่ไม่ตรงกัน'; return
  }
  changingPass.value = true
  const { error } = await supabase.auth.updateUser({ password: newPass.value })
  changingPass.value = false
  if (error) {
    passError.value = error.message
  } else {
    oldPass.value = ''
    newPass.value = ''
    confirmPass.value = ''
    Swal.fire({ icon: 'success', title: 'เปลี่ยนรหัสผ่านสำเร็จ', showConfirmButton: false, timer: 1200 })
  }
}
</script>

<template>
  <div class="space-y-6 max-w-2xl">

    <div>
      <h1 class="text-xl font-extrabold text-slate-800">ข้อมูลโรงเรียน</h1>
      <p class="text-sm text-slate-500 mt-0.5">แก้ไขเว็บไซต์และเปลี่ยนรหัสผ่าน</p>
    </div>

    <!-- ── ข้อมูลพื้นฐาน (อ่านอย่างเดียว) ──────────────────── -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div class="px-5 py-4 border-b border-slate-50 flex items-center gap-2">
        <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
        </svg>
        <h2 class="font-extrabold text-slate-700 text-sm">ข้อมูลทั่วไป (ระบบกำหนด)</h2>
      </div>
      <div class="divide-y divide-slate-50">
        <div v-for="(val, key) in {
          'ชื่อโรงเรียน':   school?.name,
          'รหัส DMC':       school?.dmc_code,
          'ตำบล':           school?.subdistrict,
          'อำเภอ':          school?.district,
          'กลุ่มโรงเรียน': school?.school_group,
          'อีเมล (username)': school?.email,
        }" :key="key" class="flex gap-4 px-5 py-3">
          <span class="text-xs font-bold text-slate-400 w-40 flex-shrink-0">{{ key }}</span>
          <span class="text-sm text-slate-700">{{ val || '—' }}</span>
        </div>
      </div>
    </div>

    <!-- ── URL เว็บไซต์ (แก้ได้) ─────────────────────────────── -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
      <h2 class="font-extrabold text-slate-800 mb-4 flex items-center gap-2">
        <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3"/>
        </svg>
        เว็บไซต์โรงเรียน
      </h2>

      <div class="space-y-3">
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1.5">URL เว็บไซต์</label>
          <input v-model="website_url" type="url"
            placeholder="https://yourschool.ac.th"
            class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm
                   focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
          <p class="text-[11px] text-slate-400 mt-1">
            ข้อมูลนี้จะแสดงในทำเนียบโรงเรียนสาธารณะ
          </p>
        </div>

        <!-- Preview -->
        <div v-if="website_url" class="flex items-center gap-2 p-3 bg-slate-50 rounded-xl border border-slate-200">
          <svg class="w-4 h-4 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
          </svg>
          <a :href="website_url" target="_blank" rel="noopener"
            class="text-sm text-primary hover:underline truncate font-medium">
            {{ website_url }}
          </a>
        </div>

        <button @click="saveProfile" :disabled="saving"
          class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-xl transition-all disabled:opacity-50 shadow-md hover:-translate-y-0.5">
          <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
          <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 3.75V16.5L12 14.25 7.5 16.5V3.75m9 0H18A2.25 2.25 0 0120.25 6v12A2.25 2.25 0 0118 20.25H6A2.25 2.25 0 013.75 18V6A2.25 2.25 0 016 3.75h1.5m9 0h-9"/>
          </svg>
          บันทึก
        </button>
      </div>
    </div>

    <!-- ── เปลี่ยนรหัสผ่าน ────────────────────────────────────── -->
    <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
      <h2 class="font-extrabold text-slate-800 mb-4 flex items-center gap-2">
        <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
        </svg>
        เปลี่ยนรหัสผ่าน
      </h2>

      <div class="space-y-3">
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1.5">รหัสผ่านใหม่</label>
          <div class="relative">
            <input v-model="newPass" :type="showNew ? 'text' : 'password'"
              placeholder="อย่างน้อย 8 ตัวอักษร"
              class="w-full px-4 py-2.5 pr-10 border border-slate-200 rounded-xl text-sm
                     focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
            <button @click="showNew = !showNew" type="button"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round"
                  :d="showNew ? 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'
                    : 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'"/>
              </svg>
            </button>
          </div>
        </div>
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1.5">ยืนยันรหัสผ่านใหม่</label>
          <input v-model="confirmPass" :type="showNew ? 'text' : 'password'"
            placeholder="กรอกซ้ำอีกครั้ง"
            class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm
                   focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"/>
        </div>

        <p v-if="passError" class="text-xs text-red-500">{{ passError }}</p>

        <button @click="changePassword" :disabled="changingPass || !newPass || !confirmPass"
          class="flex items-center gap-2 px-5 py-2.5 bg-slate-800 hover:bg-slate-700 text-white text-sm font-bold rounded-xl transition-all disabled:opacity-40 shadow-md hover:-translate-y-0.5">
          <svg v-if="changingPass" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
          </svg>
          <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
          </svg>
          เปลี่ยนรหัสผ่าน
        </button>
      </div>
    </div>

  </div>
</template>
