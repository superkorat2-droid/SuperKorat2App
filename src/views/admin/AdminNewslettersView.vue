<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const items    = ref([])
const schools  = ref([])
const loading  = ref(true)
const saving   = ref(false)
const showModal = ref(false)
const filterCategory = ref('all')
const filterYear     = ref('all')
const searchQ        = ref('')

const CATEGORIES = [
  { value:'newsletter',   label:'จดหมายข่าว' },
  { value:'announcement', label:'ประกาศ/หนังสือเวียน' },
  { value:'circular',     label:'คำสั่ง' },
  { value:'policy',       label:'นโยบาย' },
  { value:'other',        label:'อื่นๆ' },
]
const currentYear = new Date().getFullYear() + 543

const emptyForm = () => ({
  id: null, school_id: '', title: '', description: '',
  drive_url: '', category: 'newsletter',
  academic_year: String(currentYear), month: '', year: currentYear,
  is_published: false,
})
const form = ref(emptyForm())

// ── Extract Drive file ID ──────────────────────────────────────────────────────
function extractFileId(url) {
  const patterns = [/\/file\/d\/([a-zA-Z0-9_-]+)/, /id=([a-zA-Z0-9_-]+)/, /\/d\/([a-zA-Z0-9_-]+)\//]
  for (const p of patterns) { const m = url?.match(p); if (m) return m[1] }
  return null
}

function embedUrl(fileId) {
  return fileId ? `https://drive.google.com/file/d/${fileId}/preview` : null
}

async function load() {
  loading.value = true
  const [{ data: n }, { data: sc }] = await Promise.all([
    supabase.from('newsletters').select('*, schools(name, district)')
      .order('year', { ascending: false }).order('month', { ascending: false }),
    supabase.from('schools').select('id, name, district').order('district').order('name'),
  ])
  items.value   = n || []
  schools.value = sc || []
  loading.value = false
}
onMounted(load)

const years = computed(() => [...new Set(items.value.map(n => n.year).filter(Boolean))].sort((a,b)=>b-a))

const filtered = computed(() => {
  let list = items.value
  if (filterCategory.value !== 'all') list = list.filter(n => n.category === filterCategory.value)
  if (filterYear.value !== 'all')     list = list.filter(n => String(n.year) === filterYear.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(n => n.title.toLowerCase().includes(q) || n.schools?.name?.toLowerCase().includes(q))
  }
  return list
})

// ── CRUD ──────────────────────────────────────────────────────────────────────
function openCreate() { form.value = emptyForm(); showModal.value = true }
function openEdit(n)  {
  form.value = {
    id: n.id, school_id: n.school_id || '', title: n.title,
    description: n.description || '', drive_url: n.drive_url,
    category: n.category, academic_year: n.academic_year || String(currentYear),
    month: n.month || '', year: n.year || currentYear, is_published: n.is_published,
  }
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim() || !form.value.drive_url.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อและ Google Drive Link' }); return
  }
  const fileId = extractFileId(form.value.drive_url)
  if (!fileId) {
    Swal.fire({ icon: 'error', title: 'Link ไม่ถูกต้อง', text: 'กรุณาวาง Link แชร์จาก Google Drive' }); return
  }
  saving.value = true
  const payload = {
    school_id:     form.value.school_id || null,
    title:         form.value.title.trim(),
    description:   form.value.description.trim() || null,
    drive_url:     form.value.drive_url.trim(),
    file_id:       fileId,
    category:      form.value.category,
    academic_year: form.value.academic_year || null,
    month:         form.value.month ? Number(form.value.month) : null,
    year:          form.value.year ? Number(form.value.year) : null,
    is_published:  form.value.is_published,
    updated_at:    new Date().toISOString(),
  }
  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('newsletters').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('newsletters').insert(payload))
  }
  saving.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  showModal.value = false
  await load()
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1200 })
}

async function del(n) {
  const r = await Swal.fire({
    title: 'ลบรายการนี้?', text: n.title,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  await supabase.from('newsletters').delete().eq('id', n.id)
  await load()
}

async function togglePublish(n) {
  await supabase.from('newsletters').update({ is_published: !n.is_published }).eq('id', n.id)
  await load()
}

const MONTHS = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.']
function monthLabel(m) { return m ? MONTHS[m-1] : '' }
function catLabel(c)  { return CATEGORIES.find(x=>x.value===c)?.label || c }
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">จดหมายข่าว / เอกสารเผยแพร่</h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการเอกสารจาก Google Drive</p>
      </div>
      <button @click="openCreate"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        เพิ่มเอกสาร
      </button>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อเอกสาร โรงเรียน..."
        class="flex-1 min-w-[200px] px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white"/>
      <select v-model="filterCategory" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกประเภท</option>
        <option v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
      </select>
      <select v-model="filterYear" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกปี</option>
        <option v-for="y in years" :key="y" :value="String(y)">{{ y }}</option>
      </select>
    </div>

    <!-- Table -->
    <div v-if="loading" class="flex justify-center py-12">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div v-if="filtered.length === 0" class="text-center py-12 text-slate-400 text-sm">ยังไม่มีเอกสาร</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-100">
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ชื่อเอกสาร</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ประเภท</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">โรงเรียน</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">เดือน/ปี</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">สถานะ</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="n in filtered" :key="n.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3">
                <a :href="n.drive_url" target="_blank" rel="noopener"
                  class="font-bold text-slate-800 hover:text-primary transition-colors flex items-center gap-1.5">
                  <svg class="w-4 h-4 text-red-500 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/>
                  </svg>
                  {{ n.title }}
                </a>
                <p v-if="n.description" class="text-xs text-slate-400 mt-0.5">{{ n.description }}</p>
              </td>
              <td class="px-4 py-3">
                <span class="text-xs bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">{{ catLabel(n.category) }}</span>
              </td>
              <td class="px-4 py-3 text-xs text-slate-500">{{ n.schools?.name || 'สพป.' }}</td>
              <td class="px-4 py-3 text-xs text-slate-500">{{ monthLabel(n.month) }} {{ n.year }}</td>
              <td class="px-4 py-3 text-center">
                <button @click="togglePublish(n)"
                  :class="['text-xs font-bold px-2.5 py-1 rounded-full transition-colors',
                    n.is_published ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
                  {{ n.is_published ? 'เผยแพร่' : 'ร่าง' }}
                </button>
              </td>
              <td class="px-4 py-3 text-center">
                <div class="flex items-center justify-center gap-2">
                  <button @click="openEdit(n)" class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">แก้ไข</button>
                  <button @click="del(n)" class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">ลบ</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- ── Modal ───────────────────────────────────────────────────────────── -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden">
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <h2 class="font-extrabold text-slate-800">{{ form.id ? 'แก้ไขเอกสาร' : 'เพิ่มเอกสาร' }}</h2>
            <button @click="showModal=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

            <!-- Warning -->
            <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 flex gap-2">
              <svg class="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>
              </svg>
              <div class="text-xs text-amber-700">
                <p class="font-bold mb-1">⚠️ สำคัญ: ก่อนวาง Link</p>
                <ol class="space-y-0.5 list-decimal list-inside">
                  <li>เปิดไฟล์ใน Google Drive</li>
                  <li>คลิก <strong>"แชร์"</strong> (Share)</li>
                  <li>ตั้งเป็น <strong>"ทุกคนที่มีลิงก์"</strong> (Anyone with the link)</li>
                  <li>คัดลอก Link แล้ววางด้านล่าง</li>
                </ol>
              </div>
            </div>

            <!-- Drive URL -->
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">Google Drive Link <span class="text-red-500">*</span></label>
              <input v-model="form.drive_url" type="url" placeholder="https://drive.google.com/file/d/..."
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
              <p v-if="form.drive_url && !extractFileId(form.drive_url)" class="text-xs text-red-500 mt-1">
                ไม่พบ File ID — กรุณาตรวจสอบ Link
              </p>
              <p v-else-if="extractFileId(form.drive_url)" class="text-xs text-emerald-600 mt-1">
                ✓ File ID: {{ extractFileId(form.drive_url) }}
              </p>
            </div>

            <!-- Title -->
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อเอกสาร <span class="text-red-500">*</span></label>
              <input v-model="form.title" type="text" placeholder="เช่น จดหมายข่าว ฉบับที่ 1/2568"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>

            <!-- Category + School -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ประเภท</label>
                <select v-model="form.category" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">โรงเรียน</label>
                <select v-model="form.school_id" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option value="">สพป. (ทั้งเขต)</option>
                  <optgroup v-for="d in [...new Set(schools.map(s=>s.district))].sort()" :key="d" :label="`อ.${d}`">
                    <option v-for="s in schools.filter(x=>x.district===d)" :key="s.id" :value="s.id">{{ s.name }}</option>
                  </optgroup>
                </select>
              </div>
            </div>

            <!-- Date -->
            <div class="grid grid-cols-3 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">เดือน</label>
                <select v-model="form.month" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option value="">-</option>
                  <option v-for="(m,i) in MONTHS" :key="i+1" :value="i+1">{{ m }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ปี พ.ศ.</label>
                <input v-model.number="form.year" type="number" :placeholder="currentYear"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ปีการศึกษา</label>
                <input v-model="form.academic_year" type="text" :placeholder="String(currentYear)"
                  class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
              </div>
            </div>

            <!-- Description -->
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">คำอธิบาย (ไม่บังคับ)</label>
              <textarea v-model="form.description" rows="2" placeholder="รายละเอียดเพิ่มเติม..."
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm resize-none focus:outline-none focus:border-primary"/>
            </div>

            <!-- Published -->
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="form.is_published" class="w-4 h-4 accent-primary rounded"/>
              <span class="text-sm font-medium text-slate-700">เผยแพร่ทันที</span>
            </label>
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
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
