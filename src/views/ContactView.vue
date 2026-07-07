<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'

const { config, fetchConfig } = useAreaConfig()

const form = ref({ name: '', position: '', phone: '', email: '', subject: '', message: '' })
const sent    = ref(false)
const sending = ref(false)
const sendError = ref('')

async function submitForm() {
  sending.value = true
  sendError.value = ''
  const { error } = await supabase.from('contact_messages').insert({
    name:     form.value.name.trim(),
    position: form.value.position.trim(),
    phone:    form.value.phone.trim(),
    email:    form.value.email.trim(),
    subject:  form.value.subject,
    message:  form.value.message.trim(),
  })
  sending.value = false
  if (error) { sendError.value = 'ส่งข้อความไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'; return }
  sent.value = true
}
function resetForm() {
  sent.value = false
  form.value = { name: '', position: '', phone: '', email: '', subject: '', message: '' }
}

// ── ข้อมูลติดต่อ + โซเชียล จาก area_config จริง ──────────────────────
const contactInfo = computed(() => {
  const c = config.value || {}
  const items = []
  if (c.contact_address) items.push({ icon: '📍', label: 'ที่ตั้ง',    value: c.contact_address })
  if (c.contact_phone)   items.push({ icon: '📞', label: 'โทรศัพท์',  value: c.contact_phone })
  if (c.contact_fax)     items.push({ icon: '📠', label: 'โทรสาร',    value: c.contact_fax })
  if (c.contact_email)   items.push({ icon: '📧', label: 'อีเมล',     value: c.contact_email })
  items.push({ icon: '🕐', label: 'เวลาทำการ', value: 'วันจันทร์–ศุกร์ เวลา 08:30–16:30 น. (ยกเว้นวันหยุดราชการ)' })
  return items
})
const socialLinks = computed(() => {
  const c = config.value || {}
  const items = []
  if (c.facebook_url) items.push({ icon: '👍', label: 'Facebook Page', sub: 'ติดตามข่าวสารและกิจกรรม', url: c.facebook_url })
  if (c.line_url)     items.push({ icon: '💬', label: 'LINE Official', sub: 'สอบถาม/แจ้งเรื่องด่วน',    url: c.line_url })
  if (c.youtube_url)  items.push({ icon: '▶️', label: 'YouTube Channel', sub: 'วิดีโอการสอนและนิเทศ',   url: c.youtube_url })
  return items
})

// ── ศึกษานิเทศก์ (org_role='supervisor') จาก profiles จริง ───────────
const CONTACT_SVG = {
  phone:  'M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 6.75z',
  email:  'M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75',
  line_id:'M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 01-.923 1.785A5.969 5.969 0 006 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337z',
}

const supervisors = ref([])
const loadingSupervisors = ref(true)
const selected = ref(null)

async function fetchSupervisors() {
  loadingSupervisors.value = true
  const { data, error } = await supabase
    .from('profiles')
    .select('id,full_name,first_name,last_name,title,position,position_level,department,subjects,avatar_url,sort_order,phone,line_id,email,contact_visibility')
    .eq('org_role', 'supervisor')
    .order('sort_order', { ascending: true })
  if (!error) supervisors.value = data || []
  loadingSupervisors.value = false
}

function displayName(p) {
  if (p.first_name || p.last_name) return `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim()
  return p.full_name || ''
}
function visibleContact(p) {
  const vis = p.contact_visibility || {}
  const items = []
  if (p.phone   && vis.phone   !== false) items.push({ key: 'phone',   label: p.phone,   href: `tel:${p.phone}`,                     svgPath: CONTACT_SVG.phone })
  if (p.email   && vis.email   !== false) items.push({ key: 'email',   label: p.email,   href: `mailto:${p.email}`,                  svgPath: CONTACT_SVG.email })
  if (p.line_id && vis.line_id !== false) items.push({ key: 'line_id', label: p.line_id, href: `https://line.me/ti/p/~${p.line_id}`, svgPath: CONTACT_SVG.line_id })
  return items
}

onMounted(() => { fetchConfig(); fetchSupervisors() })
</script>

<template>
  <div class="font-sarabun text-slate-800 dark:text-slate-100 py-10">
    <div class="max-w-5xl mx-auto px-4">

      <!-- Header -->
      <div class="mb-10">
        <p class="text-xs text-primary font-bold uppercase tracking-widest mb-1">Contact Us</p>
        <h1 class="text-3xl font-extrabold text-slate-900 dark:text-slate-100">ติดต่อสอบถาม</h1>
        <p class="text-slate-500 dark:text-slate-400 mt-2">กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา ยินดีให้บริการและตอบข้อซักถามทุกช่องทาง</p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">

        <!-- Left: Info + socials -->
        <div class="lg:col-span-1 space-y-6">

          <!-- Contact info -->
          <div class="bg-white dark:bg-slate-800 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm p-6 space-y-4">
            <h2 class="font-extrabold text-slate-800 dark:text-slate-100 text-lg">ข้อมูลการติดต่อ</h2>
            <div v-for="info in contactInfo" :key="info.label" class="flex items-start gap-3">
              <span class="text-xl flex-shrink-0 mt-0.5">{{ info.icon }}</span>
              <div>
                <p class="text-xs font-bold text-slate-400 uppercase tracking-wider">{{ info.label }}</p>
                <p class="text-sm text-slate-700 dark:text-slate-300 mt-0.5 leading-snug">{{ info.value }}</p>
              </div>
            </div>
          </div>

          <!-- Social links -->
          <div v-if="socialLinks.length" class="rounded-3xl p-6 text-white" style="background:linear-gradient(135deg,var(--color-primary),var(--color-primary-dark))">
            <h2 class="font-extrabold text-lg mb-4">ช่องทางโซเชียล</h2>
            <div class="space-y-3">
              <a v-for="s in socialLinks" :key="s.label" :href="s.url" target="_blank" rel="noopener"
                class="flex items-center gap-3 bg-white/15 hover:bg-white/25 rounded-xl px-4 py-3 transition-colors">
                <span class="text-2xl">{{ s.icon }}</span>
                <div>
                  <p class="font-bold text-sm">{{ s.label }}</p>
                  <p class="text-white/70 text-xs">{{ s.sub }}</p>
                </div>
              </a>
            </div>
          </div>
        </div>

        <!-- Right: Form + Supervisors -->
        <div class="lg:col-span-2 space-y-6">

          <!-- Contact Form -->
          <div class="bg-white dark:bg-slate-800 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm p-6 md:p-8">
            <h2 class="font-extrabold text-slate-800 dark:text-slate-100 text-lg mb-5">📬 ส่งข้อความถึงกลุ่มนิเทศ</h2>

            <Transition enter-active-class="transition duration-300" enter-from-class="opacity-0 scale-95" enter-to-class="opacity-100 scale-100">
              <div v-if="sent" class="flex flex-col items-center justify-center py-10 text-center">
                <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center text-3xl mb-4">✅</div>
                <h3 class="text-xl font-extrabold text-slate-800 dark:text-slate-100 mb-2">ส่งข้อความสำเร็จ!</h3>
                <p class="text-slate-500 dark:text-slate-400 text-sm">เราจะติดต่อกลับภายใน 1–2 วันทำการ</p>
                <button @click="resetForm"
                  class="mt-5 bg-primary text-white text-sm font-bold px-6 py-2.5 rounded-xl hover:bg-primary-dark transition-colors">
                  ส่งข้อความใหม่
                </button>
              </div>
            </Transition>

            <form v-if="!sent" @submit.prevent="submitForm" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">ชื่อ-สกุล *</label>
                  <input v-model="form.name" type="text" required placeholder="นายสมชาย ใจดี"
                    class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">ตำแหน่ง/โรงเรียน</label>
                  <input v-model="form.position" type="text" placeholder="ครู / โรงเรียน..."
                    class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"/>
                </div>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">โทรศัพท์</label>
                  <input v-model="form.phone" type="tel" placeholder="08X-XXX-XXXX"
                    class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">อีเมล *</label>
                  <input v-model="form.email" type="email" required placeholder="example@school.ac.th"
                    class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"/>
                </div>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">หัวข้อ *</label>
                <select v-model="form.subject" required
                  class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary bg-white">
                  <option value="" disabled>-- เลือกหัวข้อ --</option>
                  <option>ขอรับการนิเทศ</option>
                  <option>สอบถามเกี่ยวกับการประเมิน</option>
                  <option>สอบถามประกันคุณภาพ (IQA/SAR)</option>
                  <option>สอบถามวิทยฐานะ (PA)</option>
                  <option>แจ้งปัญหาระบบ</option>
                  <option>อื่น ๆ</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5 uppercase tracking-wide">ข้อความ *</label>
                <textarea v-model="form.message" required rows="4" placeholder="รายละเอียดที่ต้องการสอบถาม..."
                  class="w-full px-4 py-2.5 border border-slate-200 dark:border-slate-700 dark:bg-slate-900 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary resize-none"></textarea>
              </div>
              <p v-if="sendError" class="text-sm text-red-500 font-bold">{{ sendError }}</p>
              <button type="submit" :disabled="sending"
                class="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-dark text-white text-sm font-bold py-3 rounded-xl shadow-md transition-all hover:-translate-y-0.5 disabled:opacity-60">
                <svg v-if="sending" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                <span>{{ sending ? 'กำลังส่ง...' : '📬 ส่งข้อความ' }}</span>
              </button>
            </form>
          </div>

          <!-- Supervisors directory -->
          <div class="bg-white dark:bg-slate-800 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm p-6">
            <h2 class="font-extrabold text-slate-800 dark:text-slate-100 text-lg mb-5">👩‍🏫 ติดต่อศึกษานิเทศก์โดยตรง</h2>

            <div v-if="loadingSupervisors" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div v-for="i in 4" :key="i" class="h-16 bg-slate-100 dark:bg-slate-700 rounded-2xl animate-pulse"></div>
            </div>
            <div v-else-if="supervisors.length === 0" class="text-center py-10 text-slate-400 text-sm">
              ยังไม่มีข้อมูลศึกษานิเทศก์ในระบบ
            </div>
            <div v-else class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <button v-for="sv in supervisors" :key="sv.id" @click="selected = sv"
                class="flex items-start gap-3 p-4 bg-slate-50 dark:bg-slate-900 rounded-2xl border border-slate-100 dark:border-slate-700 hover:border-primary/40 hover:bg-primary-light dark:hover:bg-slate-700 transition-all text-left">
                <div class="w-11 h-11 rounded-xl overflow-hidden flex-shrink-0 bg-primary/10 flex items-center justify-center">
                  <img v-if="sv.avatar_url" :src="sv.avatar_url" class="w-full h-full object-cover object-top"/>
                  <span v-else class="text-lg font-extrabold text-primary">{{ displayName(sv)[0] || '?' }}</span>
                </div>
                <div class="min-w-0">
                  <p class="font-bold text-sm text-slate-800 dark:text-slate-100 truncate">{{ displayName(sv) }}</p>
                  <p class="text-xs text-slate-500 dark:text-slate-400 truncate">{{ sv.position_level || sv.position }}</p>
                  <span v-if="(sv.subjects||[])[0]" class="inline-block mt-1 text-[10px] bg-secondary/10 text-secondary px-2 py-0.5 rounded-full font-bold">
                    {{ sv.subjects[0] }}{{ sv.subjects.length > 1 ? ` +${sv.subjects.length - 1}` : '' }}
                  </span>
                </div>
              </button>
            </div>
          </div>

        </div>
      </div>

    </div>

    <!-- Supervisor detail popup -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="selected" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="selected = null">
          <div class="bg-white dark:bg-slate-900 rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden">
            <div class="h-28 relative flex-shrink-0" style="background:linear-gradient(135deg,var(--color-primary),var(--color-secondary))">
              <button @click="selected = null"
                class="absolute top-3 right-3 w-9 h-9 bg-white hover:bg-slate-100 rounded-full flex items-center justify-center shadow-lg transition-colors">
                <svg class="w-4 h-4 text-slate-700" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
              <div class="absolute -bottom-12 left-1/2 -translate-x-1/2">
                <div class="w-24 h-24 rounded-full overflow-hidden ring-4 ring-white dark:ring-slate-900 shadow-xl bg-slate-100 dark:bg-slate-700">
                  <img v-if="selected.avatar_url" :src="selected.avatar_url" class="w-full h-full object-cover object-top"/>
                  <div v-else class="w-full h-full flex items-center justify-center text-3xl font-extrabold text-primary">
                    {{ displayName(selected)[0] || '?' }}
                  </div>
                </div>
              </div>
            </div>
            <div class="pt-16 pb-6 px-6">
              <div class="text-center mb-4">
                <h2 class="text-lg font-extrabold text-slate-900 dark:text-slate-50 leading-tight">{{ displayName(selected) }}</h2>
                <p class="text-primary font-bold text-sm mt-0.5">{{ selected.position_level || selected.position }}</p>
                <p v-if="selected.department" class="text-slate-400 text-xs mt-0.5">{{ selected.department }}</p>
              </div>
              <div v-if="(selected.subjects||[]).length" class="flex flex-wrap justify-center gap-1.5 mb-3">
                <span v-for="s in selected.subjects" :key="s" class="text-xs font-bold px-2.5 py-1 bg-secondary/10 text-secondary rounded-full">{{ s }}</span>
              </div>
              <div v-if="visibleContact(selected).length" class="border-t border-slate-100 dark:border-slate-800 pt-3 space-y-2">
                <a v-for="c in visibleContact(selected)" :key="c.key" :href="c.href"
                  class="flex items-center gap-2.5 text-sm text-slate-600 dark:text-slate-300 hover:text-primary transition-colors group">
                  <div class="w-7 h-7 rounded-lg bg-slate-100 dark:bg-slate-800 flex items-center justify-center flex-shrink-0 group-hover:bg-primary/10">
                    <svg class="w-3.5 h-3.5 text-slate-500 group-hover:text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" :d="c.svgPath"/>
                    </svg>
                  </div>
                  <span>{{ c.label }}</span>
                </a>
              </div>
              <p v-else class="text-center text-xs text-slate-400 border-t border-slate-100 dark:border-slate-800 pt-3">
                ยังไม่ได้เปิดเผยข้อมูลการติดต่อ
              </p>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
