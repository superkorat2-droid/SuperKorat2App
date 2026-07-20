<script setup>
import { ref, onMounted } from 'vue'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { ICON_MAP, ICON_LABELS } from '../../composables/useIcons.js'
import Swal from 'sweetalert2'

const { config, fetchConfig, updateConfig } = useAreaConfig()

const services = ref([])
const saving   = ref(false)

const DEFAULT_SERVICES = [
  { key:'nitet',    label:'กลุ่มนิเทศติดตามฯ',   icon:'eye',       type:'internal', url:'/nithet',    visible:true, order:1 },
  { key:'download', label:'ดาวน์โหลดเอกสาร',     icon:'download',  type:'internal', url:'/download',  visible:true, order:2 },
  { key:'qrcode',   label:'สร้าง QR Code',        icon:'qrcode',    type:'internal', url:'/qrcode',    visible:true, order:3 },
  { key:'urlshort', label:'ย่อลิงก์',             icon:'link',      type:'internal', url:'/url-short', visible:true, order:4 },
  { key:'sar',      label:'ระบบ SAR Online',       icon:'chart-bar', type:'external', url:'',           visible:true, order:5 },
  { key:'media',    label:'คลังสื่อนวัตกรรม',     icon:'beaker',    type:'external', url:'',           visible:true, order:6 },
  { key:'training', label:'ลงทะเบียนอบรม',        icon:'clipboard', type:'external', url:'',           visible:true, order:7 },
  { key:'contact',  label:'ติดต่อเรา',             icon:'phone',     type:'internal', url:'/contact',   visible:true, order:8 },
]

const SYSTEM_ROUTES = [
  { route:'/nithet',    label:'กลุ่มนิเทศติดตามฯ' },
  { route:'/personnel', label:'ทำเนียบบุคลากร' },
  { route:'/schools',   label:'ทำเนียบโรงเรียน' },
  { route:'/news',      label:'ข่าวสาร' },
  { route:'/download',  label:'ดาวน์โหลด' },
  { route:'/url-short', label:'ย่อลิงก์' },
  { route:'/qrcode',    label:'QR Code' },
  { route:'/contact',   label:'ติดต่อเรา' },
]

onMounted(async () => {
  await fetchConfig()
  services.value = (config.value?.services || DEFAULT_SERVICES).map(s => ({ ...s }))
})

function moveUp(i)   { if (i>0) { [services.value[i-1],services.value[i]]=[services.value[i],services.value[i-1]]; services.value.forEach((s,idx)=>s.order=idx+1) } }
function moveDown(i) { if (i<services.value.length-1) { [services.value[i],services.value[i+1]]=[services.value[i+1],services.value[i]]; services.value.forEach((s,idx)=>s.order=idx+1) } }

function addService() {
  services.value.push({ key:'svc_'+Date.now(), label:'บริการใหม่', icon:'globe', type:'external', url:'', visible:true, order:services.value.length+1 })
}
function removeService(i) {
  services.value.splice(i,1)
  services.value.forEach((s,idx) => s.order = idx+1)
}

async function save() {
  saving.value = true
  const { error } = await updateConfig({ services: services.value })
  saving.value = false
  if (error) Swal.fire({ icon:'error', title:'บันทึกไม่สำเร็จ', text: error.message })
  else Swal.fire({ icon:'success', title:'บันทึกแล้ว', showConfirmButton:false, timer:1000 })
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="globe" class="w-6 h-6 text-primary"/> จัดการบริการออนไลน์
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการปุ่มบริการบนหน้าแรก — เพิ่ม/ลบ/เรียง/ซ่อน + ตั้ง URL</p>
      </div>
      <div class="flex gap-2">
        <button @click="addService" type="button"
          class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
          <SvgIcon name="plus" class="w-4 h-4"/> เพิ่มบริการ
        </button>
        <button @click="save" :disabled="saving" type="button"
          class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
          <SvgIcon name="document" class="w-4 h-4"/>
          {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
        </button>
      </div>
    </div>

    <!-- Info -->
    <div class="flex items-center gap-2 p-3.5 bg-blue-50 rounded-2xl border border-blue-100 text-sm text-blue-700">
      <SvgIcon name="beaker" class="w-4 h-4 flex-shrink-0"/>
      <span>ปุ่มบริการที่กำหนดที่นี่จะแสดงในหน้าแรก ส่วน "บริการออนไลน์" — สลับเป็น internal/external และตั้ง URL ได้เอง</span>
    </div>

    <!-- Services list -->
    <div class="space-y-3">
      <div v-for="(svc, i) in services" :key="svc.key"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex flex-wrap items-start gap-4">

        <!-- up/down + preview -->
        <div class="flex items-center gap-3 flex-shrink-0">
          <div class="flex flex-col gap-0.5">
            <button @click="moveUp(i)" :disabled="i===0" type="button"
              class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
              </svg>
            </button>
            <button @click="moveDown(i)" :disabled="i===services.length-1" type="button"
              class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20 transition-colors">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
              </svg>
            </button>
          </div>
          <!-- icon preview -->
          <div class="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0"
            style="background:color-mix(in srgb,var(--color-primary) 12%,transparent)">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"
              :style="{color:'var(--color-primary)'}">
              <path stroke-linecap="round" stroke-linejoin="round" :d="ICON_MAP[svc.icon] || ICON_MAP.globe"/>
            </svg>
          </div>
        </div>

        <!-- fields -->
        <div class="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <!-- label -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ชื่อปุ่ม</label>
            <input v-model="svc.label" type="text"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          </div>

          <!-- icon -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Icon</label>
            <select v-model="svc.icon"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option v-for="(path, key) in ICON_MAP" :key="key" :value="key">
                {{ ICON_LABELS[key] || key }}
              </option>
            </select>
          </div>

          <!-- type -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">ประเภท</label>
            <select v-model="svc.type"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
              <option value="internal">ภายใน (route)</option>
              <option value="external">ภายนอก (URL)</option>
            </select>
          </div>

          <!-- url -->
          <div>
            <label class="text-[10px] font-bold text-slate-500 uppercase tracking-wider">
              {{ svc.type === 'internal' ? 'Route' : 'URL ปลายทาง' }}
            </label>
            <input v-model="svc.url" type="text"
              :placeholder="svc.type==='internal' ? '/personnel' : 'https://...'"
              class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm font-mono focus:outline-none focus:border-primary"/>
            <!-- route quick-select -->
            <div v-if="svc.type==='internal'" class="flex flex-wrap gap-1 mt-1.5">
              <button v-for="r in SYSTEM_ROUTES" :key="r.route" type="button"
                @click="svc.url = r.route"
                :class="['text-[9px] px-1.5 py-0.5 rounded-md transition-colors',
                  svc.url===r.route ? 'bg-primary text-white' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                {{ r.route }}
              </button>
            </div>
          </div>
        </div>

        <!-- visible + delete -->
        <div class="flex flex-col gap-2 flex-shrink-0">
          <button @click="svc.visible = !svc.visible" type="button"
            :class="['flex items-center gap-1 px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
              svc.visible ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200']">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path v-if="svc.visible" stroke-linecap="round" stroke-linejoin="round"
                d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              <path v-else stroke-linecap="round" stroke-linejoin="round"
                d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
            </svg>
            {{ svc.visible ? 'แสดง' : 'ซ่อน' }}
          </button>
          <button @click="removeService(i)" type="button"
            class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold rounded-xl bg-slate-50 text-slate-400 hover:text-red-500 hover:bg-red-50 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
            </svg>
            ลบ
          </button>
        </div>

      </div>

      <p v-if="services.length === 0" class="text-center text-slate-400 py-10">
        ยังไม่มีบริการ — กด "เพิ่มบริการ" เพื่อเริ่มต้น
      </p>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
