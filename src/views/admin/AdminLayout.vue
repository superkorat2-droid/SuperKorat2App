<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()

const profile     = ref(null)
const sidebarOpen = ref(true)
const mobileOpen  = ref(false)

// ── Role-based nav groups ───────────────────────────────────────────────────
const allGroups = [
  {
    label: '', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard',          icon: '📊', label: 'แดชบอร์ด',    roles: ['super_admin','admin','supervisor','staff','school','teacher'] },
    ]
  },
  {
    label: 'จัดการระบบ', roles: ['super_admin','admin'],
    items: [
      { to: '/dashboard/users',    icon: '👥', label: 'จัดการผู้ใช้', roles: ['super_admin','admin'] },
      { to: '/dashboard/schools',  icon: '🏫', label: 'ทำเนียบโรงเรียน', roles: ['super_admin','admin'] },
      { to: '/dashboard/settings', icon: '⚙️', label: 'ตั้งค่าเขต',    roles: ['super_admin','admin'] },
    ]
  },
  {
    label: 'จัดการเนื้อหา', roles: ['super_admin','admin','supervisor','staff'],
    items: [
      { to: '/dashboard/banners',  icon: '🖼️', label: 'แบนเนอร์',     roles: ['super_admin','admin','staff'] },
      { to: '/dashboard/news',     icon: '📰', label: 'ข่าวสาร',       roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/pages',    icon: '📄', label: 'หน้าเนื้อหา',   roles: ['super_admin','admin','supervisor'] },
      { to: '/dashboard/documents',icon: '📂', label: 'เอกสาร/ดาวน์โหลด', roles: ['super_admin','admin','supervisor','staff'] },
    ]
  },
  {
    label: 'ผลงานและรายงาน', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard/works',    icon: '🏆', label: 'ผลงาน/นวัตกรรม', roles: ['super_admin','admin','supervisor','teacher','school'] },
      { to: '/dashboard/works-approve', icon: '✅', label: 'อนุมัติผลงาน', roles: ['super_admin','admin','supervisor'] },
    ]
  },
  {
    label: 'บริการ', roles: ['super_admin','admin','supervisor','staff'],
    items: [
      { to: '/dashboard/short-urls', icon: '🔗', label: 'จัดการ URL ย่อ', roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/storage',    icon: '🗄️', label: 'พื้นที่ไฟล์ Storage', roles: ['super_admin','admin','supervisor','staff'] },
    ]
  },
  {
    label: 'โปรไฟล์', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard/profile',  icon: '👤', label: 'ข้อมูลของฉัน',  roles: ['super_admin','admin','supervisor','staff','school','teacher'] },
    ]
  },
]

const navGroups = computed(() => {
  const role = profile.value?.role || 'teacher'
  return allGroups
    .filter(g => g.roles.includes(role))
    .map(g => ({ ...g, items: g.items.filter(i => i.roles.includes(role)) }))
    .filter(g => g.items.length > 0)
})

const roleLabel = computed(() => ({
  super_admin: 'ผู้ดูแลสูงสุด', admin: 'ผู้ดูแลระบบ',
  supervisor: 'ศึกษานิเทศก์', staff: 'เจ้าหน้าที่',
  school: 'ผู้แทนโรงเรียน', teacher: 'ครู'
}[profile.value?.role] || 'ผู้ใช้งาน'))

const roleBadgeColor = computed(() => ({
  super_admin: 'bg-red-100 text-red-700',
  admin:       'bg-purple-100 text-purple-700',
  supervisor:  'bg-blue-100 text-blue-700',
  staff:       'bg-indigo-100 text-indigo-700',
  school:      'bg-emerald-100 text-emerald-700',
  teacher:     'bg-amber-100 text-amber-700',
}[profile.value?.role] || 'bg-slate-100 text-slate-600'))

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) { router.push('/login'); return }
  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  profile.value = data
  // check approved
  if (data && !data.is_approved && data.role === 'teacher') {
    await Swal.fire({ icon: 'warning', title: 'รอการอนุมัติ', text: 'บัญชีของคุณยังรอการอนุมัติจากผู้ดูแลระบบ', confirmButtonColor: '#3b82f6' })
    await supabase.auth.signOut()
    router.push('/')
  }
})

async function handleLogout() {
  const res = await Swal.fire({ title: 'ออกจากระบบ?', icon: 'question', showCancelButton: true, confirmButtonColor: '#3b82f6', cancelButtonColor: '#64748b', confirmButtonText: 'ตกลง', cancelButtonText: 'ยกเลิก', reverseButtons: true })
  if (res.isConfirmed) {
    await supabase.auth.signOut()
    router.push('/')
  }
}

function isActive(path) {
  if (path === '/dashboard') return route.path === '/dashboard'
  return route.path.startsWith(path)
}
</script>

<template>
  <div class="flex min-h-screen bg-slate-100 font-sarabun">

    <!-- ── Sidebar ──────────────────────────────────────────────────── -->
    <aside :class="[
      'fixed inset-y-0 left-0 z-30 flex flex-col bg-slate-800 text-white transition-all duration-300 ease-in-out',
      sidebarOpen ? 'w-64' : 'w-16',
      mobileOpen  ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]">
      <!-- Logo strip -->
      <div class="flex items-center gap-3 px-4 h-16 border-b border-slate-700 flex-shrink-0">
        <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center flex-shrink-0 shadow-md">
          <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
        </div>
        <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100">
          <div v-if="sidebarOpen" class="min-w-0">
            <p class="text-xs font-extrabold text-white leading-tight truncate">ระบบหลังบ้าน</p>
            <p class="text-[10px] text-slate-400 truncate">Admin Dashboard</p>
          </div>
        </Transition>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto py-3 scrollbar-none">
        <template v-for="group in navGroups" :key="group.label">
          <!-- Group label -->
          <div v-if="sidebarOpen && group.label" class="px-4 pt-4 pb-1.5 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
            {{ group.label }}
          </div>
          <div v-else-if="!sidebarOpen && group.label" class="my-2 mx-3 border-t border-slate-700/60"></div>

          <!-- Items -->
          <RouterLink v-for="item in group.items" :key="item.to" :to="item.to"
            @click="mobileOpen = false"
            :class="[
              'flex items-center gap-3 mx-2 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all group',
              isActive(item.to)
                ? 'bg-blue-600 text-white shadow-md'
                : 'text-slate-300 hover:bg-slate-700 hover:text-white'
            ]">
            <span class="text-base flex-shrink-0">{{ item.icon }}</span>
            <span v-if="sidebarOpen" class="truncate">{{ item.label }}</span>
            <!-- Tooltip เมื่อซ่อน sidebar -->
            <div v-else class="absolute left-16 bg-slate-900 text-white text-xs font-bold px-3 py-1.5 rounded-lg shadow-xl opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50">
              {{ item.label }}
            </div>
          </RouterLink>
        </template>
      </nav>

      <!-- User strip -->
      <div class="border-t border-slate-700 p-3 flex-shrink-0">
        <div v-if="profile" :class="['flex items-center gap-3 rounded-xl p-2', sidebarOpen ? 'bg-slate-700/50' : '']">
          <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center text-sm font-bold flex-shrink-0">
            {{ (profile.full_name || 'U')[0] }}
          </div>
          <div v-if="sidebarOpen" class="flex-1 min-w-0">
            <p class="text-xs font-bold text-white truncate">{{ profile.full_name || profile.email }}</p>
            <span :class="['text-[10px] font-bold px-1.5 py-0.5 rounded-md', roleBadgeColor]">{{ roleLabel }}</span>
          </div>
          <button v-if="sidebarOpen" @click="handleLogout" class="text-slate-400 hover:text-red-400 transition-colors flex-shrink-0" title="ออกจากระบบ">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
            </svg>
          </button>
        </div>
      </div>
    </aside>

    <!-- Mobile overlay -->
    <div v-if="mobileOpen" @click="mobileOpen = false" class="fixed inset-0 bg-black/50 z-20 lg:hidden"></div>

    <!-- ── Main area ────────────────────────────────────────────────── -->
    <div :class="['flex-1 flex flex-col transition-all duration-300', sidebarOpen ? 'lg:ml-64' : 'lg:ml-16']">

      <!-- Top bar -->
      <header class="sticky top-0 z-20 h-16 bg-white border-b border-slate-200 shadow-sm flex items-center justify-between px-4 gap-4">
        <div class="flex items-center gap-3">
          <!-- Mobile hamburger -->
          <button @click="mobileOpen = !mobileOpen" class="lg:hidden w-9 h-9 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-500 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
          </button>
          <!-- Sidebar toggle (desktop) -->
          <button @click="sidebarOpen = !sidebarOpen" class="hidden lg:flex w-9 h-9 items-center justify-center rounded-xl hover:bg-slate-100 text-slate-500 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
          </button>
          <!-- Breadcrumb -->
          <div class="flex items-center gap-1.5 text-sm text-slate-500">
            <RouterLink to="/" class="hover:text-blue-600 transition-colors text-xs">🏠 หน้าเว็บ</RouterLink>
            <span class="text-slate-300">/</span>
            <span class="font-semibold text-slate-700 text-xs">{{ $route.meta.title || 'แดชบอร์ด' }}</span>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <!-- View site -->
          <RouterLink to="/" target="_blank"
            class="hidden sm:flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-blue-600 border border-slate-200 hover:border-blue-300 px-3 py-2 rounded-xl transition-all">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
            ดูหน้าเว็บ
          </RouterLink>

          <!-- ⚙️ Settings (super_admin / admin only) -->
          <RouterLink
            v-if="['super_admin','admin'].includes(profile?.role)"
            to="/dashboard/settings"
            title="ตั้งค่าเขต"
            :class="[
              'w-9 h-9 flex items-center justify-center rounded-xl border transition-all text-base',
              isActive('/dashboard/settings')
                ? 'bg-blue-50 border-blue-200 text-blue-600'
                : 'border-slate-200 text-slate-500 hover:bg-slate-50 hover:text-slate-700'
            ]">
            ⚙️
          </RouterLink>

          <!-- 👤 Profile shortcut -->
          <RouterLink
            to="/dashboard/profile"
            title="โปรไฟล์ของฉัน"
            :class="[
              'w-9 h-9 flex items-center justify-center rounded-xl border transition-all text-base',
              isActive('/dashboard/profile')
                ? 'bg-blue-50 border-blue-200 text-blue-600'
                : 'border-slate-200 text-slate-500 hover:bg-slate-50 hover:text-slate-700'
            ]">
            👤
          </RouterLink>

          <!-- User pill -->
          <div v-if="profile" class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2">
            <div class="w-6 h-6 bg-blue-500 rounded-lg flex items-center justify-center text-[10px] font-bold text-white">
              {{ (profile.full_name || 'U')[0] }}
            </div>
            <span class="text-xs font-bold text-slate-700 hidden sm:block max-w-[120px] truncate">{{ profile.full_name || profile.email }}</span>
            <span :class="['text-[10px] font-bold px-1.5 py-0.5 rounded-md hidden sm:block', roleBadgeColor]">{{ roleLabel }}</span>
          </div>
        </div>
      </header>

      <!-- Page content -->
      <main class="flex-1 p-4 md:p-6">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.scrollbar-none::-webkit-scrollbar { display: none; }
.scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>
