<script setup>
/**
 * PublicNitetVisitsView — บันทึกการนิเทศที่ ศน. เลือกเผยแพร่ (หน้าสาธารณะ)
 *
 * อ่านจาก view `nithet_visits_public` ไม่ใช่ตาราง `nithet_visits` โดยตรง
 * view กรอง is_public=true AND status='final' ให้แล้ว และ **ตัดจุดที่ควรพัฒนา /
 * ข้อเสนอแนะ / ผู้รับการนิเทศ / การติดตามผล ออกตั้งแต่ระดับฐานข้อมูล**
 * — ข้อมูลอ่อนไหวต่อโรงเรียน ต้องไม่มีทางหลุดแม้เขียนหน้าเว็บพลาด
 *
 * แบ่งหน้าฝั่งเซิร์ฟเวอร์ด้วย .range() หน้าละ 20 (แบบเดียวกับ PublicWorksView)
 * เพราะปีละ 100-300 บันทึกและสะสมทุกปี ดึงมาทั้งหมดทีเดียวไม่ไหว
 * ตัวกรองจึงต้องทำฝั่งเซิร์ฟเวอร์ทั้งชุด ไม่งั้นจะกรองได้แค่ 20 รายการที่เห็น
 *
 * ชื่อหัวข้อหน้าแก้ได้จาก /dashboard/page-headers (key 'nithet-visits')
 */
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import VisitGrid from '../components/nithet/VisitGrid.vue'
import { VISIT_TYPES } from '../composables/useNithetVisits'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('nithet-visits', {
  icon: 'supervision', title: 'บันทึกการนิเทศ ติดตาม และประเมินผล', align: 'center',
})

const PER_PAGE = 20

const items      = ref([])
const totalCount = ref(0)
const loading    = ref(true)
const currentPage = ref(1)

const searchQ    = ref('')
const fType      = ref('all')
const fDistrict  = ref('all')
const fCenter    = ref('all')
const fTopic     = ref('all')
const fFrom      = ref('')
const fTo        = ref('')

// ตัวเลือกในฟิลเตอร์ — ดึงแยกจากรายการหลัก เพราะหน้าเดียวเห็นแค่ 20 แถว
// จะรู้ว่ามีอำเภอ/ศูนย์/ประเด็นอะไรบ้างต้องถามทั้งชุด (เอาเฉพาะคอลัมน์เล็ก ๆ ไม่เอา photos)
const usedTypeValues = ref([])
const districts = ref([])
const centers   = ref([])
const topics    = ref([])

const usedTypes = computed(() => VISIT_TYPES.filter(t => usedTypeValues.value.includes(t.value)))

async function loadFacets() {
  const { data } = await supabase.from('nithet_visits_public')
    .select('visit_type, school_district, school_group, topics')
  const rows = data || []
  usedTypeValues.value = [...new Set(rows.map(r => r.visit_type).filter(Boolean))]
  districts.value = [...new Set(rows.map(r => r.school_district).filter(Boolean))]
    .sort((a, b) => String(a).localeCompare(String(b), 'th'))
  centers.value   = [...new Set(rows.map(r => r.school_group).filter(Boolean))]
    .sort((a, b) => String(a).localeCompare(String(b), 'th'))

  const m = new Map()
  for (const r of rows) for (const t of r.topics || []) m.set(t, (m.get(t) || 0) + 1)
  topics.value = [...m.entries()].sort((a, b) => b[1] - a[1]).map(([t]) => t).slice(0, 30)
}

async function load() {
  loading.value = true
  let q = supabase.from('nithet_visits_public').select('*', { count: 'exact' })

  if (fType.value     !== 'all') q = q.eq('visit_type', fType.value)
  if (fDistrict.value !== 'all') q = q.eq('school_district', fDistrict.value)
  if (fCenter.value   !== 'all') q = q.eq('school_group', fCenter.value)
  if (fTopic.value    !== 'all') q = q.contains('topics', [fTopic.value])
  if (fFrom.value) q = q.gte('visit_date', fFrom.value)
  if (fTo.value)   q = q.lte('visit_date', fTo.value)

  const kw = searchQ.value.trim()
  if (kw) {
    // or() ใช้จุลภาคคั่นเงื่อนไข คำค้นที่มี , ( ) จะทำให้ PostgREST อ่านผิด ต้องกันไว้
    const safe = kw.replace(/[,()]/g, ' ').trim()
    if (safe) {
      q = q.or([
        `title.ilike.%${safe}%`,
        `summary.ilike.%${safe}%`,
        `school_name.ilike.%${safe}%`,
        `place_name.ilike.%${safe}%`,
        `supervisor_name.ilike.%${safe}%`,
      ].join(','))
    }
  }

  const from = (currentPage.value - 1) * PER_PAGE
  const { data, count } = await q
    .order('visit_date', { ascending: false })
    .range(from, from + PER_PAGE - 1)

  items.value      = data || []
  totalCount.value = count || 0
  loading.value    = false
}

onMounted(async () => {
  await fetchConfig()
  await Promise.all([load(), loadFacets()])
})

// เปลี่ยนตัวกรองต้องกลับไปหน้า 1 เสมอ ไม่งั้นค้างอยู่หน้า 5 ของผลลัพธ์ที่มีแค่ 2 หน้า
watch([fType, fDistrict, fCenter, fTopic, fFrom, fTo], () => {
  currentPage.value = 1
  load()
})

let searchTimer
watch(searchQ, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { currentPage.value = 1; load() }, 400)
})

watch(currentPage, async () => {
  await load()
  window.scrollTo({ top: 0, behavior: 'smooth' })
})

const totalPages = computed(() => Math.ceil(totalCount.value / PER_PAGE))

function pageRange() {
  const p = currentPage.value, t = totalPages.value
  const pages = []
  if (t <= 7) { for (let i = 1; i <= t; i++) pages.push(i) }
  else {
    pages.push(1)
    if (p > 3) pages.push('...')
    for (let i = Math.max(2, p - 1); i <= Math.min(t - 1, p + 1); i++) pages.push(i)
    if (p < t - 2) pages.push('...')
    pages.push(t)
  }
  return pages
}

const isFiltered = computed(() =>
  fType.value !== 'all' || fDistrict.value !== 'all' || fCenter.value !== 'all' ||
  fTopic.value !== 'all' || !!fFrom.value || !!fTo.value || !!searchQ.value.trim())

function resetFilter() {
  fType.value = fDistrict.value = fCenter.value = fTopic.value = 'all'
  fFrom.value = fTo.value = ''
  searchQ.value = ''
  currentPage.value = 1
}

const selCls = 'px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary'
const pageBtn = 'w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-colors disabled:opacity-40 disabled:cursor-not-allowed'
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name || ''} · ${totalCount} บันทึก`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="7xl"/>

    <div class="max-w-7xl mx-auto px-4 py-8 space-y-6">

      <div class="glass-card p-4 flex flex-wrap items-center gap-2">
        <input v-model="searchQ" type="search" placeholder="ค้นหาเรื่อง / โรงเรียน / สถานที่ / ผู้นิเทศ"
          class="flex-1 min-w-[200px] px-3.5 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>

        <select v-if="usedTypes.length > 1" v-model="fType" :class="selCls">
          <option value="all">ทุกประเภท</option>
          <option v-for="t in usedTypes" :key="t.value" :value="t.value">{{ t.icon }} {{ t.label }}</option>
        </select>

        <select v-if="districts.length" v-model="fDistrict" :class="selCls">
          <option value="all">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">{{ d }}</option>
        </select>

        <select v-if="centers.length" v-model="fCenter" :class="selCls">
          <option value="all">ทุกศูนย์เครือข่าย</option>
          <option v-for="c in centers" :key="c" :value="c">{{ c }}</option>
        </select>

        <select v-if="topics.length" v-model="fTopic" :class="selCls">
          <option value="all">ทุกประเด็น</option>
          <option v-for="t in topics" :key="t" :value="t">{{ t }}</option>
        </select>

        <input type="date" v-model="fFrom" title="ตั้งแต่วันที่" :class="selCls"/>
        <input type="date" v-model="fTo" title="ถึงวันที่" :class="selCls"/>

        <button v-if="isFiltered" @click="resetFilter" type="button"
          class="px-3 py-2 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
          ล้างตัวกรอง
        </button>
      </div>

      <span v-if="totalCount && !loading" class="block text-xs text-slate-400">
        แสดง {{ Math.min((currentPage - 1) * PER_PAGE + 1, totalCount) }}–{{ Math.min(currentPage * PER_PAGE, totalCount) }}
        จาก {{ totalCount.toLocaleString() }} บันทึก
      </span>

      <div v-if="!loading && !items.length" class="text-center py-16 glass-card text-slate-400">
        <p class="font-medium">{{ isFiltered ? 'ไม่พบบันทึกตามเงื่อนไขที่เลือก' : 'ยังไม่มีบันทึกที่เผยแพร่' }}</p>
        <button v-if="isFiltered" @click="resetFilter" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
        <p v-else class="text-sm mt-1">ศึกษานิเทศก์เลือกเผยแพร่เป็นรายบันทึกได้จากหน้าบันทึกการนิเทศ</p>
      </div>

      <VisitGrid v-else :items="items" :loading="loading" :cols="4" :rows="5"/>

      <!-- แบ่งหน้า -->
      <div v-if="totalPages > 1" class="flex items-center justify-center gap-1.5 py-2">
        <button @click="currentPage--" :disabled="currentPage === 1" :class="pageBtn" aria-label="หน้าก่อนหน้า">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>
          </svg>
        </button>
        <template v-for="(p, i) in pageRange()" :key="`${p}-${i}`">
          <span v-if="p === '...'" class="w-9 h-9 flex items-center justify-center text-slate-400 text-sm">…</span>
          <button v-else @click="currentPage = p"
            :class="['w-9 h-9 flex items-center justify-center rounded-xl text-sm font-bold transition-colors',
              currentPage === p ? 'bg-primary text-white border border-primary'
                                : 'border border-slate-200 text-slate-600 hover:bg-primary hover:text-white hover:border-primary']">
            {{ p }}
          </button>
        </template>
        <button @click="currentPage++" :disabled="currentPage === totalPages" :class="pageBtn" aria-label="หน้าถัดไป">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>
          </svg>
        </button>
      </div>

      <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
    </div>
  </div>
</template>
