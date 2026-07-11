<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import { Cropper } from 'vue-advanced-cropper'
import 'vue-advanced-cropper/dist/style.css'
import Swal from 'sweetalert2'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const principals  = ref([])
const loading     = ref(true)
const saving      = ref(false)
const showModal   = ref(false)
const photoPreview = ref(null)
const cropModal   = ref({ open: false, src: '' })
const cropperRef  = ref(null)
const cropping    = ref(false)
onUnmounted(() => { cropModal.value.open = false })

const POSITIONS = ['ผู้อำนวยการ','รองผู้อำนวยการ','รักษาการผู้อำนวยการ','ผู้ช่วยผู้อำนวยการ','ครูรักษาการ']

const emptyForm = () => ({
  id: null, name: '', position: '',
  phone: '', email: '', line_id: '', photo_url: '', sort_order: 0,
  visibility: { phone: false, email: false, line: false },
})
const form = ref(emptyForm())

async function load() {
  if (!props.school?.id) return
  loading.value = true
  const { data } = await supabase
    .from('school_principals').select('*')
    .eq('school_id', props.school.id).order('sort_order')
  principals.value = data || []
  loading.value = false
}
onMounted(load)

function openCreate() { form.value = emptyForm(); photoPreview.value = null; showModal.value = true }
function openEdit(p) {
  form.value = { id:p.id, name:p.name, position:p.position, phone:p.phone||'',
    email:p.email||'', line_id:p.line_id||'', photo_url:p.photo_url||'',
    sort_order:p.sort_order, visibility:{...p.visibility} }
  photoPreview.value = p.photo_url || null
  showModal.value = true
}

async function save() {
  if (!form.value.name.trim() || !form.value.position.trim()) {
    Swal.fire({ icon:'warning', title:'กรุณากรอกชื่อและตำแหน่ง' }); return
  }
  saving.value = true
  const payload = {
    school_id:  props.school.id,
    name:       form.value.name.trim(),
    position:   form.value.position.trim(),
    phone:      form.value.phone.trim() || null,
    email:      form.value.email.trim() || null,
    line_id:    form.value.line_id.trim() || null,
    photo_url:  form.value.photo_url || null,
    sort_order: form.value.sort_order,
    visibility: form.value.visibility,
    updated_at: new Date().toISOString(),
  }
  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('school_principals').update(payload).eq('id', form.value.id))
  } else {
    payload.sort_order = principals.value.length
    ;({ error } = await supabase.from('school_principals').insert(payload))
  }
  saving.value = false
  if (error) { Swal.fire({ icon:'error', title:'บันทึกไม่สำเร็จ', text:error.message }); return }
  showModal.value = false
  await load()
  Swal.fire({ icon:'success', title:'บันทึกแล้ว', showConfirmButton:false, timer:1200 })
}

async function del(p) {
  const r = await Swal.fire({
    title:'ลบข้อมูลนี้?', text:`${p.name} (${p.position})`,
    icon:'warning', showCancelButton:true,
    confirmButtonText:'ลบ', cancelButtonText:'ยกเลิก', confirmButtonColor:'#ef4444',
  })
  if (!r.isConfirmed) return
  if (p.photo_url) {
    const path = p.photo_url.split('/principal-photos/')[1]
    if (path) await supabase.storage.from('principal-photos').remove([path])
  }
  await supabase.from('school_principals').delete().eq('id', p.id)
  await load()
}

async function moveUp(i) {
  if (i === 0) return
  const a = principals.value[i], b = principals.value[i-1]
  await Promise.all([
    supabase.from('school_principals').update({ sort_order: b.sort_order }).eq('id', a.id),
    supabase.from('school_principals').update({ sort_order: a.sort_order }).eq('id', b.id),
  ])
  await load()
}
async function moveDown(i) {
  if (i >= principals.value.length - 1) return
  const a = principals.value[i], b = principals.value[i+1]
  await Promise.all([
    supabase.from('school_principals').update({ sort_order: b.sort_order }).eq('id', a.id),
    supabase.from('school_principals').update({ sort_order: a.sort_order }).eq('id', b.id),
  ])
  await load()
}

function onPhotoChange(e) {
  const file = e.target.files?.[0]; if (!file) return
  e.target.value = ''
  const reader = new FileReader()
  reader.onload = ev => { cropModal.value = { open:true, src:ev.target.result } }
  reader.readAsDataURL(file)
}
function resizeCanvas(src, size=200) {
  const c = document.createElement('canvas'); c.width = size; c.height = size
  c.getContext('2d').drawImage(src, 0, 0, size, size); return c
}
async function confirmCrop() {
  const { canvas } = cropperRef.value?.getResult() || {}; if (!canvas) return
  cropping.value = true
  const resized = resizeCanvas(canvas, 200)
  photoPreview.value = resized.toDataURL('image/jpeg', 0.8)
  resized.toBlob(async blob => {
    const path = `${props.school.id}/${Date.now()}.jpg`
    const { error } = await supabase.storage.from('principal-photos')
      .upload(path, blob, { upsert:true, contentType:'image/jpeg' })
    if (!error) {
      const { data:{ publicUrl } } = supabase.storage.from('principal-photos').getPublicUrl(path)
      form.value.photo_url = publicUrl
    }
    cropModal.value.open = false; cropping.value = false
  }, 'image/jpeg', 0.8)
}
function initials(name) { return name?.split(' ').map(n=>n[0]).join('').slice(0,2).toUpperCase() || '?' }
</script>

<template>
  <div class="space-y-5 max-w-2xl font-sarabun">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">ผู้บริหารโรงเรียน</h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการข้อมูลผู้บริหาร พร้อมตั้งค่าการแสดงผล</p>
      </div>
      <button @click="openCreate"
        class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มผู้บริหาร
      </button>
    </div>

    <div v-if="loading" class="flex justify-center py-12">
      <div class="w-7 h-7 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <div v-else-if="principals.length === 0"
      class="text-center py-14 bg-slate-50 rounded-2xl border border-slate-200">
      <svg class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0z"/>
      </svg>
      <p class="font-bold text-slate-500">ยังไม่มีข้อมูลผู้บริหาร</p>
      <p class="text-sm text-slate-400 mt-1">กด "เพิ่มผู้บริหาร" เพื่อเริ่มต้น</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="(p, i) in principals" :key="p.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-4">
        <!-- Reorder -->
        <div class="flex flex-col gap-0.5 flex-shrink-0">
          <button @click="moveUp(i)" :disabled="i===0"
            class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
          </button>
          <button @click="moveDown(i)" :disabled="i===principals.length-1"
            class="w-6 h-6 flex items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 disabled:opacity-20">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
          </button>
        </div>
        <!-- Photo -->
        <div class="w-12 h-12 rounded-full overflow-hidden bg-primary/10 flex items-center justify-center flex-shrink-0 shadow-sm">
          <img v-if="p.photo_url" :src="p.photo_url" :alt="p.name" class="w-full h-full object-cover"/>
          <span v-else class="font-bold text-primary text-sm">{{ initials(p.name) }}</span>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <p class="font-bold text-slate-800">{{ p.name }}</p>
          <span class="text-xs bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">{{ p.position }}</span>
          <!-- Contact visibility -->
          <div class="flex gap-2 mt-1.5 text-xs text-slate-400">
            <span :class="p.visibility?.phone && p.phone ? 'text-emerald-600' : 'opacity-40'">📞 {{ p.visibility?.phone && p.phone ? p.phone : 'ซ่อน' }}</span>
            <span :class="p.visibility?.email && p.email ? 'text-emerald-600' : 'opacity-40'">✉️ {{ p.visibility?.email && p.email ? 'แสดง' : 'ซ่อน' }}</span>
            <span :class="p.visibility?.line && p.line_id ? 'text-emerald-600' : 'opacity-40'">💚 {{ p.visibility?.line && p.line_id ? 'แสดง' : 'ซ่อน' }}</span>
          </div>
        </div>
        <!-- Actions -->
        <div class="flex gap-2 flex-shrink-0">
          <button @click="openEdit(p)"
            class="px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl hover:bg-primary/20 transition-colors">แก้ไข</button>
          <button @click="del(p)"
            class="px-3 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-xl hover:bg-red-100 transition-colors">ลบ</button>
        </div>
      </div>
    </div>
  </div>

  <!-- ── Modal ───────────────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-0 sm:p-4 font-sarabun">
        <div class="bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl w-full sm:max-w-lg max-h-[92dvh] flex flex-col overflow-hidden">
          <div class="flex justify-center pt-3 pb-1 sm:hidden"><div class="w-10 h-1 bg-slate-200 rounded-full"/></div>
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <h2 class="font-extrabold text-slate-800">{{ form.id ? 'แก้ไขผู้บริหาร' : 'เพิ่มผู้บริหาร' }}</h2>
            <button @click="showModal=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
            <!-- Photo -->
            <div class="flex items-center gap-4">
              <div class="w-16 h-16 rounded-full overflow-hidden bg-primary/10 flex items-center justify-center flex-shrink-0 shadow-sm">
                <img v-if="photoPreview" :src="photoPreview" class="w-full h-full object-cover"/>
                <span v-else class="text-lg font-bold text-primary">{{ initials(form.name) }}</span>
              </div>
              <div>
                <input type="file" id="sphoto-input" accept="image/jpeg,image/png,image/webp" class="sr-only" @change="onPhotoChange"/>
                <label for="sphoto-input"
                  class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl cursor-pointer hover:bg-primary/20">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/></svg>
                  {{ photoPreview ? 'เปลี่ยนรูป' : 'อัปโหลดรูป' }}
                </label>
                <p class="text-[10px] text-slate-400 mt-1">วงกลม 200×200px</p>
              </div>
            </div>
            <!-- Fields -->
            <div class="grid grid-cols-2 gap-3">
              <div class="col-span-2">
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อ-สกุล <span class="text-red-500">*</span></label>
                <input v-model="form.name" type="text" placeholder="นาย/นาง..."
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div class="col-span-2">
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ตำแหน่ง <span class="text-red-500">*</span></label>
                <input v-model="form.position" type="text" list="spos" placeholder="พิมพ์หรือเลือก..."
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <datalist id="spos">
                  <option v-for="pos in POSITIONS" :key="pos" :value="pos"/>
                </datalist>
              </div>
            </div>
            <!-- Contact + visibility -->
            <div class="space-y-3">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">ข้อมูลติดต่อ + การแสดงผล</p>
              <div v-for="field in [
                { key:'phone',  vKey:'phone', label:'เบอร์โทรศัพท์', ph:'0xx-xxx-xxxx', type:'tel' },
                { key:'email',  vKey:'email', label:'อีเมล', ph:'example@email.com', type:'email' },
                { key:'line_id',vKey:'line',  label:'LINE ID', ph:'@lineid', type:'text' },
              ]" :key="field.key" class="flex items-end gap-3">
                <div class="flex-1">
                  <label class="block text-xs text-slate-400 mb-1">{{ field.label }}</label>
                  <input v-model="form[field.key]" :type="field.type" :placeholder="field.ph"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
                <div class="flex flex-col items-center pb-1 flex-shrink-0">
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" v-model="form.visibility[field.vKey]" class="sr-only peer"/>
                    <div class="w-8 h-4 bg-slate-200 rounded-full peer peer-checked:bg-emerald-500 transition-colors
                                after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                                after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:after:translate-x-4"/>
                  </label>
                  <p class="text-[10px] text-slate-400 mt-0.5">{{ form.visibility[field.vKey] ? '🌐' : '🔒' }}</p>
                </div>
              </div>
              <p class="text-xs text-slate-400">🌐 = แสดงสาธารณะ · 🔒 = ซ่อน (ชื่อและตำแหน่งแสดงเสมอ)</p>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end flex-shrink-0">
            <button @click="showModal=false" class="px-4 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="save" :disabled="saving"
              class="flex items-center gap-2 px-6 py-2.5 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
              {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- Crop Modal -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="cropModal.open" class="fixed inset-0 z-[60] flex items-center justify-center bg-black/75 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm flex flex-col overflow-hidden">
          <div class="px-5 py-3 border-b border-slate-100">
            <p class="text-sm font-extrabold text-slate-700">ครอบรูปโปรไฟล์</p>
          </div>
          <div class="bg-slate-900" style="height:260px">
            <Cropper ref="cropperRef" :src="cropModal.src" :stencil-props="{ aspectRatio: 1 }" class="w-full h-full" style="height:100%"/>
          </div>
          <div class="px-5 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="cropModal.open=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl">ยกเลิก</button>
            <button @click="confirmCrop" :disabled="cropping"
              class="px-5 py-2 text-sm font-bold bg-primary text-white rounded-xl disabled:opacity-50 shadow-md">
              {{ cropping ? 'กำลังอัปโหลด...' : 'ยืนยัน' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
