<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const users    = ref([])
const loading  = ref(true)
const search   = ref('')
const filterRole = ref('all')
const filterStatus = ref('all')
const activeTab  = ref('all') // all | pending
const showModal  = ref(false)
const editUser   = ref(null)
const saving     = ref(false)

const roles = [
  { value: 'all',         label: 'ทุกสิทธิ์' },
  { value: 'admin',       label: 'ผู้ดูแลระบบ' },
  { value: 'supervisor',  label: 'ศึกษานิเทศก์' },
  { value: 'staff',       label: 'เจ้าหน้าที่' },
  { value: 'school',      label: 'ผู้แทนโรงเรียน' },
  { value: 'teacher',     label: 'ครู' },
]

const roleColor = { super_admin:'bg-red-100 text-red-700', admin:'bg-purple-100 text-purple-700', supervisor:'bg-blue-100 text-blue-700', staff:'bg-indigo-100 text-indigo-700', school:'bg-emerald-100 text-emerald-700', teacher:'bg-amber-100 text-amber-700' }
const roleLabel = { super_admin:'ผู้ดูแลสูงสุด', admin:'ผู้ดูแลระบบ', supervisor:'ศน.', staff:'เจ้าหน้าที่', school:'โรงเรียน', teacher:'ครู' }

onMounted(fetchUsers)

async function fetchUsers() {
  loading.value = true
  const { data } = await supabase
    .from('profiles')
    .select('id, full_name, email, role, position, phone, school_name, is_approved, is_active, can_publish_supervision, can_manage_documents, created_at, last_login_at')
    .order('created_at', { ascending: false })
  users.value  = data || []
  loading.value = false
}

const pendingUsers = computed(() => users.value.filter(u => !u.is_approved && u.role === 'teacher'))

const filteredUsers = computed(() => {
  let list = activeTab.value === 'pending' ? pendingUsers.value : users.value
  if (filterRole.value !== 'all') list = list.filter(u => u.role === filterRole.value)
  const q = search.value.trim().toLowerCase()
  if (q) list = list.filter(u =>
    (u.full_name||'').toLowerCase().includes(q) ||
    (u.email||'').toLowerCase().includes(q) ||
    (u.school_name||'').toLowerCase().includes(q)
  )
  return list
})

function openEdit(user = null) {
  editUser.value = user
    ? { ...user }
    : { full_name: '', email: '', role: 'teacher', position: '', phone: '', school_name: '', is_approved: true, is_active: true }
  showModal.value = true
}

async function saveUser() {
  saving.value = true
  if (editUser.value.id) {
    const { error } = await supabase.from('profiles').update({
      full_name:                editUser.value.full_name,
      role:                     editUser.value.role,
      position:                 editUser.value.position,
      phone:                    editUser.value.phone,
      school_name:              editUser.value.school_name,
      is_approved:              editUser.value.is_approved,
      is_active:                editUser.value.is_active,
      can_publish_supervision:  editUser.value.can_publish_supervision || false,
      can_manage_documents:     editUser.value.can_manage_documents || false,
    }).eq('id', editUser.value.id)
    if (error) { Swal.fire({ icon:'error', title:'ผิดพลาด', text: error.message }); saving.value = false; return }
  }
  saving.value = false
  showModal.value = false
  await fetchUsers()
  Swal.fire({ icon:'success', title:'บันทึกสำเร็จ', showConfirmButton: false, timer: 1500 })
}

async function approveUser(user) {
  const { error } = await supabase.from('profiles').update({ is_approved: true, approved_at: new Date().toISOString() }).eq('id', user.id)
  if (!error) { await fetchUsers(); Swal.fire({ icon:'success', title:`อนุมัติ ${user.full_name || user.email} แล้ว`, showConfirmButton:false, timer:1500 }) }
}

async function rejectUser(user) {
  const { value: reason } = await Swal.fire({ title: 'เหตุผลที่ปฏิเสธ', input: 'text', inputPlaceholder: 'ระบุเหตุผล (ไม่บังคับ)', showCancelButton: true, confirmButtonText: 'ปฏิเสธ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444' })
  if (reason !== undefined) {
    await supabase.from('profiles').update({ is_approved: false, is_active: false, reject_reason: reason || '' }).eq('id', user.id)
    await fetchUsers()
  }
}

async function toggleActive(user) {
  await supabase.from('profiles').update({ is_active: !user.is_active }).eq('id', user.id)
  user.is_active = !user.is_active
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('th-TH', { day:'numeric', month:'short', year:'numeric' })
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-900 flex items-center gap-2"><SvgIcon name="users" class="w-6 h-6 text-primary"/> จัดการผู้ใช้</h1>
        <p class="text-slate-500 text-sm mt-0.5">ผู้ใช้ทั้งหมด {{ users.length }} คน · รออนุมัติ {{ pendingUsers.length }} คน</p>
      </div>
      <button @click="openEdit()"
        class="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-bold px-5 py-2.5 rounded-xl shadow-md hover:-translate-y-0.5 transition-all">
        ➕ เพิ่มผู้ใช้
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-2">
      <button v-for="t in [{ key:'all', label:`ทั้งหมด (${users.length})` }, { key:'pending', label:`รออนุมัติ (${pendingUsers.length})` }]"
        :key="t.key" @click="activeTab = t.key"
        :class="['px-4 py-2 rounded-xl text-sm font-bold transition-all',
          activeTab === t.key ? 'bg-blue-600 text-white shadow-md' : 'bg-white text-slate-600 border border-slate-200 hover:border-blue-300']">
        {{ t.label }}
        <span v-if="t.key==='pending' && pendingUsers.length > 0" class="ml-1.5 w-4 h-4 bg-red-500 text-white text-[9px] rounded-full inline-flex items-center justify-center">{{ pendingUsers.length }}</span>
      </button>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3">
      <div class="relative flex-1 min-w-48">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0"/>
        </svg>
        <input v-model="search" type="text" placeholder="ค้นหาชื่อ อีเมล โรงเรียน..."
          class="w-full pl-9 pr-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 bg-white"/>
      </div>
      <select v-model="filterRole" class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 bg-white font-medium text-slate-600">
        <option v-for="r in roles" :key="r.value" :value="r.value">{{ r.label }}</option>
      </select>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden">
      <div v-if="loading" class="p-8 flex justify-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
      <div v-else-if="filteredUsers.length === 0" class="py-16 text-center text-slate-400">
        <div class="text-5xl mb-3">👤</div>
        <p class="font-bold">ไม่พบผู้ใช้</p>
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 border-b border-slate-100">
            <tr>
              <th class="text-left px-5 py-3 text-xs font-bold text-slate-500 uppercase tracking-wide">ผู้ใช้</th>
              <th class="text-left px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wide hidden md:table-cell">สิทธิ์</th>
              <th class="text-left px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wide hidden lg:table-cell">สมัครวันที่</th>
              <th class="text-left px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wide">สถานะ</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="u in filteredUsers" :key="u.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-5 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-9 h-9 rounded-xl bg-blue-100 flex items-center justify-center text-sm font-extrabold text-blue-600 flex-shrink-0">
                    {{ (u.full_name || u.email || 'U')[0].toUpperCase() }}
                  </div>
                  <div>
                    <p class="font-bold text-slate-800">{{ u.full_name || '(ไม่ระบุ)' }}</p>
                    <p class="text-xs text-slate-400">{{ u.email }}</p>
                    <p v-if="u.school_name" class="text-xs text-slate-400">🏫 {{ u.school_name }}</p>
                  </div>
                </div>
              </td>
              <td class="px-4 py-4 hidden md:table-cell">
                <span :class="['text-xs font-bold px-2.5 py-1 rounded-full', roleColor[u.role] || 'bg-slate-100 text-slate-600']">
                  {{ roleLabel[u.role] || u.role }}
                </span>
              </td>
              <td class="px-4 py-4 text-xs text-slate-400 hidden lg:table-cell">{{ formatDate(u.created_at) }}</td>
              <td class="px-4 py-4">
                <div class="flex flex-col gap-1">
                  <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full w-fit',
                    u.is_approved ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
                    {{ u.is_approved ? '✅ อนุมัติแล้ว' : '⏳ รออนุมัติ' }}
                  </span>
                  <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full w-fit',
                    u.is_active ? 'bg-slate-100 text-slate-500' : 'bg-red-100 text-red-600']">
                    {{ u.is_active ? 'เปิดใช้งาน' : '🚫 ปิดใช้งาน' }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center gap-1 justify-end">
                  <!-- Approve/Reject (pending teachers) -->
                  <template v-if="!u.is_approved && u.role === 'teacher'">
                    <button @click="approveUser(u)" class="text-xs font-bold bg-emerald-100 text-emerald-700 hover:bg-emerald-200 px-3 py-1.5 rounded-lg transition-colors">✅ อนุมัติ</button>
                    <button @click="rejectUser(u)"  class="text-xs font-bold bg-red-100 text-red-600 hover:bg-red-200 px-3 py-1.5 rounded-lg transition-colors">❌</button>
                  </template>
                  <!-- Edit -->
                  <button @click="openEdit(u)" class="text-xs font-bold text-slate-600 hover:text-blue-700 bg-slate-100 hover:bg-blue-50 px-3 py-1.5 rounded-lg transition-colors">✏️ แก้ไข</button>
                  <!-- Toggle active -->
                  <button @click="toggleActive(u)" :class="['text-xs font-bold px-2 py-1.5 rounded-lg transition-colors', u.is_active ? 'text-slate-400 hover:text-red-500 hover:bg-red-50' : 'text-emerald-600 hover:bg-emerald-50']">
                    {{ u.is_active ? '🚫' : '✅' }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Edit Modal -->
    <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg p-6 md:p-8">
          <h2 class="text-xl font-extrabold text-slate-900 mb-5">{{ editUser?.id ? '✏️ แก้ไขผู้ใช้' : '➕ เพิ่มผู้ใช้' }}</h2>
          <div class="space-y-4">
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อ-สกุล</label>
              <input v-model="editUser.full_name" type="text" placeholder="นายสมชาย ใจดี"
                class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200"/>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">อีเมล</label>
              <input v-model="editUser.email" type="email" :disabled="!!editUser.id" placeholder="email@example.com"
                :class="['w-full px-4 py-2.5 border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200', editUser.id ? 'border-slate-100 bg-slate-50 text-slate-400' : 'border-slate-200']"/>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">สิทธิ์</label>
                <select v-model="editUser.role" class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 bg-white">
                  <option value="admin">ผู้ดูแลระบบ</option>
                  <option value="supervisor">ศึกษานิเทศก์</option>
                  <option value="staff">เจ้าหน้าที่</option>
                  <option value="school">ผู้แทนโรงเรียน</option>
                  <option value="teacher">ครู</option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ตำแหน่ง</label>
                <input v-model="editUser.position" type="text" placeholder="ศน.ชพ."
                  class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200"/>
              </div>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">โรงเรียน (ถ้ามี)</label>
              <input v-model="editUser.school_name" type="text" placeholder="โรงเรียน..."
                class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-200"/>
            </div>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input v-model="editUser.is_approved" type="checkbox" class="w-4 h-4 accent-blue-600"/>
                <span class="text-sm font-medium text-slate-700">อนุมัติแล้ว</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input v-model="editUser.is_active" type="checkbox" class="w-4 h-4 accent-blue-600"/>
                <span class="text-sm font-medium text-slate-700">เปิดใช้งาน</span>
              </label>
            </div>
            <!-- Supervision publish permission -->
            <div class="pt-2 border-t border-slate-100">
              <label class="flex items-center gap-2 cursor-pointer">
                <input v-model="editUser.can_publish_supervision" type="checkbox" class="w-4 h-4 accent-indigo-600"/>
                <div>
                  <p class="text-sm font-medium text-slate-700">อนุญาตสร้างและเผยแพร่แบบนิเทศ</p>
                  <p class="text-xs text-slate-400">เปิดให้ staff สามารถเผยแพร่แบบนิเทศได้เอง</p>
                </div>
              </label>
            </div>
            <!-- Document/registrar permission -->
            <div class="pt-2 border-t border-slate-100">
              <label class="flex items-center gap-2 cursor-pointer">
                <input v-model="editUser.can_manage_documents" type="checkbox" class="w-4 h-4 accent-indigo-600"/>
                <div>
                  <p class="text-sm font-medium text-slate-700">สิทธิ์ธุรการ (จัดการงานเอกสาร)</p>
                  <p class="text-xs text-slate-400">เปิดให้มอบหมาย/ติดตาม/ปิดงานเอกสารในระบบธุรการได้</p>
                </div>
              </label>
            </div>
          </div>
          <div class="flex gap-3 mt-6">
            <button @click="saveUser" :disabled="saving"
              class="flex-1 bg-blue-600 hover:bg-blue-700 text-white text-sm font-bold py-3 rounded-xl transition-colors shadow-md">
              {{ saving ? 'กำลังบันทึก...' : '💾 บันทึก' }}
            </button>
            <button @click="showModal = false" class="px-5 py-3 border border-slate-200 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-50 transition-colors">
              ยกเลิก
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
