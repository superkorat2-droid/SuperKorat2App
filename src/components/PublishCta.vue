<script setup>
/**
 * PublishCta — แถบเชิญชวนให้เผยแพร่ผลงาน/สื่อ วางเหนือช่องค้นหาของหน้าสาธารณะ
 *
 * ปรับตามสถานะผู้ใช้:
 *   ยังไม่ล็อกอิน → ชวนลงทะเบียน (ไป /login?tab=register) + ลิงก์เข้าสู่ระบบ
 *   ล็อกอินแล้ว   → พาไปหน้าจัดการของตัวเองตามบทบาท
 *
 * ปลายทางของผู้ใช้บทบาท school ต้องเป็น /school ไม่ใช่ /dashboard
 * เพราะ router guard เด้ง school ออกจาก /dashboard ทุกกรณี (router/index.js)
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const props = defineProps({
  kind: { type: String, required: true },   // 'works' | 'media'
})

const { config } = useAreaConfig()
const role    = ref('')
const signedIn = ref(false)
const ready   = ref(false)   // กันปุ่มกระพริบสลับข้อความตอนโหลด

onMounted(async () => {
  const { data: { session } } = await supabase.auth.getSession()
  if (session?.user?.id) {
    signedIn.value = true
    const { data } = await supabase.from('profiles').select('role').eq('id', session.user.id).single()
    role.value = data?.role || ''
  }
  ready.value = true
})

const label = computed(() => props.kind === 'media' ? 'สื่อการเรียนรู้' : 'ผลงาน')

const manageTo = computed(() => {
  if (role.value === 'school') return '/school'          // school portal — /dashboard เข้าไม่ได้
  return props.kind === 'media' ? '/dashboard/media/new' : '/dashboard/works/new'
})

/** เขตอาจตั้งให้ต้องใช้รหัสลับในการสมัคร — บอกไว้ล่วงหน้าดีกว่าให้ไปเจอหน้างาน */
const needCode = computed(() => config.value?.register_code_enabled === true)
</script>

<template>
  <div v-if="ready"
    class="glass-card overflow-hidden relative">
    <!-- แถบสีไล่ระดับด้านซ้ายให้ดูเป็นแถบเชิญชวน ไม่ใช่การ์ดข้อมูลทั่วไป -->
    <div class="absolute inset-y-0 left-0 w-1.5"
      style="background:linear-gradient(180deg,var(--color-primary),var(--color-secondary))"/>

    <div class="flex flex-wrap items-center gap-4 px-5 py-4 pl-6">
      <div class="flex-1 min-w-[220px]">
        <p class="font-extrabold text-slate-800 flex items-center gap-2">
          <span class="text-lg">✨</span>
          <template v-if="signedIn">เผยแพร่{{ label }}ของคุณ</template>
          <template v-else>มี{{ label }}อยากเผยแพร่?</template>
        </p>
        <p class="text-xs text-slate-500 mt-0.5">
          <template v-if="signedIn">
            เพิ่ม{{ label }}เข้าสู่คลังของเขต เพื่อให้ครูและโรงเรียนอื่นนำไปใช้ต่อได้
          </template>
          <template v-else>
            ลงทะเบียนเป็นสมาชิกเพื่อส่ง{{ label }}ขึ้นเว็บของกลุ่มนิเทศ
            <span v-if="needCode" class="text-amber-600 font-bold">· ต้องมีรหัสสมัครสมาชิกจากเขต</span>
          </template>
        </p>
      </div>

      <div class="flex items-center gap-2 flex-shrink-0">
        <template v-if="signedIn">
          <router-link :to="manageTo"
            class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
            </svg>
            เพิ่ม{{ label }}
          </router-link>
        </template>
        <template v-else>
          <router-link to="/login?tab=register"
            class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M18 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM3 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 019.374 21c-2.331 0-4.512-.645-6.374-1.766z"/>
            </svg>
            ลงทะเบียนเผยแพร่{{ label }}
          </router-link>
          <router-link to="/login"
            class="text-xs font-bold text-slate-500 hover:text-primary transition-colors px-2 py-2 whitespace-nowrap">
            เข้าสู่ระบบ
          </router-link>
        </template>
      </div>
    </div>
  </div>
</template>
