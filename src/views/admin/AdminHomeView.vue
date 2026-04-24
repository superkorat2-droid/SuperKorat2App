<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

const profile   = ref(null)
const stats     = ref({ users: 0, pending: 0, news: 0, works: 0, docs: 0, schools: 0 })
const recentUsers = ref([])
const pendingWorks = ref([])
const loading   = ref(true)

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'สวัสดีตอนเช้า'
  if (h < 17) return 'สวัสดีตอนบ่าย'
  return 'สวัสดีตอนเย็น'
})

const roleLabel = computed(() => ({
  super_admin: 'ผู้ดูแลสูงสุด', admin: 'ผู้ดูแลระบบ',
  supervisor: 'ศึกษานิเทศก์', staff: 'เจ้าหน้าที่',
  school: 'ผู้แทนโรงเรียน', teacher: 'ครู'
}[profile.value?.role] || ''))

const isAdminOrAbove = computed(() => ['super_admin','admin'].includes(profile.value?.role))
const isSupervisorOrAbove = computed(() => ['super_admin','admin','supervisor'].includes(profile.value?.role))

const statCards = computed(() => {
  const cards = []
  if (isAdminOrAbove.value) {
    cards.push({ icon: '👥', label: 'ผู้ใช้ทั้งหมด', value: stats.value.users, color: 'bg-blue-50 text-blue-600', to: '/dashboard/users' })
    cards.push({ icon: '⏳', label: 'รออนุมัติ', value: stats.value.pending, color: 'bg-amber-50 text-amber-600', to: '/dashboard/users?tab=pending' })
    cards.push({ icon: '🏫', label: 'โรงเรียน', value: stats.value.schools, color: 'bg-emerald-50 text-emerald-600', to: '/dashboard/schools' })
  }
  if (isSupervisorOrAbove.value) {
    cards.push({ icon: '📰', label: 'ข่าวสาร', value: stats.value.news, color: 'bg-violet-50 text-violet-600', to: '/dashboard/news' })
    cards.push({ icon: '🏆', label: 'ผลงาน', value: stats.value.works, color: 'bg-rose-50 text-rose-600', to: '/dashboard/works' })
    cards.push({ icon: '📂', label: 'เอกสาร', value: stats.value.docs, color: 'bg-indigo-50 text-indigo-600', to: '/dashboard/documents' })
  }
  return cards
})

const quickActions = computed(() => {
  const actions = []
  if (isSupervisorOrAbove.value) {
    actions.push({ icon: '➕', label: 'เพิ่มข่าวสาร', to: '/dashboard/news?action=new', color: 'bg-blue-600 text-white hover:bg-blue-700' })
    actions.push({ icon: '📄', label: 'แก้ไขหน้าเนื้อหา', to: '/dashboard/pages', color: 'bg-indigo-600 text-white hover:bg-indigo-700' })
    actions.push({ icon: '⬆️', label: 'อัปโหลดเอกสาร', to: '/dashboard/documents?action=new', color: 'bg-violet-600 text-white hover:bg-violet-700' })
    actions.push({ icon: '🔗', label: 'สร้าง URL ย่อ', to: '/dashboard/short-urls', color: 'bg-emerald-600 text-white hover:bg-emerald-700' })
  }
  if (isAdminOrAbove.value) {
    actions.push({ icon: '⚙️', label: 'ตั้งค่าเขต', to: '/dashboard/settings', color: 'bg-slate-700 text-white hover:bg-slate-800' })
  }
  // ทุก role
  actions.push({ icon: '👤', label: 'แก้ไขโปรไฟล์', to: '/dashboard/profile', color: 'bg-white text-slate-700 border border-slate-200 hover:bg-slate-50' })
  return actions
})

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return
  const { data: p } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  profile.value = p

  // load stats in parallel
  const [
    { count: userCount },
    { count: pendingCount },
    { count: schoolCount },
    { count: newsCount },
    { count: workCount },
    { count: docCount },
    { data: recentU },
    { data: pendingW },
  ] = await Promise.all([
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('is_approved', false).eq('role', 'teacher'),
    supabase.from('schools').select('*', { count: 'exact', head: true }),
    supabase.from('news').select('*', { count: 'exact', head: true }),
    supabase.from('works').select('*', { count: 'exact', head: true }),
    supabase.from('documents').select('*', { count: 'exact', head: true }),
    supabase.from('profiles').select('id,full_name,email,role,created_at').order('created_at', { ascending: false }).limit(5),
    supabase.from('works').select('id,title,owner_id,created_at,profiles(full_name)').eq('status','pending').order('created_at', { ascending: false }).limit(5),
  ])

  stats.value = { users: userCount||0, pending: pendingCount||0, schools: schoolCount||0, news: newsCount||0, works: workCount||0, docs: docCount||0 }
  recentUsers.value  = recentU  || []
  pendingWorks.value = pendingW || []
  loading.value = false
})

const roleColor = { super_admin:'bg-red-100 text-red-700', admin:'bg-purple-100 text-purple-700', supervisor:'bg-blue-100 text-blue-700', staff:'bg-indigo-100 text-indigo-700', school:'bg-emerald-100 text-emerald-700', teacher:'bg-amber-100 text-amber-700' }
const roleNameTh = { super_admin:'ผู้ดูแลสูงสุด', admin:'ผู้ดูแลระบบ', supervisor:'ศน.', staff:'เจ้าหน้าที่', school:'โรงเรียน', teacher:'ครู' }

function timeAgo(iso) {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1)  return 'เมื่อกี้'
  if (m < 60) return `${m} นาทีที่แล้ว`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h} ชั่วโมงที่แล้ว`
  return `${Math.floor(h/24)} วันที่แล้ว`
}
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- Greeting -->
    <div class="gradient-primary rounded-3xl p-6 md:p-8 text-white relative overflow-hidden">
      <div class="absolute inset-0 opacity-10">
        <svg width="100%" height="100%"><defs><pattern id="d" width="30" height="30" patternUnits="userSpaceOnUse"><circle cx="15" cy="15" r="1" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#d)"/></svg>
      </div>
      <div class="relative">
        <p class="text-blue-200 text-sm mb-1">{{ greeting }} 👋</p>
        <h1 class="text-2xl md:text-3xl font-extrabold mb-1">{{ profile?.full_name || 'ผู้ใช้งาน' }}</h1>
        <p class="text-blue-200 text-sm">{{ roleLabel }} · ระบบหลังบ้านกลุ่มนิเทศฯ</p>
      </div>
    </div>

    <!-- Stat cards -->
    <div v-if="!loading && statCards.length" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      <RouterLink v-for="card in statCards" :key="card.label" :to="card.to"
        :class="['rounded-2xl border border-white p-5 text-center shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all', card.color]">
        <div class="text-3xl mb-1">{{ card.icon }}</div>
        <div class="text-2xl font-extrabold">{{ loading ? '—' : card.value.toLocaleString() }}</div>
        <div class="text-xs font-medium mt-1 opacity-80">{{ card.label }}</div>
      </RouterLink>
    </div>

    <!-- Quick actions -->
    <div>
      <h2 class="text-sm font-bold text-slate-500 uppercase tracking-widest mb-3">ทำรายการด่วน</h2>
      <div class="flex flex-wrap gap-2">
        <RouterLink v-for="a in quickActions" :key="a.label" :to="a.to"
          :class="['flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-bold transition-all shadow-sm', a.color]">
          {{ a.icon }} {{ a.label }}
        </RouterLink>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">

      <!-- Recent users (admin only) -->
      <div v-if="isAdminOrAbove" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-extrabold text-slate-800">👥 ผู้ใช้ล่าสุด</h2>
          <RouterLink to="/dashboard/users" class="text-xs font-bold text-blue-600 hover:underline">ดูทั้งหมด →</RouterLink>
        </div>
        <div v-if="loading" class="space-y-3">
          <div v-for="i in 4" :key="i" class="h-10 bg-slate-100 rounded-xl animate-pulse"></div>
        </div>
        <div v-else class="space-y-2">
          <div v-for="u in recentUsers" :key="u.id" class="flex items-center gap-3 p-2 hover:bg-slate-50 rounded-xl transition-colors">
            <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center text-sm font-bold text-blue-600 flex-shrink-0">
              {{ (u.full_name || u.email || 'U')[0].toUpperCase() }}
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-bold text-slate-800 truncate">{{ u.full_name || u.email }}</p>
              <p class="text-[10px] text-slate-400">{{ timeAgo(u.created_at) }}</p>
            </div>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0', roleColor[u.role] || 'bg-slate-100 text-slate-500']">
              {{ roleNameTh[u.role] || u.role }}
            </span>
          </div>
          <div v-if="recentUsers.length === 0" class="text-center py-6 text-slate-400 text-sm">ยังไม่มีผู้ใช้</div>
        </div>
      </div>

      <!-- Pending works -->
      <div v-if="isSupervisorOrAbove" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-extrabold text-slate-800">⏳ ผลงานรออนุมัติ</h2>
          <RouterLink to="/dashboard/works-approve" class="text-xs font-bold text-blue-600 hover:underline">ดูทั้งหมด →</RouterLink>
        </div>
        <div v-if="loading" class="space-y-3">
          <div v-for="i in 4" :key="i" class="h-10 bg-slate-100 rounded-xl animate-pulse"></div>
        </div>
        <div v-else class="space-y-2">
          <div v-for="w in pendingWorks" :key="w.id" class="flex items-start gap-3 p-3 bg-amber-50 border border-amber-100 rounded-xl hover:border-amber-300 transition-colors">
            <span class="text-xl flex-shrink-0">🏆</span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-bold text-slate-800 line-clamp-1">{{ w.title }}</p>
              <p class="text-[10px] text-slate-500">{{ w.profiles?.full_name || '—' }} · {{ timeAgo(w.created_at) }}</p>
            </div>
            <RouterLink :to="`/dashboard/works-approve`"
              class="text-[10px] font-bold text-amber-700 bg-amber-100 hover:bg-amber-200 px-2 py-1 rounded-lg transition-colors flex-shrink-0">
              ตรวจสอบ
            </RouterLink>
          </div>
          <div v-if="pendingWorks.length === 0" class="text-center py-6 text-slate-400 text-sm">✅ ไม่มีผลงานรออนุมัติ</div>
        </div>
      </div>

      <!-- My profile quick -->
      <div v-if="!isAdminOrAbove && !isSupervisorOrAbove" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <h2 class="font-extrabold text-slate-800 mb-4">👤 ข้อมูลของฉัน</h2>
        <div v-if="profile" class="space-y-3">
          <div class="flex gap-3"><span class="text-slate-400 text-sm w-24">ชื่อ</span><span class="text-sm font-bold text-slate-800">{{ profile.full_name || '—' }}</span></div>
          <div class="flex gap-3"><span class="text-slate-400 text-sm w-24">อีเมล</span><span class="text-sm text-slate-600 break-all">{{ profile.email }}</span></div>
          <div class="flex gap-3"><span class="text-slate-400 text-sm w-24">ตำแหน่ง</span><span class="text-sm text-slate-600">{{ profile.position || '—' }}</span></div>
          <div class="flex gap-3"><span class="text-slate-400 text-sm w-24">สิทธิ์</span><span :class="['text-xs font-bold px-2 py-0.5 rounded-full', roleColor[profile.role]]">{{ roleNameTh[profile.role] }}</span></div>
        </div>
        <RouterLink to="/dashboard/profile" class="mt-4 inline-block text-sm font-bold text-blue-600 hover:underline">แก้ไขโปรไฟล์ →</RouterLink>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
