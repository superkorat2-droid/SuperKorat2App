<script setup>
/**
 * PublicLibraryView — คลังหนังสือและคู่มือ (หน้าสาธารณะ)
 *
 * อ่านจาก view `library_public` ไม่ใช่ตาราง `library_items` โดยตรง
 * view กรอง is_published ให้แล้วในตัว จึงไม่ต้อง .eq('is_published', true) ซ้ำ
 * และมีชื่อผู้เผยแพร่มาให้เลย ไม่ต้อง embed profiles ซึ่งผูกกับ column grant
 * ที่ 0060 เปิดไว้ (ดูเหตุผลเต็มใน migration 0068)
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import LibraryGrid from '../components/LibraryGrid.vue'
import { LIBRARY_KINDS, useGroupOptions } from '../composables/useLibraryOptions'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('library', {
  icon: 'document', title: 'คลังหนังสือและคู่มือ', align: 'center',
})
const { groupOptions, groupLabel } = useGroupOptions(config)

const items   = ref([])
const loading = ref(true)

const searchQ     = ref('')
const filterKind  = ref('all')
const filterGroup = ref('all')
const filterPub   = ref('all')
const filterYear  = ref('all')

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase
    .from('library_public')
    .select('*')
    .order('year', { ascending: false, nullsFirst: false })
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
})

const years = computed(() =>
  [...new Set(items.value.map(i => i.year).filter(Boolean))].sort((a, b) => b - a))

const publishers = computed(() => {
  const m = new Map()
  items.value.forEach(i => { if (i.publisher_id && i.publisher_name) m.set(i.publisher_id, i.publisher_name) })
  return [...m.entries()].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name, 'th'))
})

// แสดงเฉพาะกลุ่มที่มีของจริง ไม่ให้ตัวเลือกว่างเปล่าเต็มไปหมด
const usedGroups = computed(() => {
  const keys = new Set(items.value.map(i => i.group_key).filter(Boolean))
  return groupOptions.value.filter(g => keys.has(g.key))
})

const filtered = computed(() => {
  let list = items.value
  if (filterKind.value  !== 'all') list = list.filter(i => i.kind === filterKind.value)
  if (filterGroup.value !== 'all') list = list.filter(i => i.group_key === filterGroup.value)
  if (filterPub.value   !== 'all') list = list.filter(i => i.publisher_id === filterPub.value)
  if (filterYear.value  !== 'all') list = list.filter(i => String(i.year) === filterYear.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) {
    list = list.filter(i =>
      (i.title || '').toLowerCase().includes(q) ||
      (i.description || '').toLowerCase().includes(q) ||
      (i.publisher_name || '').toLowerCase().includes(q))
  }
  return list
})

const isFiltered = computed(() =>
  searchQ.value.trim() || filterKind.value !== 'all' || filterGroup.value !== 'all' ||
  filterPub.value !== 'all' || filterYear.value !== 'all')

function resetFilter() {
  searchQ.value = ''; filterKind.value = 'all'; filterGroup.value = 'all'
  filterPub.value = 'all'; filterYear.value = 'all'
}

const groupLabelOf    = it => groupLabel(it.group_key)
const publisherNameOf = it => it.publisher_name || ''
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
        <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อเรื่อง / ผู้เผยแพร่"
          class="flex-1 min-w-[200px] px-3.5 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>

        <select v-model="filterKind" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกประเภท</option>
          <option v-for="k in LIBRARY_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
        </select>

        <select v-if="usedGroups.length" v-model="filterGroup" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกกลุ่มงาน</option>
          <option v-for="g in usedGroups" :key="g.key" :value="g.key">{{ g.label }}</option>
        </select>

        <select v-if="publishers.length" v-model="filterPub" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกผู้เผยแพร่</option>
          <option v-for="p in publishers" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>

        <select v-if="years.length" v-model="filterYear" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกปี</option>
          <option v-for="y in years" :key="y" :value="String(y)">พ.ศ. {{ y }}</option>
        </select>

        <button v-if="isFiltered" @click="resetFilter" type="button"
          class="px-3 py-2 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
          ล้างตัวกรอง
        </button>
      </div>

      <span v-if="isFiltered && !loading" class="block text-xs text-slate-400">
        พบ {{ filtered.length }} จาก {{ items.length }} รายการ
      </span>

      <LibraryGrid :items="filtered" :loading="loading" :cols="6"
        :group-label-of="groupLabelOf" :publisher-name-of="publisherNameOf"/>

      <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
    </div>

  </div>
</template>
