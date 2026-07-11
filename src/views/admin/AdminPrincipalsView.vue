<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import { Cropper } from 'vue-advanced-cropper'
import 'vue-advanced-cropper/dist/style.css'
import Swal from 'sweetalert2'

// ─── State ────────────────────────────────────────────────────────────────────
const principals  = ref([])
const schools     = ref([])
const loading     = ref(true)
const searchQ     = ref('')
const filterDistrict  = ref('all')
const filterGroup     = ref('all')

// ─── Modal ───────────────────────────────────────────────────────────────────
const showModal  = ref(false)
const saving     = ref(false)
const emptyForm  = () => ({
  id: null, school_id: '', name: '', position: '',
  phone: '', email: '', line_id: '', photo_url: '',
  sort_order: 0,
  visibility: { phone: false, email: false, line: false },
})
const form = ref(emptyForm())

// ─── Photo crop ──────────────────────────────────────────────────────────────
const cropModal    = ref({ open: false, src: '' })
const cropperRef   = ref(null)
const cropping     = ref(false)
const photoPreview = ref(null)
onUnmounted(() => { cropModal.value.open = false })

const POSITIONS = ['ผู้อำนวยการ','รองผู้อำนวยการ','รักษาการผู้อำนวยการ','ผู้ช่วยผู้อำนวยการ','ครูรักษาการ']

async function load() {
  loading.value = true
  const [{ data: p }, { data: sc }] = await Promise.all([
    supabase.from('school_principals')
      .select('*, schools(name, district, school_group)')
      .order('school_id').order('sort_order'),
    supabase.from('schools').select('id, name, district, school_group').order('district').order('name'),
  ])
  principals.value = p || []
  schools.value    = sc || []
  loading.value    = false
}
onMounted(load)

// ─── Filter options ───────────────────────────────────────────────────────────
const districts = computed(() => [...new Set(schools.value.map(s => s.district))].sort())
const groups    = computed(() => {
  const src = filterDistrict.value === 'all'
    ? schools.value
    : schools.value.filter(s => s.district === filterDistrict.value)
  return [...new Set(src.map(s => s.school_group))].sort()
})

// ─── Realtime filtered list ───────────────────────────────────────────────────
const filtered = computed(() => {
  let list = principals.value
  if (filterDistrict.value !== 'all') list = list.filter(p => p.schools?.district === filterDistrict.value)
  if (filterGroup.value    !== 'all') list = list.filter(p => p.schools?.school_group === filterGroup.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(p =>
      p.name.toLowerCase().includes(q) ||
      p.position.toLowerCase().includes(q) ||
      p.schools?.name?.toLowerCase().includes(q)
    )
  }
  return list
})

const schoolsWithData = computed(() => new Set(principals.value.map(p => p.school_id)).size)

// ─── Stats ────────────────────────────────────────────────────────────────────
const stats = computed(() => ({
  total:       filtered.value.length,
  withData:    new Set(filtered.value.map(p => p.school_id)).size,
  withoutData: schools.value.length - schoolsWithData.value,
}))

// ─── CRUD ─────────────────────────────────────────────────────────────────────
function openCreate(schoolId = '') {
  form.value = { ...emptyForm(), school_id: schoolId }
  photoPreview.value = null
  showModal.value = true
}

function openEdit(p) {
  form.value = {
    id: p.id, school_id: p.school_id, name: p.name,
    position: p.position, phone: p.phone || '',
    email: p.email || '', line_id: p.line_id || '',
    photo_url: p.photo_url || '', sort_order: p.sort_order,
    visibility: { ...p.visibility },
  }
  photoPreview.value = p.photo_url || null
  showModal.value = true
}

async function save() {
  if (!form.value.name.trim() || !form.value.position.trim() || !form.value.school_id) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกข้อมูลให้ครบ' }); return
  }
  saving.value = true
  const payload = {
    school_id:  form.value.school_id,
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
    ;({ error } = await supabase.from('school_principals').insert(payload))
  }
  saving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  showModal.value = false
  await load()
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1200 })
}

async function deletePrincipal(p) {
  const r = await Swal.fire({
    title: 'ลบข้อมูลนี้?', text: `${p.name} (${p.position})`,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  if (p.photo_url) {
    const path = p.photo_url.split('/principal-photos/')[1]
    if (path) await supabase.storage.from('principal-photos').remove([path])
  }
  await supabase.from('school_principals').delete().eq('id', p.id)
  await load()
}

// ─── Photo upload + crop ──────────────────────────────────────────────────────
function onPhotoChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  e.target.value = ''
  const reader = new FileReader()
  reader.onload = ev => { cropModal.value = { open: true, src: ev.target.result } }
  reader.readAsDataURL(file)
}

function resizeCanvas(src, size = 200) {
  const c = document.createElement('canvas')
  c.width = size; c.height = size
  c.getContext('2d').drawImage(src, 0, 0, size, size)
  return c
}

async function confirmCrop() {
  const { canvas } = cropperRef.value?.getResult() || {}
  if (!canvas) return
  cropping.value = true
  const resized = resizeCanvas(canvas, 200)
  photoPreview.value = resized.toDataURL('image/jpeg', 0.8)
  resized.toBlob(async blob => {
    const path = `${form.value.school_id || 'tmp'}/${Date.now()}.jpg`
    const { error } = await supabase.storage.from('principal-photos')
      .upload(path, blob, { upsert: true, contentType: 'image/jpeg' })
    if (!error) {
      const { data: { publicUrl } } = supabase.storage.from('principal-photos').getPublicUrl(path)
      form.value.photo_url = publicUrl
    }
    cropModal.value.open = false
    cropping.value = false
  }, 'image/jpeg', 0.8)
}

function initials(name) {
  return name?.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase() || '?'
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"/>
          </svg>
          ผู้บริหารโรงเรียน
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">ทำเนียบผู้บริหารทุกโรงเรียนในสังกัด</p>
      </div>
      <button @click="openCreate()"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        เพิ่มผู้บริหาร
      </button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-3 gap-4">
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-primary">{{ stats.total }}</p>
        <p class="text-xs text-slate-500 mt-1">ผู้บริหารทั้งหมด</p>
      </div>
      <div class="bg-emerald-50 rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-emerald-600">{{ stats.withData }}</p>
        <p class="text-xs text-slate-500 mt-1">โรงเรียนที่มีข้อมูล</p>
      </div>
      <div class="bg-amber-50 rounded-2xl border border-amber-200 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-amber-600">{{ stats.withoutData }}</p>
        <p class="text-xs text-slate-500 mt-1">โรงเรียนที่ยังไม่มีข้อมูล</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <div class="relative flex-1 min-w-[200px]">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>
        </svg>
        <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อ, ตำแหน่ง, โรงเรียน..."
          class="w-full pl-9 pr-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white"/>
      </div>
      <select v-model="filterDistrict" @change="filterGroup='all'"
        class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกอำเภอ</option>
        <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
      </select>
      <select v-model="filterGroup"
        class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกกลุ่มโรงเรียน</option>
        <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
      </select>
    </div>

    <!-- Table -->
    <div v-if="loading" class="flex justify-center py-12">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>
    <div v-else-if="filtered.length === 0"
      class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
      <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0z"/>
      </svg>
      <p class="font-medium">ยังไม่มีข้อมูลผู้บริหาร</p>
    </div>
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-100">
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">รูป</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ชื่อ-สกุล</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ตำแหน่ง</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">โรงเรียน</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">อำเภอ</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ติดต่อ</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="p in filtered" :key="p.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3">
                <div class="w-9 h-9 rounded-full overflow-hidden bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <img v-if="p.photo_url" :src="p.photo_url" :alt="p.name" class="w-full h-full object-cover"/>
                  <span v-else class="text-xs font-bold text-primary">{{ initials(p.name) }}</span>
                </div>
              </td>
              <td class="px-4 py-3 font-bold text-slate-800">{{ p.name }}</td>
              <td class="px-4 py-3">
                <span class="text-xs bg-primary/10 text-primary font-bold px-2.5 py-0.5 rounded-full">{{ p.position }}</span>
              </td>
              <td class="px-4 py-3 text-xs text-slate-600">{{ p.schools?.name }}</td>
              <td class="px-4 py-3 text-xs text-slate-500">{{ p.schools?.district }}</td>
              <td class="px-4 py-3">
                <div class="flex gap-2 text-xs">
                  <span v-if="p.phone && p.visibility?.phone" class="text-slate-500">📞</span>
                  <span v-if="p.email && p.visibility?.email" class="text-slate-500">✉️</span>
                  <span v-if="p.line_id && p.visibility?.line" class="text-slate-500">💚</span>
                </div>
              </td>
              <td class="px-4 py-3 text-center">
                <div class="flex items-center justify-center gap-2">
                  <button @click="openEdit(p)"
                    class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">
                    แก้ไข
                  </button>
                  <button @click="deletePrincipal(p)"
                    class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">
                    ลบ
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- ── Add/Edit Modal ──────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden">

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
                <input type="file" id="photo-input" accept="image/jpeg,image/png,image/webp" class="sr-only"
                  @change="onPhotoChange"/>
                <label for="photo-input"
                  class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl cursor-pointer hover:bg-primary/20 transition-colors">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/></svg>
                  {{ photoPreview ? 'เปลี่ยนรูป' : 'อัปโหลดรูป' }}
                </label>
                <p class="text-[10px] text-slate-400 mt-1">ครอบเป็นวงกลม 200×200px</p>
              </div>
            </div>

            <!-- School -->
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">โรงเรียน <span class="text-red-500">*</span></label>
              <select v-model="form.school_id"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                <option value="">-- เลือกโรงเรียน --</option>
                <optgroup v-for="d in districts" :key="d" :label="`อ.${d}`">
                  <option v-for="s in schools.filter(sc=>sc.district===d)" :key="s.id" :value="s.id">{{ s.name }}</option>
                </optgroup>
              </select>
            </div>

            <!-- Name + Position -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อ-สกุล <span class="text-red-500">*</span></label>
                <input v-model="form.name" type="text" placeholder="นาย/นาง..."
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ตำแหน่ง <span class="text-red-500">*</span></label>
                <input v-model="form.position" type="text" list="admin-positions" placeholder="พิมพ์หรือเลือก..."
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <datalist id="admin-positions">
                  <option v-for="pos in POSITIONS" :key="pos" :value="pos"/>
                </datalist>
              </div>
            </div>

            <!-- Contact -->
            <div class="space-y-3">
              <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">ข้อมูลติดต่อ</p>
              <div v-for="field in [
                { key:'phone',  label:'เบอร์โทรศัพท์', placeholder:'0xx-xxx-xxxx', type:'tel' },
                { key:'email',  label:'อีเมล',           placeholder:'example@email.com', type:'email' },
                { key:'line_id',label:'LINE ID',          placeholder:'@lineid', type:'text' },
              ]" :key="field.key" class="flex items-center gap-3">
                <div class="flex-1">
                  <label class="block text-xs text-slate-400 mb-1">{{ field.label }}</label>
                  <input v-model="form[field.key]" :type="field.type" :placeholder="field.placeholder"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                </div>
                <!-- Visibility toggle -->
                <div class="pt-4 flex-shrink-0">
                  <label class="relative inline-flex items-center cursor-pointer" :title="form.visibility[field.key === 'line_id' ? 'line' : field.key] ? 'แสดงสาธารณะ' : 'ซ่อน'">
                    <input type="checkbox"
                      v-model="form.visibility[field.key === 'line_id' ? 'line' : field.key]"
                      class="sr-only peer"/>
                    <div class="w-8 h-4 bg-slate-200 rounded-full peer peer-checked:bg-emerald-500 transition-colors
                                after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white
                                after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:after:translate-x-4"/>
                  </label>
                  <p class="text-[10px] text-slate-400 text-center mt-0.5">{{ form.visibility[field.key === 'line_id' ? 'line' : field.key] ? '🌐' : '🔒' }}</p>
                </div>
              </div>
              <p class="text-xs text-slate-400">🌐 = แสดงสาธารณะ · 🔒 = ซ่อน</p>
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

  <!-- ── Photo Crop Modal ────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="cropModal.open"
        class="fixed inset-0 z-[60] flex items-center justify-center bg-black/75 p-4 font-sarabun"
        @click.self="cropModal.open=false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm flex flex-col overflow-hidden">
          <div class="px-5 py-3 border-b border-slate-100 flex-shrink-0">
            <p class="text-sm font-extrabold text-slate-700">ครอบรูปโปรไฟล์ (วงกลม)</p>
          </div>
          <div class="bg-slate-900 overflow-hidden" style="height:280px">
            <Cropper ref="cropperRef" :src="cropModal.src"
              :stencil-props="{ aspectRatio: 1 }"
              class="w-full h-full" style="height:100%"/>
          </div>
          <div class="px-5 py-4 border-t border-slate-100 flex gap-3 justify-end flex-shrink-0">
            <button @click="cropModal.open=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="confirmCrop" :disabled="cropping"
              class="flex items-center gap-1.5 px-5 py-2 text-sm font-bold bg-primary text-white rounded-xl disabled:opacity-50 transition-all shadow-md">
              <svg v-if="cropping" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
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
