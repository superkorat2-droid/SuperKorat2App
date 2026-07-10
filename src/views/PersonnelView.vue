<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('personnel', {
  icon: 'users', title: 'ทำเนียบบุคลากร', subtitle: 'บุคลากรกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
})
const loading   = ref(true)
const personnel = ref([])
const selected  = ref(null)

// Social & contact SVG paths
const SOCIAL_ICONS = {
  personal_website: { label: 'เว็บไซต์',   svgPath: 'M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418' },
  portfolio_url:    { label: 'Portfolio',   svgPath: 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  facebook_url:     { label: 'Facebook',    svgPath: 'M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244' },
  youtube_url:      { label: 'YouTube',     svgPath: 'M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z' },
  tiktok_url:       { label: 'TikTok',      svgPath: 'M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 00-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0020 4.77 5.07 5.07 0 0019.91 1S18.73.65 16 2.48a13.38 13.38 0 00-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 005 4.77a5.44 5.44 0 00-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 009 18.13V22' },
  twitter_url:      { label: 'X',           svgPath: 'M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.615 11.615 0 006.29 1.84' },
  instagram_url:    { label: 'Instagram',   svgPath: 'M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.776 48.776 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316zM16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z' },
  linkedin_url:     { label: 'LinkedIn',    svgPath: 'M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 2.25 0 00-2.25 2.25v.894m7.5 0a48.667 48.667 0 00-7.5 0M12 12.75h.008v.008H12V12.75z' },
}
const CONTACT_SVG = {
  phone:  'M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 6.75z',
  email:  'M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75',
  line_id:'M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.48.432.447.74 1.04.586 1.641a4.483 4.483 0 01-.923 1.785A5.969 5.969 0 006 21c1.282 0 2.47-.402 3.445-1.087.81.22 1.668.337 2.555.337z',
}

const ORG_ORDER = ['director','deputy','group_director','supervisor','staff','other']

onMounted(async () => {
  fetchConfig()
  const { data } = await supabase
    .from('profiles')
    .select('id,full_name,first_name,last_name,title,position,position_level,org_role,department,subjects,expertise,bio,avatar_url,sort_order,phone,line_id,email,facebook_url,youtube_url,tiktok_url,twitter_url,instagram_url,linkedin_url,personal_website,portfolio_url,contact_visibility')
    .in('role', ['supervisor','staff'])
    .eq('is_active', true).eq('is_approved', true)
    .order('sort_order', { ascending: true })
  personnel.value = (data || []).sort((a,b) => {
    const ra = ORG_ORDER.indexOf(a.org_role), rb = ORG_ORDER.indexOf(b.org_role)
    return ra !== rb ? ra - rb : (a.sort_order||99) - (b.sort_order||99)
  })
  loading.value = false
})

// กลุ่มงาน config
const personnelGroupConfig = computed(() =>
  config.value?.personnel_groups || []
)

// ตรวจว่า department ของบุคลากรนั้นถูกซ่อนไหม
function isDeptVisible(p) {
  const cfg = personnelGroupConfig.value
  if (!cfg.length) return true
  const dep = p.department
  if (!dep) return true  // ไม่มี department → แสดงเสมอ
  const g = cfg.find(g => g.label === dep)
  return g ? g.visible !== false : true
}

// ── computed ──────────────────────────────────────────────────────
const directors = computed(() =>
  personnel.value.filter(p => p.org_role === 'director' && isDeptVisible(p))
)
const deputies  = computed(() =>
  personnel.value.filter(p => p.org_role === 'deputy' && isDeptVisible(p))
)
const groupDirs = computed(() =>
  personnel.value.filter(p => p.org_role === 'group_director' && isDeptVisible(p))
)
const nonExecs  = computed(() =>
  personnel.value.filter(p => !['director','deputy','group_director'].includes(p.org_role))
)

const departmentGroups = computed(() => {
  const map = {}
  nonExecs.value.forEach(p => {
    const dep = p.department || 'ไม่ระบุกลุ่มงาน'
    if (!map[dep]) map[dep] = []
    map[dep].push(p)
  })
  const cfg = personnelGroupConfig.value
  return Object.entries(map)
    .filter(([dep]) => {
      // ซ่อนกลุ่มที่ visible=false ใน config
      if (!cfg.length) return true
      const g = cfg.find(g => g.label === dep)
      return g ? g.visible !== false : true
    })
    .sort((a,b) => {
      // เรียงตาม config order
      const ga = cfg.find(g => g.label === a[0])
      const gb = cfg.find(g => g.label === b[0])
      const oa = ga?.order ?? 99, ob = gb?.order ?? 99
      return oa !== ob ? oa - ob : a[0].localeCompare(b[0], 'th')
    })
})

// ── helpers ───────────────────────────────────────────────────────
function displayName(p) {
  if (p.first_name || p.last_name) return `${p.title||''}${p.first_name||''}${p.last_name ? ' '+p.last_name : ''}`.trim()
  return p.full_name || ''
}
// การ์ดขึ้นบรรทัดใหม่ที่ช่องว่างจริงระหว่างชื่อ/นามสกุลเสมอ กันคำถูกตัดกลางคำ
// (word-break:keep-all ไม่กันการตัดคำไทยกลางพยางค์ในเบราว์เซอร์ chromium)
function cardNameFirstLine(p) {
  const t = `${p.title||''}${p.first_name||''}`.trim()
  return t || p.full_name || ''
}
function cardNameLastLine(p) {
  return (p.first_name || p.last_name) ? (p.last_name || '') : ''
}
function isExec(p) { return ['director','deputy','group_director'].includes(p.org_role) }

function visibleSocials(p) {
  const vis = p.contact_visibility || {}
  return Object.entries(SOCIAL_ICONS).filter(([k]) => p[k] && vis[k] !== false)
    .map(([k, m]) => ({ key: k, url: p[k], label: m.label, svgPath: m.svgPath }))
}
function visibleContact(p) {
  const vis = p.contact_visibility || {}
  const items = []
  if (p.phone   && vis.phone   !== false) items.push({ key:'phone',   label:p.phone,   href:`tel:${p.phone}`,              svgPath:CONTACT_SVG.phone })
  if (p.email   && vis.email   !== false) items.push({ key:'email',   label:p.email,   href:`mailto:${p.email}`,           svgPath:CONTACT_SVG.email })
  if (p.line_id && vis.line_id !== false) items.push({ key:'line_id', label:p.line_id, href:`https://line.me/ti/p/~${p.line_id}`, svgPath:CONTACT_SVG.line_id })
  return items
}
</script>

<template>
  <div class="font-sarabun min-h-screen transition-colors" style="background:radial-gradient(ellipse at top,#f0f4ff 0%,#f8fafc 60%)">

    <!-- Page header -->
    <PageHero :title="header.title" :subtitle="header.subtitle"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      size="md" align="left" max-width="6xl"/>

    <div class="max-w-6xl mx-auto px-4 py-8">

      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-20">
        <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"></div>
      </div>

      <!-- ══ DIRECTORY ══════════════════════════════════════════════ -->
      <template v-else>

        <!-- แถว 1: ผอ.เขต (director) — กลางหน้า -->
        <div v-if="directors.length" class="mb-8">
          <div class="flex justify-center gap-5">
            <button v-for="p in directors" :key="p.id" @click="selected = p"
              class="personnel-card hover:shadow-xl hover:-translate-y-1 transition-all">
              <div class="card-cover" style="background:linear-gradient(135deg,var(--color-primary),var(--color-secondary))">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover"/>
                    <span v-else class="avatar-initial">{{ displayName(p)[0] }}</span>
              </div>
              <div class="card-body">
                <p class="card-name">{{ cardNameFirstLine(p) }}<br v-if="cardNameLastLine(p)">{{ cardNameLastLine(p) }}</p>
                <p class="card-pos">{{ p.position }}</p>
              </div>
            </button>
          </div>
          <div v-if="deputies.length || groupDirs.length" class="flex justify-center mt-4">
            <div class="w-px h-8 bg-slate-300 dark:bg-slate-600"></div>
          </div>
        </div>

        <!-- แถว 2: รอง ผอ. (deputy) — กลางหน้า -->
        <div v-if="deputies.length" class="mb-8">
          <div class="flex justify-center flex-wrap gap-5">
            <button v-for="p in deputies" :key="p.id" @click="selected = p"
              class="personnel-card hover:shadow-xl hover:-translate-y-1 transition-all">
              <div class="card-cover" style="background:linear-gradient(135deg,var(--color-secondary),var(--color-primary))">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover"/>
                    <span v-else class="avatar-initial">{{ displayName(p)[0] }}</span>
              </div>
              <div class="card-body">
                <p class="card-name">{{ cardNameFirstLine(p) }}<br v-if="cardNameLastLine(p)">{{ cardNameLastLine(p) }}</p>
                <p class="card-pos">{{ p.position }}</p>
              </div>
            </button>
          </div>
          <div v-if="groupDirs.length" class="flex justify-center mt-4">
            <div class="w-px h-8 bg-slate-300 dark:bg-slate-600"></div>
          </div>
        </div>

        <!-- แถว 3: ผอ.กลุ่ม (group_director) — กลางหน้า -->
        <div v-if="groupDirs.length" class="mb-10">
          <div class="flex justify-center flex-wrap gap-5">
            <button v-for="p in groupDirs" :key="p.id" @click="selected = p"
              class="personnel-card hover:shadow-xl hover:-translate-y-1 transition-all">
              <div class="card-cover" style="background:linear-gradient(135deg,#1e3a5f,#312e81)">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover"/>
                    <span v-else class="avatar-initial">{{ displayName(p)[0] }}</span>
              </div>
              <div class="card-body">
                <p class="card-name">{{ cardNameFirstLine(p) }}<br v-if="cardNameLastLine(p)">{{ cardNameLastLine(p) }}</p>
                <p class="card-pos">{{ p.position }}</p>
                <p v-if="p.department" class="card-dept">{{ p.department }}</p>
              </div>
            </button>
          </div>
        </div>

        <!-- แถว 4+: กลุ่มงาน + บุคลากร -->
        <div v-for="[dep, members] in departmentGroups" :key="dep" class="mb-10">
          <!-- หัวข้อกลุ่มงาน -->
          <div class="flex items-center gap-3 mb-6">
            <!-- accent bar พร้อม mini gradient -->
            <div class="flex-shrink-0 flex items-center gap-2 px-3 py-2 rounded-xl"
              style="background:linear-gradient(to right,color-mix(in srgb,var(--color-primary) 12%,transparent),transparent)">
              <div class="w-1 h-6 rounded-full" style="background:var(--color-primary)"></div>
              <h2 class="text-base font-extrabold text-slate-800 dark:text-slate-100 whitespace-nowrap">{{ dep }}</h2>
            </div>
            <div class="flex-1 h-px bg-slate-200 dark:bg-slate-700"></div>
            <span class="text-xs font-bold px-3 py-1 rounded-full text-white flex-shrink-0"
              style="background:var(--color-primary)">
              {{ members.length }} คน
            </span>
          </div>
          <!-- การ์ด 4 คอลัมน์ แถวสุดท้ายอยู่กลาง -->
          <div class="flex flex-wrap justify-center gap-5">
            <button v-for="p in members" :key="p.id" @click="selected = p"
              class="personnel-card hover:shadow-xl hover:-translate-y-1 transition-all">
              <div class="card-cover" style="background:linear-gradient(135deg,var(--color-primary),var(--color-secondary))">
                <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover"/>
                    <span v-else class="avatar-initial">{{ displayName(p)[0] }}</span>
              </div>
              <div class="card-body">
                <p class="card-name">{{ cardNameFirstLine(p) }}<br v-if="cardNameLastLine(p)">{{ cardNameLastLine(p) }}</p>
                <p class="card-pos">{{ p.position_level || p.position }}</p>
                <div class="flex flex-wrap justify-center gap-1 mt-1.5">
                  <span v-for="s in (p.subjects||[]).slice(0,2)" :key="s"
                    class="text-[9px] font-bold px-1.5 py-0.5 bg-secondary/10 text-secondary rounded-full">{{ s }}</span>
                  <span v-if="(p.subjects||[]).length > 2" class="text-[9px] px-1.5 py-0.5 bg-slate-100 text-slate-400 rounded-full">
                    +{{ p.subjects.length - 2 }}
                  </span>
                </div>
              </div>
            </button>
          </div>
        </div>

      </template>
    </div>

    <!-- ── Profile Modal ──────────────────────────────────────────── -->
    <Teleport to="body">
    <Transition enter-active-class="transition duration-200 ease-out" enter-from-class="opacity-0 scale-95"
      leave-active-class="transition duration-150 ease-in" leave-to-class="opacity-0 scale-95">
      <div v-if="selected" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
        @click.self="selected = null">
        <div class="bg-white dark:bg-slate-900 rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden">
          <!-- Modal: gradient + วงกลม -->
          <div class="h-28 relative flex-shrink-0"
            style="background:linear-gradient(135deg,var(--color-primary),var(--color-secondary))">
            <button @click="selected = null"
              class="absolute top-3 right-3 w-9 h-9 bg-white hover:bg-slate-100 rounded-full flex items-center justify-center shadow-lg transition-colors">
              <svg class="w-4 h-4 text-slate-700" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
            <div class="absolute -bottom-12 left-1/2 -translate-x-1/2">
              <div class="w-24 h-24 rounded-full overflow-hidden ring-4 ring-white dark:ring-slate-900 shadow-xl bg-slate-100 dark:bg-slate-700">
                <img v-if="selected.avatar_url" :src="selected.avatar_url" class="w-full h-full object-cover object-top"/>
                <div v-else class="w-full h-full flex items-center justify-center text-3xl font-extrabold text-primary">
                  {{ displayName(selected)[0] || '?' }}
                </div>
              </div>
            </div>
          </div>
          <div class="pt-16 pb-6 px-6">
            <div class="text-center mb-4">
              <h2 class="text-lg font-extrabold text-slate-900 dark:text-slate-50 leading-tight break-keep break-words">{{ displayName(selected) }}</h2>
              <p class="text-primary font-bold text-sm mt-0.5">{{ isExec(selected) ? selected.position : (selected.position_level || selected.position) }}</p>
              <p v-if="selected.department" class="text-slate-400 text-xs mt-0.5">{{ selected.department }}</p>
            </div>
            <div v-if="(selected.subjects||[]).length" class="flex flex-wrap justify-center gap-1.5 mb-3">
              <span v-for="s in selected.subjects" :key="s" class="text-xs font-bold px-2.5 py-1 bg-secondary/10 text-secondary rounded-full">{{ s }}</span>
            </div>
            <div v-if="(selected.expertise||[]).length" class="flex flex-wrap justify-center gap-1.5 mb-3">
              <span v-for="e in selected.expertise" :key="e" class="text-xs px-2.5 py-1 bg-slate-100 dark:bg-slate-800 text-slate-500 rounded-full">{{ e }}</span>
            </div>
            <p v-if="selected.bio && selected.bio !== selected.position_level && selected.bio !== selected.position"
              class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed text-center mb-4 border-t border-slate-100 dark:border-slate-800 pt-3">{{ selected.bio }}</p>
            <div v-if="visibleContact(selected).length" class="border-t border-slate-100 dark:border-slate-800 pt-3 mb-3 space-y-2">
              <a v-for="c in visibleContact(selected)" :key="c.key" :href="c.href"
                class="flex items-center gap-2.5 text-sm text-slate-600 dark:text-slate-300 hover:text-primary transition-colors group">
                <div class="w-7 h-7 rounded-lg bg-slate-100 dark:bg-slate-800 flex items-center justify-center flex-shrink-0 group-hover:bg-primary/10">
                  <svg class="w-3.5 h-3.5 text-slate-500 group-hover:text-primary" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" :d="c.svgPath"/>
                  </svg>
                </div>
                <span>{{ c.label }}</span>
              </a>
            </div>
            <div v-if="visibleSocials(selected).length" class="border-t border-slate-100 dark:border-slate-800 pt-3 flex flex-wrap gap-2">
              <a v-for="sc in visibleSocials(selected)" :key="sc.key" :href="sc.url" target="_blank" rel="noopener"
                class="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 hover:bg-primary/10 hover:text-primary rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="sc.svgPath"/>
                </svg>
                {{ sc.label }}
              </a>
            </div>
          </div>
        </div>
      </div>
    </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

/* ── Unified card — height เท่ากันทุกใบ ───────────────────────── */
.personnel-card {
  @apply w-52 bg-white dark:bg-slate-800 rounded-2xl shadow-lg hover:shadow-2xl overflow-hidden text-left cursor-pointer flex flex-col;
  min-height: 260px;
}
.personnel-card-sm {
  @apply w-48;
  min-height: 240px;
}

/* card-cover = ภาพเต็มบน aspect ratio แนวตั้ง */
.card-cover {
  @apply relative overflow-hidden flex-shrink-0 bg-slate-100 dark:bg-slate-700;
  aspect-ratio: 3.5 / 4;
}
.card-cover img {
  @apply w-full h-full object-cover object-top;
}
/* gradient fade ล่างภาพ */
.card-cover::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, transparent 65%, rgba(255,255,255,0.75) 100%);
  pointer-events: none;
}
.dark .card-cover::after {
  background: linear-gradient(to bottom, transparent 65%, rgba(30,41,59,0.75) 100%);
}
/* avatar-wrap ไม่ใช้แล้วใน card */
.card-avatar-wrap, .card-avatar { display: none; }
.avatar-initial {
  display: flex;
  @apply w-full h-full items-center justify-center text-4xl font-extrabold;
  color: var(--color-primary);
}
.card-body {
  @apply pt-3 pb-4 px-3 text-center flex-1 flex flex-col items-center;
}
.card-name {
  @apply font-extrabold text-slate-800 dark:text-slate-100 text-sm leading-tight break-keep break-words;
}
.card-pos {
  @apply text-xs text-primary font-bold mt-1 leading-tight break-keep break-words;
}
.card-dept {
  @apply text-[10px] text-slate-400 mt-0.5 break-keep break-words;
}

/* org chart */
.org-row {
  @apply relative flex flex-col items-center;
}
.org-h-line {
  @apply h-px bg-slate-300 dark:bg-slate-600 absolute top-6;
}
</style>
