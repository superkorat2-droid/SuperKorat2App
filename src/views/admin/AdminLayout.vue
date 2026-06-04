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

// ── SVG icon paths (heroicons outline 24px, stroke-width 1.5) ──────────────
const NAV_ICONS = {
  dashboard:      'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z',
  users:          'M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z',
  schools:        'M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z',
  settings:       'M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
  homeSections:   'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z',
  banners:        'M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z',
  globe:          'M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418',
  supervision:    'M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z',
  news:           'M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5M6 7.5h3v3H6v-3z',
  pages:          'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z',
  documents:      'M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 9v.776',
  works:          'M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M7.73 9.728a6.726 6.726 0 002.748 1.35m8.272-6.842V4.5c0 2.108-.966 3.99-2.48 5.228m2.48-5.492a46.32 46.32 0 012.916.52 6.003 6.003 0 01-5.395 4.972m0 0a6.726 6.726 0 01-2.749 1.35m0 0a6.772 6.772 0 01-3.044 0',
  approve:        'M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-.39 3.72 3.745 3.745 0 01-3.72.39 3.745 3.745 0 01-3.068 1.593 3.746 3.746 0 01-3.068-1.593 3.745 3.745 0 01-3.72-.39 3.745 3.745 0 01-.39-3.72A3.745 3.745 0 013 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 01.39-3.72 3.745 3.745 0 013.72-.39A3.745 3.745 0 0112 3c1.268 0 2.39.63 3.068 1.593a3.745 3.745 0 013.72.39 3.746 3.746 0 01.39 3.72A3.745 3.745 0 0121 12z',
  urls:           'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244',
  storage:        'M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 5.625c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125',
  students:       'M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197',
  enrollment:     'M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z',
  profile:        'M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z',
}

// ── Route → icon key mapping ────────────────────────────────────
const ICON_MAP = {
  '/dashboard':              'dashboard',
  '/dashboard/users':        'users',
  '/dashboard/schools':      'schools',
  '/dashboard/students':     'students',
  '/dashboard/enrollment':   'enrollment',
  '/dashboard/settings':     'settings',
  '/dashboard/home-sections':'homeSections',
  '/dashboard/banners':      'banners',
  '/dashboard/services':     'globe',
  '/dashboard/supervision':  'supervision',
  '/dashboard/news':         'news',
  '/dashboard/pages':        'pages',
  '/dashboard/documents':    'documents',
  '/dashboard/works':        'works',
  '/dashboard/works-approve':'approve',
  '/dashboard/short-urls':   'urls',
  '/dashboard/storage':      'storage',
  '/dashboard/profile':      'profile',
}

// ── Role-based nav groups ───────────────────────────────────────
const allGroups = [
  {
    label: '', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard',          label: 'แดชบอร์ด',          roles: ['super_admin','admin','supervisor','staff','school','teacher'] },
    ]
  },
  {
    label: 'จัดการระบบ', roles: ['super_admin','admin'],
    items: [
      { to: '/dashboard/users',     label: 'จัดการผู้ใช้',   roles: ['super_admin','admin'] },
      { to: '/dashboard/personnel', label: 'จัดการบุคลากร', roles: ['super_admin','admin'] },
      { to: '/dashboard/schools',    label: 'ทำเนียบโรงเรียน',  roles: ['super_admin','admin'] },
      { to: '/dashboard/principals',  label: 'ผู้บริหารโรงเรียน', roles: ['super_admin','admin'] },
      { to: '/dashboard/newsletters', label: 'จดหมายข่าว',         roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/media',       label: 'คลังสื่อการเรียนรู้', roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/dmc',        label: 'รอบ DMC นักเรียน', roles: ['super_admin','admin'] },
      { to: '/dashboard/students',   label: 'ข้อมูลนักเรียน',   roles: ['super_admin','admin','supervisor'] },
      { to: '/dashboard/enrollment', label: 'สถิติย้อนหลัง',    roles: ['super_admin','admin','supervisor'] },
      { to: '/dashboard/settings', label: 'ตั้งค่าเขต',         roles: ['super_admin','admin'] },
    ]
  },
  {
    label: 'จัดการเนื้อหา', roles: ['super_admin','admin','supervisor','staff'],
    items: [
      { to: '/dashboard/home-sections', label: 'Section หน้าแรก', roles: ['super_admin','admin'] },
      { to: '/dashboard/banners',   label: 'แบนเนอร์',        roles: ['super_admin','admin','staff'] },
      { to: '/dashboard/services',  label: 'บริการออนไลน์',  roles: ['super_admin','admin'] },
      { to: '/dashboard/news',      label: 'ข่าวสาร',            roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/pages',     label: 'หน้าเนื้อหา',        roles: ['super_admin','admin','supervisor'] },
      { to: '/dashboard/documents',   label: 'เอกสาร/ดาวน์โหลด',  roles: ['super_admin','admin','supervisor','staff'] },
    ]
  },
  {
    label: 'นิเทศติดตาม', roles: ['super_admin','admin','supervisor','staff'],
    items: [
      { to: '/dashboard/supervision', label: 'แบบนิเทศติดตาม', roles: ['super_admin','admin','supervisor','staff'] },
    ]
  },
  {
    label: 'ผลงานและรายงาน', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard/works',         label: 'ผลงาน/นวัตกรรม', roles: ['super_admin','admin','supervisor','teacher','school'] },
      { to: '/dashboard/works-approve', label: 'อนุมัติผลงาน',   roles: ['super_admin','admin','supervisor'] },
    ]
  },
  {
    label: 'บริการ', roles: ['super_admin','admin','supervisor','staff'],
    items: [
      { to: '/dashboard/short-urls', label: 'จัดการ URL ย่อ',      roles: ['super_admin','admin','supervisor','staff'] },
      { to: '/dashboard/storage',    label: 'พื้นที่ไฟล์ Storage', roles: ['super_admin','admin','supervisor','staff'] },
    ]
  },
  {
    label: 'โปรไฟล์', roles: ['super_admin','admin','supervisor','staff','school','teacher'],
    items: [
      { to: '/dashboard/profile', label: 'ข้อมูลของฉัน', roles: ['super_admin','admin','supervisor','staff','school','teacher'] },
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
  super_admin: 'bg-red-500/20 text-red-300',
  admin:       'bg-violet-500/20 text-violet-300',
  supervisor:  'bg-sky-500/20 text-sky-300',
  staff:       'bg-indigo-500/20 text-indigo-300',
  school:      'bg-emerald-500/20 text-emerald-300',
  teacher:     'bg-amber-500/20 text-amber-300',
}[profile.value?.role] || 'bg-white/10 text-white/60'))

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) { router.push('/login'); return }
  const { data } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  profile.value = data
  if (data && !data.is_approved && data.role === 'teacher') {
    await Swal.fire({ icon: 'warning', title: 'รอการอนุมัติ', text: 'บัญชีของคุณยังรอการอนุมัติจากผู้ดูแลระบบ', confirmButtonColor: '#3b82f6' })
    await supabase.auth.signOut()
    router.push('/')
  }
})

async function handleLogout() {
  const res = await Swal.fire({
    title: 'ออกจากระบบ?', icon: 'question', showCancelButton: true,
    confirmButtonColor: '#ef4444', cancelButtonColor: '#64748b',
    confirmButtonText: 'ตกลง', cancelButtonText: 'ยกเลิก', reverseButtons: true
  })
  if (res.isConfirmed) {
    await supabase.auth.signOut()
    router.push('/')
  }
}

function isActive(path) {
  if (path === '/dashboard') return route.path === '/dashboard'
  return route.path.startsWith(path)
}

function iconKey(to) {
  return ICON_MAP[to] || 'dashboard'
}
</script>

<template>
  <div class="flex min-h-screen bg-slate-100 font-sarabun">

    <!-- ── Sidebar ────────────────────────────────────────────────── -->
    <aside :class="[
      'fixed inset-y-0 left-0 z-30 flex flex-col transition-all duration-300 ease-in-out',
      'bg-[#0c1220] text-white',
      sidebarOpen ? 'w-64' : 'w-16',
      mobileOpen  ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
    ]">

      <!-- Logo strip -->
      <div class="flex items-center gap-3 px-4 h-16 border-b border-white/5 flex-shrink-0">
        <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 shadow-md"
          style="background-color: var(--color-secondary)">
          <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round"
              d="M9 4.5v15m6-15v15m-10.875 0h15.75c.621 0 1.125-.504 1.125-1.125V5.625c0-.621-.504-1.125-1.125-1.125H4.125C3.504 4.5 3 5.004 3 5.625v12.75c0 .621.504 1.125 1.125 1.125z"/>
          </svg>
        </div>
        <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100">
          <div v-if="sidebarOpen" class="min-w-0">
            <p class="text-xs font-extrabold text-white leading-tight truncate">ระบบหลังบ้าน</p>
            <p class="text-[10px] text-white/50 truncate">Admin Dashboard</p>
          </div>
        </Transition>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto py-3 scrollbar-none">
        <template v-for="group in navGroups" :key="group.label">
          <!-- Group label -->
          <div v-if="sidebarOpen && group.label"
            class="px-4 pt-4 pb-1.5 text-[10px] font-bold text-white/40 uppercase tracking-widest">
            {{ group.label }}
          </div>
          <div v-else-if="!sidebarOpen && group.label"
            class="my-2 mx-3 border-t border-white/10"></div>

          <!-- Nav items -->
          <RouterLink v-for="item in group.items" :key="item.to" :to="item.to"
            @click="mobileOpen = false"
            :class="[
              'relative flex items-center gap-3 mx-2 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all group',
              isActive(item.to)
                ? 'bg-white/10 text-white'
                : 'text-white/70 hover:bg-white/10 hover:text-white'
            ]">
            <!-- Left accent border when active -->
            <span v-if="isActive(item.to)"
              class="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 rounded-r-full"
              style="background-color: var(--color-secondary)"></span>

            <!-- SVG icon -->
            <svg class="w-4.5 h-4.5 flex-shrink-0 w-[18px] h-[18px]"
              fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="NAV_ICONS[iconKey(item.to)]"/>
            </svg>

            <span v-if="sidebarOpen" class="truncate">{{ item.label }}</span>

            <!-- Tooltip when sidebar collapsed -->
            <div v-else
              class="absolute left-14 bg-slate-900 text-white text-xs font-bold px-3 py-1.5 rounded-lg shadow-xl opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50 ring-1 ring-white/10">
              {{ item.label }}
            </div>
          </RouterLink>
        </template>
      </nav>

      <!-- User strip -->
      <div class="border-t border-white/10 p-3 flex-shrink-0">
        <div v-if="profile"
          :class="['flex items-center gap-3 rounded-xl p-2', sidebarOpen ? 'bg-white/5' : '']">
          <div class="w-8 h-8 rounded-lg flex items-center justify-center text-xs font-extrabold flex-shrink-0 text-white"
            style="background-color: var(--color-secondary)">
            {{ (profile.full_name || 'U')[0].toUpperCase() }}
          </div>
          <div v-if="sidebarOpen" class="flex-1 min-w-0">
            <p class="text-xs font-bold text-white/80 truncate">{{ profile.full_name || profile.email }}</p>
            <span :class="['text-[10px] font-bold px-1.5 py-0.5 rounded-md', roleBadgeColor]">{{ roleLabel }}</span>
          </div>
          <button v-if="sidebarOpen" @click="handleLogout"
            class="text-white/50 hover:text-red-400 transition-colors flex-shrink-0" title="ออกจากระบบ">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round"
                d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"/>
            </svg>
          </button>
        </div>
      </div>
    </aside>

    <!-- Mobile overlay -->
    <div v-if="mobileOpen" @click="mobileOpen = false"
      class="fixed inset-0 bg-black/60 z-20 lg:hidden backdrop-blur-sm"></div>

    <!-- ── Main area ──────────────────────────────────────────────── -->
    <div :class="['flex-1 flex flex-col transition-all duration-300', sidebarOpen ? 'lg:ml-64' : 'lg:ml-16']">

      <!-- Top bar -->
      <header class="sticky top-0 z-20 h-16 bg-white border-b border-slate-200 shadow-sm flex items-center justify-between px-4 gap-4">
        <div class="flex items-center gap-3">
          <!-- Mobile hamburger -->
          <button @click="mobileOpen = !mobileOpen"
            class="lg:hidden w-9 h-9 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-500 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>
            </svg>
          </button>
          <!-- Sidebar toggle desktop -->
          <button @click="sidebarOpen = !sidebarOpen"
            class="hidden lg:flex w-9 h-9 items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>
            </svg>
          </button>
          <!-- Breadcrumb -->
          <div class="flex items-center gap-1.5 text-xs text-slate-400">
            <RouterLink to="/" class="hover:text-primary transition-colors flex items-center gap-1">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"/>
              </svg>
              หน้าเว็บ
            </RouterLink>
            <span class="text-slate-200">/</span>
            <span class="font-semibold text-slate-700">{{ $route.meta.title || 'แดชบอร์ด' }}</span>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <!-- View site -->
          <RouterLink to="/"
            class="hidden sm:flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-primary border border-slate-200 hover:border-primary/30 px-3 py-2 rounded-xl transition-all">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>
            </svg>
            ดูหน้าเว็บ
          </RouterLink>

          <!-- Settings shortcut -->
          <RouterLink v-if="['super_admin','admin'].includes(profile?.role)"
            to="/dashboard/settings" title="ตั้งค่าเขต"
            :class="[
              'w-9 h-9 flex items-center justify-center rounded-xl border transition-all',
              isActive('/dashboard/settings')
                ? 'bg-primary-light border-primary/20 text-primary'
                : 'border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-slate-600'
            ]">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="NAV_ICONS.settings"/>
            </svg>
          </RouterLink>

          <!-- Profile shortcut -->
          <RouterLink to="/dashboard/profile" title="โปรไฟล์ของฉัน"
            :class="[
              'w-9 h-9 flex items-center justify-center rounded-xl border transition-all',
              isActive('/dashboard/profile')
                ? 'bg-primary-light border-primary/20 text-primary'
                : 'border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-slate-600'
            ]">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="NAV_ICONS.profile"/>
            </svg>
          </RouterLink>

          <!-- User pill -->
          <div v-if="profile"
            class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2">
            <div class="w-6 h-6 rounded-lg flex items-center justify-center text-[10px] font-extrabold text-white flex-shrink-0"
              style="background-color: var(--color-secondary)">
              {{ (profile.full_name || 'U')[0].toUpperCase() }}
            </div>
            <span class="text-xs font-bold text-slate-700 hidden sm:block max-w-[120px] truncate">
              {{ profile.full_name || profile.email }}
            </span>
            <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-md hidden sm:block bg-slate-100 text-slate-500">
              {{ roleLabel }}
            </span>
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
