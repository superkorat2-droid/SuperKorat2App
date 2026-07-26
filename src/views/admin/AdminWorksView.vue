<script setup>
/**
 * AdminWorksView — รายการผลงาน/นวัตกรรม
 * admin เห็นทุกอัน · คนอื่นเห็นเฉพาะของตัวเอง (RLS คุมอีกชั้นอยู่แล้ว)
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import SvgIcon from '../../components/SvgIcon.vue'
import { WORK_TYPES, WORK_STATUS, workTypeMeta, workStatusMeta, fmtDate, AUTO_APPROVE_ROLES } from '../../composables/useWorks'

const router = useRouter()
const route  = useRoute()
// ใช้ไฟล์เดียวกันทั้งหลังบ้านเขตและ portal โรงเรียน — path ปลายทางคิดจาก route ที่อยู่
// (role school ถูก guard เด้งออกจาก /dashboard จึงต้องอยู่ใต้ /school)
const base = computed(() => route.path.startsWith('/school') ? '/school/works' : '/dashboard/works')
const items   = ref([])
const loading = ref(true)
const myId    = ref(null)
const myRole  = ref('')
const filterType   = ref('all')
const filterStatus = ref('all')
const searchQ      = ref('')
const mineOnly     = ref(false)

const isAdmin    = computed(() => ['super_admin','admin'].includes(myRole.value))
const canSeeAll  = computed(() => [...AUTO_APPROVE_ROLES].includes(myRole.value))
function canEdit(w) { return isAdmin.value || w.owner_id === myId.value }

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || null
  if (user?.id) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase.from('works').select('*').order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}
onMounted(load)

const stats = computed(() => ({
  total:    items.value.length,
  pending:  items.value.filter(w => w.status === 'pending').length,
  approved: items.value.filter(w => w.status === 'approved').length,
  mine:     items.value.filter(w => w.owner_id === myId.value).length,
}))

const filtered = computed(() => {
  const q = searchQ.value.trim().toLowerCase()
  return items.value.filter(w =>
    (filterType.value   === 'all' || w.work_type === filterType.value) &&
    (filterStatus.value === 'all' || w.status === filterStatus.value) &&
    (!mineOnly.value || w.owner_id === myId.value) &&
    (!q || q.split(/\s+/).every(word => (w.title || '').toLowerCase().includes(word)))
  )
})

async function del(w) {
  const res = await Swal.fire({
    title: 'ลบผลงานนี้?', text: w.title, icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('works').delete().eq('id', w.id)
  if (error) return Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message })
  await load()
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="star" class="w-6 h-6 text-primary"/>
          ผลงาน / นวัตกรรม
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">
          <template v-if="canSeeAll">เผยแพร่ผลงานได้ทันที ไม่ต้องรออนุมัติ</template>
          <template v-else>ส่งผลงานเพื่อรอการอนุมัติจากศึกษานิเทศก์</template>
        </p>
      </div>
      <button @click="router.push(`${base}/new`)"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <SvgIcon name="plus" class="w-4 h-4"/> เพิ่มผลงาน
      </button>
    </div>

    <!-- สถิติ -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="glass-tile p-4 text-center"><p class="text-2xl font-extrabold text-slate-800">{{ stats.total }}</p><p class="text-xs text-slate-500">ทั้งหมด</p></div>
      <div class="glass-tile p-4 text-center"><p class="text-2xl font-extrabold text-amber-600">{{ stats.pending }}</p><p class="text-xs text-slate-500">รออนุมัติ</p></div>
      <div class="glass-tile p-4 text-center"><p class="text-2xl font-extrabold text-emerald-600">{{ stats.approved }}</p><p class="text-xs text-slate-500">เผยแพร่แล้ว</p></div>
      <div class="glass-tile p-4 text-center"><p class="text-2xl font-extrabold text-primary">{{ stats.mine }}</p><p class="text-xs text-slate-500">ของฉัน</p></div>
    </div>

    <!-- ตัวกรอง -->
    <div class="flex flex-wrap items-center gap-2">
      <input v-model="searchQ" placeholder="ค้นหาชื่อผลงาน…"
        class="flex-1 min-w-[180px] px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm focus:outline-none focus:border-primary"/>
      <select v-model="filterType" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกประเภท</option>
        <option v-for="t in WORK_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
      </select>
      <select v-model="filterStatus" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกสถานะ</option>
        <option v-for="(s, k) in WORK_STATUS" :key="k" :value="k">{{ s.label }}</option>
      </select>
      <label v-if="canSeeAll" class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none px-2">
        <input type="checkbox" v-model="mineOnly" class="w-4 h-4 rounded accent-[var(--color-primary)]"/> เฉพาะของฉัน
      </label>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
    <div v-else-if="!filtered.length" class="glass-card p-10 text-center text-slate-500">
      <p class="text-3xl mb-2">📚</p>
      <p class="font-medium">ยังไม่มีผลงาน</p>
      <p class="text-xs mt-1">กด "เพิ่มผลงาน" เพื่อเริ่มต้น</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="w in filtered" :key="w.id" class="glass-card p-4">
        <div class="flex flex-wrap items-start gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1.5">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workTypeMeta(w.work_type).bg, workTypeMeta(w.work_type).text]">
                {{ workTypeMeta(w.work_type).icon }} {{ workTypeMeta(w.work_type).label }}
              </span>
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workStatusMeta(w.status).bg, workStatusMeta(w.status).text]">
                {{ workStatusMeta(w.status).label }}
              </span>
              <span class="text-xs text-slate-500">{{ fmtDate(w.created_at) }}</span>
            </div>
            <h3 class="font-bold text-slate-800">{{ w.title }}</h3>
            <p v-if="w.description" class="text-xs text-slate-500 line-clamp-2 mt-0.5">{{ w.description }}</p>
            <p v-if="w.status === 'rejected' && w.reject_reason"
              class="text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-2">
              เหตุผลที่ตีกลับ: {{ w.reject_reason }}
            </p>
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <template v-if="canEdit(w)">
              <button @click="router.push(`${base}/${w.id}/edit`)"
                class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">แก้ไข</button>
              <button @click="del(w)"
                class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">ลบ</button>
            </template>
            <span v-else class="text-[11px] text-slate-400 self-center">ไม่ใช่ผลงานของคุณ</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
