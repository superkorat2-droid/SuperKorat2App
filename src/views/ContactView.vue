<script setup>
import { ref } from 'vue'

const form = ref({ name: '', position: '', phone: '', email: '', subject: '', message: '' })
const sent = ref(false)
const sending = ref(false)

async function submitForm() {
  sending.value = true
  await new Promise(r => setTimeout(r, 1000))
  sending.value = false
  sent.value = true
}

const supervisors = [
  { name: 'นายสมชาย ใจดี',       position: 'ผู้อำนวยการกลุ่มนิเทศฯ', phone: '08X-XXX-XXXX', subject: 'ภาษาไทย/ปฐมวัย' },
  { name: 'นางสาวมานี มีสุข',     position: 'ศึกษานิเทศก์ชำนาญการพิเศษ', phone: '08X-XXX-XXXX', subject: 'คณิตศาสตร์/วิทย์' },
  { name: 'นายวิชัย แสงทอง',     position: 'ศึกษานิเทศก์ชำนาญการพิเศษ', phone: '08X-XXX-XXXX', subject: 'ประกันคุณภาพ/IQA' },
  { name: 'นางอรทัย วิชาการ',    position: 'ศึกษานิเทศก์ชำนาญการ',      phone: '08X-XXX-XXXX', subject: 'สังคม/ภาษาต่างประเทศ' },
]

const contactInfo = [
  { icon: '📍', label: 'ที่ตั้ง',     value: 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา ชั้น 2 สำนักงานเขตพื้นที่การศึกษา' },
  { icon: '📞', label: 'โทรศัพท์',   value: '0X-XXXX-XXXX ต่อ XXX (กลุ่มนิเทศฯ)' },
  { icon: '📠', label: 'โทรสาร',     value: '0X-XXXX-XXXX' },
  { icon: '📧', label: 'อีเมล',      value: 'nithet@obec.go.th' },
  { icon: '🕐', label: 'เวลาทำการ',  value: 'วันจันทร์–ศุกร์ เวลา 08:30–16:30 น. (ยกเว้นวันหยุดราชการ)' },
]
</script>

<template>
  <div class="font-sarabun text-slate-800 py-10">
    <div class="max-w-5xl mx-auto px-4">

      <!-- Header -->
      <div class="mb-10">
        <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Contact Us</p>
        <h1 class="text-3xl font-extrabold text-slate-900">ติดต่อสอบถาม</h1>
        <p class="text-slate-500 mt-2">กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา ยินดีให้บริการและตอบข้อซักถามทุกช่องทาง</p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">

        <!-- Left: Info + supervisors -->
        <div class="lg:col-span-1 space-y-6">

          <!-- Contact info -->
          <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 space-y-4">
            <h2 class="font-extrabold text-slate-800 text-lg">ข้อมูลการติดต่อ</h2>
            <div v-for="info in contactInfo" :key="info.label" class="flex items-start gap-3">
              <span class="text-xl flex-shrink-0 mt-0.5">{{ info.icon }}</span>
              <div>
                <p class="text-xs font-bold text-slate-400 uppercase tracking-wider">{{ info.label }}</p>
                <p class="text-sm text-slate-700 mt-0.5 leading-snug">{{ info.value }}</p>
              </div>
            </div>
          </div>

          <!-- Social links -->
          <div class="bg-gradient-to-br from-blue-600 to-indigo-700 rounded-3xl p-6 text-white">
            <h2 class="font-extrabold text-lg mb-4">ช่องทางโซเชียล</h2>
            <div class="space-y-3">
              <a href="#" class="flex items-center gap-3 bg-white/15 hover:bg-white/25 rounded-xl px-4 py-3 transition-colors">
                <span class="text-2xl">💬</span>
                <div>
                  <p class="font-bold text-sm">LINE Official</p>
                  <p class="text-white/70 text-xs">@nithet-group</p>
                </div>
              </a>
              <a href="#" class="flex items-center gap-3 bg-white/15 hover:bg-white/25 rounded-xl px-4 py-3 transition-colors">
                <span class="text-2xl">👍</span>
                <div>
                  <p class="font-bold text-sm">Facebook Page</p>
                  <p class="text-white/70 text-xs">กลุ่มนิเทศฯ สพป.</p>
                </div>
              </a>
              <a href="#" class="flex items-center gap-3 bg-white/15 hover:bg-white/25 rounded-xl px-4 py-3 transition-colors">
                <span class="text-2xl">▶️</span>
                <div>
                  <p class="font-bold text-sm">YouTube Channel</p>
                  <p class="text-white/70 text-xs">วิดีโอการสอนและนิเทศ</p>
                </div>
              </a>
            </div>
          </div>
        </div>

        <!-- Right: Form + Supervisors -->
        <div class="lg:col-span-2 space-y-6">

          <!-- Contact Form -->
          <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6 md:p-8">
            <h2 class="font-extrabold text-slate-800 text-lg mb-5">📬 ส่งข้อความถึงเรา</h2>

            <Transition enter-active-class="transition duration-300" enter-from-class="opacity-0 scale-95" enter-to-class="opacity-100 scale-100">
              <div v-if="sent" class="flex flex-col items-center justify-center py-10 text-center">
                <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center text-3xl mb-4">✅</div>
                <h3 class="text-xl font-extrabold text-slate-800 mb-2">ส่งข้อความสำเร็จ!</h3>
                <p class="text-slate-500 text-sm">เราจะติดต่อกลับภายใน 1–2 วันทำการ</p>
                <button @click="sent = false; form = { name:'',position:'',phone:'',email:'',subject:'',message:'' }"
                  class="mt-5 bg-blue-600 text-white text-sm font-bold px-6 py-2.5 rounded-xl hover:bg-blue-700 transition-colors">
                  ส่งข้อความใหม่
                </button>
              </div>
            </Transition>

            <form v-if="!sent" @submit.prevent="submitForm" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">ชื่อ-สกุล *</label>
                  <input v-model="form.name" type="text" required placeholder="นายสมชาย ใจดี"
                    class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">ตำแหน่ง/โรงเรียน</label>
                  <input v-model="form.position" type="text" placeholder="ครู / โรงเรียน..."
                    class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">โทรศัพท์</label>
                  <input v-model="form.phone" type="tel" placeholder="08X-XXX-XXXX"
                    class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">อีเมล *</label>
                  <input v-model="form.email" type="email" required placeholder="example@school.ac.th"
                    class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"/>
                </div>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">หัวข้อ *</label>
                <select v-model="form.subject" required
                  class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 bg-white">
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
                <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">ข้อความ *</label>
                <textarea v-model="form.message" required rows="4" placeholder="รายละเอียดที่ต้องการสอบถาม..."
                  class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400 resize-none"></textarea>
              </div>
              <button type="submit" :disabled="sending"
                class="w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-bold py-3 rounded-xl shadow-md transition-all hover:-translate-y-0.5">
                <svg v-if="sending" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                <span>{{ sending ? 'กำลังส่ง...' : '📬 ส่งข้อความ' }}</span>
              </button>
            </form>
          </div>

          <!-- Supervisors directory -->
          <div class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
            <h2 class="font-extrabold text-slate-800 text-lg mb-5">👩‍🏫 ติดต่อศึกษานิเทศก์โดยตรง</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div v-for="sv in supervisors" :key="sv.name"
                class="flex items-start gap-3 p-4 bg-slate-50 rounded-2xl border border-slate-100 hover:bg-blue-50 hover:border-blue-200 transition-all">
                <div class="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center text-xl flex-shrink-0">👤</div>
                <div class="min-w-0">
                  <p class="font-bold text-sm text-slate-800 truncate">{{ sv.name }}</p>
                  <p class="text-xs text-slate-500 truncate">{{ sv.position }}</p>
                  <p class="text-xs font-bold text-blue-600 mt-1">{{ sv.phone }}</p>
                  <span class="inline-block mt-1 text-[10px] bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full font-bold">{{ sv.subject }}</span>
                </div>
              </div>
            </div>
            <p class="text-center text-xs text-slate-400 mt-4 pt-4 border-t border-slate-100">
              * ข้อมูลบุคลากรจริงจะดึงจากระบบฐานข้อมูล
            </p>
          </div>

        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
