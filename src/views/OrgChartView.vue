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
// การ์ด ผอ.กลุ่ม (chart-card-sm) แคบกว่าการ์ดผอ.เขต/รองผอ.เขต มาก — ใช้เกณฑ์ย่อขนาดที่เข้มกว่าเดิม กันตัวหนังสือถูกตัด
const SM_TIERS = [[13, 'text-xs'], [18, 'text-[10px]'], [Infinity, 'text-[9px]']]

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

const directors  = computed(() => personnel.value.filter(p => p.org_role === 'director'))
const deputies   = computed(() => personnel.value.filter(p => p.org_role === 'deputy'))
const groupDirs  = computed(() => personnel.value.filter(p => p.org_role === 'group_director'))

const groupConfig = computed(() => config.value?.personnel_groups || [])

// กลุ่มงาน: เริ่มจากรายการกลุ่มที่ตั้งค่าไว้ใน "จัดการกลุ่มงาน" ทั้งหมดก่อน (แม้ยังไม่มีใครสังกัดก็ให้ขึ้นโครงไว้)
// แล้วค่อยเติมสมาชิกที่ department ตรงกับกลุ่มนั้น (ไม่รวม ผอ.เขต/รองผอ.เขต/ผอ.กลุ่ม เพราะมีชั้นของตัวเองแล้ว)
// เรียงสมาชิกตาม sort_order (ไม่ระบุ "หัวหน้า" แยก — คนแรกในลำดับคือคนที่ถูกจัดไว้บนสุด)
const deptGroups = computed(() => {
  const rest = personnel.value.filter(p => !['director', 'deputy', 'group_director'].includes(p.org_role))
  const map = {}
  rest.forEach(p => {
    const dep = p.department || 'ไม่ระบุกลุ่มงาน'
    if (!map[dep]) map[dep] = []
    map[dep].push(p)
  })
  const cfg = groupConfig.value

  const fromConfig = cfg
    .filter(g => g.visible !== false)
    .sort((a, b) => (a.order ?? 99) - (b.order ?? 99))
    .map(g => ({
      name: g.label,
      members: [...(map[g.label] || [])].sort((a, b) => (a.sort_order ?? 99) - (b.sort_order ?? 99)),
    }))

  // กลุ่มที่มีคนจริงแต่ department ไม่ตรงกับ label ไหนเลยใน config (เช่น ยังไม่ได้ตั้งกลุ่มไว้) — แสดงต่อท้าย กันข้อมูลตกหล่น
  const configLabels = new Set(cfg.map(g => g.label))
  const extras = Object.entries(map)
    .filter(([dep]) => !configLabels.has(dep))
    .map(([dep, members]) => ({
      name: dep,
      members: [...members].sort((a, b) => (a.sort_order ?? 99) - (b.sort_order ?? 99)),
    }))
    .sort((a, b) => a.name.localeCompare(b.name, 'th'))

  return [...fromConfig, ...extras]
})

// แบ่งกล่องกลุ่มงานเป็นแถวละ 4 กล่อง แล้ววาดเส้นแนวนอน+ก้านแบบเดียวกับชั้นอื่น (แถวละชุด กันเส้นเพี้ยนตอนห่อบรรทัด)
const DEPT_ROW_SIZE = 4
const deptGroupRows = computed(() => {
  const rows = []
  for (let i = 0; i < deptGroups.value.length; i += DEPT_ROW_SIZE) {
    rows.push(deptGroups.value.slice(i, i + DEPT_ROW_SIZE))
  }
  return rows
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
      <div v-else-if="!directors.length && !deputies.length && !groupDirs.length && !deptGroups.length"
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
            <p class="chart-name" :class="fitTextClass(displayName(p), SM_TIERS)">{{ displayName(p) }}</p>
            <p class="chart-pos" :class="fitTextClass(p.position, SM_TIERS)">{{ p.position }}</p>
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
                <p class="chart-name" :class="fitTextClass(displayName(p), SM_TIERS)">{{ displayName(p) }}</p>
                <p class="chart-pos" :class="fitTextClass(p.position, SM_TIERS)">{{ p.position }}</p>
              </div>
            </div>
          </div>
        </template>

        <!-- Tier 3: ผู้อำนวยการกลุ่ม -->
        <template v-if="groupDirs.length">
          <div class="chart-connector"></div>
          <div class="chart-branch">
            <div v-for="p in groupDirs" :key="p.id" class="chart-branch-item">
              <div class="chart-card chart-card-sm">
                <div class="chart-avatar chart-avatar-sm">
                  <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover object-top"/>
                  <span v-else class="chart-avatar-initial">{{ displayName(p)[0] }}</span>
                </div>
                <p class="chart-name" :class="fitTextClass(displayName(p), SM_TIERS)">{{ displayName(p) }}</p>
                <p class="chart-pos" :class="fitTextClass(p.position, SM_TIERS)">{{ p.position }}</p>
              </div>
            </div>
          </div>
        </template>

        <!-- Tier 4: กลุ่มงาน — แบ่งเป็นแถวละ 4 กล่อง แต่ละแถววาดเส้นแนวนอน+ก้านเหมือนชั้นอื่น
             (แถวละชุดแยกกัน กันเส้นเพี้ยนเวลาห่อบรรทัดของทั้งกลุ่ม) -->
        <template v-if="deptGroupRows.length">
          <template v-for="(row, ri) in deptGroupRows" :key="ri">
            <div class="chart-connector"></div>
            <div class="chart-branch chart-branch-deptrow">
              <div v-for="g in row" :key="g.name" class="chart-branch-item">
                <div class="chart-box">
                  <p class="chart-box-title" :class="fitTextClass(g.name, [[22,'text-sm'],[30,'text-xs'],[Infinity,'text-[11px]']])">{{ g.name }}</p>
                  <div v-if="g.members.length" class="chart-roster">
                    <div v-for="m in g.members" :key="m.id" class="chart-roster-item">
                      <div class="chart-roster-avatar">
                        <img v-if="m.avatar_url" :src="m.avatar_url" class="w-full h-full object-cover object-top"/>
                        <span v-else class="chart-roster-initial">{{ displayName(m)[0] }}</span>
                      </div>
                      <span class="chart-roster-name">{{ displayName(m) }}</span>
                    </div>
                  </div>
                  <p v-else class="chart-box-empty">ยังไม่มีเจ้าหน้าที่</p>
                </div>
              </div>
            </div>
          </template>
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
.chart-branch-item { @apply relative flex flex-col items-center pt-8; }
.chart-branch-item::before {
  /* เส้นสต็มลงมาจากเส้นแนวนอนถึงกล่อง */
  content: ''; position: absolute; top: 0; left: 50%; width: 2px; height: 2rem;
  background: theme('colors.slate.300'); transform: translateX(-50%);
}
.dark .chart-branch-item::before { background: theme('colors.slate.600'); }
.chart-branch-item::after {
  /* เส้นแนวนอนคาดด้านบน เชื่อมกล่องในแถวเดียวกัน — ยื่นเลยขอบกล่องออกไปครึ่งหนึ่งของช่องว่าง (gap-6=24px)
     ทั้งสองข้าง กันเส้นขาดเป็นช่วงๆ ตรงรอยต่อระหว่างกล่อง (ปกติ left/right:0 จะหยุดแค่ขอบกล่องตัวเอง
     ไม่คลุมช่องว่างระหว่างกล่อง) */
  content: ''; position: absolute; top: 0; left: -12px; right: -12px; height: 2px;
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
/* แถวกลุ่มงาน (chart-box กว้าง 256px ×4 + ช่องไฟ ต้องการ ~1130px ถึงจะพอดี 1 แถวจริง)
   แคบกว่านี้ให้ตกลงมาเรียงเป็นคอลัมน์เดียวไปเลย กันเส้นคาดเพี้ยนตอนห่อกลางแถว */
@media (max-width: 1180px) {
  .chart-branch-deptrow { flex-direction: column; }
  .chart-branch-deptrow > .chart-branch-item::after { display: none; }
}

/* ── การ์ดผู้บริหาร (ผอ.เขต/รองผอ.เขต/ผอ.กลุ่ม) ───────────────── */
.chart-card {
  @apply w-44 bg-white dark:bg-slate-800 rounded-2xl shadow-lg border border-slate-100 dark:border-slate-700
         overflow-hidden flex flex-col items-center pt-4 pb-3 px-2 text-center;
}
.chart-card-sm { @apply w-36 pt-3 pb-2 px-1.5; }
.chart-avatar {
  @apply w-16 h-16 rounded-full overflow-hidden bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-2 flex-shrink-0;
}
.chart-avatar-sm { @apply w-12 h-12 mb-1.5; }
.chart-avatar-initial { @apply text-2xl font-extrabold; color: var(--color-primary); }
.chart-name { @apply w-full font-extrabold text-slate-800 dark:text-slate-100 leading-tight whitespace-nowrap overflow-hidden; }
.chart-pos  { @apply w-full text-primary font-bold mt-0.5 leading-tight whitespace-nowrap overflow-hidden; }

/* ── กล่องกลุ่มงาน (แสดงทุกคนในกลุ่มเป็นรูปเล็ก+ชื่อ เรียงตามลำดับ) ── */
.chart-box {
  @apply w-64 bg-white dark:bg-slate-800/60 rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700
         p-4 text-center;
}
.chart-box-title { @apply font-extrabold leading-tight break-keep break-words mb-3; color: var(--color-primary); }
.chart-roster { @apply flex flex-col gap-2; }
.chart-roster-item { @apply flex items-center gap-2 text-left; }
.chart-roster-avatar {
  @apply w-7 h-7 rounded-full overflow-hidden bg-slate-100 dark:bg-slate-700 flex items-center justify-center flex-shrink-0;
}
.chart-roster-initial { @apply text-[10px] font-extrabold; color: var(--color-primary); }
.chart-roster-name { @apply text-xs font-bold text-slate-600 dark:text-slate-300 leading-tight; }
.chart-box-empty { @apply text-xs text-slate-400 italic; }
</style>
