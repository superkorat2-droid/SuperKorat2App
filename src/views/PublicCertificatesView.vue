<script setup>
/**
 * PublicCertificatesView — คลังเกียรติบัตร (หน้าสาธารณะ)
 *
 * อ่านจาก view `certificates_public` (กรอง is_published ให้แล้วในตัว)
 * คลิกการ์ดเปิดลิงก์เกียรติบัตรจริงในแท็บใหม่ทันที ไม่มีหน้ารายละเอียด
 * เพราะเนื้อหาจริงอยู่ปลายทาง (Google Apps Script / Drive) อยู่แล้ว
 */
import { ref, computed, onMounted } from 'vue'
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
  return list
})

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
      <div v-else class="flex flex-wrap gap-4">
        <div v-for="c in filtered" :key="c.id" class="w-[calc(50%-0.5rem)] sm:w-[calc(33.333%-0.75rem)] md:w-[calc(25%-0.75rem)] lg:w-[calc(16.666%-0.85rem)]">
          <CertificateCard :item="c" :group-label="groupLabel"/>
        </div>
      </div>

      <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
    </div>
  </div>
</template>
