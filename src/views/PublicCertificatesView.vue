<script setup>
/**
 * PublicCertificatesView — คลังเกียรติบัตร (หน้าสาธารณะ)
 *
 * อ่านจาก view `certificates_public` (กรอง is_published ให้แล้วในตัว)
 * คลิกการ์ดเปิดลิงก์เกียรติบัตรจริงในแท็บใหม่ทันที ไม่มีหน้ารายละเอียด
 * เพราะเนื้อหาจริงอยู่ปลายทาง (Google Apps Script / Drive) อยู่แล้ว
 */
import { ref, computed, watch, nextTick, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import CertificateCard from '../components/CertificateCard.vue'
import { useGroupOptions } from '../composables/useLibraryOptions'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('certificates', {
  icon: 'document', title: 'คลังเกียรติบัตร', align: 'center',
})
const { groupOptions, groupLabel } = useGroupOptions(config)

const items   = ref([])
const loading = ref(true)

const searchQ     = ref('')
const filterGroup = ref('all')

// แบ่งหน้าแบบเดียวกับหน้าข่าวสาร: 12 ใบ/หน้า (4 คอลัมน์ x 3 แถว)
const page      = ref(1)
const PAGE_SIZE = 12
const gridRef   = ref(null)

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase
    .from('certificates_public')
    .select('*')
    .order('cert_date', { ascending: false, nullsFirst: false })
    .order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
})

// แสดงเฉพาะกลุ่มที่มีของจริง ไม่ให้ตัวเลือกว่างเปล่าเต็มไปหมด
const usedGroups = computed(() => {
  const keys = new Set(items.value.map(i => i.group_key).filter(Boolean))
  return groupOptions.value.filter(g => keys.has(g.key))
})

const filtered = computed(() => {
  let list = items.value
  if (filterGroup.value !== 'all') list = list.filter(i => i.group_key === filterGroup.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) {
    list = list.filter(i =>
      (i.title || '').toLowerCase().includes(q) ||
      (i.responsible_names || '').toLowerCase().includes(q))
  }
  // ปักหมุดขึ้นก่อน — sort ของ JS เสถียร ลำดับวันที่เดิมในแต่ละกลุ่มจึงไม่เปลี่ยน
  return [...list].sort((a, b) => (b.is_pinned ? 1 : 0) - (a.is_pinned ? 1 : 0))
})

watch([searchQ, filterGroup], () => { page.value = 1 })

const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / PAGE_SIZE)))
const paginated  = computed(() => filtered.value.slice((page.value - 1) * PAGE_SIZE, page.value * PAGE_SIZE))

// กดเลขหน้าแล้วเลื่อนมาที่แถวการ์ด ไม่ต้องไถผ่าน Hero ทุกครั้ง (เปลี่ยนจากการค้นหา/กรองไม่เลื่อน)
async function goPage(n) {
  if (n < 1 || n > totalPages.value || n === page.value) return
  page.value = n
  await nextTick()
  gridRef.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

const isFiltered = computed(() => searchQ.value.trim() || filterGroup.value !== 'all')

function resetFilter() { searchQ.value = ''; filterGroup.value = 'all' }
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name || ''} · ${items.length} รายการ`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="7xl"/>

    <div class="max-w-7xl mx-auto px-4 py-8 space-y-6">

      <!-- ตัวกรอง -->
      <div class="glass-card p-4 flex flex-wrap items-center gap-2">
        <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อเรื่อง / ผู้รับผิดชอบ"
          class="flex-1 min-w-[200px] px-3.5 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>

        <select v-if="usedGroups.length" v-model="filterGroup" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกกลุ่มงาน</option>
          <option v-for="g in usedGroups" :key="g.key" :value="g.key">{{ g.label }}</option>
        </select>

        <button v-if="isFiltered" @click="resetFilter" type="button"
          class="px-3 py-2 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
          ล้างตัวกรอง
        </button>
      </div>

      <span v-if="isFiltered && !loading" class="block text-xs text-slate-400">
        พบ {{ filtered.length }} จาก {{ items.length }} รายการ
      </span>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
      <div v-else-if="!filtered.length" class="text-center py-16 text-slate-400">
        <span class="block text-4xl mb-3 opacity-40">📜</span>
        <span class="block font-bold">ยังไม่มีเกียรติบัตร</span>
      </div>
      <template v-else>
        <!-- flex + justify-center: แถวที่ไม่เต็ม (เช่น มีแค่ 1-3 ใบ หรือแถวสุดท้าย) จัดกึ่งกลาง ไม่ชิดซ้าย
             ความกว้างคำนวณให้เท่ากริด 1/2/4 คอลัมน์ (gap-5 = 1.25rem) การ์ดจึงขนาดเท่ากันทุกใบ -->
        <div ref="gridRef" class="flex flex-wrap justify-center gap-5 scroll-mt-28">
          <div v-for="c in paginated" :key="c.id"
            class="w-full sm:w-[calc(50%-0.625rem)] lg:w-[calc(25%-0.9375rem)]">
            <CertificateCard :item="c" :group-label="groupLabel"/>
          </div>
        </div>

        <!-- เลขหน้า (รูปแบบเดียวกับหน้าข่าวสาร) -->
        <div v-if="totalPages > 1" class="flex items-center justify-center gap-2 pt-4">
          <button @click="goPage(page - 1)" :disabled="page === 1" type="button" aria-label="หน้าก่อนหน้า"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-all disabled:opacity-30">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/></svg>
          </button>
          <button v-for="n in totalPages" :key="n" @click="goPage(n)" type="button"
            :class="['w-9 h-9 rounded-xl text-sm font-bold border transition-all',
              page === n ? 'bg-primary text-white border-primary shadow-md' : 'border-white/80 bg-white/60 backdrop-blur text-slate-600 hover:border-primary/40']">
            {{ n }}
          </button>
          <button @click="goPage(page + 1)" :disabled="page === totalPages" type="button" aria-label="หน้าถัดไป"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-white/80 bg-white/60 backdrop-blur text-slate-500 hover:bg-primary hover:text-white hover:border-primary transition-all disabled:opacity-30">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
          </button>
        </div>
      </template>

      <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
    </div>
  </div>
</template>
