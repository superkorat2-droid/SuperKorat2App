<script setup>
/**
 * PublicVideosView — วีดิทัศน์การศึกษา (หน้าสาธารณะ)
 *
 * อ่านจาก view `videos_public` ไม่ใช่ตาราง `videos` โดยตรง
 * view กรอง status='approved' ให้แล้วในตัว และแนบชื่อผู้เผยแพร่/โรงเรียนมาให้
 * ไม่ต้อง embed profiles ซึ่ง 0060 revoke จาก anon ไปแล้ว (ดูเหตุผลเต็มใน 0071)
 *
 * ชื่อหัวข้อหน้าแก้ได้จาก /dashboard/page-headers (key 'videos')
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import VideoGrid from '../components/VideoGrid.vue'
import VideoPlayerModal from '../components/VideoPlayerModal.vue'
import { VIDEO_CATEGORIES } from '../composables/useVideos'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('videos', {
  icon: 'news', title: 'วีดิทัศน์การศึกษา', align: 'center',
})

const items   = ref([])
const loading = ref(true)
const playing = ref(null)

const searchQ      = ref('')
const filterCat    = ref('all')
const filterOwner  = ref('all')
const filterYear   = ref('all')

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase
    .from('videos_public')
    .select('*')
    .order('is_featured', { ascending: false })
    .order('sort_order', { ascending: true })
    .order('published_at', { ascending: false, nullsFirst: false })
  items.value = data || []
  loading.value = false
})

/** ตัวเลือกในฟิลเตอร์มาจากของที่มีจริงเท่านั้น ไม่โชว์ตัวเลือกที่กดแล้วว่างเปล่า */
const usedCategories = computed(() => {
  const used = new Set(items.value.map(i => i.category))
  return VIDEO_CATEGORIES.filter(c => used.has(c.value))
})

const owners = computed(() => {
  const map = new Map()
  for (const i of items.value) {
    const name = i.school_name || i.owner_name
    if (name && !map.has(name)) map.set(name, name)
  }
  return [...map.keys()].sort((a, b) => a.localeCompare(b, 'th'))
})

const years = computed(() =>
  [...new Set(items.value.map(i => i.academic_year).filter(Boolean))].sort((a, b) => b - a)
)

const filtered = computed(() => {
  let list = items.value
  if (filterCat.value   !== 'all') list = list.filter(i => i.category === filterCat.value)
  if (filterOwner.value !== 'all') list = list.filter(i => (i.school_name || i.owner_name) === filterOwner.value)
  if (filterYear.value  !== 'all') list = list.filter(i => String(i.academic_year) === filterYear.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) {
    list = list.filter(i =>
      (i.title || '').toLowerCase().includes(q) ||
      (i.description || '').toLowerCase().includes(q) ||
      (i.school_name || '').toLowerCase().includes(q) ||
      (i.owner_name || '').toLowerCase().includes(q))
  }
  return list
})

const isFiltered = computed(() =>
  filterCat.value !== 'all' || filterOwner.value !== 'all' || filterYear.value !== 'all' || !!searchQ.value.trim()
)
function resetFilter() {
  filterCat.value = 'all'; filterOwner.value = 'all'; filterYear.value = 'all'; searchQ.value = ''
}

/** นับยอดชมครั้งเดียวต่อ session — sessionStorage กันรีเฟรชแล้วนับซ้ำ */
async function play(v) {
  playing.value = v
  const key = `vv_${v.id}`
  if (sessionStorage.getItem(key)) return
  sessionStorage.setItem(key, '1')
  await supabase.rpc('record_video_view', { p_video_id: v.id, p_session_id: key })
  const row = items.value.find(i => i.id === v.id)
  if (row) row.view_count = (row.view_count || 0) + 1
}
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name || ''} · ${items.length} คลิป`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="7xl"/>

    <div class="max-w-7xl mx-auto px-4 py-8 space-y-6">

      <div class="glass-card p-4 flex flex-wrap items-center gap-2">
        <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อคลิป / โรงเรียน / ผู้เผยแพร่"
          class="flex-1 min-w-[200px] px-3.5 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>

        <select v-if="usedCategories.length" v-model="filterCat"
          class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกหมวดหมู่</option>
          <option v-for="c in usedCategories" :key="c.value" :value="c.value">{{ c.icon }} {{ c.label }}</option>
        </select>

        <select v-if="owners.length" v-model="filterOwner"
          class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกโรงเรียน/ผู้เผยแพร่</option>
          <option v-for="o in owners" :key="o" :value="o">{{ o }}</option>
        </select>

        <select v-if="years.length" v-model="filterYear"
          class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
          <option value="all">ทุกปีการศึกษา</option>
          <option v-for="y in years" :key="y" :value="String(y)">ปีการศึกษา {{ y }}</option>
        </select>

        <button v-if="isFiltered" @click="resetFilter" type="button"
          class="px-3 py-2 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
          ล้างตัวกรอง
        </button>
      </div>

      <span v-if="isFiltered && !loading" class="block text-xs text-slate-400">
        พบ {{ filtered.length }} จาก {{ items.length }} คลิป
      </span>

      <VideoGrid :items="filtered" :loading="loading" :cols="4" :rows="2" @play="play"/>

      <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
    </div>

    <VideoPlayerModal :item="playing" @close="playing = null"/>
  </div>
</template>
