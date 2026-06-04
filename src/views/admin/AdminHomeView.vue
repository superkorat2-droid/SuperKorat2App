<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

// SVG paths สำหรับ icons
const I = {
  users:    'M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z',
  clock:    'M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z',
  school:   'M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5',
  news:     'M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5',
  trophy:   'M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 002.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 012.916.52 6.003 6.003 0 01-5.395 4.972m0 0a6.726 6.726 0 01-2.749 1.35m0 0a6.772 6.772 0 01-3.044 0',
  folder:   'M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z',
  plus:     'M12 4.5v15m7.5-7.5h-15',
  document: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z',
  upload:   'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5',
  link:     'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244',
  settings: 'M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
  user:     'M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z',
}

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
    cards.push({ icon: 'users',  label: 'ผู้ใช้ทั้งหมด', value: stats.value.users,   color: 'bg-blue-50 text-blue-600',     to: '/dashboard/users' })
    cards.push({ icon: 'clock',  label: 'รออนุมัติ',     value: stats.value.pending,  color: 'bg-amber-50 text-amber-600',   to: '/dashboard/users?tab=pending' })
    cards.push({ icon: 'school', label: 'โรงเรียน',      value: stats.value.schools,  color: 'bg-emerald-50 text-emerald-600', to: '/dashboard/schools' })
  }
  if (isSupervisorOrAbove.value) {
    cards.push({ icon: 'news',   label: 'ข่าวสาร', value: stats.value.news,  color: 'bg-violet-50 text-violet-600', to: '/dashboard/news' })
    cards.push({ icon: 'trophy', label: 'ผลงาน',   value: stats.value.works, color: 'bg-rose-50 text-rose-600',     to: '/dashboard/works' })
    cards.push({ icon: 'folder', label: 'เอกสาร',  value: stats.value.docs,  color: 'bg-indigo-50 text-indigo-600', to: '/dashboard/documents' })
  }
  return cards
})

const quickActions = computed(() => {
  const actions = []
  if (isSupervisorOrAbove.value) {
    actions.push({ icon: 'plus',     label: 'เพิ่มข่าวสาร',     to: '/dashboard/news?action=new',   color: 'bg-blue-600 text-white hover:bg-blue-700' })
    actions.push({ icon: 'document', label: 'แก้ไขหน้าเนื้อหา', to: '/dashboard/pages',              color: 'bg-indigo-600 text-white hover:bg-indigo-700' })
    actions.push({ icon: 'upload',   label: 'อัปโหลดเอกสาร',    to: '/dashboard/documents?action=new', color: 'bg-violet-600 text-white hover:bg-violet-700' })
    actions.push({ icon: 'link',     label: 'สร้าง URL ย่อ',     to: '/dashboard/short-urls',         color: 'bg-emerald-600 text-white hover:bg-emerald-700' })
  }
  if (isAdminOrAbove.value) {
    actions.push({ icon: 'settings', label: 'ตั้งค่าเขต', to: '/dashboard/settings', color: 'bg-slate-700 text-white hover:bg-slate-800' })
  }
  actions.push({ icon: 'user', label: 'แก้ไขโปรไฟล์', to: '/dashboard/profile', color: 'bg-white text-slate-700 border border-slate-200 hover:bg-slate-50' })
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
        <p class="text-blue-200 text-sm mb-1">{{ greeting }}</p>
        <h1 class="text-2xl md:text-3xl font-extrabold mb-1">{{ profile?.full_name || 'ผู้ใช้งาน' }}</h1>
        <p class="text-blue-200 text-sm">{{ roleLabel }} · ระบบหลังบ้านกลุ่มนิเทศฯ</p>
      </div>
    </div>

    <!-- Stat cards -->
    <div v-if="!loading && statCards.length" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      <RouterLink v-for="card in statCards" :key="card.label" :to="card.to"
        :class="['rounded-2xl border border-white p-5 text-center shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all', card.color]">
        <div class="flex justify-center mb-2">
          <svg class="w-7 h-7" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" :d="I[card.icon]"/>
          </svg>
        </div>
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
          <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" :d="I[a.icon]"/>
          </svg>
          {{ a.label }}
        </RouterLink>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">

      <!-- Recent users (admin only) -->
      <div v-if="isAdminOrAbove" class="bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-extrabold text-slate-800 flex items-center gap-2">
            <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" :d="I.users"/></svg>
            ผู้ใช้ล่าสุด
          </h2>
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
          <h2 class="font-extrabold text-slate-800 flex items-center gap-2">
            <svg class="w-4 h-4 text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" :d="I.clock"/></svg>
            ผลงานรออนุมัติ
          </h2>
          <RouterLink to="/dashboard/works-approve" class="text-xs font-bold text-blue-600 hover:underline">ดูทั้งหมด →</RouterLink>
        </div>
        <div v-if="loading" class="space-y-3">
          <div v-for="i in 4" :key="i" class="h-10 bg-slate-100 rounded-xl animate-pulse"></div>
        </div>
        <div v-else class="space-y-2">
          <div v-for="w in pendingWorks" :key="w.id" class="flex items-start gap-3 p-3 bg-amber-50 border border-amber-100 rounded-xl hover:border-amber-300 transition-colors">
            <svg class="w-5 h-5 flex-shrink-0 text-rose-400" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" :d="I.trophy"/></svg>
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
