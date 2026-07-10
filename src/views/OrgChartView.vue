<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('org', {
  icon: 'building', title: 'โครงสร้างการบริหารงาน',
  subtitle: 'ผังโครงสร้างองค์กรกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
})

const loading   = ref(true)
const personnel = ref([])

function displayName(p) {
  if (!p) return '-'
  if (p.first_name || p.last_name) return `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim()
  return p.full_name || p.email || '-'
}
// ชื่อ/ตำแหน่งอยู่บรรทัดเดียวเสมอ ยาวเกินให้ย่อขนาดแทนตัดบรรทัด (เหมือน PersonnelView.vue)
function fitTextClass(text, tiers = [[18, 'text-sm'], [24, 'text-xs'], [Infinity, 'text-[10px]']]) {
  const len = (text || '').length
  return tiers.find(([max]) => len <= max)[1]
}

onMounted(async () => {
  fetchConfig()
  const { data } = await supabase
    .from('profiles')
    .select('id,full_name,first_name,last_name,title,position,position_level,org_role,department,avatar_url,sort_order')
    .in('role', ['supervisor', 'staff'])
    .eq('is_active', true).eq('is_approved', true)
    .order('sort_order', { ascending: true })
  personnel.value = data || []
  loading.value = false
})

const directors = computed(() => personnel.value.filter(p => p.org_role === 'director'))
const deputies  = computed(() => personnel.value.filter(p => p.org_role === 'deputy'))

const groupConfig = computed(() => config.value?.personnel_groups || [])

function isGroupVisible(label) {
  const cfg = groupConfig.value
  if (!cfg.length) return true
  const g = cfg.find(g => g.label === label)
  return g ? g.visible !== false : true
}

// กลุ่มงาน: รวมทุกคนที่ไม่ใช่ ผอ.เขต/รองผอ.เขต (รวม group_director ปนกับ staff) จัดตาม department
// หัวหน้ากลุ่ม = คนที่ sort_order น้อยสุดในกลุ่มนั้น (ไม่ต้องตั้งค่าเพิ่ม)
const deptGroups = computed(() => {
  const rest = personnel.value.filter(p => !['director', 'deputy'].includes(p.org_role))
  const map = {}
  rest.forEach(p => {
    const dep = p.department || 'ไม่ระบุกลุ่มงาน'
    if (!map[dep]) map[dep] = []
    map[dep].push(p)
  })
  const cfg = groupConfig.value
  return Object.entries(map)
    .filter(([dep]) => isGroupVisible(dep))
    .map(([dep, members]) => {
      const sorted = [...members].sort((a, b) => (a.sort_order ?? 99) - (b.sort_order ?? 99))
      return { name: dep, count: sorted.length, head: sorted[0] }
    })
    .sort((a, b) => {
      const ga = cfg.find(g => g.label === a.name)
      const gb = cfg.find(g => g.label === b.name)
      const oa = ga?.order ?? 99, ob = gb?.order ?? 99
      return oa !== ob ? oa - ob : a.name.localeCompare(b.name, 'th')
    })
})
</script>

<template>
  <div class="font-sarabun min-h-[60vh] bg-slate-50 dark:bg-slate-950">
    <PageHero :title="header.title" :subtitle="header.subtitle" :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      size="md" align="left" max-width="6xl"/>

    <div class="max-w-6xl mx-auto px-4 py-8">
      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-20">
        <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"></div>
      </div>

      <!-- Empty -->
      <div v-else-if="!directors.length && !deputies.length && !deptGroups.length"
        class="text-center py-20 text-slate-400">
        ยังไม่มีข้อมูลบุคลากรสำหรับแสดงผัง
      </div>

      <div v-else class="chart-wrap">
        <!-- Tier 1: ผอ.เขต -->
        <div v-if="directors.length" class="chart-tier">
          <div v-for="p in directors" :key="p.id" class="chart-card">
            <div class="chart-avatar">
              <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover object-top"/>
              <span v-else class="chart-avatar-initial">{{ displayName(p)[0] }}</span>
            </div>
            <p class="chart-name" :class="fitTextClass(displayName(p))">{{ displayName(p) }}</p>
            <p class="chart-pos" :class="fitTextClass(p.position)">{{ p.position }}</p>
          </div>
        </div>

        <!-- Tier 2: รองผอ.เขต -->
        <template v-if="deputies.length">
          <div class="chart-connector"></div>
          <div class="chart-branch">
            <div v-for="p in deputies" :key="p.id" class="chart-branch-item">
              <div class="chart-card">
                <div class="chart-avatar">
                  <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover object-top"/>
                  <span v-else class="chart-avatar-initial">{{ displayName(p)[0] }}</span>
                </div>
                <p class="chart-name" :class="fitTextClass(displayName(p))">{{ displayName(p) }}</p>
                <p class="chart-pos" :class="fitTextClass(p.position)">{{ p.position }}</p>
              </div>
            </div>
          </div>
        </template>

        <!-- Tier 3: กลุ่มงาน -->
        <template v-if="deptGroups.length">
          <div class="chart-connector"></div>
          <div class="chart-branch chart-branch-wrap">
            <div v-for="g in deptGroups" :key="g.name" class="chart-branch-item">
              <div class="chart-box">
                <p class="chart-box-title" :class="fitTextClass(g.name, [[22,'text-sm'],[30,'text-xs'],[Infinity,'text-[11px]']])">{{ g.name }}</p>
                <p class="chart-box-count">{{ g.count }} คน</p>
                <div v-if="g.head" class="chart-box-head">
                  <span class="chart-box-head-label">หัวหน้า</span>
                  <span class="chart-box-head-name">{{ displayName(g.head) }}</span>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }

/* ── โครงผัง + เส้นเชื่อม ─────────────────────────────────────── */
.chart-wrap { @apply flex flex-col items-center; }

.chart-tier { @apply flex flex-wrap justify-center gap-6; }

/* เส้นดิ่งเชื่อมระหว่างชั้น */
.chart-connector { @apply w-0.5 h-8 bg-slate-300 dark:bg-slate-600; }

/* แถวลูก (มีเส้นแนวนอนคาดด้านบน + เส้นสต็มลงมาแต่ละกล่อง) */
.chart-branch { @apply flex justify-center gap-6 flex-wrap; }
.chart-branch-wrap { @apply flex-wrap; }
.chart-branch-item { @apply relative flex flex-col items-center pt-8; }
.chart-branch-item::before {
  /* เส้นสต็มลงมาจากเส้นแนวนอนถึงกล่อง */
  content: ''; position: absolute; top: 0; left: 50%; width: 2px; height: 2rem;
  background: theme('colors.slate.300'); transform: translateX(-50%);
}
.dark .chart-branch-item::before { background: theme('colors.slate.600'); }
.chart-branch-item::after {
  /* เส้นแนวนอนคาดด้านบน เชื่อมกล่องในแถวเดียวกัน */
  content: ''; position: absolute; top: 0; left: 0; right: 0; height: 2px;
  background: theme('colors.slate.300');
}
.dark .chart-branch-item::after { background: theme('colors.slate.600'); }
.chart-branch-item:first-child::after { left: 50%; }
.chart-branch-item:last-child::after  { right: 50%; }
.chart-branch-item:only-child::after  { display: none; }

/* จอแคบ: กล่องตกลงมาเรียงเป็นแถวใหม่ ทำให้เส้นแนวนอนคาด (::after) เพี้ยน — ตัดออก เหลือแค่เส้นเชื่อมชั้นบนสุด */
@media (max-width: 640px) {
  .chart-branch { flex-direction: column; }
  .chart-branch-item::after { display: none; }
}

/* ── การ์ดผู้บริหาร (ผอ.เขต/รองผอ.เขต) ───────────────────────── */
.chart-card {
  @apply w-40 bg-white dark:bg-slate-800 rounded-2xl shadow-lg border border-slate-100 dark:border-slate-700
         overflow-hidden flex flex-col items-center pt-4 pb-3 px-2 text-center;
}
.chart-avatar {
  @apply w-16 h-16 rounded-full overflow-hidden bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-2 flex-shrink-0;
}
.chart-avatar-initial { @apply text-2xl font-extrabold; color: var(--color-primary); }
.chart-name { @apply w-full font-extrabold text-slate-800 dark:text-slate-100 leading-tight whitespace-nowrap overflow-hidden; }
.chart-pos  { @apply w-full text-primary font-bold mt-0.5 leading-tight whitespace-nowrap overflow-hidden; }

/* ── กล่องกลุ่มงาน (สรุป 1 กล่องต่อกลุ่ม) ────────────────────── */
.chart-box {
  @apply w-56 bg-white dark:bg-slate-800/60 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700
         p-4 text-center;
}
.chart-box-title { @apply font-extrabold leading-tight break-keep break-words; color: var(--color-primary); }
.chart-box-count {
  @apply inline-block text-[10px] font-bold text-white px-2 py-0.5 rounded-full mt-1.5;
  background: var(--color-secondary);
}
.chart-box-head { @apply mt-2 pt-2 border-t border-slate-100 dark:border-slate-700 text-xs; }
.chart-box-head-label { @apply text-slate-400 mr-1; }
.chart-box-head-name  { @apply font-bold text-slate-600 dark:text-slate-300; }
</style>
