<script setup>
import { ref, onMounted } from 'vue'
import { useAreaConfig, DEFAULT_HOME_SECTIONS } from '../../composables/useAreaConfig'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()

const sections = ref([])
const saving   = ref(false)

// ── BG Color presets ──────────────────────────────────────────────
const BG_PRESETS = [
  { label: 'ขาว',        value: '#ffffff' },
  { label: 'Slate 50',   value: '#f8fafc' },
  { label: 'Slate 100',  value: '#f1f5f9' },
  { label: 'Slate 200',  value: '#e2e8f0' },
  { label: 'Blue 50',    value: '#eff6ff' },
  { label: 'Amber 50',   value: '#fffbeb' },
  { label: 'Emerald 50', value: '#ecfdf5' },
]

// ── Section icons ─────────────────────────────────────────────────
const SECTION_ICONS = {
  news:     'M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5',
  services: 'M13.5 16.875h3.375m0 0h3.375m-3.375 0V13.5m0 3.375v3.375M6 10.5h2.25a2.25 2.25 0 002.25-2.25V6a2.25 2.25 0 00-2.25-2.25H6A2.25 2.25 0 003.75 6v2.25A2.25 2.25 0 006 10.5zm0 9.75h2.25A2.25 2.25 0 0010.5 18v-2.25a2.25 2.25 0 00-2.25-2.25H6a2.25 2.25 0 00-2.25 2.25V18A2.25 2.25 0 006 20.25zm9.75-9.75H18a2.25 2.25 0 002.25-2.25V6A2.25 2.25 0 0018 3.75h-2.25A2.25 2.25 0 0013.5 6v2.25a2.25 2.25 0 002.25 2.25z',
  cta:      'M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18',
}

const SECTION_DESC = {
  news:     'การ์ดข่าวสาร 8 รายการล่าสุด',
  services: 'สถิติเขต + เมนูบริการออนไลน์',
  cta:      'แบนเนอร์เชิญชวน + ลิงค์หลัก',
}

onMounted(async () => {
  await fetchConfig()
  const raw = config.value?.home_sections
  if (Array.isArray(raw) && raw.length > 0) {
    sections.value = raw.map(s => ({ ...s })).sort((a, b) => a.order - b.order)
  } else {
    sections.value = DEFAULT_HOME_SECTIONS.map(s => ({ ...s }))
  }
})

// ── Reorder ───────────────────────────────────────────────────────
function moveUp(i) {
  if (i === 0) return
  const arr = [...sections.value]
  ;[arr[i - 1], arr[i]] = [arr[i], arr[i - 1]]
  arr.forEach((s, idx) => s.order = idx + 1)
  sections.value = arr
}
function moveDown(i) {
  if (i === sections.value.length - 1) return
  const arr = [...sections.value]
  ;[arr[i], arr[i + 1]] = [arr[i + 1], arr[i]]
  arr.forEach((s, idx) => s.order = idx + 1)
  sections.value = arr
}

// ── Save ──────────────────────────────────────────────────────────
async function save() {
  saving.value = true
  const payload = sections.value.map((s, i) => ({ ...s, order: i + 1 }))
  const { error } = await updateConfig({ home_sections: payload })
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
  }
  saving.value = false
}

// ── Contrast check for badge ──────────────────────────────────────
function isDark(hex) {
  const [r, g, b] = hex.match(/\w\w/g).map(x => parseInt(x, 16))
  return (r * 299 + g * 587 + b * 114) / 1000 < 128
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"/>
          </svg>
          จัดการ Section หน้าแรก
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">เปิด/ปิด เรียงลำดับ และเปลี่ยนสีพื้นหลังแต่ละ section</p>
      </div>
      <button @click="save" :disabled="saving"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5 disabled:opacity-50">
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

    <!-- Info -->
    <div class="flex gap-2 p-3.5 bg-blue-50 rounded-2xl border border-blue-100 text-sm text-blue-700">
      <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"/>
      </svg>
      <span>แบนเนอร์/Hero อยู่บนสุดเสมอ ส่วน section ด้านล่างเรียงตามลำดับที่กำหนดที่นี่</span>
    </div>

    <!-- Sections list -->
    <div class="space-y-3">
      <div v-for="(sec, i) in sections" :key="sec.key"
        :class="['bg-white rounded-2xl border-2 shadow-sm transition-all',
          sec.visible ? 'border-slate-100' : 'border-dashed border-slate-200 opacity-60']">

        <div class="p-4 flex flex-wrap items-start gap-4">

          <!-- Order number + arrows -->
          <div class="flex flex-col items-center gap-1 flex-shrink-0">
            <button @click="moveUp(i)" :disabled="i === 0"
              class="w-7 h-7 flex items-center justify-center rounded-lg border border-slate-200 hover:bg-slate-100 disabled:opacity-30 transition-colors">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
              </svg>
            </button>
            <span class="text-xs font-extrabold text-slate-400 w-7 text-center">{{ i + 1 }}</span>
            <button @click="moveDown(i)" :disabled="i === sections.length - 1"
              class="w-7 h-7 flex items-center justify-center rounded-lg border border-slate-200 hover:bg-slate-100 disabled:opacity-30 transition-colors">
              <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
              </svg>
            </button>
          </div>

          <!-- Icon + Info -->
          <div class="flex items-center gap-3 flex-1 min-w-0">
            <div class="w-11 h-11 rounded-xl flex-shrink-0 flex items-center justify-center"
              :style="{ backgroundColor: sec.bg || '#f8fafc' }">
              <svg class="w-5 h-5" :class="isDark(sec.bg || '#f8fafc') ? 'text-white' : 'text-primary'"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" :d="SECTION_ICONS[sec.key] || SECTION_ICONS.news"/>
              </svg>
            </div>
            <div>
              <p class="font-extrabold text-slate-800">{{ sec.label }}</p>
              <p class="text-xs text-slate-400">{{ SECTION_DESC[sec.key] || '' }}</p>
            </div>
          </div>

          <!-- Visible toggle -->
          <div class="flex-shrink-0">
            <button @click="sec.visible = !sec.visible"
              :class="['flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border-2 transition-all',
                sec.visible
                  ? 'border-emerald-400 bg-emerald-50 text-emerald-700'
                  : 'border-slate-200 bg-slate-50 text-slate-400']">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round"
                  :d="sec.visible
                    ? 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'
                    : 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'"/>
              </svg>
              {{ sec.visible ? 'แสดง' : 'ซ่อน' }}
            </button>
          </div>
        </div>

        <!-- Section title input -->
        <div class="px-4 pb-2">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1.5">ชื่อที่แสดงในหน้าแรก</p>
          <input v-model="sec.title" type="text"
            :placeholder="sec.key === 'news' ? 'เช่น ข่าวสารและประชาสัมพันธ์' : sec.key === 'services' ? 'เช่น บริการออนไลน์' : 'เช่น ระบบกลุ่มนิเทศ ติดตามและประเมินผล'"
            class="w-full px-3 py-2 text-sm border border-slate-200 rounded-xl focus:outline-none focus:border-primary transition-colors bg-slate-50 focus:bg-white"/>
        </div>

        <!-- BG Color picker -->
        <div class="px-4 pb-4">
          <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">สีพื้นหลัง Section</p>
          <div class="flex flex-wrap items-center gap-2">
            <!-- Preset circles -->
            <button v-for="preset in BG_PRESETS" :key="preset.value"
              @click="sec.bg = preset.value"
              :title="preset.label"
              :class="['w-8 h-8 rounded-full border-2 transition-all hover:scale-110 shadow-sm',
                sec.bg === preset.value ? 'border-primary scale-110 shadow-md' : 'border-slate-200']"
              :style="{ backgroundColor: preset.value }">
              <svg v-if="sec.bg === preset.value" class="w-4 h-4 mx-auto"
                :class="isDark(preset.value) ? 'text-white' : 'text-primary'"
                fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
              </svg>
            </button>

            <!-- Divider -->
            <div class="w-px h-6 bg-slate-200"></div>

            <!-- Custom color picker -->
            <label class="relative cursor-pointer group" title="เลือกสีกำหนดเอง">
              <div class="w-8 h-8 rounded-full border-2 border-dashed border-slate-300 group-hover:border-primary transition-colors flex items-center justify-center overflow-hidden"
                :style="{ backgroundColor: BG_PRESETS.some(p => p.value === sec.bg) ? 'transparent' : sec.bg }">
                <svg v-if="BG_PRESETS.some(p => p.value === sec.bg)"
                  class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
                </svg>
              </div>
              <input type="color" :value="sec.bg" @input="sec.bg = $event.target.value"
                class="absolute inset-0 opacity-0 cursor-pointer w-full h-full"/>
            </label>

            <!-- Current BG preview badge -->
            <div class="flex items-center gap-1.5 ml-2">
              <div class="w-5 h-5 rounded border border-slate-200 shadow-sm" :style="{ backgroundColor: sec.bg }"></div>
              <span class="text-xs font-mono text-slate-500">{{ sec.bg }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Preview hint -->
    <div class="bg-slate-50 rounded-2xl border border-slate-200 p-4">
      <p class="text-xs font-bold text-slate-500 mb-3">ตัวอย่างลำดับ Section</p>
      <div class="flex flex-col gap-1.5">
        <!-- Banner fixed -->
        <div class="flex items-center gap-2 px-3 py-2 bg-slate-800 text-white text-xs font-bold rounded-xl">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>
          </svg>
          แบนเนอร์ (คงที่)
        </div>
        <!-- Dynamic sections -->
        <template v-for="(sec, i) in sections" :key="sec.key">
          <div :class="['flex items-center gap-2 px-3 py-2 text-xs font-bold rounded-xl border transition-all',
            sec.visible ? 'border-transparent' : 'opacity-40 border-dashed border-slate-300']"
            :style="{ backgroundColor: sec.bg || '#ffffff' }">
            <span class="text-slate-400 font-bold w-4">{{ i + 1 }}</span>
            <svg class="w-3.5 h-3.5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="SECTION_ICONS[sec.key] || SECTION_ICONS.news"/>
            </svg>
            <span class="text-slate-700">{{ sec.label }}</span>
            <span v-if="!sec.visible" class="ml-auto text-slate-400 text-[10px]">ซ่อน</span>
          </div>
        </template>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
