<script setup>
import { ref, onMounted, computed } from 'vue'
import { iconPath, isIconKey } from '../../composables/useIcons.js'
const setTimeout = window.setTimeout
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { useNavPages } from '../../composables/useNavPages'
import { useAreaConfig } from '../../composables/useAreaConfig'
import IconPicker from '../../components/IconPicker.vue'
import Swal from 'sweetalert2'

const router = useRouter()
const { fetchNavPages, DEFAULT_GROUPS } = useNavPages()
const { config, fetchConfig, updateConfig } = useAreaConfig()

const myProfile = ref(null)
const isAdmin   = computed(() => ['super_admin','admin'].includes(myProfile.value?.role))

const pages    = ref([])
const loading  = ref(true)
const saving   = ref(false)
const savingGroups = ref(false)

// nav_groups state (local copy for editing)
const navGroups = ref([])

const TYPE_LABELS  = { cms:'CMS', system:'ระบบ', link:'ลิงค์' }

// routes ทั้งหมดที่มีใน system
const SYSTEM_ROUTES = [
  { route: '/personnel',      label: 'ทำเนียบบุคลากร' },
  { route: '/site-info',      label: 'ข้อมูลสารสนเทศ' },
  { route: '/schools',        label: 'ทำเนียบโรงเรียน' },
  { route: '/news',           label: 'ข่าวสาร' },
  { route: '/download',       label: 'ดาวน์โหลดเอกสาร' },
  { route: '/url-short',      label: 'ย่อลิงค์' },
  { route: '/qrcode',         label: 'สร้าง QR Code' },
  { route: '/contact',        label: 'ติดต่อสอบถาม' },
  { route: '/nithet',         label: 'กลุ่มนิเทศ' },
  { route: '/school',         label: 'Portal โรงเรียน' },
]

const showRouteList = ref(false)
const filteredRoutes = computed(() => {
  const q = (form.value.system_route || '').toLowerCase()
  if (!q) return SYSTEM_ROUTES
  return SYSTEM_ROUTES.filter(r => r.route.includes(q) || r.label.includes(q))
})
const TYPE_COLORS  = { cms:'bg-blue-100 text-blue-700', system:'bg-emerald-100 text-emerald-700', link:'bg-amber-100 text-amber-700' }

// computed GROUP_LABELS จาก navGroups
const GROUP_LABELS = computed(() => {
  const m = {}
  navGroups.value.forEach(g => { m[g.key] = g.label })
  return m
})

function moveGroupUp(i) {
  if (i === 0) return
  ;[navGroups.value[i - 1], navGroups.value[i]] = [navGroups.value[i], navGroups.value[i - 1]]
  navGroups.value.forEach((g, idx) => g.order = idx + 1)
}
function moveGroupDown(i) {
  if (i === navGroups.value.length - 1) return
  ;[navGroups.value[i], navGroups.value[i + 1]] = [navGroups.value[i + 1], navGroups.value[i]]
  navGroups.value.forEach((g, idx) => g.order = idx + 1)
}

function addGroup() {
  const label = '(กลุ่มใหม่)'
  const key   = 'group_' + Date.now()
  navGroups.value.push({ key, label, visible: true, order: navGroups.value.length + 1 })
}

function removeGroup(i) {
  const g = navGroups.value[i]
  const hasPages = pages.value.some(p => p.nav_group === g.key)
  if (hasPages) {
    Swal.fire({ icon: 'warning', title: 'ลบไม่ได้', text: 'กลุ่มนี้มีหน้าอยู่ ย้ายหน้าออกก่อน', confirmButtonColor: '#3b82f6' })
    return
  }
  navGroups.value.splice(i, 1)
  navGroups.value.forEach((g, idx) => g.order = idx + 1)
}

async function saveGroups() {
  savingGroups.value = true
  await updateConfig({ nav_groups: navGroups.value })
  savingGroups.value = false
  fetchNavPages(true)
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 800 })
}

const showForm = ref(false)
const form     = ref(newForm())

function newForm() {
  return { id: null, slug: '', title: '', nav_icon: 'document', nav_group: 'general',
           nav_order: 99, page_type: 'cms', system_route: '', show_in_nav: false, is_published: false }
}

const grouped = computed(() => {
  // แสดงทุก group เสมอ แม้ยังไม่มีหน้า
  return navGroups.value.map(g => ({
    key:   g.key,
    label: g.label,
    items: pages.value
      .filter(p => p.nav_group === g.key)
      .sort((a,b) => a.nav_order - b.nav_order),
  }))
})

async function load() {
  loading.value = true

  // โหลด profile ก่อน
  if (!myProfile.value) {
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      const { data: p } = await supabase.from('profiles').select('id,role').eq('id', user.id).single()
      myProfile.value = p
    }
  }

  const [{ data: pagesData }] = await Promise.all([
    supabase.from('pages').select('*').order('nav_group').order('nav_order'),
    fetchConfig(),
  ])

  // supervisor เห็นเฉพาะหน้าที่ได้รับมอบหมาย
  const allPages = pagesData || []
  pages.value = isAdmin.value
    ? allPages
    : allPages.filter(p => (p.assigned_users || []).includes(myProfile.value?.id))

  navGroups.value = (config.value?.nav_groups || DEFAULT_GROUPS).map(g => ({ ...g }))
  loading.value   = false
}

onMounted(load)

function openCreate() { form.value = newForm(); showForm.value = true }
function openEdit(p)  { form.value = { ...p };   showForm.value = true }

async function save() {
  if (!form.value.title.trim()) return
  if (!form.value.slug.trim()) {
    const raw = form.value.title.trim().toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\w-]/g, '')
      .replace(/^-+|-+$/g, '') // ตัด - นำหน้า/ท้าย
    // ถ้าสั้นกว่า 2 ตัวอักษร (เช่น "-2") ใช้ timestamp แทน
    form.value.slug = raw.length >= 2 ? raw : `page-${Date.now()}`
  }
  saving.value = true
  if (form.value.id) {
    const { id, ...patch } = form.value
    await supabase.from('pages').update(patch).eq('id', id)
  } else {
    const { id, ...payload } = form.value
    await supabase.from('pages').insert({ ...payload, blocks: [] })
  }
  saving.value   = false
  showForm.value = false
  await load()
  fetchNavPages(true)
}

async function togglePublish(p) {
  await supabase.from('pages').update({ is_published: !p.is_published }).eq('id', p.id)
  p.is_published = !p.is_published
  fetchNavPages(true)
}

// ── Page Permissions ──────────────────────────────────────────────
const showPermModal = ref(false)
const permTarget    = ref(null)   // page ที่กำลังจัดการ
const supervisors   = ref([])     // รายชื่อ supervisor/staff ทั้งหมด
const permLoading   = ref(false)
const permSaving    = ref(false)

function displayName(p) {
  if (p.first_name || p.last_name) return `${p.title||''}${p.first_name||''} ${p.last_name||''}`.trim()
  return p.full_name || p.email || '-'
}

async function openPermissions(p) {
  permTarget.value = { ...p, assigned_users: [...(p.assigned_users || [])] }
  showPermModal.value = true
  if (supervisors.value.length === 0) {
    permLoading.value = true
    const { data } = await supabase
      .from('profiles')
      .select('id, full_name, first_name, last_name, title, position, position_level, avatar_url')
      .in('role', ['supervisor', 'staff'])
      .eq('is_active', true)
      .eq('is_approved', true)
      .order('full_name')
    supervisors.value = data || []
    permLoading.value = false
  }
}

function toggleAssign(userId) {
  const arr = permTarget.value.assigned_users
  const idx = arr.indexOf(userId)
  idx >= 0 ? arr.splice(idx, 1) : arr.push(userId)
}

async function savePermissions() {
  permSaving.value = true
  const { error } = await supabase
    .from('pages')
    .update({ assigned_users: permTarget.value.assigned_users })
    .eq('id', permTarget.value.id)
  permSaving.value = false
  if (error) return Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  // อัปเดตใน pages list ด้วย
  const p = pages.value.find(x => x.id === permTarget.value.id)
  if (p) p.assigned_users = [...permTarget.value.assigned_users]
  showPermModal.value = false
  Swal.fire({ icon: 'success', title: 'บันทึกสิทธิ์แล้ว', showConfirmButton: false, timer: 900 })
}

async function deletePage(p) {
  const res = await Swal.fire({
    title: `ลบ "${p.title}"?`, icon: 'warning', showCancelButton: true,
    confirmButtonColor: '#ef4444', confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('pages').delete().eq('id', p.id)
  pages.value = pages.value.filter(x => x.id !== p.id)
  fetchNavPages(true)
}

function goEditor(p) { router.push(`/dashboard/pages/${p.id}/edit`) }
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2"><SvgIcon name="document" class="w-6 h-6 text-primary"/> จัดการหน้าเนื้อหา</h1>
        <p class="text-sm text-slate-500 mt-0.5">สร้าง แก้ไข และจัดการเมนูนำทางสาธารณะ</p>
      </div>
      <button v-if="isAdmin" @click="openCreate"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary text-white font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        สร้างหน้าใหม่
      </button>
    </div>

    <!-- Supervisor info banner -->
    <div v-if="!loading && !isAdmin"
      class="flex items-center gap-3 p-3.5 bg-amber-50 border border-amber-200 rounded-2xl text-sm text-amber-700">
      <SvgIcon name="star" class="w-4 h-4 flex-shrink-0 text-amber-500"/>
      <span>แสดงเฉพาะหน้าที่คุณได้รับมอบหมาย — สามารถแก้เนื้อหาได้แต่ไม่สามารถสร้างหน้าใหม่หรือจัดการเมนูได้</span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 3" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Nav Groups manager (admin only) -->
    <div v-else-if="isAdmin" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-extrabold text-slate-700">กลุ่มเมนูนำทาง</p>
        <div class="flex items-center gap-2">
          <button @click="addGroup"
            class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
            </svg>
            เพิ่มกลุ่ม
          </button>
          <button @click="saveGroups" :disabled="savingGroups"
            class="px-3 py-1.5 text-xs font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 transition-all disabled:opacity-50">
            {{ savingGroups ? '...' : 'บันทึก' }}
          </button>
        </div>
      </div>
      <div class="space-y-2">
        <div v-for="(g, i) in navGroups" :key="g.key"
          class="flex items-center gap-2 px-3 py-2 bg-slate-50 rounded-xl border border-slate-100">
          <!-- Up/Down -->
          <div class="flex flex-col gap-0.5">
            <button @click="moveGroupUp(i)" :disabled="i===0"
              class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
              </svg>
            </button>
            <button @click="moveGroupDown(i)" :disabled="i===navGroups.length-1"
              class="w-5 h-5 flex items-center justify-center rounded text-slate-400 hover:bg-slate-200 disabled:opacity-20 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
              </svg>
            </button>
          </div>
          <!-- Label input -->
          <input v-model="g.label" type="text"
            class="flex-1 px-2 py-1 text-sm font-bold border border-slate-200 rounded-lg bg-white focus:outline-none focus:border-primary"/>
          <!-- key badge -->
          <span class="text-[10px] font-mono text-slate-400 bg-slate-200 px-1.5 py-0.5 rounded">{{ g.key }}</span>
          <!-- Toggle visible -->
          <button @click="g.visible = !g.visible"
            :class="['px-2.5 py-1 text-xs font-bold rounded-lg transition-colors',
              g.visible ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-200 text-slate-400']">
            {{ g.visible ? '👁 แสดง' : '🚫 ซ่อน' }}
          </button>
          <!-- Delete group -->
          <button @click="removeGroup(i)"
            class="w-6 h-6 flex items-center justify-center rounded text-slate-300 hover:text-red-400 hover:bg-red-50 transition-colors">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Page groups -->
    <div class="space-y-6">
      <div v-for="g in grouped" :key="g.key">
        <p class="text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 px-1">{{ g.label }}</p>
        <div class="space-y-2">
          <div v-for="p in g.items" :key="p.id"
            class="bg-white rounded-2xl border border-slate-100 shadow-sm px-4 py-3 flex flex-wrap items-center gap-3">
            <!-- Icon + title -->
            <div class="w-8 h-8 flex-shrink-0 flex items-center justify-center rounded-lg bg-slate-100">
              <svg v-if="isIconKey(p.nav_icon)" class="w-4 h-4 text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(p.nav_icon)"/>
              </svg>
              <span v-else class="text-base">{{ p.nav_icon || '📄' }}</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-bold text-slate-800 truncate">{{ p.title }}</p>
              <p class="text-xs text-slate-400 font-mono">/{{ p.slug }}</p>
            </div>
            <!-- Badges -->
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', TYPE_COLORS[p.page_type]]">
              {{ TYPE_LABELS[p.page_type] }}
            </span>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full',
              p.show_in_nav ? 'bg-primary/10 text-primary' : 'bg-slate-100 text-slate-400']">
              {{ p.show_in_nav ? '📌 เมนู' : 'ซ่อน' }}
            </span>
            <!-- Actions -->
            <div class="flex items-center gap-1.5 flex-shrink-0">
              <button v-if="p.page_type === 'cms'" @click="goEditor(p)"
                class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-indigo-50 text-indigo-700 rounded-xl hover:bg-indigo-100 transition-colors">
                <SvgIcon name="document" class="w-3.5 h-3.5"/>
                แก้เนื้อหา
              </button>
              <button @click="togglePublish(p)"
                :class="['flex items-center gap-1 px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                  p.is_published ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100' : 'bg-slate-50 text-slate-500 hover:bg-slate-100']">
                <SvgIcon :name="p.is_published ? 'eye' : 'magnify'" class="w-3.5 h-3.5"/>
                {{ p.is_published ? 'เผยแพร่' : 'ฉบับร่าง' }}
              </button>
              <!-- ปุ่มจัดการสิทธิ์ (เฉพาะ CMS) -->
              <button v-if="p.page_type === 'cms'" @click="openPermissions(p)"
                :title="`ผู้ดูแล ${(p.assigned_users||[]).length} คน`"
                :class="['w-8 h-8 flex items-center justify-center rounded-xl transition-colors relative',
                  (p.assigned_users||[]).length > 0 ? 'bg-amber-50 text-amber-600 hover:bg-amber-100' : 'text-slate-300 hover:bg-slate-100']">
                <SvgIcon name="users" class="w-4 h-4"/>
                <span v-if="(p.assigned_users||[]).length > 0"
                  class="absolute -top-1 -right-1 w-4 h-4 bg-amber-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                  {{ (p.assigned_users||[]).length }}
                </span>
              </button>
              <button @click="openEdit(p)"
                class="w-8 h-8 flex items-center justify-center rounded-xl text-slate-400 hover:bg-slate-100 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
              </button>
              <button @click="deletePage(p)"
                class="w-8 h-8 flex items-center justify-center rounded-xl text-slate-300 hover:text-red-500 hover:bg-red-50 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal form -->
    <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" leave-to-class="opacity-0">
      <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg flex flex-col" style="max-height:90vh">

          <!-- Header sticky -->
          <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-slate-100 flex-shrink-0">
            <h2 class="text-lg font-extrabold text-slate-800">{{ form.id ? 'แก้ไขหน้า' : 'สร้างหน้าใหม่' }}</h2>
            <button @click="showForm = false"
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Scrollable body -->
          <div class="overflow-y-auto flex-1 px-6 py-4 space-y-4">
          <div class="grid grid-cols-2 gap-3">
            <div class="col-span-2">
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ชื่อหน้า *</label>
              <input v-model="form.title" type="text" placeholder="เช่น วิสัยทัศน์และพันธกิจ"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">Slug (URL) <span class="text-red-400">*</span></label>
              <input v-model="form.slug" type="text" placeholder="พิมพ์ slug เป็นภาษาอังกฤษ เช่น my-page"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
              <p class="text-[10px] text-slate-400 mt-0.5">ตัวอักษรเล็ก a-z, ตัวเลข, ขีด - เท่านั้น (ถ้าว่างจะใช้ page-timestamp)</p>
            </div>
            <div class="col-span-2">
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2 block">Icon</label>
              <IconPicker v-model="form.nav_icon"/>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ประเภท</label>
              <select v-model="form.page_type"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
                <option value="cms">CMS (แก้เนื้อหาเอง)</option>
                <option value="system">ระบบ (Vue component)</option>
                <option value="link">ลิงค์ภายนอก</option>
              </select>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">กลุ่มเมนู</label>
              <select v-model="form.nav_group"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white">
                <option v-for="g in navGroups" :key="g.key" :value="g.key">{{ g.label }}</option>
              </select>
            </div>
            <div v-if="form.page_type !== 'cms'" class="col-span-2">
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">
                {{ form.page_type === 'link' ? 'URL ปลายทาง' : 'Route' }}
              </label>
              <div class="relative mt-1">
                <input v-model="form.system_route" type="text"
                  :placeholder="form.page_type === 'link' ? 'https://www.example.com' : 'พิมพ์ / เพื่อดู routes...'"
                  @focus="showRouteList = form.page_type === 'system'"
                  @blur="setTimeout(() => showRouteList = false, 150)"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono"/>
                <!-- Autocomplete dropdown (system only) -->
                <div v-if="showRouteList && form.page_type === 'system'"
                  class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-lg overflow-hidden">
                  <button v-for="r in filteredRoutes" :key="r.route"
                    type="button"
                    @mousedown.prevent="form.system_route = r.route; showRouteList = false"
                    class="w-full flex items-center gap-3 px-3 py-2 hover:bg-primary-light text-left transition-colors">
                    <span class="font-mono text-xs text-primary font-bold">{{ r.route }}</span>
                    <span class="text-xs text-slate-500">{{ r.label }}</span>
                  </button>
                  <p v-if="filteredRoutes.length === 0" class="px-3 py-2 text-xs text-slate-400">ไม่พบ route</p>
                </div>
              </div>
            </div>
            <div>
              <label class="text-xs font-bold text-slate-500 uppercase tracking-wider">ลำดับในกลุ่ม</label>
              <input v-model.number="form.nav_order" type="number" min="1"
                class="mt-1 w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
            </div>
          </div>

          <!-- Toggles -->
          <div class="flex gap-4">
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="form.show_in_nav" class="accent-primary w-4 h-4"/>
              <span class="text-sm font-bold text-slate-700">แสดงในเมนู</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="form.is_published" class="accent-primary w-4 h-4"/>
              <span class="text-sm font-bold text-slate-700">เผยแพร่ทันที</span>
            </label>
          </div>

          </div><!-- end scrollable body -->

          <!-- Footer sticky -->
          <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
            <button @click="showForm = false"
              class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50 transition-colors">
              ยกเลิก
            </button>
            <button @click="save" :disabled="saving || !form.title.trim()"
              class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark transition-colors disabled:opacity-50">
              {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ── Permission Modal ──────────────────────────────────────── -->
    <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" leave-to-class="opacity-0">
      <div v-if="showPermModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
        @click.self="showPermModal = false">
        <div class="bg-white rounded-3xl shadow-2xl w-full max-w-md flex flex-col" style="max-height:85vh">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-slate-100 flex-shrink-0">
            <div>
              <h2 class="text-base font-extrabold text-slate-800">จัดการสิทธิ์ผู้ดูแล</h2>
              <p class="text-xs text-slate-400 mt-0.5">{{ permTarget?.title }}</p>
            </div>
            <button @click="showPermModal = false"
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Body -->
          <div class="overflow-y-auto flex-1 px-6 py-4">
            <p class="text-xs text-slate-500 mb-3">
              ติ๊กเพื่อให้บุคลากรสามารถแก้เนื้อหาหน้านี้ได้ — ไม่มีสิทธิ์จัดการเมนูหรือสร้างหน้าใหม่
            </p>

            <!-- Loading -->
            <div v-if="permLoading" class="space-y-2">
              <div v-for="i in 4" :key="i" class="h-12 bg-slate-100 rounded-xl animate-pulse"></div>
            </div>

            <!-- Supervisor list -->
            <div v-else class="space-y-1.5">
              <p v-if="supervisors.length === 0" class="text-sm text-slate-400 text-center py-6">
                ไม่มีบุคลากรในระบบ
              </p>
              <label v-for="s in supervisors" :key="s.id"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl cursor-pointer hover:bg-slate-50 transition-colors"
                :class="permTarget?.assigned_users?.includes(s.id) ? 'bg-primary/5 ring-1 ring-primary/20' : ''">
                <input type="checkbox"
                  :checked="permTarget?.assigned_users?.includes(s.id)"
                  @change="toggleAssign(s.id)"
                  class="w-4 h-4 accent-primary flex-shrink-0"/>
                <!-- avatar -->
                <div class="w-8 h-8 rounded-full overflow-hidden bg-slate-100 flex-shrink-0">
                  <img v-if="s.avatar_url" :src="s.avatar_url" class="w-full h-full object-cover"/>
                  <div v-else class="w-full h-full flex items-center justify-center text-xs font-bold text-primary">
                    {{ displayName(s)[0] || '?' }}
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-slate-700 truncate">{{ displayName(s) }}</p>
                  <p class="text-[10px] text-slate-400">{{ s.position_level || s.position || 'บุคลากร' }}</p>
                </div>
                <span v-if="permTarget?.assigned_users?.includes(s.id)"
                  class="text-[10px] font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-full flex-shrink-0">
                  มีสิทธิ์
                </span>
              </label>
            </div>
          </div>

          <!-- Footer -->
          <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
            <button @click="showPermModal = false"
              class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">
              ยกเลิก
            </button>
            <button @click="savePermissions" :disabled="permSaving"
              class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold hover:bg-primary-dark disabled:opacity-50">
              {{ permSaving ? 'กำลังบันทึก...' : 'บันทึกสิทธิ์' }}
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
