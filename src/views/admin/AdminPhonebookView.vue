<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { telHref } from '../../composables/useMapLink'

// สมุดโทรศัพท์ผู้บริหาร — ใช้เฉพาะ ศน./เจ้าหน้าที่/แอดมิน (RLS ของ school_principals คุมอีกชั้น)
const rows    = ref([])
const loading = ref(true)
const searchQ = ref('')
const filterDistrict = ref('all')
const filterGroup    = ref('all')
const filterPos      = ref('all')
const onlyPhone      = ref(false)
const copiedId = ref(null)

// แก้เบอร์ได้เฉพาะแอดมิน (ฟังก์ชัน set_principal_phone ใน DB ตรวจซ้ำอีกชั้น) — ศน./เจ้าหน้าที่ ดูและโทรได้อย่างเดียว
const isAdmin = ref(false)

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    const { data: me } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    isAdmin.value = ['super_admin', 'admin'].includes(me?.role)
  }
  const { data } = await supabase
    .from('school_principals')
    .select('id, name, position, phone, visibility, schools!inner(name, district, school_group, is_active)')
    .eq('schools.is_active', true)
  rows.value = (data || []).map(p => ({ ...p, school: p.schools }))
  loading.value = false
})

const thSort = (a, b) => String(a).localeCompare(String(b), 'th', { numeric: true })
const districts = computed(() => [...new Set(rows.value.map(r => r.school.district))].sort(thSort))
const groups = computed(() => {
  const src = filterDistrict.value === 'all' ? rows.value : rows.value.filter(r => r.school.district === filterDistrict.value)
  return [...new Set(src.map(r => r.school.school_group))].sort(thSort)
})
const POSITIONS = ['ผู้อำนวยการ', 'รักษาการผู้อำนวยการ', 'รองผู้อำนวยการ', 'ผู้ช่วยผู้อำนวยการ', 'ครูรักษาการ']
// ตัวเลือกตำแหน่ง: มาตรฐานก่อน แล้วตามด้วยตำแหน่งอื่นที่มีในข้อมูลจริง
const positions = computed(() => {
  const present = new Set(rows.value.map(r => r.position))
  return [...POSITIONS.filter(p => present.has(p)), ...[...present].filter(p => !POSITIONS.includes(p)).sort(thSort)]
})

function onDistrictChange() { filterGroup.value = 'all' }

const digits = s => String(s || '').replace(/\D/g, '')
const filtered = computed(() => {
  const q = searchQ.value.trim().replace(/\s+/g, '')
  const qd = digits(q)
  return rows.value
    .filter(r => {
      if (filterDistrict.value !== 'all' && r.school.district !== filterDistrict.value) return false
      if (filterGroup.value !== 'all' && r.school.school_group !== filterGroup.value) return false
      if (filterPos.value !== 'all' && r.position !== filterPos.value) return false
      if (onlyPhone.value && !r.phone) return false
      if (!q) return true
      return (r.name + r.school.name).replace(/\s+/g, '').includes(q) || (qd && digits(r.phone).includes(qd))
    })
    .sort((a, b) =>
      thSort(a.school.district, b.school.district) ||
      thSort(a.school.school_group, b.school.school_group) ||
      thSort(a.school.name, b.school.name))
})

// 0812345678 → 081-234-5678 (ใช้แสดงผลเท่านั้น ลิงก์โทรใช้ตัวเลขล้วนผ่าน telHref)
const fmtPhone = p => {
  const d = digits(p)
  return d.length === 10 ? `${d.slice(0, 3)}-${d.slice(3, 6)}-${d.slice(6)}` : p
}

// ─── เพิ่มผู้บริหารคนใหม่ (แอดมินเท่านั้น — RLS ของ school_principals คุมอีกชั้น) ───
const schoolOpts = ref([])
const showAdd  = ref(false)
const addForm  = ref({ school_id: '', name: '', position: 'รองผู้อำนวยการ', phone: '' })
const addErr   = ref('')
const adding   = ref(false)
async function openAdd() {
  showAdd.value = true; addErr.value = ''
  if (!schoolOpts.value.length) {
    const { data } = await supabase.from('schools').select('id, name, district, school_group').eq('is_active', true)
    schoolOpts.value = (data || []).sort((a, b) => thSort(a.district, b.district) || thSort(a.name, b.name))
  }
}
async function addPrincipal() {
  const f = addForm.value
  const name = f.name.trim().replace(/\s+/g, ' ')
  const phone = digits(f.phone)
  if (!f.school_id || !name) { addErr.value = 'เลือกโรงเรียนและกรอกชื่อ'; return }
  if (phone && !/^0\d{8,9}$/.test(phone)) { addErr.value = 'เบอร์โทรไม่ถูกต้อง (ต้องขึ้นต้น 0 และมี 9-10 หลัก)'; return }
  adding.value = true; addErr.value = ''
  const { data: last } = await supabase.from('school_principals').select('sort_order')
    .eq('school_id', f.school_id).order('sort_order', { ascending: false }).limit(1)
  const { data, error } = await supabase.from('school_principals').insert({
    school_id: f.school_id, name, position: f.position, phone: phone || null,
    sort_order: (last?.[0]?.sort_order ?? -1) + 1,
    visibility: { phone: false, email: false, line: false },   // เริ่มต้นไม่เปิดสาธารณะ
  }).select('id, name, position, phone, visibility').single()
  adding.value = false
  if (error) { addErr.value = error.message; return }
  const sc = schoolOpts.value.find(x => x.id === f.school_id)
  rows.value.push({ ...data, school: { name: sc.name, district: sc.district, school_group: sc.school_group, is_active: true } })
  addForm.value = { school_id: '', name: '', position: f.position, phone: '' }
  showAdd.value = false
}

// ─── แก้/ลบเบอร์ (ผ่าน RPC set_principal_phone แตะได้เฉพาะคอลัมน์ phone) ───
const editId   = ref(null)
const editVal  = ref('')
const saving   = ref(false)
const errMsg   = ref('')
function startEdit(r) { editId.value = r.id; editVal.value = r.phone || ''; errMsg.value = '' }
function cancelEdit() { editId.value = null; errMsg.value = '' }
async function savePhone(r, value) {
  saving.value = true; errMsg.value = ''
  const { data, error } = await supabase.rpc('set_principal_phone', { p_id: r.id, p_phone: value })
  saving.value = false
  if (error) { errMsg.value = error.message; return }
  r.phone = data
  editId.value = null
}
function removePhone(r) {
  if (confirm(`ลบเบอร์ของ ${r.name}?`)) savePhone(r, '')
}

async function copyPhone(r) {
  try {
    await navigator.clipboard.writeText(digits(r.phone))
  } catch {
    const ta = document.createElement('textarea')
    ta.value = digits(r.phone)
    document.body.appendChild(ta); ta.select(); document.execCommand('copy'); ta.remove()
  }
  copiedId.value = r.id
  setTimeout(() => { if (copiedId.value === r.id) copiedId.value = null }, 1500)
}
</script>

<template>
  <div class="space-y-4">
    <div>
      <h1 class="text-xl font-black text-slate-800">สมุดโทรศัพท์ผู้บริหาร</h1>
      <p class="text-xs text-slate-500 mt-0.5">เฉพาะเจ้าหน้าที่ที่เข้าสู่ระบบ (แก้เบอร์ได้เฉพาะแอดมิน) — เบอร์จะไม่แสดงบนหน้าเว็บสาธารณะ ยกเว้นผู้บริหารเลือกเปิดเอง</p>
    </div>

    <div class="glass-card p-3 flex flex-wrap items-center gap-2">
      <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อผู้บริหาร / โรงเรียน / เบอร์"
        class="flex-1 min-w-[200px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <select v-model="filterDistrict" @change="onDistrictChange"
        class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกอำเภอ</option>
        <option v-for="d in districts" :key="d" :value="d">{{ d }}</option>
      </select>
      <select v-model="filterGroup"
        class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกศูนย์เครือข่าย</option>
        <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
      </select>
      <select v-model="filterPos"
        class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกตำแหน่ง</option>
        <option v-for="p in positions" :key="p" :value="p">{{ p }}</option>
      </select>
      <label class="flex items-center gap-1.5 text-xs text-slate-600 select-none">
        <input v-model="onlyPhone" type="checkbox" class="rounded"/> เฉพาะที่มีเบอร์
      </label>
      <span class="text-xs text-slate-400 ml-auto">{{ filtered.length }} รายการ</span>
    </div>

    <div v-if="isAdmin" class="space-y-2">
      <button v-if="!showAdd" type="button" @click="openAdd" data-testid="open-add"
        class="px-4 py-2 rounded-xl bg-emerald-600 text-white text-sm font-bold">+ เพิ่มผู้บริหารคนใหม่</button>
      <div v-else class="glass-card p-3 space-y-2" data-testid="add-panel">
        <div class="text-sm font-bold text-slate-700">เพิ่มผู้บริหารคนใหม่</div>
        <div class="grid gap-2 sm:grid-cols-2">
          <select v-model="addForm.school_id" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white sm:col-span-2">
            <option value="">— เลือกโรงเรียน —</option>
            <option v-for="s in schoolOpts" :key="s.id" :value="s.id">อ.{{ s.district }} · {{ s.name }}</option>
          </select>
          <input v-model="addForm.name" placeholder="ชื่อ-นามสกุล (รวมคำนำหน้า)" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white"/>
          <select v-model="addForm.position" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white">
            <option v-for="p in POSITIONS" :key="p" :value="p">{{ p }}</option>
          </select>
          <input v-model="addForm.phone" type="tel" inputmode="tel" placeholder="เบอร์โทร (เว้นว่างได้)" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white"/>
        </div>
        <div v-if="addErr" class="text-xs text-red-600">{{ addErr }}</div>
        <div class="flex gap-2">
          <button type="button" :disabled="adding" @click="addPrincipal" class="px-4 py-2 rounded-xl bg-emerald-600 text-white text-sm font-bold disabled:opacity-50">บันทึก</button>
          <button type="button" @click="showAdd = false" class="px-4 py-2 rounded-xl bg-slate-100 text-slate-600 text-sm font-bold">ยกเลิก</button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>
    <div v-else-if="!filtered.length" class="glass-card text-center py-16 text-slate-400 text-sm">ไม่พบรายการ</div>

    <div v-else class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      <div v-for="r in filtered" :key="r.id" class="glass-card p-3 flex items-center gap-3" data-testid="phonebook-row">
        <div class="min-w-0 flex-1">
          <div class="font-bold text-slate-800 text-sm truncate">{{ r.name }}</div>
          <div class="text-xs text-slate-500 truncate">{{ r.position }} · {{ r.school.name }}</div>
          <div class="text-[11px] text-slate-400 truncate">
            อ.{{ r.school.district }} · {{ r.school.school_group }}
            <span v-if="r.visibility?.phone" class="ml-1 text-emerald-600">· เปิดสาธารณะ</span>
          </div>
          <div v-if="r.phone" class="text-sm font-bold text-slate-700 mt-0.5 tabular-nums">{{ fmtPhone(r.phone) }}</div>
          <div v-else class="text-xs text-slate-400 mt-0.5">ยังไม่มีเบอร์</div>
        </div>
        <div v-if="editId === r.id" class="flex flex-col gap-1.5 flex-shrink-0 w-36">
          <input v-model="editVal" type="tel" inputmode="tel" placeholder="0812345678" @keyup.enter="savePhone(r, editVal)"
            class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
          <div v-if="errMsg" class="text-[11px] text-red-600">{{ errMsg }}</div>
          <button type="button" :disabled="saving" @click="savePhone(r, editVal)"
            class="px-3 py-1.5 rounded-xl bg-emerald-600 text-white text-xs font-bold disabled:opacity-50">บันทึก</button>
          <button type="button" @click="cancelEdit" class="px-3 py-1 rounded-xl bg-slate-100 text-slate-600 text-[11px] font-bold">ยกเลิก</button>
        </div>
        <div v-else class="flex flex-col gap-1.5 flex-shrink-0">
          <!-- ลิงก์ tel: ตรง ๆ (ตัวเลขล้วน) ใช้ได้ทั้ง Android และ iOS — ห้ามใช้ window.open/JS ยิงแทน -->
          <a v-if="r.phone" :href="`tel:${telHref(r.phone)}`"
            class="px-4 py-2 rounded-xl bg-emerald-600 text-white text-sm font-bold text-center active:bg-emerald-700">📞 โทร</a>
          <div class="flex gap-1">
            <button v-if="r.phone" type="button" @click="copyPhone(r)"
              class="flex-1 px-2 py-1 rounded-xl bg-slate-100 text-slate-600 text-[11px] font-bold">
              {{ copiedId === r.id ? 'คัดลอกแล้ว' : 'คัดลอก' }}
            </button>
            <button v-if="isAdmin" type="button" @click="startEdit(r)" data-testid="edit-phone"
              class="flex-1 px-2 py-1 rounded-xl bg-slate-100 text-slate-600 text-[11px] font-bold">{{ r.phone ? 'แก้' : '+ เพิ่มเบอร์' }}</button>
            <button v-if="isAdmin && r.phone" type="button" @click="removePhone(r)"
              class="px-2 py-1 rounded-xl bg-red-50 text-red-600 text-[11px] font-bold">ลบ</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
