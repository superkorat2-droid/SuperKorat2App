<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const props = defineProps({ school: { type: Object, default: null }, profile: { type: Object, default: null } })

const items   = ref([])
const loading = ref(true)
const saving  = ref(false)
const showModal = ref(false)

const CATEGORIES = [
  { value:'newsletter', label:'จดหมายข่าว' },
  { value:'announcement', label:'ประกาศ/หนังสือเวียน' },
  { value:'other', label:'อื่นๆ' },
]
const MONTHS = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.']
const currentYear = new Date().getFullYear() + 543

const emptyForm = () => ({
  id: null, title: '', description: '', drive_url: '',
  category: 'newsletter', academic_year: String(currentYear),
  month: '', year: currentYear, is_published: false,
})
const form = ref(emptyForm())

function extractFileId(url) {
  const patterns = [/\/file\/d\/([a-zA-Z0-9_-]+)/, /id=([a-zA-Z0-9_-]+)/, /\/d\/([a-zA-Z0-9_-]+)\//]
  for (const p of patterns) { const m = url?.match(p); if (m) return m[1] }
  return null
}

async function load() {
  if (!props.school?.id) return
  loading.value = true
  const { data } = await supabase.from('newsletters').select('*')
    .eq('school_id', props.school.id).order('year', { ascending: false }).order('month', { ascending: false })
  items.value   = data || []
  loading.value = false
}
onMounted(load)

function openCreate() { form.value = emptyForm(); showModal.value = true }
function openEdit(n)  {
  form.value = {
    id: n.id, title: n.title, description: n.description || '',
    drive_url: n.drive_url, category: n.category,
    academic_year: n.academic_year || String(currentYear),
    month: n.month || '', year: n.year || currentYear, is_published: n.is_published,
  }
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim() || !form.value.drive_url.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อและ Link' }); return
  }
  const fileId = extractFileId(form.value.drive_url)
  if (!fileId) {
    Swal.fire({ icon: 'error', title: 'Link ไม่ถูกต้อง', text: 'กรุณาวาง Link แชร์จาก Google Drive' }); return
  }
  saving.value = true
  const payload = {
    school_id: props.school.id, title: form.value.title.trim(),
    description: form.value.description.trim() || null,
    drive_url: form.value.drive_url.trim(), file_id: fileId,
    category: form.value.category, academic_year: form.value.academic_year || null,
    month: form.value.month ? Number(form.value.month) : null,
    year: form.value.year ? Number(form.value.year) : null,
    is_published: form.value.is_published, updated_at: new Date().toISOString(),
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
  const r = await Swal.fire({ title: 'ลบรายการนี้?', text: n.title, icon: 'warning', showCancelButton: true, confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444' })
  if (!r.isConfirmed) return
  await supabase.from('newsletters').delete().eq('id', n.id)
  await load()
}

function catLabel(c) { return CATEGORIES.find(x=>x.value===c)?.label || c }
function monthLabel(m) { return m ? MONTHS[m-1] : '' }
</script>

<template>
  <div class="space-y-5 max-w-2xl font-sarabun">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">จดหมายข่าว / เอกสารเผยแพร่</h1>
        <p class="text-sm text-slate-500 mt-0.5">เผยแพร่เอกสารของโรงเรียนผ่าน Google Drive</p>
      </div>
      <button @click="openCreate" class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มเอกสาร
      </button>
    </div>

    <div v-if="loading" class="flex justify-center py-12"><div class="w-7 h-7 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/></div>
    <div v-else-if="items.length === 0" class="text-center py-14 bg-slate-50 rounded-2xl border border-slate-200">
      <svg class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/></svg>
      <p class="font-bold text-slate-500">ยังไม่มีเอกสาร</p>
      <p class="text-sm text-slate-400 mt-1">กด "เพิ่มเอกสาร" เพื่อเริ่มต้น</p>
    </div>
    <div v-else class="space-y-3">
      <div v-for="n in items" :key="n.id" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-4">
        <div class="w-10 h-10 bg-red-50 rounded-xl flex items-center justify-center flex-shrink-0">
          <svg class="w-5 h-5 text-red-500" viewBox="0 0 24 24" fill="currentColor"><path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/></svg>
        </div>
        <div class="flex-1 min-w-0">
          <a :href="n.drive_url" target="_blank" rel="noopener"
            class="font-bold text-slate-800 hover:text-primary transition-colors text-sm">
            {{ n.title }} ↗
          </a>
          <div class="flex flex-wrap gap-1.5 mt-1">
            <span class="text-xs bg-primary/10 text-primary font-bold px-2 py-0.5 rounded-full">{{ catLabel(n.category) }}</span>
            <span v-if="n.month" class="text-xs text-slate-400">{{ monthLabel(n.month) }} {{ n.year }}</span>
            <span :class="['text-xs font-bold px-2 py-0.5 rounded-full', n.is_published ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500']">
              {{ n.is_published ? 'เผยแพร่' : 'ร่าง' }}
            </span>
          </div>
        </div>
        <div class="flex gap-2 flex-shrink-0">
          <button @click="openEdit(n)" class="px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl hover:bg-primary/20 transition-colors">แก้ไข</button>
          <button @click="del(n)" class="px-3 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-xl hover:bg-red-100 transition-colors">ลบ</button>
        </div>
      </div>
    </div>
  </div>

  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 p-0 sm:p-4 font-sarabun">
        <div class="bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl w-full sm:max-w-lg max-h-[92dvh] flex flex-col overflow-hidden">
          <div class="flex justify-center pt-3 pb-1 sm:hidden"><div class="w-10 h-1 bg-slate-200 rounded-full"/></div>
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <h2 class="font-extrabold text-slate-800">{{ form.id ? 'แก้ไขเอกสาร' : 'เพิ่มเอกสาร' }}</h2>
            <button @click="showModal=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
            <!-- Warning -->
            <div class="bg-amber-50 border border-amber-200 rounded-xl p-3">
              <p class="text-xs font-bold text-amber-700 mb-1">⚠️ ก่อนวาง Link — ต้องทำก่อน!</p>
              <ol class="text-xs text-amber-700 space-y-0.5 list-decimal list-inside">
                <li>เปิดไฟล์ใน Google Drive → คลิก <strong>"แชร์"</strong></li>
                <li>เปลี่ยนเป็น <strong>"ทุกคนที่มีลิงก์"</strong> (Anyone with the link)</li>
                <li>คัดลอก Link แล้ววางด้านล่าง</li>
              </ol>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">Google Drive Link <span class="text-red-500">*</span></label>
              <input v-model="form.drive_url" type="url" placeholder="https://drive.google.com/file/d/..."
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
              <p v-if="form.drive_url && !extractFileId(form.drive_url)" class="text-xs text-red-500 mt-1">ไม่พบ File ID — ตรวจสอบ Link</p>
              <p v-else-if="extractFileId(form.drive_url)" class="text-xs text-emerald-600 mt-1">✓ Link ถูกต้อง</p>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อเอกสาร <span class="text-red-500">*</span></label>
              <input v-model="form.title" type="text" placeholder="เช่น จดหมายข่าว ฉ.1/2568"
                class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ประเภท</label>
                <select v-model="form.category" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
                  <option v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">เดือน/ปี</label>
                <div class="flex gap-1.5">
                  <select v-model="form.month" class="flex-1 px-2 py-2.5 border border-slate-200 rounded-xl text-xs bg-white focus:outline-none focus:border-primary">
                    <option value="">-</option>
                    <option v-for="(m,i) in MONTHS" :key="i+1" :value="i+1">{{ m }}</option>
                  </select>
                  <input v-model.number="form.year" type="number" :placeholder="currentYear"
                    class="w-20 px-2 py-2.5 border border-slate-200 rounded-xl text-xs focus:outline-none focus:border-primary"/>
                </div>
              </div>
            </div>
            <textarea v-model="form.description" rows="2" placeholder="คำอธิบาย (ไม่บังคับ)"
              class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm resize-none focus:outline-none focus:border-primary"/>
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
